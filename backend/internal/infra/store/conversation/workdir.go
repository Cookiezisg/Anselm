// workdir.go — the residency-GROUPED reads and the two residency-wide writes (WRK-077 WD1.5).
//
// The grouping is a GROUP BY, which row-mapped CRUD cannot express, so it takes orm's raw read escape
// hatch (db.Query) with the manual workspace-scoping idiom the other raw-read stores use
// (reqctx.RequireWorkspaceID) — see flowrun/stats.go for the same pair. ONE query answers the whole
// projection: both counts and the recency key, per residency, in a single index range scan.
//
// The two writes are the point of the batch's backend half: the rail must not loop N requests to archive
// or delete a folder's worth of threads, and it must not be able to leave HALF a folder archived. Each is
// one statement inside one transaction, with the id set read inside the same transaction so the caller's
// per-row cascades act on exactly the rows that were written.
//
// workdir.go —— 按驻地**分组**的读 + 两个驻地级的写（WRK-077 WD1.5）。
//
// 分组是 GROUP BY，行映射 CRUD 表达不了，故走 orm 的原始读逃生口（db.Query）+ 其余原始读 store 用的手动
// workspace 隔离惯用形（reqctx.RequireWorkspaceID）——同一对组合见 flowrun/stats.go。**一条**查询答完整个
// 投影:每个驻地的两个计数与 recency 键，一次索引区间扫。
//
// 两个写正是本批后端半边的意义:rail 不该为归档/删除一个目录量的线程循环打 N 个请求，也**不该有能力**留下
// **半个**归档了的目录。各是一个事务里的一条语句，且 id 集在**同一**事务里读出，使调用方的逐行级联恰好作用
// 在被写的那些行上。
package conversation

import (
	"context"
	"fmt"

	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// WorkDirGroups aggregates the workspace's UNPINNED, non-deleted conversations by residency.
//
// The two counts come back from ONE pass (COUNT … FILTER, SQLite's aggregate filter) so the caller needs
// no `?archived=` parameter and no second request: the rail's "show archived" toggle picks or sums them,
// and a bulk action inventories the sum. `MAX(last_message_at)` spans BOTH archive states, so toggling the
// view never reorders the groups — a group's position answers "when was I last here", which archiving one
// old thread inside it did not change.
//
// Ordered most-recently-active first, `work_dir` ascending as the tiebreaker so the order is TOTAL (two
// residencies whose newest thread shares a timestamp must not swap between two identical requests).
//
// WorkDirGroups 把本 workspace 的**未置顶、未删除**对话按驻地聚合。
//
// 两个计数由**一趟**扫出（COUNT … FILTER，SQLite 的聚合过滤），故调用方**不需要** `?archived=` 参数、也不需要
// 第二次请求:rail 的「显示已归档」开关自行取其一或求和，批量动作盘点二者之和。`MAX(last_message_at)` 跨**两种**
// 归档态，故切换视图绝不重排组——一个组的位次答的是「我上次在这儿是什么时候」，而在它里面归档一条老线程并没有
// 改变那件事。
//
// 按最近活跃降序、`work_dir` 升序作 tiebreaker，使顺序是**全序**（两个最新线程时间戳相同的驻地，不该在两次
// 相同请求间互换位置）。
func (s *Store) WorkDirGroups(ctx context.Context) ([]conversationdomain.WorkDirGroup, error) {
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return nil, err
	}
	rows, err := s.db.Query(ctx, `
		SELECT work_dir,
			COUNT(*) FILTER (WHERE archived = 0),
			COUNT(*) FILTER (WHERE archived = 1),
			MAX(last_message_at)
		FROM conversations
		WHERE workspace_id = ? AND deleted_at IS NULL AND pinned = 0 AND work_dir <> ''
		GROUP BY work_dir
		ORDER BY MAX(last_message_at) DESC, work_dir ASC`, wsID)
	if err != nil {
		return nil, fmt.Errorf("conversationstore.WorkDirGroups: %w", err)
	}
	defer rows.Close()

	out := []conversationdomain.WorkDirGroup{}
	for rows.Next() {
		var (
			g       conversationdomain.WorkDirGroup
			lastRaw any
		)
		if err := rows.Scan(&g.WorkDir, &g.ActiveCount, &g.ArchivedCount, &lastRaw); err != nil {
			return nil, fmt.Errorf("conversationstore.WorkDirGroups scan: %w", err)
		}
		// An aggregate has no declared type, so the driver hands the DATETIME back as text — the foundation
		// owns that decode. 聚合无声明类型，驱动把 DATETIME 作文本交回——那份解码归地基。
		if g.LastMessageAt, err = ormpkg.ParseDBTime(lastRaw); err != nil {
			return nil, fmt.Errorf("conversationstore.WorkDirGroups lastMessageAt: %w", err)
		}
		out = append(out, g)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("conversationstore.WorkDirGroups rows: %w", err)
	}
	return out, nil
}

