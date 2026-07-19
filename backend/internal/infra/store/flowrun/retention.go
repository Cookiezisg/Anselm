// retention.go implements flowrundomain.Repository.PurgeTerminalRunsBefore — the run-history
// retention sweep's ONE batch (scheduler 工单⑬, 判决④).
//
// ★ D1 CARVE-OUT #2. flowruns / flowrun_nodes are Log tables (no deleted_at), and the package doc's
// "the one permitted physical delete is DeleteFailedNodes" is no longer the whole truth: this is the
// second, and it is a DIFFERENT KIND. :replay deletes a NON-RESULT (a failed row, removed so the
// idempotent re-walk can retry — no history is erased). This deletes REAL HISTORY. It is legitimate
// because it is CAPACITY GOVERNANCE the user configured, not business logic quietly dropping rows:
// the line is explicit (Settings → 存储 → Run 历史保留), server-held, honest in the UI (the big
// table renders a tombstone at the line, never a silent gap), and the audit truth inside the
// retention window stays COMPLETE. The legislation is registered in database.md's flowrun section —
// read it before touching this file.
//
// SCOPE — only a run's OWN rows go: the header, its node rows, and the audit rows THAT RUN produced
// (the four execution-log tables' `flowrun_id = <this run>`). A function executed from chat carries
// flowrun_id = ” and is never touched. Collateral ledgers (trigger firings, notifications,
// touchpoints) keep their own truth axis and are NOT swept — their flowrunId becomes a dangling
// reference whose deep link 404s and renders the client's orphan tombstone (前端 §13 先例).
//
// SAFETY — running / parked runs are NEVER deleted, however old: only the terminal set
// (completed/failed/cancelled) with a non-NULL completed_at strictly before the cutoff. A terminal
// row with a NULL completed_at is left alone (a destructive sweep that cannot date a row must keep
// it, not guess).
//
// retention.go 实现 flowrundomain.Repository.PurgeTerminalRunsBefore——run 历史保留清理的**一批**
// （scheduler 工单⑬、判决④）。
//
// ★ **D1 例外 #2**。flowruns / flowrun_nodes 是 Log 表（无 deleted_at），而包注释那句「唯一允许的物理删是
// DeleteFailedNodes」已不是全部真相：这是第二个，且**性质不同**。:replay 删的是**非结果**（failed 行，删掉
// 让幂等重走重试——没有历史被抹）。这里删的是**真实历史**。它正当，是因为它是用户配置的**容量治理**、而非
// 业务逻辑偷偷丢行：线是显式的（Settings → 存储 → Run 历史保留）、服务端自持、在 UI 里诚实（大表在线上渲
// 墓碑、绝不静默留缺口），且**保留窗内的审计真相完整**。立法登记在 database.md 的 flowrun 节——动本文件前
// 先读它。
//
// **范围**——只删 run **自己**的行：头、它的节点行、以及**该 run 产生的**审计行（四张执行日志表的
// `flowrun_id = <本 run>`）。从对话跑的 function 其 flowrun_id = ”、永不被碰。旁系台账（trigger firing、
// 通知、触点）各有自己的真相轴、**不清**——它们的 flowrunId 成悬挂引用，深链 404、渲客户端的孤儿墓碑
// （前端 §13 先例）。
//
// **安全**——running / parked 的 run **永不**删，不管多老：只删终态集（completed/failed/cancelled）中
// completed_at 非 NULL 且**严格早于** cutoff 的。终态但 completed_at 为 NULL 的行放过（一个断不了行的年份的
// 破坏性清理必须留它、而不是猜）。
package flowrun

