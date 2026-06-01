//go:build pipeline

package cross

import (
	"encoding/json"
	"testing"

	functionapp "github.com/sunweilin/forgify/backend/internal/app/function"
	workflowapp "github.com/sunweilin/forgify/backend/internal/app/workflow"
	triggerdomain "github.com/sunweilin/forgify/backend/internal/domain/trigger"
	th "github.com/sunweilin/forgify/backend/test/harness"
)

const pollCode = "def poll(lastCursor):\n    return {\"events\": [], \"nextCursor\": \"c1\"}\n"

func mkOpRaw(op string, body map[string]any) functionapp.Op {
	body["op"] = op
	raw, _ := json.Marshal(body)
	return functionapp.Op{Type: op, Raw: raw}
}

func pollingActive(states []triggerdomain.State) bool {
	for _, s := range states {
		if s.Kind == triggerdomain.KindPolling {
			return true
		}
	}
	return false
}

// covers: cross:polling_trigger:functionRef_resolves_and_registers
// Full chain: a kind=polling function (set_kind + set_polling_interval) → a workflow whose trigger
// node references it via config.spec.functionRef → activate resolves the function's PollingInterval
// + confirms kind=polling → the polling listener registers. This is the regression guard for the
// rewritten polling subsystem (the prior stub used wrong field names and never resolved a function).
func TestPollingTrigger_RegistersFromFunctionRef(t *testing.T) {
	h := th.New(t)
	th.RequireFunctionResources(t, h)
	ctx := th.CtxAs("test-user")

	// 1. A polling forge function: kind=polling, interval 30s, fixed poll(lastCursor) signature.
	fn, _, err := h.Function.Create(ctx, functionapp.CreateInput{Ops: []functionapp.Op{
		mkOpRaw("set_meta", map[string]any{"name": "queue_poller"}),
		mkOpRaw("set_code", map[string]any{"code": pollCode}),
		mkOpRaw("set_kind", map[string]any{"kind": "polling"}),
		mkOpRaw("set_polling_interval", map[string]any{"interval": "30s"}),
	}})
	if err != nil {
		t.Fatalf("create polling function: %v", err)
	}

	// Sanity: the active version persisted kind=polling + interval.
	av, err := h.Function.ActiveVersion(ctx, fn.ID)
	if err != nil {
		t.Fatalf("ActiveVersion: %v", err)
	}
	if av.Kind != "polling" || av.PollingInterval != "30s" {
		t.Fatalf("active version kind=%q interval=%q, want polling/30s", av.Kind, av.PollingInterval)
	}

	// 2. A workflow whose trigger node references the polling function (17 §7 spec.functionRef).
	trigCfg := `{"op":"add_node","node":{"id":"trig","type":"trigger","config":{"kind":"polling","spec":{"functionRef":"` + fn.ID + `"}}}}`
	wf, _, err := h.Workflow.Create(ctx, workflowapp.CreateInput{Ops: []workflowapp.Op{
		{Type: "set_meta", Raw: []byte(`{"op":"set_meta","name":"poll_wf","description":"polling e2e"}`)},
		{Type: "add_node", Raw: []byte(trigCfg)},
	}})
	if err != nil {
		t.Fatalf("create polling workflow: %v", err)
	}

	// 3. Create auto-enabled + synced → the polling listener must be registered (Interval resolved
	//    the function's interval and confirmed kind=polling).
	if !pollingActive(h.Trigger.State(wf.ID)) {
		t.Fatalf("polling listener not registered after activate; states=%+v", h.Trigger.State(wf.ID))
	}
}

// covers: cross:polling_trigger:non_polling_functionRef_fails_registration
// A trigger node pointing at a NORMAL function must fail to register (Interval rejects kind!=polling),
// rather than silently registering a dead listener.
func TestPollingTrigger_NonPollingFunctionRefDoesNotRegister(t *testing.T) {
	h := th.New(t)
	th.RequireFunctionResources(t, h)
	ctx := th.CtxAs("test-user")

	// A NORMAL function (no set_kind).
	fn := h.NewFunction(t, "normal_fn", "def main():\n    return {\"ok\": true}\n")

	trigCfg := `{"op":"add_node","node":{"id":"trig","type":"trigger","config":{"kind":"polling","spec":{"functionRef":"` + fn.ID + `"}}}}`
	wf, _, err := h.Workflow.Create(ctx, workflowapp.CreateInput{Ops: []workflowapp.Op{
		{Type: "set_meta", Raw: []byte(`{"op":"set_meta","name":"bad_poll_wf","description":"polling e2e"}`)},
		{Type: "add_node", Raw: []byte(trigCfg)},
	}})
	if err != nil {
		t.Fatalf("create workflow: %v", err)
	}
	// Registration is fail-soft: the listener does not register (Interval errors on kind!=polling).
	if pollingActive(h.Trigger.State(wf.ID)) {
		t.Errorf("polling listener registered for a NORMAL function — should have been rejected")
	}
}
