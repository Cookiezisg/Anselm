package scenarios

// scheduler_p1_test.go — scheduler P1 工单黑盒:
// ⑥ GET /flowruns 过滤器(origin/triggerId/startedAfter/startedBefore,真 run 真过滤 + 非法值 422)
// ⑮ GET /flowruns 的 completedAfter/completedBefore 窗(半开边界由 run 自己的 completedAt 钉死 +
//    NULL 剔除:未落定 run 被任一 completed 窗剔除 → status=running&completedAfter 空)
// ⑦ trigger :pause/:resume(暂停后 cron 到点不 fire、:fire 422、重启后仍暂停;resume 后真 fire)
//
// scheduler_p1_test.go — black-box for the scheduler list/schedule work orders: ⑥ flowrun list
// filters over real runs (origin/triggerId/started window + loud 422s), ⑮ the completed_at window
// (half-open bounds pinned by a run's own completedAt + the NULL rule that a still-running run is
// dropped by any completed window), and ⑦ the trigger pause/resume switch (a paused cron does NOT
// fire at the tick, :fire is refused, the switch survives a restart; resume fires again).

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/sunweilin/anselm/testend/harness"
)

type frRow struct {
	ID          string `json:"id"`
	Status      string `json:"status"`
	Origin      string `json:"origin"`
	TriggerID   string `json:"triggerId"`
	CompletedAt string `json:"completedAt"`
}

func listRunRows(t *testing.T, wc *harness.Client, query string) []frRow {
	t.Helper()
	var rows []frRow
	wc.GET("/api/v1/flowruns"+query).OK(t, &rows)
	return rows
}

// TestFlowruns_ListFilters — 工单⑥: one webhook-fired run + one manual run in the same workflow,
// then every new filter axis proves itself against real rows.
func TestFlowruns_ListFilters(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "fr-filters"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	trgID := trgCreate(t, wc, "filter_hook", "webhook", map[string]any{"path": "filterp"})
	wfID, _ := wfWithTrigger(t, wc, "filter_pipe", trgID)

	// One trigger-fired run (origin = the trigger's kind: webhook) + one manual run (origin=manual).
	// 一个触发起的 run（origin=trigger kind：webhook）+ 一个手动 run（origin=manual）。
	wc.POST("/api/v1/triggers/"+trgID+":fire", map[string]any{}).OK(t, nil)
	wc.POST("/api/v1/flowruns", map[string]any{"workflowId": wfID, "payload": map[string]any{}}).OK(t, nil)
	harness.Eventually(t, 30000, "both runs complete", func() bool {
		rows := listRunRows(t, wc, "?workflowId="+wfID)
		done := 0
		for _, r := range rows {
			if r.Status == "completed" {
				done++
			}
		}
		return done == 2
	})

	// origin filter: exactly one run per origin, and the two never bleed into each other.
	// origin 过滤：每个 origin 恰一条，互不串。
	hooked := listRunRows(t, wc, "?workflowId="+wfID+"&origin=webhook")
	if len(hooked) != 1 || hooked[0].Origin != "webhook" || hooked[0].TriggerID != trgID {
		t.Fatalf("origin=webhook must match exactly the fired run: %+v", hooked)
	}
	manual := listRunRows(t, wc, "?workflowId="+wfID+"&origin=manual")
	if len(manual) != 1 || manual[0].Origin != "manual" {
		t.Fatalf("origin=manual must match exactly the manual run: %+v", manual)
	}

	// triggerId filter: only the fired run carries the entry trg_. triggerId 过滤：只有触发起的 run 带入口 trg_。
	byTrg := listRunRows(t, wc, "?triggerId="+trgID)
	if len(byTrg) != 1 || byTrg[0].ID != hooked[0].ID {
		t.Fatalf("triggerId filter must match only the fired run: %+v", byTrg)
	}

	// started window: everything sits between the distant past and future bounds; an inverted
	// window is honestly empty. 时间窗：远过去/远未来界内全中；反向窗诚实为空。
	past, future := "2000-01-01T00:00:00Z", "2100-01-01T00:00:00Z"
	if rows := listRunRows(t, wc, "?workflowId="+wfID+"&startedAfter="+past+"&startedBefore="+future); len(rows) != 2 {
		t.Fatalf("wide window must match both runs, got %d", len(rows))
	}
	if rows := listRunRows(t, wc, "?workflowId="+wfID+"&startedBefore="+past); len(rows) != 0 {
		t.Fatalf("window ending in the past must be empty, got %d", len(rows))
	}
	// Filters compose with AND. 过滤 AND 组合。
	if rows := listRunRows(t, wc, "?workflowId="+wfID+"&origin=webhook&status=completed&startedAfter="+past); len(rows) != 1 {
		t.Fatalf("composed filters must still match the fired run, got %d", len(rows))
	}

	// Illegal values are loud 422s, never silent empty pages. 非法值 422 大声拒、绝不静默空页。
	wc.GET("/api/v1/flowruns?origin=gremlin").Fail(t, 422, "FLOWRUN_LIST_INVALID_FILTER")
	wc.GET("/api/v1/flowruns?startedAfter=yesterday").Fail(t, 422, "FLOWRUN_LIST_INVALID_FILTER")
	wc.GET("/api/v1/flowruns?startedBefore=24h").Fail(t, 422, "FLOWRUN_LIST_INVALID_FILTER")
	wc.GET("/api/v1/flowruns?status=parked").Fail(t, 422, "FLOWRUN_INVALID_STATUS") // 既有轴不回归。
}

