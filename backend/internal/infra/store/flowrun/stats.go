// stats.go implements flowrundomain.Repository.RunStats — the operational statistics batch
// (scheduler 工单③). Aggregation SQL is beyond the row-mapped CRUD, so this uses the orm's raw
// read escape hatch (db.Query) with the search store's manual workspace-scoping idiom
// (reqctx.RequireWorkspaceID). Six bounded queries total (never per-id N+1): totals, workspace
// parked-run count, per-workflow aggregates, recent beads, per-workflow parked runs, consecutive
// failures — all driven by the existing idx_fr_ws_workflow / idx_frn_parked indexes; no schema change.
//
// Time comparisons go through julianday() on BOTH sides: the driver stores DATETIME as ISO-8601
// text, and julianday normalizes format drift (legacy second-precision rows vs nanosecond rows)
// that raw string comparison would mis-order at the margins.
//
// stats.go 实现 flowrundomain.Repository.RunStats——运营统计批查（scheduler 工单③）。聚合 SQL 超出
// 行映射 CRUD，走 orm 的原始读逃生口（db.Query）+ search store 的手动 workspace 隔离惯用形
// （reqctx.RequireWorkspaceID）。总共六条有界查询（绝不逐 id N+1）：totals、全 workspace 等人 run 数、
// 逐 workflow 聚合、近况珠串、逐 workflow 等人 run 数、连败计数——全部由既有 idx_fr_ws_workflow /
// idx_frn_parked 驱动；零 schema 变更。
//
// 时间比较两侧都过 julianday()：驱动把 DATETIME 存成 ISO-8601 文本，julianday 归一格式漂移
// （秒精度旧行 vs 纳秒新行）——裸字符串比较会在边缘错序。
package flowrun