// ArchiveWorkDir archives one residency's UNPINNED, not-yet-archived conversations.
//
// The `archived = false` predicate is what keeps the returned count honest: it reports what CHANGED, not
// what matched, so a caller re-running the action on a fully-archived group emits no echoes and reports 0
// rather than claiming it archived a group again.
//
// ArchiveWorkDir 归档某驻地下**未置顶、尚未归档**的对话。
//
// `archived = false` 那个谓词正是让返回计数诚实的东西:它报的是**改变了什么**、不是匹配了什么，故在一个已全部
// 归档的组上重跑这个动作会不发任何回声、报 0，而不是声称自己又归档了一遍。
func (s *Store) ArchiveWorkDir(ctx context.Context, workDir string) ([]string, error) {
	return s.writeWorkDir(ctx, "ArchiveWorkDir", workDir, true, func(q *ormpkg.Query[conversationdomain.Conversation]) (int64, error) {
		return q.Updates(ctx, map[string]any{"archived": true})
	})
}

// SoftDeleteWorkDir soft-deletes one residency's UNPINNED conversations, ACROSS archive states — a
// destructive action must not silently depend on which view toggle happens to be on.
//
// It stamps `deleted_at` on the CONVERSATION rows and nothing else. `messages` / `message_blocks` are D1
// Log tables: they carry no `deleted_at` and are never deleted, logically or physically, here or anywhere.
// The thread's content survives on disk; what disappears is the thread's own row from every read path.
//
// SoftDeleteWorkDir 软删某驻地下**未置顶**的对话、**跨归档态**——一个破坏性动作不该静默地取决于哪个视图开关
// 正好开着。
//
// 它只在**对话行**上盖 `deleted_at`、别的什么都不动。`messages` / `message_blocks` 是 D1 Log 表:它们没有
// `deleted_at`，此处与任何别处都绝不逻辑删或物理删它们。线程的内容仍在盘上；消失的是线程**自己那一行**——
// 从每条读路径上。
func (s *Store) SoftDeleteWorkDir(ctx context.Context, workDir string) ([]string, error) {
	return s.writeWorkDir(ctx, "SoftDeleteWorkDir", workDir, false, func(q *ormpkg.Query[conversationdomain.Conversation]) (int64, error) {
		// Query.Delete on a table with a `deleted` column is the SOFT delete (one UPDATE stamping
		// deleted_at) — D1 by construction, not by remembering. 带 deleted 列的表上 Query.Delete 就是软删。
		return q.Delete(ctx)
	})
}

// writeWorkDir is the shared body of the two residency-wide writes: open ONE transaction, resolve the id
// set, apply ONE statement, and cross-check that the statement touched exactly that set.
//
// Reading the ids inside the transaction is not decoration. The caller cascades per-row side effects off
// this list (stop in-flight generation, purge relation edges, purge the touchpoint ledger); a list read
// OUTSIDE the write could name a row the write never reached, and the cascade would then tear down state
// belonging to a live conversation. The row-count cross-check turns any future drift between the two
// WHEREs into a rolled-back error instead of a silent half-action.
//
// `onlyActive` narrows to not-yet-archived rows (archive) or leaves both states in (delete) — see each
// caller for why they differ.
//
// writeWorkDir 是两个驻地级写的共同体:开**一个**事务、解出 id 集、施加**一条**语句，并交叉核对该语句恰好
// 动了那个集合。
//
// 在事务**内**读 id 不是装饰。调用方据这份名单逐行级联副作用（停在途生成、清 relation 边、清触点台账）;一份
// 在写**之外**读的名单可能点出一条写根本没碰到的行，于是级联会拆掉一条**还活着**的对话的状态。行数交叉核对
// 把两个 WHERE 之间未来任何漂移变成一次**回滚的错误**、而不是一次静默的半个动作。
//
// `onlyActive` 收窄到尚未归档的行（归档）或两态全收（删除）——为何不同见各调用方。
func (s *Store) writeWorkDir(
	ctx context.Context,
	op, workDir string,
	onlyActive bool,
	apply func(*ormpkg.Query[conversationdomain.Conversation]) (int64, error),
) ([]string, error) {
	var ids []string
	err := s.db.Transaction(ctx, func(tx *ormpkg.DB) error {
		repo := ormpkg.For[conversationdomain.Conversation](tx, "conversations")
		scope := func() *ormpkg.Query[conversationdomain.Conversation] {
			q := repo.Query().WhereEq("work_dir", workDir).WhereEq("pinned", false)
			if onlyActive {
				q = q.WhereEq("archived", false)
			}
			return q
		}
		ids = nil
		if err := scope().Pluck(ctx, "id", &ids); err != nil {
			return fmt.Errorf("conversationstore.%s ids: %w", op, err)
		}
		if len(ids) == 0 {
			return nil // nothing in this residency — no statement, no echo. 组内无货:不发语句、不发回声。
		}
		n, err := apply(scope())
		if err != nil {
			return fmt.Errorf("conversationstore.%s: %w", op, err)
		}
		if n != int64(len(ids)) {
			return fmt.Errorf("conversationstore.%s: wrote %d rows but resolved %d ids", op, n, len(ids))
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return ids, nil
}
