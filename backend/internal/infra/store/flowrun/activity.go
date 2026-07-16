// activity.go implements flowrundomain.Repository.ListActivity — the per-run execution activity
// projection (scheduler 工单⑤) feeding the run flagship's gantt + ledger. It UNIONs the four
// execution-log tables (function_executions / handler_calls / agent_executions / mcp_calls) by
// flowrun_id — each branch driven by its existing `(workspace_id, flowrun_id) WHERE flowrun_id != ”`
// partial index — and LEFT JOINs the flowrun_nodes truth row on the record-once key
// (flowrun_id, node_id, iteration) = idx_frn_once to attach the queue stamp ready_at (工单⑫).
// Raw-read escape hatch + manual workspace scoping, the stats.go idiom. The keyset page is the orm
// Page family's tuple comparison, ASCENDING on (started_at, id) — the gantt's natural order; exec
// ids are globally unique across the four tables (distinct prefixes), so the pk tiebreaker is sound.
// The table names are the four stores' own literals (they export no constants); database.md lists
// them — a rename would break this SQL loudly at test time, not silently.
//
// activity.go 实现 flowrundomain.Repository.ListActivity——按 run 的执行活动投影（scheduler 工单⑤），
// 喂 run 旗舰的甘特+台账。四张执行日志表按 flowrun_id UNION——每支走各自既有的
// `(workspace_id, flowrun_id) WHERE flowrun_id != ”` 偏索引——再按 record-once 键
// (flowrun_id, node_id, iteration) = idx_frn_once LEFT JOIN flowrun_nodes 真相行拿排队戳 ready_at
// （工单⑫）。原始读逃生口 + 手动 workspace 隔离，同 stats.go 惯用形。keyset 分页用 orm Page 家族的
// 元组比较、按 (started_at, id) **升序**——甘特天然序；四表 exec id 前缀各异全局唯一，pk tiebreaker
// 成立。表名是四个 store 自己的字面量（它们不导出常量）；database.md 登记在案——改名会让本 SQL 在测试
// 期大声崩、绝不静默。
package flowrun

import (
	"context"
	"database/sql"
	"fmt"

	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	paginationpkg "github.com/sunweilin/anselm/backend/internal/pkg/pagination"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// activityBranch is one UNION arm: SELECT the shared column shape out of one audit table. The
// column aliases in the FIRST branch name the union's columns.
//
// activityBranch 是一条 UNION 臂：从一张审计表选出共享列形。首臂的列别名命名整个 union 的列。
const activityBranch = `SELECT '%s' AS kind, id, flowrun_node_id AS node_id, flowrun_iteration AS iteration, status, started_at, ended_at, elapsed_ms
			FROM %s WHERE workspace_id = ? AND flowrun_id = ?`

func (s *Store) ListActivity(ctx context.Context, flowrunID, cursor string, limit int) ([]*flowrundomain.ActivityRow, string, error) {
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return nil, "", err
	}
	if limit <= 0 {
		limit = 50
	}

	union := fmt.Sprintf(activityBranch, flowrundomain.ActivityKindFunction, "function_executions") +
		"\n\t\t\tUNION ALL\n\t\t\t" + fmt.Sprintf(activityBranch, flowrundomain.ActivityKindHandler, "handler_calls") +
		"\n\t\t\tUNION ALL\n\t\t\t" + fmt.Sprintf(activityBranch, flowrundomain.ActivityKindAgent, "agent_executions") +
		"\n\t\t\tUNION ALL\n\t\t\t" + fmt.Sprintf(activityBranch, flowrundomain.ActivityKindMCP, "mcp_calls")

	args := []any{wsID, flowrunID, wsID, flowrunID, wsID, flowrunID, wsID, flowrunID, flowrunID}
	where := ""
	if cursor != "" {
		var c paginationpkg.Cursor
		if err := paginationpkg.DecodeCursor(cursor, &c); err != nil {
			return nil, "", fmt.Errorf("flowrunstore.ListActivity cursor: %w", err)
		}
		// Same tuple comparison as orm Page/PageTimeAsc: bound and stored values share the driver's
		// serialization, so the bare-column tuple stays consistent AND sargable.
		// 与 orm Page/PageTimeAsc 同一元组比较：界值与存值同走 driver 序列化，裸列元组既一致又可走索引。
		where = "WHERE (a.started_at, a.id) > (?, ?)\n\t\t"
		args = append(args, c.Key, c.ID)
	}
	args = append(args, limit+1) // one extra row to detect a next page. 多取一行探测下页。

	rows, err := s.db.Query(ctx, `
		SELECT a.kind, a.id, a.node_id, a.iteration, a.status, a.started_at, a.ended_at, a.elapsed_ms, n.ready_at
		FROM (
			`+union+`
		) a
		LEFT JOIN flowrun_nodes n ON n.flowrun_id = ? AND n.node_id = a.node_id AND n.iteration = a.iteration
		`+where+`ORDER BY a.started_at ASC, a.id ASC
		LIMIT ?`, args...)
	if err != nil {
		return nil, "", fmt.Errorf("flowrunstore.ListActivity: %w", err)
	}
	defer rows.Close()

	out := make([]*flowrundomain.ActivityRow, 0, limit)
	for rows.Next() {
		var (
			r                    flowrundomain.ActivityRow
			startedRaw, endedRaw string
			readyRaw             sql.NullString
		)
		// Timestamps come off a subquery (no declared column type → the driver's time auto-parse
		// does not fire) as text; parseDBTime mirrors the driver's write formats (stats.go idiom).
		// 时间戳出自子查询（无声明列类型 → 驱动时间自动解析不触发）、为文本；parseDBTime 对齐驱动写入
		// 格式（stats.go 惯用形）。
		if err := rows.Scan(&r.Kind, &r.ExecID, &r.NodeID, &r.Iteration, &r.Status, &startedRaw, &endedRaw, &r.ElapsedMs, &readyRaw); err != nil {
			return nil, "", fmt.Errorf("flowrunstore.ListActivity scan: %w", err)
		}
		if r.StartedAt, err = parseDBTime(startedRaw); err != nil {
			return nil, "", fmt.Errorf("flowrunstore.ListActivity startedAt: %w", err)
		}
		if r.EndedAt, err = parseDBTime(endedRaw); err != nil {
			return nil, "", fmt.Errorf("flowrunstore.ListActivity endedAt: %w", err)
		}
		if readyRaw.Valid {
			ts, err := parseDBTime(readyRaw.String)
			if err != nil {
				return nil, "", fmt.Errorf("flowrunstore.ListActivity readyAt: %w", err)
			}
			r.ReadyAt = &ts
		}
		out = append(out, &r)
	}
	if err := rows.Err(); err != nil {
		return nil, "", fmt.Errorf("flowrunstore.ListActivity rows: %w", err)
	}

	var next string
	if len(out) > limit {
		last := out[limit-1]
		next, err = paginationpkg.EncodeCursor(paginationpkg.Cursor{Key: last.StartedAt, ID: last.ExecID})
		if err != nil {
			return nil, "", fmt.Errorf("flowrunstore.ListActivity cursor encode: %w", err)
		}
		out = out[:limit]
	}
	return out, next, nil
}