import (
	"context"
	"database/sql"
	"fmt"
	"math"
	"strings"
	"time"

	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func (s *Store) RunStats(ctx context.Context, q flowrundomain.StatsQuery) (*flowrundomain.RunStats, error) {
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return nil, err
	}
	out := &flowrundomain.RunStats{ByWorkflow: []*flowrundomain.WorkflowStats{}}

	// --- totals (workspace-wide, independent of the requested ids) ---------------------------

	// completedSince/failedSince window on completed_at: "failed in the window" means the run
	// REACHED failed inside it (see domain doc).
	// completedSince/failedSince 按 completed_at 开窗：「窗口内失败」= run 在窗口内**落定**失败。
	err = s.db.QueryRow(ctx, `
		SELECT
			COUNT(*) FILTER (WHERE status = 'running'),
			COUNT(*) FILTER (WHERE status = 'completed' AND julianday(completed_at) >= julianday(?)),
			COUNT(*) FILTER (WHERE status = 'failed'    AND julianday(completed_at) >= julianday(?))
		FROM flowruns WHERE workspace_id = ?`,
		q.Since, q.Since, wsID,
	).Scan(&out.Totals.Running, &out.Totals.CompletedSince, &out.Totals.FailedSince)
	if err != nil {
		return nil, fmt.Errorf("flowrunstore.RunStats totals: %w", err)
	}

	// Parked = runs awaiting a human: DISTINCT runs still running with ≥1 parked node. The join
	// on r.status='running' excludes parked rows orphaned on already-terminal runs (undecidable).
	// 等人 = 等人处理的 run 数：仍 running 且持 ≥1 parked 节点的 DISTINCT run。join r.status='running'
	// 排除遗留在已终态 run 上的 parked 行（不可决策）。
	err = s.db.QueryRow(ctx, `
		SELECT COUNT(DISTINCT n.flowrun_id)
		FROM flowrun_nodes n
		JOIN flowruns r ON r.id = n.flowrun_id
		WHERE n.workspace_id = ? AND n.status = 'parked' AND r.status = 'running'`,
		wsID,
	).Scan(&out.Totals.ParkedRuns)
	if err != nil {
		return nil, fmt.Errorf("flowrunstore.RunStats parked: %w", err)
	}

	if len(q.WorkflowIDs) == 0 {
		return out, nil
	}

	// --- byWorkflow (requested ids only; one row per id, zero-filled, request order) ----------

	rows := make(map[string]*flowrundomain.WorkflowStats, len(q.WorkflowIDs))
	for _, id := range q.WorkflowIDs {
		st := &flowrundomain.WorkflowStats{WorkflowID: id, Recent: []string{}}
		rows[id] = st
		out.ByWorkflow = append(out.ByWorkflow, st)
	}
	in := "(" + strings.TrimSuffix(strings.Repeat("?, ", len(q.WorkflowIDs)), ", ") + ")"
	idArgs := make([]any, 0, len(q.WorkflowIDs))
	for _, id := range q.WorkflowIDs {
		idArgs = append(idArgs, id)
	}

	// ① Base aggregates: running count, last run, windowed success/failure counts + mean elapsed.
	// ① 基础聚合：running 数、最近一次 run、窗口内成败计数 + 平均耗时。
	args := append([]any{q.Since, q.Since, q.Since, wsID}, idArgs...)
	base, err := s.db.Query(ctx, `
		SELECT workflow_id,
			COUNT(*) FILTER (WHERE status = 'running'),
			MAX(started_at),
			COUNT(*) FILTER (WHERE status = 'completed' AND julianday(completed_at) >= julianday(?)),
			COUNT(*) FILTER (WHERE status = 'failed'    AND julianday(completed_at) >= julianday(?)),
			AVG((julianday(completed_at) - julianday(started_at)) * 86400000.0)
				FILTER (WHERE status = 'completed' AND julianday(completed_at) >= julianday(?))
		FROM flowruns
		WHERE workspace_id = ? AND workflow_id IN `+in+`
		GROUP BY workflow_id`, args...)
	if err != nil {
		return nil, fmt.Errorf("flowrunstore.RunStats byWorkflow: %w", err)
	}
	defer base.Close()
	for base.Next() {
		var (
			wfID      string
			running   int
			lastRaw   sql.NullString
			completed int
			failed    int
			avgMs     sql.NullFloat64
		)
		if err := base.Scan(&wfID, &running, &lastRaw, &completed, &failed, &avgMs); err != nil {
			return nil, fmt.Errorf("flowrunstore.RunStats byWorkflow scan: %w", err)
		}
		st := rows[wfID]
		st.Running = running
		if lastRaw.Valid {
			ts, err := parseDBTime(lastRaw.String)
			if err != nil {
				return nil, fmt.Errorf("flowrunstore.RunStats lastRunAt: %w", err)
			}
			st.LastRunAt = &ts
		}
		if completed+failed > 0 {
			rate := float64(completed) / float64(completed+failed)
			st.SuccessRate = &rate
		}
		if avgMs.Valid {
			ms := int64(math.Round(avgMs.Float64))
			st.AvgElapsedMs = &ms
		}
	}
	if err := base.Err(); err != nil {
		return nil, fmt.Errorf("flowrunstore.RunStats byWorkflow rows: %w", err)
	}

	// ② Recent beads: last RecentN statuses per workflow, newest→oldest (same (started_at, id)
	// order every run list renders).
	// ② 近况珠串：逐 workflow 最近 RecentN 个状态、新→旧（与所有 run 列表同 (started_at, id) 序）。
	args = append(append([]any{wsID}, idArgs...), q.RecentN)
	recent, err := s.db.Query(ctx, `
		SELECT workflow_id, status FROM (
			SELECT workflow_id, status,
				ROW_NUMBER() OVER (PARTITION BY workflow_id ORDER BY started_at DESC, id DESC) AS rn
			FROM flowruns
			WHERE workspace_id = ? AND workflow_id IN `+in+`
		) WHERE rn <= ?
		ORDER BY workflow_id, rn`, args...)
	if err != nil {
		return nil, fmt.Errorf("flowrunstore.RunStats recent: %w", err)
	}
	defer recent.Close()
	for recent.Next() {
		var wfID, status string
		if err := recent.Scan(&wfID, &status); err != nil {
			return nil, fmt.Errorf("flowrunstore.RunStats recent scan: %w", err)
		}
		rows[wfID].Recent = append(rows[wfID].Recent, status)
	}
	if err := recent.Err(); err != nil {
		return nil, fmt.Errorf("flowrunstore.RunStats recent rows: %w", err)
	}

	// ③ Awaiting-human runs per workflow: the totals' parked bucket sliced by workflow_id (same
	// DISTINCT-run + still-running semantics) — the rail's amber dot.
	// ③ 逐 workflow 等人 run 数：totals 的 parked 桶按 workflow_id 分桶（同 DISTINCT run + 仍
	// running 语义）——rail 琥珀点。
	args = append([]any{wsID}, idArgs...)
	parked, err := s.db.Query(ctx, `
		SELECT r.workflow_id, COUNT(DISTINCT n.flowrun_id)
		FROM flowrun_nodes n
		JOIN flowruns r ON r.id = n.flowrun_id
		WHERE n.workspace_id = ? AND n.status = 'parked' AND r.status = 'running'
			AND r.workflow_id IN `+in+`
		GROUP BY r.workflow_id`, args...)
	if err != nil {
		return nil, fmt.Errorf("flowrunstore.RunStats byWorkflow parked: %w", err)
	}
	defer parked.Close()
	for parked.Next() {
		var wfID string
		var n int
		if err := parked.Scan(&wfID, &n); err != nil {
			return nil, fmt.Errorf("flowrunstore.RunStats byWorkflow parked scan: %w", err)
		}
		rows[wfID].ParkedRuns = n
	}
	if err := parked.Err(); err != nil {
		return nil, fmt.Errorf("flowrunstore.RunStats byWorkflow parked rows: %w", err)
	}

	// ④ Consecutive failures: failed runs with NO newer completed/cancelled run — i.e. the failed
	// streak since the last self-heal, walked on the same (started_at, id) sequence. running runs
	// simply don't participate (undecided: they neither count nor break the streak); tuple
	// comparison keeps same-timestamp neighbors ordered exactly like the lists render them.
	// ④ 连败：没有更新的 completed/cancelled 的 failed run——即自上次自愈以来的失败连串，走同一
	// (started_at, id) 序。running 不参与（未定局：不计数也不断串）；元组比较让同时间戳邻居与列表
	// 渲染完全同序。
	args = append([]any{wsID}, idArgs...)
	streak, err := s.db.Query(ctx, `
		SELECT f.workflow_id, COUNT(*)
		FROM flowruns f
		WHERE f.workspace_id = ? AND f.workflow_id IN `+in+` AND f.status = 'failed'
			AND NOT EXISTS (
				SELECT 1 FROM flowruns g
				WHERE g.workspace_id = f.workspace_id AND g.workflow_id = f.workflow_id
					AND g.status IN ('completed','cancelled')
					AND (g.started_at > f.started_at OR (g.started_at = f.started_at AND g.id > f.id))
			)
		GROUP BY f.workflow_id`, args...)
	if err != nil {
		return nil, fmt.Errorf("flowrunstore.RunStats streak: %w", err)
	}
	defer streak.Close()
	for streak.Next() {
		var wfID string
		var n int
		if err := streak.Scan(&wfID, &n); err != nil {
			return nil, fmt.Errorf("flowrunstore.RunStats streak scan: %w", err)
		}
		rows[wfID].ConsecutiveFailures = n
	}
	if err := streak.Err(); err != nil {
		return nil, fmt.Errorf("flowrunstore.RunStats streak rows: %w", err)
	}
	return out, nil
}

// parseDBTime decodes a DATETIME expression result (e.g. MAX(started_at)) the driver hands back
// as text: an expression column has no declared type, so the driver's own time auto-parse does
// not fire. Layouts mirror the driver's write format plus the naive legacy form (assumed UTC).
//
// parseDBTime 解码表达式列（如 MAX(started_at)）返回的 DATETIME 文本：表达式列无声明类型，驱动的
// 时间自动解析不触发。layout 对齐驱动写入格式 + 无时区旧形（按 UTC）。
func parseDBTime(raw string) (time.Time, error) {
	for _, layout := range []string{
		"2006-01-02 15:04:05.999999999-07:00", // glebarez/go-sqlite write format. 驱动写入格式。
		"2006-01-02 15:04:05.999999999",       // naive legacy rows. 无时区旧行。
		time.RFC3339Nano,
	} {
		if ts, err := time.Parse(layout, raw); err == nil {
			return ts.UTC(), nil
		}
	}
	return time.Time{}, fmt.Errorf("unrecognized DATETIME text %q", raw)
}