// TestFlowruns_CompletedWindow — 工单⑮: the `?completedAfter`/`?completedBefore` window that makes the
// Overview's 「24h 失败」 KPI card clickable. Two things black-box CANNOT test (they go to unit tests):
// (1) that the read seeks idx_fr_ws_status_completed — that is an EXPLAIN guard (flowrun_plan_test.go),
// (2) old runs (retention needs >1 day). What it CAN — and does here, against real rows — is the
// SEMANTICS: half-open bounds pinned by a run's OWN completedAt (mid-point discrimination the started
// window's test never did), and the load-bearing NULL rule — a run with no completed_at (parked, still
// running) is dropped by ANY completed window, so `status=running&completedAfter=<past>` is empty. That
// last one is the surprising-but-correct behavior a future reader must not "fix", so it is nailed here.
func TestFlowruns_CompletedWindow(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "fr-completed"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	// wfApproval: trigger → approval. A run parks (RUNNING, no completed_at). Decide "no" with no
	// no-edge → it lands completed (gets a completed_at). Zero tokens, zero sandbox.
	// wfApproval:trigger → approval。run park(RUNNING、无 completed_at);决 no 且无 no 边 → completed。
	apfID := wc.POST("/api/v1/approvals", map[string]any{
		"name": "cw_gate", "template": "ok {{ input.v }}?", "allowReason": true,
	}).Field(t, "id")
	wfApproval := wfCreate(t, wc, "cw_approval_pipe", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
		{"op": "add_node", "node": map[string]any{"id": "human", "kind": "approval", "ref": apfID, "input": map[string]any{"v": "start.v"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "human"}},
	})
	// wfGhost: trigger → ghost function → always failed (a failed run HAS a completed_at). 幽灵 fn → failed。
	wfGhost := wfCreate(t, wc, "cw_ghost_pipe", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
		{"op": "add_node", "node": map[string]any{"id": "boom", "kind": "action", "ref": "fn_ghost_never_exists"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "boom"}},
	})

	var started struct {
		Flowrun struct {
			ID string `json:"id"`
		} `json:"flowrun"`
		Nodes json.RawMessage `json:"nodes"`
	}
	// The RUNNING run — parked and left undecided (no completed_at, ever). 在跑 run:park 不决,永无 completed_at。
	wc.POST("/api/v1/flowruns", map[string]any{"workflowId": wfApproval, "payload": map[string]any{"v": "run"}}).OK(t, &started)
	if !strings.Contains(string(started.Nodes), `"parked"`) {
		t.Fatalf("the running run must park: %s", started.Nodes)
	}
	runningID := started.Flowrun.ID
	// The COMPLETED run — parked, then decided no (no no-edge → settles completed). 落定 completed 的 run。
	wc.POST("/api/v1/flowruns", map[string]any{"workflowId": wfApproval, "payload": map[string]any{"v": "done"}}).OK(t, &started)
	completedID := started.Flowrun.ID
	wc.POST("/api/v1/flowruns/"+completedID+"/approvals/human:decide", map[string]any{"decision": "no", "reason": "cw"}).OK(t, nil)
	harness.Eventually(t, 20000, "the completed run lands", func() bool {
		r := wc.GET("/api/v1/flowruns/" + completedID)
		return r.Status == 200 && strings.Contains(string(r.Data), `"status":"completed"`)
	})
	// The FAILED run — a ghost fn (a failed run also has a completed_at). 失败 run(也有 completed_at)。
	failedID, status, _ := runAndWait(t, wc, wfGhost, map[string]any{}, 30000)
	if status != "failed" {
		t.Fatalf("ghost-fn run must fail, got %s", status)
	}

	find := func(rows []frRow, id string) *frRow {
		for i := range rows {
			if rows[i].ID == id {
				return &rows[i]
			}
		}
		return nil
	}

	// completed_at is on the wire for landed runs and ABSENT for the running one (omitempty). This is
	// the whole premise: a completed window can only speak about runs that carry the column.
	// completed_at 在落定 run 的线缆上、在 running 那个上**缺席**(omitempty)——completed 窗只讲带该列的 run。
	all := listRunRows(t, wc, "?workflowId="+wfApproval)
	completed := find(all, completedID)
	running := find(all, runningID)
	if completed == nil || completed.CompletedAt == "" {
		t.Fatalf("the completed run must carry a completedAt: %+v", completed)
	}
	if running == nil || running.CompletedAt != "" {
		t.Fatalf("the running run must NOT carry a completedAt (it never landed): %+v", running)
	}

	c0, err := time.Parse(time.RFC3339, completed.CompletedAt)
	if err != nil {
		t.Fatalf("parse completedAt %q: %v", completed.CompletedAt, err)
	}
	before := c0.Add(-time.Second).UTC().Format(time.RFC3339Nano)
	after := c0.Add(time.Second).UTC().Format(time.RFC3339Nano)

	// Half-open [after, before) on completed_at, pinned by the run's OWN instant:
	//   completedAfter just before it  → present (inclusive lower bound reached from below)
	//   completedAfter one second after → absent
	//   completedBefore one second after → present ; completedBefore just before → absent
	// 半开窗,由 run 自己的时刻钉死:下界含、上界不含。
	if r := find(listRunRows(t, wc, "?workflowId="+wfApproval+"&completedAfter="+before), completedID); r == nil {
		t.Fatalf("completedAfter just before its landing must INCLUDE the run")
	}
	if r := find(listRunRows(t, wc, "?workflowId="+wfApproval+"&completedAfter="+after), completedID); r != nil {
		t.Fatalf("completedAfter one second after its landing must EXCLUDE the run")
	}
	if r := find(listRunRows(t, wc, "?workflowId="+wfApproval+"&completedBefore="+after), completedID); r == nil {
		t.Fatalf("completedBefore just after its landing must INCLUDE the run")
	}
	if r := find(listRunRows(t, wc, "?workflowId="+wfApproval+"&completedBefore="+before), completedID); r != nil {
		t.Fatalf("completedBefore just before its landing must EXCLUDE the run")
	}

	// THE load-bearing rule: a run with no completed_at is dropped by ANY completed window (NULL >= ?
	// is never true). A wide-open completedAfter holds the completed run but NOT the still-parked one.
	// 承重规则:无 completed_at 的 run 被任一 completed 窗剔除。宽窗收落定的、绝不收还 park 着的。
	past := "2000-01-01T00:00:00Z"
	wide := listRunRows(t, wc, "?workflowId="+wfApproval+"&completedAfter="+past)
	if find(wide, completedID) == nil {
		t.Fatalf("a wide completedAfter must hold the completed run")
	}
	if find(wide, runningID) != nil {
		t.Fatalf("a wide completedAfter must NOT hold the still-running (unlanded) run")
	}
	// The surprising-but-correct one: status=running + completedAfter is EMPTY — a running run cannot
	// satisfy a completed window. Nailed so nobody "fixes" it. 在跑 run 满足不了 completed 窗 → 空。
	if rows := listRunRows(t, wc, "?workflowId="+wfApproval+"&status=running&completedAfter="+past); len(rows) != 0 {
		t.Fatalf("status=running & completedAfter must be empty (running has no completed_at), got %d", len(rows))
	}

	// AND-composition with status across the workspace: the failed run is the card's exact predicate
	// (status=failed & completedAfter=<past>). AND 组合:失败 run = 牌的精确谓词。
	failedWide := listRunRows(t, wc, "?status=failed&completedAfter="+past)
	if find(failedWide, failedID) == nil {
		t.Fatalf("status=failed & completedAfter must hold the ghost-fn failure")
	}
	for _, r := range failedWide {
		if r.Status != "failed" {
			t.Fatalf("status=failed filter leaked a %s row", r.Status)
		}
	}

	// Bad bounds are loud 422s naming the flowrun list filter (same code as startedAfter — same
	// resource, deliberately NOT firings' code). 坏界 422、点名 flowrun 列表过滤(同 startedAfter 的码)。
	wc.GET("/api/v1/flowruns?completedAfter=yesterday").Fail(t, 422, "FLOWRUN_LIST_INVALID_FILTER")
	wc.GET("/api/v1/flowruns?completedBefore=24h").Fail(t, 422, "FLOWRUN_LIST_INVALID_FILTER")
}

