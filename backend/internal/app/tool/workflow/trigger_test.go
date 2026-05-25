package workflow

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"testing"

	schedulerapp "github.com/sunweilin/forgify/backend/internal/app/scheduler"
)

type fakeStarter struct {
	gotWorkflowID string
	gotKind       string
	gotInput      map[string]any
	gotDryRun     bool
	runID         string
	err           error
}

func (f *fakeStarter) StartRunWithOptions(_ context.Context, workflowID, triggerKind string, input map[string]any, opts schedulerapp.StartRunOptions) (string, error) {
	f.gotWorkflowID = workflowID
	f.gotKind = triggerKind
	f.gotInput = input
	f.gotDryRun = opts.DryRun
	return f.runID, f.err
}

func TestTriggerWorkflow_Execute_PassesDryRunAndReturnsRunID(t *testing.T) {
	fake := &fakeStarter{runID: "fr_abc"}
	tool := &TriggerWorkflow{sched: fake}
	out, err := tool.Execute(context.Background(), `{"workflowId":"wf_x","dryRun":true}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	if fake.gotWorkflowID != "wf_x" || !fake.gotDryRun || fake.gotKind != "manual" {
		t.Errorf("starter got wf=%q dryRun=%v kind=%q, want wf_x/true/manual", fake.gotWorkflowID, fake.gotDryRun, fake.gotKind)
	}
	if !strings.Contains(out, "fr_abc") {
		t.Errorf("output %q should contain flowrunId fr_abc", out)
	}
}

func TestTriggerWorkflow_Execute_MissingWorkflowID(t *testing.T) {
	tool := &TriggerWorkflow{sched: &fakeStarter{}}
	_, err := tool.Execute(context.Background(), `{"dryRun":true}`)
	if err == nil || !strings.Contains(err.Error(), "workflowId required") {
		t.Errorf("expected workflowId-required error, got %v", err)
	}
}

func TestTriggerWorkflow_Execute_PropagatesSchedulerError(t *testing.T) {
	tool := &TriggerWorkflow{sched: &fakeStarter{err: errors.New("disabled")}}
	_, err := tool.Execute(context.Background(), `{"workflowId":"wf_x"}`)
	if err == nil || !strings.Contains(err.Error(), "trigger_workflow") {
		t.Errorf("expected wrapped trigger_workflow error, got %v", err)
	}
}

func TestTriggerWorkflow_Metadata(t *testing.T) {
	tool := &TriggerWorkflow{}
	if tool.Name() != "trigger_workflow" {
		t.Errorf("Name = %q, want trigger_workflow", tool.Name())
	}
	if tool.IsReadOnly() {
		t.Error("trigger_workflow must not be read-only (it starts a run)")
	}
	var schema map[string]any
	if err := json.Unmarshal(tool.Parameters(), &schema); err != nil {
		t.Fatalf("Parameters not valid JSON: %v", err)
	}
}
