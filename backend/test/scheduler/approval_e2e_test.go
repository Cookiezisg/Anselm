//go:build pipeline

// approval_e2e_test.go — Plan 06 F4 + Plan 05 §6.1/§3.5 end-to-end.
// Exercises the full approval lifecycle:
//
//   build workflow w/ approval node → trigger → pause → POST /approvals
//   → resume → complete
//
// RehydrateOnBoot is unit-tested in app/scheduler/pause_test.go; this
// pipeline test focuses on the HTTP approve → resume → complete path
// which is the user-facing UX gate.
//
// approval_e2e_test.go —— F4 + Plan 05 §6.1/§3.5 端到端。RehydrateOnBoot
// 由单测覆盖,本测专注 HTTP approve → resume → complete 用户面 UX。

package scheduler_test

import (
	"testing"
	"time"

	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
	workflowapp "github.com/sunweilin/forgify/backend/internal/app/workflow"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
	th "github.com/sunweilin/forgify/backend/test/harness"
)

// TestApproval_PauseResumeComplete_E2E — happy path approve.
//
//	trigger → approval pause → POST :approvals approve → completes
//
// TestApproval_PauseResumeComplete_E2E approve 路径完整跑通。
func TestApproval_PauseResumeComplete_E2E(t *testing.T) {
	h := th.New(t)
	ctx := th.LocalCtxAs(reqctxpkg.DefaultLocalUserID)

	// Build workflow: trigger → approval (will pause) → downstream
	// (approval.approved → ack node).
	// trigger → approval → ack(approval.approved port);approval pause 后
	// resume approved 走 ack 节点 → complete。
	wf, _, err := h.Workflow.Create(ctx, workflowapp.CreateInput{
		Ops: []workflowapp.Op{
			{Type: "set_meta", Raw: []byte(`{"op":"set_meta","name":"approval_happy","description":"e2e approve"}`)},
			{Type: "add_node", Raw: []byte(`{"op":"add_node","node":{"id":"trig","type":"trigger","config":{"triggerType":"manual"}}}`)},
			{Type: "add_node", Raw: []byte(`{"op":"add_node","node":{"id":"gate","type":"approval","config":{"prompt":"Proceed?"}}}`)},
			{Type: "add_node", Raw: []byte(`{"op":"add_node","node":{"id":"ack","type":"variable","config":{"operation":"set","name":"acked","value":"yes"}}}`)},
			{Type: "add_edge", Raw: []byte(`{"op":"add_edge","edge":{"id":"e1","from":"trig","to":"gate"}}`)},
			{Type: "add_edge", Raw: []byte(`{"op":"add_edge","edge":{"id":"e2","from":"gate.approved","to":"ack"}}`)},
		},
	})
	if err != nil {
		t.Fatalf("Create workflow: %v", err)
	}

	// Trigger.
	var trigResp struct {
		Data struct {
			RunID string `json:"runId"`
		} `json:"data"`
	}
	if status := th.DoRequest(t, h, "POST", "/api/v1/workflows/"+wf.ID+":trigger",
		map[string]any{}, &trigResp); status != 201 {
		t.Fatalf("trigger: %d", status)
	}
	runID := trigResp.Data.RunID

	// Wait for paused state.
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		run, _ := h.FlowRunRepo.Get(ctx, runID)
		if run != nil && run.Status == flowrundomain.StatusPaused {
			if run.PausedState == nil || run.PausedState.NodeID != "gate" {
				t.Fatalf("paused but PausedState wrong: %+v", run.PausedState)
			}
			break
		}
		time.Sleep(20 * time.Millisecond)
	}

	// POST approvals — approve.
	var approveResp struct {
		Data struct {
			Resumed bool `json:"resumed"`
		} `json:"data"`
	}
	if status := th.DoRequest(t, h, "POST",
		"/api/v1/flowruns/"+runID+"/approvals/gate",
		map[string]any{"decision": "approved"}, &approveResp); status != 202 {
		t.Fatalf("approve status = %d, want 202", status)
	}
	if !approveResp.Data.Resumed {
		t.Errorf("resumed=false in response")
	}

	// Wait for completion.
	deadline = time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		run, _ := h.FlowRunRepo.Get(ctx, runID)
		if run != nil && run.Status == flowrundomain.StatusCompleted {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("run did not complete after approval within 2s")
}

