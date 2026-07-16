// flowrun_stats_test.go — black-box coverage for GET /flowrun-stats (scheduler 工单③), the
// operational statistics batch feeding the scheduler ocean's rail + Overview. Zero tokens, zero
// sandbox: completed comes from an approval decided "no" with no no-edge (the run settles with
// nothing ready), failed from an action referencing a ghost function, running+parked from an
// undecided approval.
//
// flowrun_stats_test.go——GET /flowrun-stats（scheduler 工单③）的黑盒覆盖:喂 scheduler 海洋 rail +
// Overview 的运营统计批查。零 token 零 sandbox:completed 用「审批决 no 且无 no 边」造（无 ready 即
// 落定）、failed 用引用幽灵 function 的 action 造、running+parked 用未决审批造。
package scenarios

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

type statsRow struct {
	WorkflowID          string   `json:"workflowId"`
	Running             int      `json:"running"`
	ParkedRuns          int      `json:"parkedNodes"`
	LastRunAt           string   `json:"lastRunAt"`
	Recent              []string `json:"recent"`
	SuccessRate         *float64 `json:"successRate"`
	AvgElapsedMs        *int64   `json:"avgElapsedMs"`
	ConsecutiveFailures int      `json:"consecutiveFailures"`
}

type statsResp struct {
	Totals struct {
		Running        int `json:"running"`
		CompletedSince int `json:"completedSince"`
		FailedSince    int `json:"failedSince"`
		ParkedNodes    int `json:"parkedNodes"`
	} `json:"totals"`
	ByWorkflow []statsRow `json:"byWorkflow"`
}

