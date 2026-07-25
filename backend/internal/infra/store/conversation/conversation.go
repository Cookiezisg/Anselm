// Package conversation is the orm-backed conversationdomain.Repository: a workspace-scoped,
// soft-deleted thread table. Workspace isolation + soft-delete are automatic (orm fills/filters
// from ctx), so no method hand-writes a predicate. List is always pinned-first; its secondary key
// follows ListFilter.Sort — activity (last_message_at) / created (created_at) via Page, or name
// (title COLLATE NOCASE) via PageAsc — each keyset-paginated on its own column.
//
// Package conversation 是 conversationdomain.Repository 的 orm 实现：按 workspace、软删的线程表。
// workspace 隔离 + 软删自动（orm 据 ctx 填/过滤），故无方法手写谓词。List 恒置顶优先；次键随 ListFilter.Sort——
// activity（last_message_at）/ created（created_at）经 Page，或 name（title COLLATE NOCASE）经 PageAsc——各按自身列 keyset 分页。
package conversation

import (
	"context"
	"errors"
	"fmt"
	"time"

	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

// Schema is the conversations DDL, exported as ordered idempotent statements for bootstrap to
// apply via db.Migrate. A business/Log table with soft-delete (deleted_at) per D1; the partial
// list index keys the pinned-first, newest-next ordering the frontend renders.
//
// Schema 是 conversations 表 DDL，按序幂等语句导出、由 bootstrap 经 db.Migrate 应用。业务表带
// 软删（deleted_at，D1）；partial 列表索引键住「置顶优先、再最新」的前端渲染顺序。
var Schema = []string{
	`CREATE TABLE IF NOT EXISTS conversations (
		id                       TEXT PRIMARY KEY,
		workspace_id             TEXT NOT NULL,
		title                    TEXT NOT NULL DEFAULT '',
		auto_titled              INTEGER NOT NULL DEFAULT 0,
		system_prompt            TEXT NOT NULL DEFAULT '',
		summary                  TEXT NOT NULL DEFAULT '',
		summary_covers_up_to_seq INTEGER NOT NULL DEFAULT 0,
		attached_documents       TEXT NOT NULL DEFAULT '[]',
		archived                 INTEGER NOT NULL DEFAULT 0,
		pinned                   INTEGER NOT NULL DEFAULT 0,
		model_override           TEXT,
		created_at               DATETIME NOT NULL,
		updated_at               DATETIME NOT NULL,
		last_message_at          DATETIME NOT NULL,
		unread                   INTEGER NOT NULL DEFAULT 0,
		deleted_at               DATETIME
	)`,
	`CREATE INDEX IF NOT EXISTS idx_conversations_ws_list ON conversations(workspace_id, pinned DESC, last_message_at DESC, id DESC) WHERE deleted_at IS NULL`,
	// sort=name covering index: pinned-first, then title A–Z (COLLATE NOCASE, matching the ORDER BY +
	// keyset comparison), id ASC tiebreaker. Mirrors the activity index for the title-keyed page.
	// sort=name 覆盖索引:置顶优先、再 title A–Z（COLLATE NOCASE，与 ORDER BY + keyset 比较一致）、id 升序 tiebreaker。
	`CREATE INDEX IF NOT EXISTS idx_conversations_ws_title ON conversations(workspace_id, pinned DESC, title COLLATE NOCASE ASC, id ASC) WHERE deleted_at IS NULL`,
	// sort=created covering index: pinned-first, then created_at DESC, id DESC — matches the created-sort
	// ORDER BY + keyset so a rail scrolled by creation order is an index range scan, not a full-workspace
	// scan + temp-b-tree filesort (which the keyset cursor could not shrink). Sibling of the two above; a
	// documented, reachable sort mode must not degrade to O(N²) on a long-lived thread list (R12 family).
	// sort=created 覆盖索引:置顶优先、再 created_at DESC、id DESC——与 created 排序的 ORDER BY + keyset 一致,
	// 使按创建序翻 rail 是索引区间扫而非全工作区扫 + 临时 b-tree filesort（keyset 游标无从收窄）。与上两条同族;
	// 文档化且可达的排序模式不该在长期线程列表上退化成 O(N²)（R12 族）。
	`CREATE INDEX IF NOT EXISTS idx_conversations_ws_created ON conversations(workspace_id, pinned DESC, created_at DESC, id DESC) WHERE deleted_at IS NULL`,

	// Column evolution — fork lineage (WRK-077 CH-b). ADD COLUMN (not baked into the CREATE) so an
	// existing install gains the pair on next boot; SQLite has no ADD COLUMN IF NOT EXISTS, so
	// re-runs rely on db.Migrate treating "duplicate column name" on an ALTER … ADD COLUMN as
	// already-applied. NOT NULL DEFAULT '' rather than NULLable (the trigger.paused precedent): the
	// domain field is a plain string, and "" already means "not a fork" — a nullable column would
	// buy a second spelling of the same absence and a nil scan for every pre-fork row. Deliberately
	// UNindexed: lineage is read one row at a time (the open thread's own head), never filtered on.
	//
	// 列演化——分叉血缘（WRK-077 CH-b）。用 ADD COLUMN（不并进 CREATE）使已有安装下次启动补这对列；
	// SQLite 无 ADD COLUMN IF NOT EXISTS，重复执行靠 db.Migrate 把 ALTER … ADD COLUMN 的
	// "duplicate column name" 视作已应用。用 NOT NULL DEFAULT '' 而非可空（照 trigger.paused 先例）：
	// domain 字段是纯 string，且 "" 已表达「不是分叉」——可空列只会为同一种「不存在」多买一种拼法 +
	// 给每条 fork 之前的旧行一次 nil 扫描。**刻意不建索引**：血缘每次只读一行（当前线程自己的头行）、
	// 从不作过滤条件。
	`ALTER TABLE conversations ADD COLUMN forked_from_conversation_id TEXT NOT NULL DEFAULT ''`,
	`ALTER TABLE conversations ADD COLUMN forked_from_message_id TEXT NOT NULL DEFAULT ''`,

	// Column evolution — the residency (WRK-077 WD1). Third use of the same idempotent-by-outcome ADD
	// COLUMN path as the fork-lineage pair above, for the same reasons: an existing install gains it on
	// next boot, and a re-run relies on db.Migrate reading "duplicate column name" as already-applied.
	// TEXT NOT NULL DEFAULT '' rather than NULLable — '' already means "not mounted".
	//
	// Now INDEXED (WD1.5): the rail groups by this column and pages inside one group, so the column went
	// from "read one row by primary key per turn" to "GROUP BY over the whole workspace on every rail
	// paint" — which is exactly the load the WD1 comment said would earn the index its keep. The index
	// below is that index; see idx_conversations_ws_workdir.
	//
	// 列演化——驻地（WRK-077 WD1）。与上方分叉血缘两列同一条结果幂等 ADD COLUMN 径的第三次使用,理由相同:
	// 已有安装下次启动补列、重复执行靠 db.Migrate 把 "duplicate column name" 视作已应用。用 TEXT NOT NULL
	// DEFAULT '' 而非可空——'' 已表达「未挂」。
	//
	// **现已建索引（WD1.5）**:rail 按本列分组、并在单个组内翻页,故本列从「每回合按主键读一行」变成了「每次
	// rail 绘制都对整个 workspace 做一次 GROUP BY」——正是 WD1 注释所说「索引挣得回它的钱」的那种负载。下面
	// 那条就是它，见 idx_conversations_ws_workdir。
	`ALTER TABLE conversations ADD COLUMN work_dir TEXT NOT NULL DEFAULT ''`,

	// Residency index (WRK-077 WD1.5) — added AFTER the ADD COLUMN it depends on (statements are ordered
	// and applied in order; indexing a column that does not exist yet fails on a fresh install). It serves
	// BOTH of the rail's residency reads with one structure: the `workdir-groups` GROUP BY walks
	// (workspace_id, work_dir) as an index range and gets `MAX(last_message_at)` from the trailing key
	// without touching the table, and `?workDir=<path>` page-scans one contiguous run of the same index in
	// the exact order the page needs. `pinned` is deliberately NOT in the key: the pin predicate cuts a
	// single-user handful of rows and putting it ahead of work_dir would break the grouping's range scan.
	//
	// 驻地索引（WRK-077 WD1.5）——排在它所依赖的 ADD COLUMN **之后**（语句有序、按序应用;给一个还不存在的列
	// 建索引会在全新安装上失败）。一个结构服务 rail 的**两条**驻地读:`workdir-groups` 的 GROUP BY 把
	// (workspace_id, work_dir) 当索引区间走、并从尾键直接拿到 `MAX(last_message_at)` 而不碰表；`?workDir=<path>`
	// 则以页所需的**确切顺序**扫同一索引里一段连续区间。`pinned` **刻意不进键**:置顶谓词切掉的是单用户量级的
	// 寥寥几行，把它放在 work_dir 之前会毁掉分组的区间扫。
	`CREATE INDEX IF NOT EXISTS idx_conversations_ws_workdir ON conversations(workspace_id, work_dir, last_message_at DESC) WHERE deleted_at IS NULL`,
}

// Store implements conversationdomain.Repository over pkg/orm.
//
// Store 基于 pkg/orm 实现 conversationdomain.Repository。
type Store struct {
	db   *ormpkg.DB
	repo *ormpkg.Repo[conversationdomain.Conversation]
}

// New constructs a Store bound to the conversations table.
//
// New 构造绑定 conversations 表的 Store。
func New(db *ormpkg.DB) *Store {
	return &Store{db: db, repo: ormpkg.For[conversationdomain.Conversation](db, "conversations")}
}

var _ conversationdomain.Repository = (*Store)(nil)

func (s *Store) Insert(ctx context.Context, c *conversationdomain.Conversation) error {
	if err := s.repo.Create(ctx, c); err != nil {
		return fmt.Errorf("conversationstore.Insert: %w", err)
	}
	return nil
}

func (s *Store) Get(ctx context.Context, id string) (*conversationdomain.Conversation, error) {
	c, err := s.repo.Get(ctx, id)
	if errors.Is(err, ormpkg.ErrNotFound) {
		return nil, conversationdomain.ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("conversationstore.Get: %w", err)
	}
	return c, nil
}

func (s *Store) GetBatch(ctx context.Context, ids []string) ([]*conversationdomain.Conversation, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	rows, err := s.repo.WhereIn("id", toAny(ids)...).Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("conversationstore.GetBatch: %w", err)
	}
	return rows, nil
}

