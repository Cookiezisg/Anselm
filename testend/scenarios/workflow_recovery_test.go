package scenarios

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// TestWorkflow_ParkedApprovalSurvivesRestartAndDecide proves that a parked human gate is durable
// recovery state, not an in-memory spinner: boot preserves the running flowrun and inbox row, a
// post-restart decision resumes the pinned graph, and the downstream function audit remains joined.
//
// TestWorkflow_ParkedApprovalSurvivesRestartAndDecide 证明 parked 人工审批是耐久恢复状态，而非内存
// spinner：重启保留 running flowrun 与 inbox 行；重启后决定仍续跑钉死图，下游 function 审计仍闭合。
func TestWorkflow_ParkedApprovalSurvivesRestartAndDecide(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "wf-approval-recovery"}).OK(t, nil)
	wsID := ws.Field(t, "id")
	wc := c.WS(wsID)

	publishFn := fnCreate(t, wc, "approval_recovered_publish", "def publish(decision: str) -> dict:\n    return {'published': decision}\n")
	apfID := wc.POST("/api/v1/approvals", map[string]any{
		"name": "approval_recovery_gate", "template": "approve {{ input.amount }}?", "allowReason": true,
	}).Field(t, "id")
	wfID := wfCreate(t, wc, "approval_recovery_pipe", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
		{"op": "add_node", "node": map[string]any{
			"id": "human", "kind": "approval", "ref": apfID,
			"input": map[string]any{"amount": "start.amount"},
		}},
		{"op": "add_node", "node": map[string]any{
			"id": "publish", "kind": "action", "ref": publishFn,
			"input": map[string]any{"decision": "human.decision"},
		}},
		{"op": "add_edge", "edge": map[string]any{"id": "e-start-human", "from": "start", "to": "human"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e-human-publish", "from": "human", "to": "publish", "fromPort": "yes"}},
	})

	var started struct {
		Flowrun struct {
			ID string `json:"id"`
		} `json:"flowrun"`
		Nodes json.RawMessage `json:"nodes"`
	}
	wc.POST("/api/v1/flowruns", map[string]any{
		"workflowId": wfID,
		"payload":    map[string]any{"amount": "500"},
	}).OK(t, &started)
	runID := started.Flowrun.ID
	if runID == "" || !strings.Contains(string(started.Nodes), `"status":"parked"`) {
		t.Fatalf("approval run must park before the crash: id=%q nodes=%s", runID, started.Nodes)
	}

	// Kill while the human decision is pending. A parked row is a recoverable live state, not an
	// abandoned in-flight call, so boot must leave it in the inbox.
	// 人工决定待处理时杀进程。parked 行是可恢复的活状态，不是废弃在途调用，boot 必须留在 inbox。
	srv.Kill9(t)
	srv.Restart(t)
	wc2 := srv.Client(t).WS(wsID)

	var recovered struct {
		Flowrun struct {
			Status string `json:"status"`
		} `json:"flowrun"`
		Nodes json.RawMessage `json:"nodes"`
	}
	harness.Eventually(t, 20000, "parked run survives boot", func() bool {
		r := wc2.GET("/api/v1/flowruns/" + runID)
		if r.Status != 200 {
			return false
		}
		if json.Unmarshal(r.Data, &recovered) != nil {
			return false
		}
		return recovered.Flowrun.Status == "running" && strings.Contains(string(recovered.Nodes), `"status":"parked"`)
	})

	var inbox struct {
		Parked []struct {
			FlowrunID string `json:"flowrunId"`
			NodeID    string `json:"nodeId"`
		} `json:"parked"`
	}
	wc2.GET("/api/v1/flowrun-inbox").OK(t, &inbox)
	matched := 0
	for _, row := range inbox.Parked {
		if row.FlowrunID == runID && row.NodeID == "human" {
			matched++
		}
	}
	if matched != 1 {
		t.Fatalf("restart must preserve exactly one actionable approval inbox row, got %d/%+v", matched, inbox.Parked)
	}

	wc2.POST("/api/v1/flowruns/"+runID+"/approvals/human:decide", map[string]any{
		"decision": "yes", "reason": "recovered approval",
	}).OK(t, nil)
	harness.Eventually(t, 20000, "recovered approval resumes workflow", func() bool {
		var got struct {
			Flowrun struct {
				Status string `json:"status"`
			} `json:"flowrun"`
			Nodes json.RawMessage `json:"nodes"`
		}
		r := wc2.GET("/api/v1/flowruns/" + runID)
		if r.Status != 200 || json.Unmarshal(r.Data, &got) != nil {
			return false
		}
		return got.Flowrun.Status == "completed" && strings.Contains(string(got.Nodes), `"published":"yes"`)
	})

	var final struct {
		Flowrun struct {
			Status string `json:"status"`
		} `json:"flowrun"`
		Nodes []struct {
			NodeID    string         `json:"nodeId"`
			Status    string         `json:"status"`
			Iteration int            `json:"iteration"`
			Result    map[string]any `json:"result"`
		} `json:"nodes"`
	}
	wc2.GET("/api/v1/flowruns/"+runID).OK(t, &final)
	if final.Flowrun.Status != "completed" || len(final.Nodes) != 3 {
		t.Fatalf("recovered approval graph must have three completed nodes: %+v", final)
	}
	seen := map[string]bool{}
	for _, node := range final.Nodes {
		if seen[node.NodeID] || node.Status != "completed" || node.Iteration != 0 {
			t.Fatalf("approval recovery node rows must be unique completed iteration 0: %+v", final.Nodes)
		}
		seen[node.NodeID] = true
		if node.NodeID == "human" && node.Result["decision"] != "yes" {
			t.Fatalf("approval decision was not durable: %+v", node.Result)
		}
	}
	for _, id := range []string{"start", "human", "publish"} {
		if !seen[id] {
			t.Fatalf("approval recovery lost node %s: %+v", id, final.Nodes)
		}
	}

	var executions struct {
		Executions []struct {
			Status           string `json:"status"`
			FlowrunID        string `json:"flowrunId"`
			FlowrunNodeID    string `json:"flowrunNodeId"`
			FlowrunIteration int    `json:"flowrunIteration"`
		} `json:"executions"`
	}
	wc2.GET("/api/v1/functions/"+publishFn+"/executions?flowrunId="+runID).OK(t, &executions)
	if len(executions.Executions) != 1 || executions.Executions[0].Status != "ok" || executions.Executions[0].FlowrunID != runID || executions.Executions[0].FlowrunNodeID != "publish" || executions.Executions[0].FlowrunIteration != 0 {
		t.Fatalf("post-restart approval continuation provenance wrong: %+v", executions.Executions)
	}
}