// TestFlowrunStats_BatchProjection: 全景一遍——totals 全 workspace、byWorkflow 请求序含幽灵零值行、
// recent 新→旧、连败计数、parked=等人 run 数、超限与坏 since 大声拒。
func TestFlowrunStats_BatchProjection(t *testing.T) {
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "fr-stats"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	// wfA: trigger → approval(yes 边悬空也行,这里干脆无下游)。两个 run:#1 park 不决(running+等人),
	// #2 决 no → 无 no 边 → run completed。
	apfID := wc.POST("/api/v1/approvals", map[string]any{
		"name": "stats_gate", "template": "ok {{ input.v }}?", "allowReason": true,
	}).Field(t, "id")
	wfA := wfCreate(t, wc, "stats_approval_pipe", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
		{"op": "add_node", "node": map[string]any{"id": "human", "kind": "approval", "ref": apfID, "input": map[string]any{"v": "start.v"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "human"}},
	})
	// wfB: trigger → 幽灵 function → 每次必 failed。
	wfB := wfCreate(t, wc, "stats_ghost_pipe", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
		{"op": "add_node", "node": map[string]any{"id": "boom", "kind": "action", "ref": "fn_ghost_never_exists"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "boom"}},
	})

	// run A#1 → park 后置之不理(running + 等人)。
	var started struct {
		Flowrun struct {
			ID string `json:"id"`
		} `json:"flowrun"`
		Nodes json.RawMessage `json:"nodes"`
	}
	wc.POST("/api/v1/flowruns", map[string]any{"workflowId": wfA, "payload": map[string]any{"v": "one"}}).OK(t, &started)
	if !strings.Contains(string(started.Nodes), `"parked"`) {
		t.Fatalf("run A#1 must park: %s", started.Nodes)
	}
	// run A#2 → park → 决 no → completed(无 no 边,无 ready 即落定)。
	wc.POST("/api/v1/flowruns", map[string]any{"workflowId": wfA, "payload": map[string]any{"v": "two"}}).OK(t, &started)
	runA2 := started.Flowrun.ID
	wc.POST("/api/v1/flowruns/"+runA2+"/approvals/human:decide", map[string]any{"decision": "no", "reason": "stats probe"}).OK(t, nil)
	harness.Eventually(t, 20000, "run A#2 completes after the no decision", func() bool {
		r := wc.GET("/api/v1/flowruns/" + runA2)
		return r.Status == 200 && strings.Contains(string(r.Data), `"status":"completed"`)
	})
	// run B ×2 → 都 failed(连败 ×2)。
	for i := 0; i < 2; i++ {
		_, status, _ := runAndWait(t, wc, wfB, map[string]any{}, 30000)
		if status != "failed" {
			t.Fatalf("ghost-fn run must fail, got %s", status)
		}
	}

	// 批查:请求序 = [wfA, wfB, 幽灵 id];幽灵回零值行、不缺席。
	var stats statsResp
	wc.GET("/api/v1/flowrun-stats?workflowIds="+wfA+","+wfB+",wf_ghost_id").OK(t, &stats)

	if stats.Totals.Running != 1 || stats.Totals.CompletedSince != 1 || stats.Totals.FailedSince != 2 || stats.Totals.ParkedNodes != 1 {
		t.Fatalf("totals wrong: %+v", stats.Totals)
	}
	if len(stats.ByWorkflow) != 3 || stats.ByWorkflow[0].WorkflowID != wfA || stats.ByWorkflow[1].WorkflowID != wfB || stats.ByWorkflow[2].WorkflowID != "wf_ghost_id" {
		t.Fatalf("byWorkflow must follow request order incl. the ghost id: %+v", stats.ByWorkflow)
	}

	a := stats.ByWorkflow[0]
	// recent 新→旧:A#2(completed)在前、A#1(running)在后;行级 parkedNodes=1(A#1 未决审批,rail 琥珀点);
	// 窗口内成功率 1(cancelled/running 不参与);无连败。
	if a.Running != 1 || a.ParkedRuns != 1 || len(a.Recent) != 2 || a.Recent[0] != "completed" || a.Recent[1] != "running" {
		t.Fatalf("wfA row wrong: %+v", a)
	}
	if a.SuccessRate == nil || *a.SuccessRate != 1.0 || a.AvgElapsedMs == nil || a.ConsecutiveFailures != 0 || a.LastRunAt == "" {
		t.Fatalf("wfA windowed stats wrong: %+v", a)
	}

	b := stats.ByWorkflow[1]
	if b.ConsecutiveFailures != 2 || b.ParkedRuns != 0 || b.SuccessRate == nil || *b.SuccessRate != 0 || len(b.Recent) != 2 || b.Recent[0] != "failed" {
		t.Fatalf("wfB row wrong: %+v", b)
	}
	if b.AvgElapsedMs != nil {
		t.Fatalf("wfB has no completed run — avgElapsedMs must be absent, got %v", *b.AvgElapsedMs)
	}

	g := stats.ByWorkflow[2]
	if g.Running != 0 || g.ParkedRuns != 0 || len(g.Recent) != 0 || g.SuccessRate != nil || g.ConsecutiveFailures != 0 || g.LastRunAt != "" {
		t.Fatalf("ghost id must be a zero row: %+v", g)
	}

	// recentN=1 只留最新一珠;since 窗口挪到未来 → 窗口数清零、连败仍在。
	// (解进全新变量——json.Unmarshal 会复用旧切片元素,omitempty 缺席键会留下上一轮的指针。)
	var knobs statsResp
	wc.GET("/api/v1/flowrun-stats?workflowIds="+wfB+"&recentN=1&since=2099-01-01T00:00:00Z").OK(t, &knobs)
	if len(knobs.ByWorkflow[0].Recent) != 1 || knobs.ByWorkflow[0].SuccessRate != nil || knobs.ByWorkflow[0].ConsecutiveFailures != 2 {
		t.Fatalf("recentN/since knobs wrong: %+v", knobs.ByWorkflow[0])
	}
	if knobs.Totals.FailedSince != 0 {
		t.Fatalf("future since must empty the windowed totals: %+v", knobs.Totals)
	}

	// 超限:51 个 id → 422 大声拒带码。
	ids := make([]string, 51)
	for i := range ids {
		ids[i] = fmt.Sprintf("wf_bulk%02d", i)
	}
	r := wc.GET("/api/v1/flowrun-stats?workflowIds=" + strings.Join(ids, ","))
	if r.Status != 422 || r.Code != "FLOWRUN_STATS_TOO_MANY_IDS" {
		t.Fatalf("51 ids must 422 FLOWRUN_STATS_TOO_MANY_IDS, got %d %s", r.Status, r.Code)
	}
	// 坏 since → 422。
	r = wc.GET("/api/v1/flowrun-stats?since=gremlin")
	if r.Status != 422 || r.Code != "FLOWRUN_STATS_INVALID_SINCE" {
		t.Fatalf("bad since must 422 FLOWRUN_STATS_INVALID_SINCE, got %d %s", r.Status, r.Code)
	}
}