// TestApproval_InvalidDecision_Returns400 — bad decision rejected.
//
// TestApproval_InvalidDecision_Returns400 — decision 不在白名单返 400。
func TestApproval_InvalidDecision_Returns400(t *testing.T) {
	h := th.New(t)
	ctx := th.LocalCtxAs(reqctxpkg.DefaultLocalUserID)

	wf, _, err := h.Workflow.Create(ctx, workflowapp.CreateInput{
		Ops: []workflowapp.Op{
			{Type: "set_meta", Raw: []byte(`{"op":"set_meta","name":"approval_bad","description":"e2e bad decision"}`)},
			{Type: "add_node", Raw: []byte(`{"op":"add_node","node":{"id":"trig","type":"trigger","config":{"triggerType":"manual"}}}`)},
			{Type: "add_node", Raw: []byte(`{"op":"add_node","node":{"id":"gate","type":"approval","config":{"prompt":"go?"}}}`)},
			{Type: "add_edge", Raw: []byte(`{"op":"add_edge","edge":{"id":"e1","from":"trig","to":"gate"}}`)},
		},
	})
	if err != nil {
		t.Fatalf("Create: %v", err)
	}

	var trigResp struct {
		Data struct {
			RunID string `json:"runId"`
		} `json:"data"`
	}
	_ = th.DoRequest(t, h, "POST", "/api/v1/workflows/"+wf.ID+":trigger",
		map[string]any{}, &trigResp)

	// Wait for pause.
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		run, _ := h.FlowRunRepo.Get(ctx, trigResp.Data.RunID)
		if run != nil && run.Status == flowrundomain.StatusPaused {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}

	var errResp th.ErrEnvelope
	status := th.DoRequest(t, h, "POST",
		"/api/v1/flowruns/"+trigResp.Data.RunID+"/approvals/gate",
		map[string]any{"decision": "maybe"}, &errResp)
	if status != 400 {
		t.Errorf("invalid decision status = %d, want 400", status)
	}
	if errResp.Error.Code != "FLOWRUN_APPROVAL_DECISION_INVALID" {
		t.Errorf("code = %q, want FLOWRUN_APPROVAL_DECISION_INVALID", errResp.Error.Code)
	}
}

// TestApproval_WrongNodeID_Returns404 — approve at a node that isn't
// the paused gate returns FLOWRUN_APPROVAL_NODE_NOT_FOUND.
//
// TestApproval_WrongNodeID_Returns404 — approve 在非 paused 节点返 404。
func TestApproval_WrongNodeID_Returns404(t *testing.T) {
	h := th.New(t)
	ctx := th.LocalCtxAs(reqctxpkg.DefaultLocalUserID)

	wf, _, err := h.Workflow.Create(ctx, workflowapp.CreateInput{
		Ops: []workflowapp.Op{
			{Type: "set_meta", Raw: []byte(`{"op":"set_meta","name":"approval_wrongnode","description":"e2e"}`)},
			{Type: "add_node", Raw: []byte(`{"op":"add_node","node":{"id":"trig","type":"trigger","config":{"triggerType":"manual"}}}`)},
			{Type: "add_node", Raw: []byte(`{"op":"add_node","node":{"id":"gate","type":"approval","config":{"prompt":"go?"}}}`)},
			{Type: "add_edge", Raw: []byte(`{"op":"add_edge","edge":{"id":"e1","from":"trig","to":"gate"}}`)},
		},
	})
	if err != nil {
		t.Fatalf("Create: %v", err)
	}

	var trigResp struct {
		Data struct {
			RunID string `json:"runId"`
		} `json:"data"`
	}
	_ = th.DoRequest(t, h, "POST", "/api/v1/workflows/"+wf.ID+":trigger",
		map[string]any{}, &trigResp)

	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		run, _ := h.FlowRunRepo.Get(ctx, trigResp.Data.RunID)
		if run != nil && run.Status == flowrundomain.StatusPaused {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}

	var errResp th.ErrEnvelope
	status := th.DoRequest(t, h, "POST",
		"/api/v1/flowruns/"+trigResp.Data.RunID+"/approvals/wrong_node",
		map[string]any{"decision": "approved"}, &errResp)
	if status != 404 {
		t.Errorf("wrong node status = %d, want 404", status)
	}
	if errResp.Error.Code != "FLOWRUN_APPROVAL_NODE_NOT_FOUND" {
		t.Errorf("code = %q, want FLOWRUN_APPROVAL_NODE_NOT_FOUND", errResp.Error.Code)
	}
}
