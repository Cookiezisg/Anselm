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
	"encoding/json"
	"errors"
	"fmt"
	"time"

	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	paginationpkg "github.com/sunweilin/anselm/backend/internal/pkg/pagination"
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

// conversationTimeCursor carries the secondary time/id key, the pinned partition it belongs to, and
// the normalized list-query scope. The partition is part of the opaque cursor because pinned-first is
// a two-part order; the scope is part of it because a cursor from another filter can silently skip rows.
//
// conversationTimeCursor 载次键时间/id、所属置顶分区及归一化的列表查询 scope。置顶优先是两段式排序，分区必须进入
// opaque cursor；scope 也必须进入，因为另一个过滤器铸出的 cursor 可能静默漏行。
type conversationTimeCursor struct {
	Key    time.Time `json:"c"`
	ID     string    `json:"i"`
	Pinned *bool     `json:"p,omitempty"`
	Start  bool      `json:"s,omitempty"`
	Scope  string    `json:"f"`
}

// conversationStringCursor is the same partition-aware cursor for sort=name's string keyset.
//
// conversationStringCursor 是 sort=name 字符串 keyset 的同款分区游标。
type conversationStringCursor struct {
	Key    string `json:"c"`
	ID     string `json:"i"`
	Pinned *bool  `json:"p,omitempty"`
	Start  bool   `json:"s,omitempty"`
	Scope  string `json:"f"`
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

// listQuery applies the filters shared by one pinned partition. The partition predicate is deliberately
// added here rather than in ListFilter: a complete pinned-first page walk queries the true and false
// partitions independently, then joins them in order without asking the generic ORM cursor to understand
// a leading boolean sort key.
//
// listQuery 应用一个置顶分区共用的过滤条件。分区谓词刻意在这里追加而非塞进 ListFilter：完整的置顶优先分页分别
// 查询 true/false 两段，再按顺序拼接，不要求通用 ORM cursor 理解一个前置布尔排序键。
func (s *Store) listQuery(filter conversationdomain.ListFilter, pinned bool) *ormpkg.Query[conversationdomain.Conversation] {
	q := s.repo.Query().WhereEq("pinned", pinned)
	switch filter.Archive {
	case conversationdomain.ArchiveArchived:
		q = q.WhereEq("archived", true)
	case conversationdomain.ArchiveAll:
		// no archived predicate — both active and archived
	default: // ArchiveActive
		q = q.WhereEq("archived", false)
	}
	if filter.WorkDir != nil {
		q = q.WhereEq("work_dir", *filter.WorkDir)
	}
	return q.WhereLike("title", filter.Search)
}

// listPartitionPage pages one pinned state with the generic, single-partition keyset. Since the query
// already has `pinned = ?`, Page's secondary cursor is now a complete order key within that partition.
//
// listPartitionPage 在一个置顶态内分页。查询已经带 `pinned = ?`，故 Page 的次键游标在该分区内就是完整排序键。
func (s *Store) listPartitionPage(ctx context.Context, filter conversationdomain.ListFilter, pinned bool, cursor string, limit int) ([]*conversationdomain.Conversation, string, error) {
	q := s.listQuery(filter, pinned)
	if filter.Sort == conversationdomain.ListSortName {
		return q.Order("title COLLATE NOCASE ASC, id ASC").PageKeyset("title").PageAsc(ctx, cursor, limit)
	}
	keyset := "last_message_at"
	if filter.Sort == conversationdomain.ListSortCreated {
		keyset = "created_at"
	}
	return q.Order(keyset+" DESC, id DESC").PageKeyset(keyset).Page(ctx, cursor, limit)
}

func pinnedPartitions(scope conversationdomain.PinScope) []bool {
	switch scope {
	case conversationdomain.PinPinned:
		return []bool{true}
	case conversationdomain.PinUnpinned:
		return []bool{false}
	default:
		return []bool{true, false}
	}
}

func malformedConversationCursor(reason string) error {
	return fmt.Errorf("%w: conversation list cursor %s", paginationpkg.ErrMalformedCursor, reason)
}

// conversationCursorScopeKey normalizes the public list axes into a stable opaque scope. A cursor
// from another sort/filter is not merely suboptimal: applying it can silently skip rows, so the store
// rejects it instead of relying on every caller to remember the reset rule.
//
// conversationCursorScopeKey 将公开列表轴归一成稳定的 opaque scope。另一个排序/过滤铸出的 cursor 不是「略差」而是
// 可能静默漏行，故 store 主动拒绝，不把完整性寄托在每个调用方都记住重置规则。
type conversationCursorScope struct {
	Archive string  `json:"a"`
	Sort    string  `json:"s"`
	Search  string  `json:"q"`
	Pinned  string  `json:"p"`
	WorkDir *string `json:"w,omitempty"`
}

func conversationCursorScopeKey(filter conversationdomain.ListFilter) string {
	sort := string(conversationdomain.ListSortActivity)
	switch filter.Sort {
	case conversationdomain.ListSortCreated, conversationdomain.ListSortName:
		sort = string(filter.Sort)
	}
	archive := string(conversationdomain.ArchiveActive)
	switch filter.Archive {
	case conversationdomain.ArchiveArchived, conversationdomain.ArchiveAll:
		archive = string(filter.Archive)
	}
	pinned := string(conversationdomain.PinAny)
	switch filter.Pinned {
	case conversationdomain.PinPinned, conversationdomain.PinUnpinned:
		pinned = string(filter.Pinned)
	}
	raw, _ := json.Marshal(conversationCursorScope{
		Archive: archive,
		Sort:    sort,
		Search:  filter.Search,
		Pinned:  pinned,
		WorkDir: filter.WorkDir,
	})
	return string(raw)
}

func encodeTimeConversationCursor(raw string, pinned bool, scope string) (string, error) {
	var c paginationpkg.Cursor
	if err := paginationpkg.DecodeCursor(raw, &c); err != nil {
		return "", err
	}
	return paginationpkg.EncodeCursor(conversationTimeCursor{Key: c.Key, ID: c.ID, Pinned: &pinned, Scope: scope})
}

func encodeStringConversationCursor(raw string, pinned bool, scope string) (string, error) {
	var c paginationpkg.StringCursor
	if err := paginationpkg.DecodeCursor(raw, &c); err != nil {
		return "", err
	}
	return paginationpkg.EncodeCursor(conversationStringCursor{Key: c.Key, ID: c.ID, Pinned: &pinned, Scope: scope})
}

func encodeStartConversationCursor(pinned bool, scope string) (string, error) {
	return paginationpkg.EncodeCursor(conversationTimeCursor{Pinned: &pinned, Start: true, Scope: scope})
}

func encodeStartConversationStringCursor(pinned bool, scope string) (string, error) {
	return paginationpkg.EncodeCursor(conversationStringCursor{Pinned: &pinned, Start: true, Scope: scope})
}

// List returns one complete pinned-first page. The cursor carries the partition because a cursor made
// at the end of a pinned page must not filter out newer unpinned rows. The same partition walk is used
// for activity, created, and name sorts; a page is filled across the partition boundary when needed.
//
// List 返一页**完整**的置顶优先结果。游标带分区信息，因为置顶页末的游标不能把时间更新的未置顶行过滤掉。
// activity、created、name 三种排序共用同一分区遍历；需要时会跨分区补满一页。
func (s *Store) List(ctx context.Context, filter conversationdomain.ListFilter) ([]*conversationdomain.Conversation, string, error) {
	limit := filter.Limit
	if limit <= 0 {
		limit = 50
	}
	partitions := pinnedPartitions(filter.Pinned)
	scope := conversationCursorScopeKey(filter)

	var timeCursor *conversationTimeCursor
	var stringCursor *conversationStringCursor
	if filter.Cursor != "" {
		if filter.Sort == conversationdomain.ListSortName {
			var c conversationStringCursor
			if err := paginationpkg.DecodeCursor(filter.Cursor, &c); err != nil {
				return nil, "", fmt.Errorf("conversationstore.List: %w", err)
			}
			if c.Pinned == nil {
				return nil, "", malformedConversationCursor("is missing its pinned partition")
			}
			if c.Scope != scope {
				return nil, "", malformedConversationCursor("belongs to a different list query")
			}
			stringCursor = &c
		} else {
			var c conversationTimeCursor
			if err := paginationpkg.DecodeCursor(filter.Cursor, &c); err != nil {
				return nil, "", fmt.Errorf("conversationstore.List: %w", err)
			}
			if c.Pinned == nil {
				return nil, "", malformedConversationCursor("is missing its pinned partition")
			}
			if c.Scope != scope {
				return nil, "", malformedConversationCursor("belongs to a different list query")
			}
			timeCursor = &c
		}
	}

	start := 0
	if timeCursor != nil {
		found := false
		for i, pinned := range partitions {
			if pinned == *timeCursor.Pinned {
				start, found = i, true
				break
			}
		}
		if !found {
			return nil, "", malformedConversationCursor("does not match the requested pin scope")
		}
	} else if stringCursor != nil {
		found := false
		for i, pinned := range partitions {
			if pinned == *stringCursor.Pinned {
				start, found = i, true
				break
			}
		}
		if !found {
			return nil, "", malformedConversationCursor("does not match the requested pin scope")
		}
	}

	items := make([]*conversationdomain.Conversation, 0, limit)
	for i := start; i < len(partitions); i++ {
		pinned := partitions[i]
		partitionCursor := ""
		if i == start {
			if timeCursor != nil && !timeCursor.Start {
				var err error
				partitionCursor, err = paginationpkg.EncodeCursor(paginationpkg.Cursor{Key: timeCursor.Key, ID: timeCursor.ID})
				if err != nil {
					return nil, "", fmt.Errorf("conversationstore.List: %w", err)
				}
			}
			if stringCursor != nil && !stringCursor.Start {
				var err error
				partitionCursor, err = paginationpkg.EncodeCursor(paginationpkg.StringCursor{Key: stringCursor.Key, ID: stringCursor.ID})
				if err != nil {
					return nil, "", fmt.Errorf("conversationstore.List: %w", err)
				}
			}
		}
		rows, next, err := s.listPartitionPage(ctx, filter, pinned, partitionCursor, limit-len(items))
		if err != nil {
			return nil, "", fmt.Errorf("conversationstore.List: %w", err)
		}
		items = append(items, rows...)
		if next != "" {
			if filter.Sort == conversationdomain.ListSortName {
				next, err = encodeStringConversationCursor(next, pinned, scope)
			} else {
				next, err = encodeTimeConversationCursor(next, pinned, scope)
			}
			if err != nil {
				return nil, "", fmt.Errorf("conversationstore.List: %w", err)
			}
			return items, next, nil
		}
		if len(items) < limit {
			continue
		}

		// The current partition ended exactly at the page boundary. Probe later partitions so we only
		// advertise a next page when a row really exists; its start cursor replays that first row.
		// 当前分区恰好填满页面且已结束。探测后续分区，只有确有行才发 next；start cursor 会重放该首行。
		for j := i + 1; j < len(partitions); j++ {
			probe, _, err := s.listPartitionPage(ctx, filter, partitions[j], "", 1)
			if err != nil {
				return nil, "", fmt.Errorf("conversationstore.List: %w", err)
			}
			if len(probe) == 0 {
				continue
			}
			if filter.Sort == conversationdomain.ListSortName {
				next, err := encodeStartConversationStringCursor(partitions[j], scope)
				if err != nil {
					return nil, "", fmt.Errorf("conversationstore.List: %w", err)
				}
				return items, next, nil
			}
			next, err := encodeStartConversationCursor(partitions[j], scope)
			if err != nil {
				return nil, "", fmt.Errorf("conversationstore.List: %w", err)
			}
			return items, next, nil
		}
		return items, "", nil
	}
	return items, "", nil
}

// Count returns the exact live-row count for the public list axes. The pinned-first list is physically
// two partition queries, so Count sums the same partitions List walks instead of counting a broader set
// and asking the client to infer the pin scope.
//
// Count 返回公开列表轴下的存活行精确总数。置顶优先列表物理上是两个分区查询，故 Count 求和与 List 相同的分区，
// 不先数一个更宽的集合再让客户端猜置顶范围。
func (s *Store) Count(ctx context.Context, filter conversationdomain.ListFilter) (int, error) {
	total := int64(0)
	for _, pinned := range pinnedPartitions(filter.Pinned) {
		n, err := s.listQuery(filter, pinned).Count(ctx)
		if err != nil {
			return 0, fmt.Errorf("conversationstore.Count: %w", err)
		}
		total += n
	}
	return int(total), nil
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
