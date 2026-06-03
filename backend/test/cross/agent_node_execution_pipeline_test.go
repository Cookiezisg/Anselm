//go:build pipeline

package cross

import (
	"testing"
	"time"

	agentapp "github.com/sunweilin/forgify/backend/internal/app/agent"
	workflowapp "github.com/sunweilin/forgify/backend/internal/app/workflow"
	agentdomain "github.com/sunweilin/forgify/backend/internal/domain/agent"
	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
	th "github.com/sunweilin/forgify/backend/test/harness"
)

// TestWorkflow_AgentRefNode_RecordsExecution_E2E proves the agent↔function parity: a workflow agent
// node referencing an Agent entity (config.agentRef) routes through agentService.InvokeAgent (the
// single execution method, mirrors dispatch_function → RunFunction) and records one AgentExecution
// with triggeredBy=workflow + flowrunId — so search_agent_executions shows workflow-driven runs, just
// like function executions show workflow function-node runs.
//
// covers: cross:workflow_agent:agentref_records_execution
func TestWorkflow_AgentRefNode_RecordsExecution_E2E(t *testing.T) {
	fake := th.NewFakeLLMServer(t)
	fake.PushScript(th.ScriptText("classification done"))

	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	h.SeedDeepSeek(t, "fake-test-key")
	ctx := th.CtxAs("test-user")

	// 1. A first-class Agent entity (v1 auto-accepts).
	ag, _, err := h.Agent.Create(ctx, agentapp.CreateInput{
		Name:   "router",
		Prompt: "Classify the input.",
	})
	if err != nil {
		t.Fatalf("create agent: %v", err)
	}

	// 2. A workflow whose agent node references the entity via config.agentRef.
	agentNode := `{"op":"add_node","node":{"id":"ag1","type":"agent","config":{"agentRef":"` + ag.ID + `","maxTurns":2}}}`
	wf, _, err := h.Workflow.Create(ctx, workflowapp.CreateInput{Ops: []workflowapp.Op{
		{Type: "set_meta", Raw: []byte(`{"op":"set_meta","name":"agentref_wf","description":"agentRef e2e"}`)},
		{Type: "add_node", Raw: []byte(`{"op":"add_node","node":{"id":"trig","type":"trigger","config":{"triggerType":"manual"}}}`)},
		{Type: "add_node", Raw: []byte(agentNode)},
		{Type: "add_edge", Raw: []byte(`{"op":"add_edge","edge":{"id":"e1","from":"trig","to":"ag1"}}`)},
	}})
	if err != nil {
		t.Fatalf("create workflow: %v", err)
	}

	// 3. Trigger + wait for terminal.
	var trigResp struct {
		Data struct{ RunID string } `json:"data"`
	}
	if status := th.DoRequest(t, h, "POST", "/api/v1/workflows/"+wf.ID+":trigger", map[string]any{"input": map[string]any{"text": "hello"}}, &trigResp); status != 201 {
		t.Fatalf("trigger: %d", status)
	}
	runID := trigResp.Data.RunID

	deadline := time.Now().Add(15 * time.Second)
	var final *flowrundomain.FlowRun
	for time.Now().Before(deadline) {
		run, _ := h.FlowRunRepo.Get(ctx, runID)
		if run != nil && (run.Status == flowrundomain.StatusCompleted || run.Status == flowrundomain.StatusFailed) {
			final = run
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if final == nil || final.Status != flowrundomain.StatusCompleted {
		t.Fatalf("flowrun did not complete: %+v", final)
	}

	// 4. The agent run must have recorded an AgentExecution (triggeredBy=workflow + flowrunId).
	res, err := h.Agent.SearchExecutions(ctx, agentdomain.ExecutionFilter{AgentID: ag.ID})
	if err != nil {
		t.Fatalf("SearchExecutions: %v", err)
	}
	if res.Count != 1 {
		t.Fatalf("expected 1 recorded agent execution from the workflow node, got %d", res.Count)
	}
	e := res.Executions[0]
	if e.TriggeredBy != agentdomain.TriggeredByWorkflow {
		t.Errorf("execution triggeredBy = %q, want workflow", e.TriggeredBy)
	}
	if e.FlowrunID != runID {
		t.Errorf("execution flowrunId = %q, want %q", e.FlowrunID, runID)
	}
	if e.Status != agentdomain.ExecutionStatusOK {
		t.Errorf("execution status = %q, want ok", e.Status)
	}
}
