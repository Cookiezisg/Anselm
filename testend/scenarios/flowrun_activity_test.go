// flowrun_activity_test.go — black-box coverage for GET /flowruns/{id}/activity (scheduler 工单⑤)
// + the node queue stamps it joins (工单⑫). Zero tokens: a two-agent-node workflow driven by
// llmmock leaves two agent_executions audit rows; the activity page must return them in gantt
// order with positive execution windows and the ⑫ queue stamp attached, and the run's node rows
// must carry readyAt/startedAt on the wire.
//
// flowrun_activity_test.go——GET /flowruns/{id}/activity（scheduler 工单⑤）+ 它 join 的节点排队戳
// （工单⑫）的黑盒覆盖。零 token：llmmock 驱动的双 agent 节点 workflow 留两条 agent_executions 审计行；
// activity 页必须按甘特序返回、执行窗为正、带 ⑫ 排队戳，且 run 节点行线缆携 readyAt/startedAt。
package scenarios

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/sunweilin/anselm/testend/harness"
)

type activityRow struct {
	NodeID    string     `json:"nodeId"`
	Iteration int        `json:"iteration"`
	Kind      string     `json:"kind"`
	ExecID    string     `json:"execId"`
	Status    string     `json:"status"`
	ReadyAt   *time.Time `json:"readyAt"`
	StartedAt time.Time  `json:"startedAt"`
	EndedAt   time.Time  `json:"endedAt"`
	ElapsedMs int64      `json:"elapsedMs"`
}

// TestFlowrunActivity_GanttProjection: 双 agent 节点串行 run → activity 两行甘特序、执行窗为正、
// 排队戳存在且 ready ≤ started;节点行线缆带 ⑫ 两戳;?limit=1 keyset 走两页不漏不重;幽灵 run 404。
func TestFlowrunActivity_GanttProjection(t *testing.T) {
	t.Parallel()
	wc, mock := agentSetup(t)

	agID := agCreate(t, wc, map[string]any{
		"name": "Activity Worker", "description": "gantt probe", "prompt": "Do the step.",
	})
	wfID := wfCreate(t, wc, "activity_pipe", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
		{"op": "add_node", "node": map[string]any{"id": "step1", "kind": "agent", "ref": agID,
			"input": map[string]any{"task": "start.task"}}},
		{"op": "add_node", "node": map[string]any{"id": "step2", "kind": "agent", "ref": agID,
			"input": map[string]any{"task": "step1.text"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "step1"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e2", "from": "step1", "to": "step2"}},
	})
	// StallMS keeps each agent turn measurably long — the execution window must be POSITIVE.
	// StallMS 让每个 agent 轮可测地长——执行窗必须为**正**。
	mock.Enqueue(agModel, harness.LLMTurn{Text: "one done", StallMS: 30})
	mock.Enqueue(agModel, harness.LLMTurn{Text: "two done", StallMS: 30})

	runID, status, nodes := runAndWait(t, wc, wfID, map[string]any{"task": "go"}, 30000)
	if status != "completed" {
		t.Fatalf("two-agent run must complete, got %s nodes=%s", status, nodes)
	}

	// ⑫ on the wire: the run's scheduled node rows carry readyAt/startedAt; the seed trigger stays bare.
	// ⑫ 上线缆：被调度节点行携 readyAt/startedAt；seed trigger 行保持无戳。
	var nodeRows []struct {
		NodeID    string     `json:"nodeId"`
		Kind      string     `json:"kind"`
		ReadyAt   *time.Time `json:"readyAt"`
		StartedAt *time.Time `json:"startedAt"`
	}
	if err := json.Unmarshal(nodes, &nodeRows); err != nil {
		t.Fatalf("nodes decode: %v", err)
	}
	for _, n := range nodeRows {
		switch n.Kind {
		case "trigger":
			if n.ReadyAt != nil || n.StartedAt != nil {
				t.Fatalf("seed trigger row must carry no queue stamps: %+v", n)
			}
		default:
			if n.ReadyAt == nil || n.StartedAt == nil || n.StartedAt.Before(*n.ReadyAt) {
				t.Fatalf("node %s must carry ordered queue stamps: %+v", n.NodeID, n)
			}
		}
	}

	// ⑤: gantt order, positive windows, queue stamp joined.
	// ⑤：甘特序、执行窗为正、排队戳 join 到位。
	var rows []activityRow
	wc.GET("/api/v1/flowruns/"+runID+"/activity").OK(t, &rows)
	if len(rows) != 2 {
		t.Fatalf("want 2 activity rows, got %d: %+v", len(rows), rows)
	}
	if rows[0].NodeID != "step1" || rows[1].NodeID != "step2" {
		t.Fatalf("gantt order wrong: %+v", rows)
	}
	for i, r := range rows {
		if r.Kind != "agent" || r.Status != "ok" || r.Iteration != 0 || r.ExecID == "" {
			t.Fatalf("row %d shape wrong: %+v", i, r)
		}
		if r.ElapsedMs <= 0 || !r.EndedAt.After(r.StartedAt) {
			t.Fatalf("row %d execution window must be positive: elapsed=%d started=%v ended=%v", i, r.ElapsedMs, r.StartedAt, r.EndedAt)
		}
		if r.ReadyAt == nil || r.StartedAt.Before(*r.ReadyAt) {
			t.Fatalf("row %d must carry the queue stamp with ready ≤ started: %+v", i, r)
		}
	}
	if rows[1].StartedAt.Before(rows[0].StartedAt) {
		t.Fatalf("rows must ascend by startedAt: %v then %v", rows[0].StartedAt, rows[1].StartedAt)
	}

	// N4 keyset: limit=1 walks two pages without skip or duplication.
	// N4 keyset：limit=1 走两页不漏不重。
	var page1 []activityRow
	r1 := wc.GET("/api/v1/flowruns/" + runID + "/activity?limit=1")
	r1.OK(t, &page1)
	if len(page1) != 1 || r1.NextCursor == "" || page1[0].ExecID != rows[0].ExecID {
		t.Fatalf("page 1 wrong: %+v next=%q", page1, r1.NextCursor)
	}
	var page2 []activityRow
	r2 := wc.GET("/api/v1/flowruns/" + runID + "/activity?limit=1&cursor=" + r1.NextCursor)
	r2.OK(t, &page2)
	if len(page2) != 1 || page2[0].ExecID != rows[1].ExecID || r2.NextCursor != "" {
		t.Fatalf("page 2 wrong: %+v next=%q", page2, r2.NextCursor)
	}

	// Ghost run → honest 404, never an empty page. 幽灵 run → 诚实 404、绝非空页。
	if r := wc.GET("/api/v1/flowruns/fr_ghost_never/activity"); r.Status != 404 || r.Code != "FLOWRUN_NOT_FOUND" {
		t.Fatalf("ghost run must 404 FLOWRUN_NOT_FOUND, got %d %s", r.Status, r.Code)
	}
}