// List returns one page, pinned-first, with the secondary key chosen by filter.Sort (default
// activity). The cursor keys only (sortColumn, id) — the leading pinned partition relies on all pins
// landing on page one (few, single-user), so it never drifts across pages. PageKeyset aligns the
// cursor column with the ORDER BY's sort column (the keyset invariant); the name path additionally
// keeps that alignment collation-sensitive (COLLATE NOCASE on column, ORDER BY, and index alike).
//
// List 返一页，置顶优先，次键由 filter.Sort 选（默认 activity）。游标只键 (sortColumn, id)——置顶分区靠
// 「所有置顶都落首页」（少、单用户）故不跨页漂移。PageKeyset 让游标列与 ORDER BY 排序列对齐（keyset 不变量）；
// name 路径另把这个对齐做成对 collation 敏感（列 / ORDER BY / 索引同 COLLATE NOCASE）。
func (s *Store) List(ctx context.Context, filter conversationdomain.ListFilter) ([]*conversationdomain.Conversation, string, error) {
	q := s.repo.Query()
	// Exactly one archived predicate per scope (or none for ArchiveAll). ArchiveAll is the rail's
	// "show archived" mode — active + archived in one list, each row carrying its archived flag.
	// 每个 scope 恰好一个 archived 谓词（ArchiveAll 不加）。ArchiveAll = rail「显示已归档」：活跃+归档同列、各带 archived 标志。
	switch filter.Archive {
	case conversationdomain.ArchiveArchived:
		q = q.WhereEq("archived", true)
	case conversationdomain.ArchiveAll:
		// no archived predicate — both active and archived
	default: // ArchiveActive
		q = q.WhereEq("archived", false)
	}
	// Exactly one pin predicate per scope (or none for PinAny). The grouped rail asks for the two halves
	// separately so each thread is rendered exactly once. 每个 scope 恰一个置顶谓词（PinAny 不加）。
	switch filter.Pinned {
	case conversationdomain.PinPinned:
		q = q.WhereEq("pinned", true)
	case conversationdomain.PinUnpinned:
		q = q.WhereEq("pinned", false)
	default: // PinAny
	}
	// The residency filter's three states (see ListFilter.WorkDir): nil adds nothing, &"" asks for the
	// unmounted ones — an equality on the empty string, NOT "no filter", which is exactly why the field is a
	// pointer — and &path narrows to one group.
	// 驻地过滤的三态（见 ListFilter.WorkDir）:nil 什么都不加、&"" 要未挂的那些（对**空串**的等值比较、**不是**
	// 「不过滤」，这正是该字段是指针的原因）、&path 收窄到一个组。
	if filter.WorkDir != nil {
		q = q.WhereEq("work_dir", *filter.WorkDir)
	}
	q = q.WhereLike("title", filter.Search)
	// Sort is always pinned-first; the secondary key is recency (default) or creation order. The
	// keyset cursor MUST key the same column the ORDER BY sorts by — PageKeyset aligns them, so the
	// cursor's WHERE/encode track the chosen column (else pages skip/duplicate). Unknown/empty sort
	// → activity (no 400 on a sort typo).
	//
	// 排序恒置顶优先；次键为最近活跃（默认）或创建序。keyset 游标必须键 ORDER BY 所按的同一列——PageKeyset
	// 对齐之，使游标 WHERE/encode 跟选定列（否则跨页漏/重）。未知/空 sort → activity（不为 sort 笔误报 400）。
	var (
		rows []*conversationdomain.Conversation
		next string
		err  error
	)
	if filter.Sort == conversationdomain.ListSortName {
		// Title A–Z (case-insensitive), pinned-first, id ASC tiebreaker — a STRING keyset via PageAsc
		// (ascending). Order, keyset column, and the idx_conversations_ws_title index all agree on
		// COLLATE NOCASE + direction (the keyset invariant, collation-sensitive here).
		// title A–Z（大小写不敏感）、置顶优先、id 升序 tiebreaker——经 PageAsc 的字符串升序 keyset。Order / keyset 列 /
		// idx_conversations_ws_title 索引三处在 COLLATE NOCASE + 方向上一致（keyset 不变量，此处对 collation 敏感）。
		rows, next, err = q.Order("pinned DESC, title COLLATE NOCASE ASC, id ASC").PageKeyset("title").PageAsc(ctx, filter.Cursor, filter.Limit)
	} else {
		// activity (default) / created: time-keyed, pinned-first, descending via Page.
		// activity（默认）/ created：时间键、置顶优先、降序，经 Page。
		keyset := "last_message_at"
		if filter.Sort == conversationdomain.ListSortCreated {
			keyset = "created_at"
		}
		rows, next, err = q.Order("pinned DESC, "+keyset+" DESC, id DESC").PageKeyset(keyset).Page(ctx, filter.Cursor, filter.Limit)
	}
	if err != nil {
		return nil, "", fmt.Errorf("conversationstore.List: %w", err)
	}
	return rows, next, nil
}