import (
	"context"
	"fmt"
	"strings"
	"time"

	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// auditTables are the four execution-log tables carrying a flowrun_id — the rows a run PRODUCED.
// Same four literals activity.go UNIONs (the four stores export no table-name constants);
// database.md lists them, and the retention tests delete through every branch, so a rename breaks
// loudly at test time rather than silently leaking rows.
//
// auditTables 是带 flowrun_id 的四张执行日志表——run **产生**的行。与 activity.go UNION 的四个字面量相同
// （四个 store 不导出表名常量）；database.md 登记在案，且保留清理测试逐支都删，故改名会在测试期大声崩、
// 而非静默漏行。
var auditTables = []string{"function_executions", "handler_calls", "agent_executions", "mcp_calls"}

func (s *Store) PurgeTerminalRunsBefore(ctx context.Context, cutoff time.Time, batch int) (int, error) {
	if batch <= 0 {
		batch = flowrundomain.RetentionBatchSize
	}
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return 0, err
	}

	var purged int
	err = s.db.Transaction(ctx, func(tx *ormpkg.DB) error {
		// Collect the batch INSIDE the tx, then delete exactly those ids — the TrimOldestVersions
		// idiom (pluck the doomed ids, delete by that single source of truth) rather than a bare
		// DELETE … WHERE <predicate>, which orm cannot bound anyway (Query.Delete ignores Limit, and
		// stock SQLite has no DELETE … LIMIT) and which would give us no ids for the child deletes.
		// The window is BARE (`completed_at < ?`), like every other completed_at/started_at window in
		// this package: within the one canonical UTC text format all writers stamp, text order IS
		// chronological order (TestTimeText_OrdersChronologically). julianday() here would only add
		// millisecond rounding at the cutoff — harmless to a retention line measured in days, but
		// inconsistent with the windows the Overview counts on, so bare keeps one rule.
		// 在事务**内**收集这一批，再精确删这些 id——TrimOldestVersions 惯用形（先 pluck 将死 id、再按这个
		// 单一真相源删），而非裸 DELETE … WHERE <谓词>：后者 orm 本就界不住（Query.Delete 忽略 Limit，
		// 原版 SQLite 也无 DELETE … LIMIT），且不会给我们删子行要用的 id。窗口是**裸的**（`completed_at < ?`），
		// 与本包其余 completed_at/started_at 窗一致：在所有写者盖的那一种规范 UTC 文本格式内，文本序**就是**
		// 时间序（TestTimeText_OrdersChronologically）。这里用 julianday() 只会在 cutoff 处加毫秒舍入——对以
		// 天计的保留线无害，但与 Overview 所数的那些窗不一致，故裸比较保持一条规则。
		rows, err := tx.Query(ctx, `
			SELECT id FROM flowruns
			WHERE workspace_id = ?
				AND status IN ('completed','failed','cancelled')
				AND completed_at IS NOT NULL
				AND completed_at < ?
			ORDER BY completed_at ASC
			LIMIT ?`, wsID, cutoff, batch)
		if err != nil {
			return fmt.Errorf("select batch: %w", err)
		}
		var ids []any
		for rows.Next() {
			var id string
			if err := rows.Scan(&id); err != nil {
				rows.Close()
				return fmt.Errorf("scan batch: %w", err)
			}
			ids = append(ids, id)
		}
		if err := rows.Err(); err != nil {
			rows.Close()
			return fmt.Errorf("batch rows: %w", err)
		}
		rows.Close()
		if len(ids) == 0 {
			return nil
		}

		// Children before parents, all in this one tx: there is no FK between the tables (the schema
		// declares none), so nothing cascades — an interrupted sweep must never leave node/audit rows
		// whose run header is gone.
		// 子先于父、都在这**一个**事务里：表间无 FK（schema 没声明），故什么都不级联——被打断的清理绝不能
		// 留下 run 头已亡的节点/审计行。
		in := "(" + strings.TrimSuffix(strings.Repeat("?, ", len(ids)), ", ") + ")"
		args := append([]any{wsID}, ids...)
		for _, table := range auditTables {
			if _, err := tx.Exec(ctx, `DELETE FROM `+table+` WHERE workspace_id = ? AND flowrun_id IN `+in, args...); err != nil {
				return fmt.Errorf("delete %s: %w", table, err)
			}
		}
		if _, err := tx.Exec(ctx, `DELETE FROM `+TableFlowRunNodes+` WHERE workspace_id = ? AND flowrun_id IN `+in, args...); err != nil {
			return fmt.Errorf("delete nodes: %w", err)
		}
		// Re-assert the terminal guard on the header delete: a :replay between the SELECT and here
		// would have flipped a failed run back to running, and reopening it means the user wants it —
		// the sweep must lose that race. Its node rows are already gone, which is exactly what a
		// replay does to them anyway (DeleteFailedNodes), and the memoized completed rows it would
		// have reused are a performance loss, never a correctness one: the re-walk simply re-runs them.
		// 在删头时**重申**终态守卫：SELECT 与此处之间的一次 :replay 会把 failed run 翻回 running，而重开它
		// 意味着用户要它——清理必须输掉这场竞速。它的节点行已经没了，而这正是 replay 本就会对它们做的事
		// （DeleteFailedNodes）；被抄的 completed 行没了只是性能损失、绝非正确性损失：重走把它们重跑一遍。
		res, err := tx.Exec(ctx, `
			DELETE FROM `+TableFlowRuns+`
			WHERE workspace_id = ? AND id IN `+in+`
				AND status IN ('completed','failed','cancelled')`, args...)
		if err != nil {
			return fmt.Errorf("delete runs: %w", err)
		}
		n, err := res.RowsAffected()
		if err != nil {
			return fmt.Errorf("rows affected: %w", err)
		}
		purged = int(n)
		return nil
	})
	if err != nil {
		return 0, fmt.Errorf("flowrunstore.PurgeTerminalRunsBefore: %w", err)
	}
	return purged, nil
}
