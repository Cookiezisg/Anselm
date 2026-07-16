// stats.go implements flowrundomain.Repository.RunStats — the operational statistics batch
// (scheduler 工单③). Aggregation SQL is beyond the row-mapped CRUD, so this uses the orm's raw
// read escape hatch (db.Query) with the search store's manual workspace-scoping idiom
// (reqctx.RequireWorkspaceID). SIX queries, one per section, never a per-id N+1: totals, workspace
// parked-run count, per-workflow aggregates, recent beads, per-workflow parked runs, consecutive
// failures.
//
// "Six queries, ≤50 ids, bounded output" is NOT a cost bound, and reading it as one is how this file
// grew a multi-second query nobody noticed. What these six cost is set by what they SCAN, and their
// input is a workspace's whole run history — which the shipped config grows without any help from the
// user (cron@1m × the 90d default retention = 129,600 rows). Every section is therefore an index
// question, not a row-count question; the streak (④) is the cautionary tale, and idx_fr_ws_wf_status's
// note carries the measurements. Adding a section here means asking what it scans at 10^5 rows and
// whether an index covers that — in that order.
//
// KNOWN AND MEASURED, not fixed here: at that volume the endpoint has a ~0.39s floor, essentially all
// of it query ①'s GROUP BY — it visits every run of the requested workflows and evaluates julianday()
// per row (the `since` windows cannot seek, since they bound completed_at while every index orders by
// started_at). Unlike the streak this is LINEAR and predictable, so it is recorded rather than traded
// for another index on a hunch: buying it back means a (ws, wf, status, completed_at) index or
// splitting ① into per-status seeks, and neither should happen before someone measures that the floor
// actually hurts. stats_bench_test.go is where that measurement goes.
//
// 「六条查询、≤50 个 id、输出有界」**不是成本上界**——把它读成上界，正是本文件长出一条几秒级查询却没人发现
// 的原因。这六条真正的成本由它们**扫**什么决定，而它们的输入是一个 workspace 的**整部 run 历史**——出厂
// 配置不用用户帮忙就能把它养大（cron@1m × 90d 默认保留线 = 129,600 行）。故每一节都是**索引问题**、不是
// 行数问题；连败（④）是那个前车之鉴，实测数字在 idx_fr_ws_wf_status 的注释里。在这里加一节 = 先问它在
// 10^5 行上扫什么、再问有没有索引覆盖——顺序不能反。
//
// **已知且已实测、但不在此修**：在那个量上本端点有 ~0.39s 的地板，几乎全部来自查询 ① 的 GROUP BY——它访问
// 请求 workflow 的每一个 run、并逐行求 julianday()（`since` 窗口 seek 不了：它界的是 completed_at，而所有
// 索引按 started_at 排）。与连败不同，这个是**线性可预测**的，故记档、而不是凭直觉再换一个索引：要把它买
// 回来得加 (ws, wf, status, completed_at) 索引、或把 ① 拆成逐状态 seek，而这两件事都该等到有人**测**出这
// 个地板真的疼了再做。那次测量的去处就是 stats_bench_test.go。
//
// Time comparisons against the caller's `since` go through julianday() on BOTH sides: the driver
// stores DATETIME as ISO-8601 text, and julianday normalizes the format drift between that text and
// a Go-supplied bound, which raw string comparison would mis-order at the margins. Column-vs-column
// comparisons within this table deliberately do NOT (④): same writer, same format, and julianday
// there would only blind the index.
//
// stats.go 实现 flowrundomain.Repository.RunStats——运营统计批查（scheduler 工单③）。聚合 SQL 超出
// 行映射 CRUD，走 orm 的原始读逃生口（db.Query）+ search store 的手动 workspace 隔离惯用形
// （reqctx.RequireWorkspaceID）。**六条查询**、每节一条，绝不逐 id N+1：totals、全 workspace 等人
// run 数、逐 workflow 聚合、近况珠串、逐 workflow 等人 run 数、连败计数。
//
// 「六条查询、≤50 个 id、输出有界」**不是成本上界**——把它读成上界，正是本文件长出一条 12 秒查询却没人
// 发现的原因。这六条真正的成本由它们**扫**什么决定，而它们的输入是一个 workspace 的**整部 run 历史**——
// 出厂配置不用用户帮忙就能把它养大（cron@1m × 90d 默认保留线 = 129,600 行）。故每一节都是**索引问题**、
// 不是行数问题；连败（④）是那个前车之鉴，实测数字在 idx_fr_ws_wf_status 的注释里。在这里加一节 = 先问
// 它在 10^5 行上扫什么、再问有没有索引覆盖——顺序不能反。
//
// 与调用方 `since` 的时间比较两侧都过 julianday()：驱动把 DATETIME 存成 ISO-8601 文本，julianday 归一
// 「落库文本 vs Go 传入的边界」之间的格式漂移——裸字符串比较会在边缘错序。**本表列与列**之间的比较则
// 刻意不过（④）：同一个写者、同一个格式，那里用 julianday 只会把索引弄瞎。
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
	//
	// The mean's FILTER excludes replayed runs as well as failed ones — one reason, not two: a header's
	// completed_at−started_at only answers "how long does this take" for a run that went start→finish
	// ONCE. :replay reopens the SAME header and never moves started_at (it is the ordering key of every
	// run list, matrix column and the streak walk above — moving it would rewrite history), so a run
	// that took 30s and was replayed to success three days later reports THREE DAYS. That distortion is
	// orders of magnitude past the time-to-failure one the failed exclusion already exists to avoid, so
	// letting it through while filtering failed would be incoherent. See the domain's contract for the
	// deliberate remainder (approval wait is wall-clock and stays in).
	//
	// ① 基础聚合：running 数、最近一次 run、窗口内成败计数 + 平均耗时。
	//
	// 均值的 FILTER 同时排除**被 replay 过的** run 与 failed run——同一个理由、不是两个：头上的
	// completed_at−started_at 只对「一次跑完」的 run 才答得上「这要跑多久」。:replay 重开的是**同一个头**、
	// 且绝不移动 started_at（它是所有 run 列表 / 矩阵列 / 上面那段连败游走的排序键——移它就是改写历史），
	// 于是一个跑了 30 秒、三天后 replay 成功的 run 会报**三天**。这个扭曲比「剔除 failed」本就要避开的
	// 「多久才死」大好几个数量级，故一边滤 failed 一边放它进来是自相矛盾。刻意留下的那部分（审批等待属于
	// 墙钟、留在里面）见 domain 的契约。
	args := append([]any{q.Since, q.Since, q.Since, wsID}, idArgs...)
	base, err := s.db.Query(ctx, `
		SELECT workflow_id,
			COUNT(*) FILTER (WHERE status = 'running'),
			MAX(started_at),
			COUNT(*) FILTER (WHERE status = 'completed' AND julianday(completed_at) >= julianday(?)),
			COUNT(*) FILTER (WHERE status = 'failed'    AND julianday(completed_at) >= julianday(?)),
			AVG((julianday(completed_at) - julianday(started_at)) * 86400000.0)
				FILTER (WHERE status = 'completed' AND replay_count = 0 AND julianday(completed_at) >= julianday(?))
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

	// ④ Consecutive failures: failed runs with NO newer COMPLETED run — i.e. the failed streak since
	// the last self-heal, walked on the same (started_at, id) sequence. Only completed breaks it:
	// self-heal means the workflow demonstrably WORKED. running and cancelled both simply don't
	// participate — undecided and neutral respectively (the domain's one law for cancelled); neither
	// counts nor breaks. Tuple comparison keeps same-timestamp neighbors ordered exactly like the
	// lists render them.
	//
	// Two things make this fast, and both are load-bearing (see idx_fr_ws_wf_status's note for the
	// measured numbers this shape replaces):
	//   - The EXISTS probe rides idx_fr_ws_wf_status, whose (ws, wf, status) prefix turns "is there a
	//     newer completed run" into a seek at the newest completed row instead of a scan over every
	//     newer row of the workflow — the difference between O(K log N) and O(K²) in the streak length.
	//   - The comparison stays RAW, deliberately: julianday() would defeat that index. It is safe here
	//     and only here because both sides are COLUMNS of this table, written by one driver in one
	//     format, and the raw text order is by definition the order the indexes and every run list
	//     already use. julianday belongs where a column meets a caller-supplied parameter (the `since`
	//     windows above), which is where format drift actually lives.
	//
	// ④ 连败：没有更新的 **completed** 的 failed run——即自上次自愈以来的失败连串，走同一 (started_at, id)
	// 序。**只有 completed 断串**：自愈的意思是该 workflow **证明**跑通了。running 与 cancelled 都不参与
	// ——分别是未定局与中性（domain 里 cancelled 的唯一立法）；两者既不计数也不断串。元组比较让同时间戳
	// 邻居与列表渲染完全同序。
	//
	// 让它快的有两点、皆承重（这个形状取代了什么，实测数字见 idx_fr_ws_wf_status 的注释）：
	//   - EXISTS 探测走 idx_fr_ws_wf_status，其 (ws, wf, status) 前缀把「有没有更新的 completed」从
	//     「扫遍该 workflow 所有更新的行」变成「seek 到最新那条 completed」——在连败长度上就是 O(K log N)
	//     与 O(K²) 之差。
	//   - 比较**刻意**保持裸的：julianday() 会让那个索引失效。它在这里、也只在这里安全，因为两侧都是**本表
	//     的列**、由同一个驱动以同一格式写入，而裸文本序**按定义**就是索引与所有 run 列表已在用的序。
	//     julianday 属于「列 vs 调用方传入的参数」（上面那些 `since` 窗口）——格式漂移真正住的地方。
	args = append([]any{wsID}, idArgs...)
	streak, err := s.db.Query(ctx, `
		SELECT f.workflow_id, COUNT(*)
		FROM flowruns f
		WHERE f.workspace_id = ? AND f.workflow_id IN `+in+` AND f.status = 'failed'
			AND NOT EXISTS (
				SELECT 1 FROM flowruns g
				WHERE g.workspace_id = f.workspace_id AND g.workflow_id = f.workflow_id
					AND g.status = 'completed'
					AND (g.started_at, g.id) > (f.started_at, f.id)
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