// TouchLastMessage sets last_message_at and the unread flag on one conversation in ONE UPDATE (chat
// calls it when a message lands). Folding unread into the same UPDATE keeps it atomic with the recency
// bump — the user-send path (unread=false) can never half-commit into "your own message looks unread".
// unread is not a sort/cursor key, so the partial list indexes are untouched.
//
// TouchLastMessage 在一条 UPDATE 里设某对话的 last_message_at 与 unread 标志（chat 在消息落地时调）。把 unread 折进
// 同一条 UPDATE 使其与 recency 刷新原子——用户发送路径（unread=false）绝不会半提交成「自己的消息看着未读」。unread 非
// 排序/游标键，partial 列表索引不动。
func (s *Store) TouchLastMessage(ctx context.Context, id string, t time.Time, unread bool) error {
	if _, err := s.repo.Query().WhereEq("id", id).Updates(ctx, map[string]any{"last_message_at": t, "unread": unread}); err != nil {
		return fmt.Errorf("conversationstore.TouchLastMessage: %w", err)
	}
	return nil
}

// MarkSeen clears the unread flag on one conversation (the :seen action — the user opened the thread
// without sending). A single focused UPDATE on unread only; idempotent (an unknown id matches 0 rows
// and returns nil). last_message_at is untouched, so opening a thread never reorders the list.
//
// MarkSeen 清某对话的 unread 标志（:seen 动作——用户没发、只是打开了线程）。只针对 unread 列的聚焦 UPDATE；幂等
// （未知 id 匹配 0 行、返 nil）。不动 last_message_at，故打开线程绝不重排列表。
func (s *Store) MarkSeen(ctx context.Context, id string) error {
	if _, err := s.repo.Query().WhereEq("id", id).Updates(ctx, map[string]any{"unread": false}); err != nil {
		return fmt.Errorf("conversationstore.MarkSeen: %w", err)
	}
	return nil
}

func (s *Store) Update(ctx context.Context, c *conversationdomain.Conversation) error {
	if err := s.repo.Save(ctx, c); err != nil {
		return fmt.Errorf("conversationstore.Update: %w", err)
	}
	return nil
}

func (s *Store) SoftDelete(ctx context.Context, id string) error {
	found, err := s.repo.Delete(ctx, id)
	if err != nil {
		return fmt.Errorf("conversationstore.SoftDelete: %w", err)
	}
	if !found {
		return conversationdomain.ErrNotFound
	}
	return nil
}

// toAny widens a []string to []any for orm WhereIn variadic args.
//
// toAny 把 []string 拓宽为 []any 以喂 orm WhereIn 变长参数。
func toAny(ss []string) []any {
	out := make([]any, len(ss))
	for i, v := range ss {
		out[i] = v
	}
	return out
}