type trgRow struct {
	Paused     bool   `json:"paused"`
	Listening  bool   `json:"listening"`
	NextFireAt string `json:"nextFireAt"`
}

func getTrg(t *testing.T, wc *harness.Client, id string) trgRow {
	t.Helper()
	var tr trgRow
	wc.GET("/api/v1/triggers/"+id).OK(t, &tr)
	return tr
}

// TestTrigger_PauseResume_CronGate — 工单⑦: pause a listening every-minute cron, restart the
// process (the switch is persisted), prove the tick passes WITHOUT firing, then resume and see it
// fire for real.
func TestTrigger_PauseResume_CronGate(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "trg-pause"}).OK(t, nil)
	wsID := ws.Field(t, "id")
	wc := c.WS(wsID)

	trgID := trgCreate(t, wc, "tick_gate", "cron", map[string]any{"expression": "* * * * *"})
	wfID, _ := wfWithTrigger(t, wc, "pause_pipe", trgID)

	// Listening (workflow active) — now hit the switch before any tick lands.
	// 已在监听（workflow active）——在任何刻度落地前按下开关。
	var paused trgRow
	wc.POST("/api/v1/triggers/"+trgID+":pause", map[string]any{}).OK(t, &paused)
	if !paused.Paused || paused.Listening || paused.NextFireAt != "" {
		t.Fatalf("paused trigger must read paused=true, listening=false, no nextFireAt: %+v", paused)
	}
	// Idempotent repeat. 重复暂停幂等。
	wc.POST("/api/v1/triggers/"+trgID+":pause", map[string]any{}).OK(t, nil)
	// Manual fire refuses loudly. 手动催大声拒。
	wc.POST("/api/v1/triggers/"+trgID+":fire", map[string]any{}).Fail(t, 422, "TRIGGER_PAUSED")

	// The switch survives a hard restart (persisted column + boot re-attach skips Register).
	// 开关活过硬重启（持久列 + boot 重挂跳过 Register）。
	srv.Kill9(t)
	srv.Restart(t)
	wc = srv.Client(t).WS(wsID)
	if tr := getTrg(t, wc, trgID); !tr.Paused || tr.Listening || tr.NextFireAt != "" {
		t.Fatalf("pause must survive a restart: %+v", tr)
	}

	// Let at least one full minute boundary pass — the tick must NOT fire. Baselines are taken
	// AFTER the pause: in the sliver between activate and :pause a boundary tick may already have
	// fired, which is legitimate pre-pause history, not a gate leak.
	// 让至少一个整分钟边界过去——刻度必须不 fire。基线在 pause **之后**取：activate 与 :pause 的间隙
	// 可能恰逢边界已 fire 一次，那是暂停前的合法历史、不是闸漏。
	baseRuns := len(listRunRows(t, wc, "?workflowId="+wfID))
	baseFired := strings.Count(string(wc.GET("/api/v1/triggers/"+trgID+"/activations").Data), `"fired":true`)
	boundary := time.Now().Truncate(time.Minute).Add(time.Minute + 10*time.Second)
	time.Sleep(time.Until(boundary))
	if rows := listRunRows(t, wc, "?workflowId="+wfID); len(rows) != baseRuns {
		t.Fatalf("paused cron must not start runs at the tick: %d → %d", baseRuns, len(rows))
	}
	if fired := strings.Count(string(wc.GET("/api/v1/triggers/"+trgID+"/activations").Data), `"fired":true`); fired != baseFired {
		t.Fatalf("paused cron must not record fired activations: %d → %d", baseFired, fired)
	}

	// Resume flips it back: projection restored, then the next tick really fires a NEW run
	// (strictly beyond the pre-pause baseline).
	// 恢复翻回：投影复原,下一刻度真触发**新** run（严格超出暂停前基线）。
	var resumed trgRow
	wc.POST("/api/v1/triggers/"+trgID+":resume", map[string]any{}).OK(t, &resumed)
	if resumed.Paused || !resumed.Listening || resumed.NextFireAt == "" {
		t.Fatalf("resumed trigger must read paused=false, listening=true, nextFireAt set: %+v", resumed)
	}
	harness.Eventually(t, 75000, "a fresh run completes after resume", func() bool {
		rows := listRunRows(t, wc, "?workflowId="+wfID+"&status=completed")
		return len(rows) > baseRuns
	})

	// The fired run carries the cron provenance stamp — closing the loop with 工单⑥'s filter.
	// 触发的 run 带 cron 溯源章——与工单⑥ 的过滤闭环。
	if rows := listRunRows(t, wc, fmt.Sprintf("?workflowId=%s&origin=cron", wfID)); len(rows) == 0 {
		t.Fatalf("the post-resume run must stamp origin=cron")
	}
}
