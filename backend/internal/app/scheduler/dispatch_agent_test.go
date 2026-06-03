package scheduler

import (
	"context"
	"testing"

	agentapp "github.com/sunweilin/forgify/backend/internal/app/agent"
	agentdomain "github.com/sunweilin/forgify/backend/internal/domain/agent"
	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// captureInvoker records the InvokeInput + the ctx userID the dispatcher hands InvokeAgent.
type captureInvoker struct {
	gotInput agentapp.InvokeInput
	gotUID   string
}

func (r *captureInvoker) InvokeAgent(ctx context.Context, in agentapp.InvokeInput) (*agentapp.ExecutionResult, error) {
	r.gotUID, _ = reqctxpkg.GetUserID(ctx)
	r.gotInput = in
	return &agentapp.ExecutionResult{OK: true, Output: "done", Status: agentdomain.ExecutionStatusOK}, nil
}

// TestAgentDispatch_AgentRefRoutesToInvokeAgent verifies an agentRef node routes through the agent
// service's InvokeAgent (single execution method, mirrors dispatch_function → RunFunction) with the
// run ctx (carries userID), agentRef, workflow trigger, and node payload.
func TestAgentDispatch_AgentRefRoutesToInvokeAgent(t *testing.T) {
	d := NewAgentDispatcher(&fakeAgentPicker{}, fakeKeyProvider{}, nil, nil, nil, nil)
	inv := &captureInvoker{}
	d.SetAgentResolver(inv)

	ctx := reqctxpkg.SetUserID(context.Background(), "u_test")
	out := d.Dispatch(ctx, DispatchInput{
		Node:   workflowdomain.NodeSpec{ID: "n1", Type: workflowdomain.NodeTypeAgent, Config: map[string]any{"agentRef": "ag_x"}},
		NodeIn: map[string]any{"text": "hello"},
		ExecCtx: &ExecutionContext{Run: &flowrundomain.FlowRun{ID: "fr_1"}},
	})

	if out.Error != nil {
		t.Fatalf("unexpected dispatch error: %v", out.Error)
	}
	if inv.gotUID != "u_test" {
		t.Errorf("InvokeAgent ctx userID = %q, want u_test (dispatcher must pass the run ctx)", inv.gotUID)
	}
	if inv.gotInput.AgentID != "ag_x" {
		t.Errorf("InvokeInput.AgentID = %q, want ag_x", inv.gotInput.AgentID)
	}
	if inv.gotInput.TriggeredBy != agentdomain.TriggeredByWorkflow {
		t.Errorf("InvokeInput.TriggeredBy = %q, want workflow", inv.gotInput.TriggeredBy)
	}
	if inv.gotInput.FlowrunID != "fr_1" || inv.gotInput.FlowrunNodeID != "n1" {
		t.Errorf("InvokeInput flowrun=%q node=%q, want fr_1/n1", inv.gotInput.FlowrunID, inv.gotInput.FlowrunNodeID)
	}
	if inv.gotInput.Input["text"] != "hello" {
		t.Errorf("InvokeInput.Input not forwarded: %+v", inv.gotInput.Input)
	}
}
