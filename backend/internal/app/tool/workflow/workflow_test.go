package workflow

import (
	"context"
	"database/sql"
	"encoding/json"
	stderrors "errors"
	"fmt"
	"reflect"
	"slices"
	"strings"
	"testing"

	_ "github.com/glebarez/go-sqlite"
	"go.uber.org/zap"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	workflowapp "github.com/sunweilin/anselm/backend/internal/app/workflow"
	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	workflowstore "github.com/sunweilin/anselm/backend/internal/infra/store/workflow"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// TestCapFlowrunNodes — F173: a large/looping run's node set is capped for the LLM tool result so a
// 1000-iteration loop (~2000 rows / ~650KB) cannot flood the model context. <= cap → all rows + no
// summary; > cap → every failure/parked node + a recent tail (<= cap) + a summary with the true total.
func TestCapFlowrunNodes(t *testing.T) {
	mk := func(n, failIdx int) []*flowrundomain.FlowRunNode {
		out := make([]*flowrundomain.FlowRunNode, n)
		for i := range out {
			st := flowrundomain.StatusCompleted
			if i == failIdx {
				st = flowrundomain.StatusFailed
			}
			out[i] = &flowrundomain.FlowRunNode{ID: fmt.Sprintf("frn_%d", i), NodeID: "loop", Iteration: i, Status: st}
		}
		return out
	}

	// Small run: all returned, no summary.
	if shown, summary := capFlowrunNodes(mk(10, -1)); len(shown) != 10 || summary != nil {
		t.Fatalf("small run must return all nodes + no summary, got %d shown summary=%v", len(shown), summary)
	}

	// Big run with one failure: capped, summary carries the true total, the failure IS included.
	shown, summary := capFlowrunNodes(mk(500, 3))
	if len(shown) > maxFlowrunNodes {
		t.Fatalf("big run must cap to <= %d, got %d", maxFlowrunNodes, len(shown))
	}
	if summary == nil || summary["totalNodes"] != 500 {
		t.Fatalf("big run must carry a summary with the true total (500), got %v", summary)
	}
	hasFailure := false
	for _, n := range shown {
		if n.Status == flowrundomain.StatusFailed {
			hasFailure = true
		}
	}
	if !hasFailure {
		t.Fatal("a capped run MUST still include the failed node (the debug-relevant one)")
	}
}

func TestGetFlowrunDescriptionStatesLargeRunProjection(t *testing.T) {
	d := (&GetFlowrun{}).Description()
	for _, want := range []string{"80", "non-completed", "nodeSummary", "GET /api/v1/flowruns/{id}", "flowrunId", "character-for-character", "never abbreviate", "do not use file_path"} {
		if !strings.Contains(d, want) {
			t.Errorf("get_flowrun description must state %q, got %q", want, d)
		}
	}
	if strings.Contains(d, "every node's record") {
		t.Errorf("get_flowrun description must not promise an uncapped full node set: %q", d)
	}
}

func TestGetFlowrunParametersMakeIDFieldUnambiguous(t *testing.T) {
	var schema struct {
		Properties map[string]struct {
			Description string `json:"description"`
		} `json:"properties"`
	}
	if err := json.Unmarshal((&GetFlowrun{}).Parameters(), &schema); err != nil {
		t.Fatalf("get_flowrun parameter schema must be valid JSON: %v", err)
	}
	desc := schema.Properties["flowrunId"].Description
	for _, want := range []string{"Required run ID", "fr_", "character-for-character", "never abbreviate", "not file_path"} {
		if !strings.Contains(desc, want) {
			t.Errorf("flowrunId parameter description must state %q, got %q", want, desc)
		}
	}
}

func TestSearchFlowrunsDescriptionKeepsListAndDetailAsExplicitSteps(t *testing.T) {
	d := (&SearchFlowruns{}).Description()
	for _, want := range []string{"workflow name", "status, error and timing", "Do not automatically call get_flowrun", "explicitly asks", "one specific run"} {
		if !strings.Contains(d, want) {
			t.Errorf("search_flowruns description must state %q, got %q", want, d)
		}
	}
}

func TestSearchFlowrunsParametersConstrainStatusAndUnknownFields(t *testing.T) {
	var schema struct {
		AdditionalProperties bool `json:"additionalProperties"`
		Properties           map[string]struct {
			Enum []string `json:"enum"`
		} `json:"properties"`
	}
	if err := json.Unmarshal((&SearchFlowruns{}).Parameters(), &schema); err != nil {
		t.Fatalf("search_flowruns parameter schema must be valid JSON: %v", err)
	}
	if schema.AdditionalProperties {
		t.Fatal("search_flowruns must reject fields outside its explicit filter contract")
	}
	if got := schema.Properties["status"].Enum; !slices.Equal(got, []string{"running", "completed", "failed", "cancelled"}) {
		t.Fatalf("status enum = %#v", got)
	}
}

func TestGetFlowrunNormalizesOnlyAnUnambiguousFilePathAlias(t *testing.T) {
	tool := &GetFlowrun{}
	got, changed := tool.NormalizeArguments(json.RawMessage(`{"file_path":"fr_19b3486793b3b754"}`))
	if !changed {
		t.Fatal("fr_ file_path alias should be normalized")
	}
	var args map[string]any
	if err := json.Unmarshal(got, &args); err != nil {
		t.Fatalf("normalized args are invalid JSON: %v", err)
	}
	if args["flowrunId"] != "fr_19b3486793b3b754" || args["file_path"] != nil {
		t.Fatalf("normalized args = %#v, want only exact flowrunId", args)
	}
	for _, raw := range []string{
		`{"file_path":"/tmp/run.json"}`,
		`{"file_path":""}`,
	} {
		if _, changed := tool.NormalizeArguments(json.RawMessage(raw)); changed {
			t.Errorf("ambiguous alias %s must not be normalized", raw)
		}
	}
	got, changed = tool.NormalizeArguments(json.RawMessage(`{"flowrunId":"fr_exact","file_path":"fr_exact"}`))
	if !changed || string(got) != `{"flowrunId":"fr_exact"}` {
		t.Fatalf("same-value redundant alias = %s, changed=%v; want only flowrunId", got, changed)
	}
	if _, changed := tool.NormalizeArguments(json.RawMessage(`{"flowrunId":"fr_exact","file_path":"fr_other"}`)); changed {
		t.Fatal("conflicting file_path must not be normalized")
	}
}

func TestGetFlowrunRejectsFilePathAfterNormalizationBoundary(t *testing.T) {
	if err := (&GetFlowrun{}).ValidateInput(json.RawMessage(`{"file_path":"/tmp/run.json"}`)); err == nil || !strings.Contains(err.Error(), "file_path is not accepted") {
		t.Fatalf("ordinary file_path must be rejected clearly, got %v", err)
	}
	if err := (&GetFlowrun{}).ValidateInput(json.RawMessage(`{"flowrunId":"fr_exact","file_path":"fr_other"}`)); err == nil || !strings.Contains(err.Error(), "file_path is not accepted") {
		t.Fatalf("conflicting file_path must be rejected clearly, got %v", err)
	}
}

func TestGetFlowrunNotFoundReasonIsActionable(t *testing.T) {
	err := flowrundomain.ErrNotFound.WithDetails(map[string]any{
		"reason": "No workflow run exists for the supplied flowrunId. Verify that the ID is correct and belongs to the current workspace.",
	})
	if !strings.Contains(err.Error(), "flowrun not found") {
		t.Fatalf("tool must preserve the stable not-found message: %v", err)
	}
	if !strings.Contains(err.Details["reason"].(string), "current workspace") {
		t.Fatalf("tool not-found reason must explain the workspace check: %#v", err.Details)
	}
}

func TestFlowrunNodesResultNamedKeepsIdentityAndAddsDisplayName(t *testing.T) {
	run := &flowrundomain.FlowRun{ID: "fr_1", WorkflowID: "wf_1"}
	out := flowrunNodesResultNamed(run, nil, "nightly_rollup")
	if out["workflowName"] != "nightly_rollup" {
		t.Fatalf("named result must expose the resolved workflow name: %#v", out)
	}
	gotRun, ok := out["flowrun"].(*flowrundomain.FlowRun)
	if !ok || gotRun.WorkflowID != "wf_1" {
		t.Fatalf("named result must preserve the durable workflow id: %#v", out["flowrun"])
	}
	if _, ok := flowrunNodesResultNamed(run, nil, "")["workflowName"]; ok {
		t.Fatal("unresolved workflow name must be omitted rather than invented")
	}
}

// TestWorkflowTools_Wiring asserts all 14 tools are constructed with the expected names and
// each satisfies the 5-method Tool interface: 7 build/query + 5 execution-lifecycle (D1) +
// 2 run-observability.
func TestWorkflowTools_Wiring(t *testing.T) {
	tools := WorkflowTools(nil, nil, nil, nil) // nil svc OK: we only inspect Name() here
	want := map[string]bool{
		"search_workflow": false, "get_workflow": false, "create_workflow": false,
		"edit_workflow": false, "revert_workflow": false, "delete_workflow": false,
		"capability_check_workflow": false,
		// execution lifecycle (D1)
		"trigger_workflow": false, "stage_workflow": false, "activate_workflow": false,
		"deactivate_workflow": false, "kill_workflow": false,
		// run observability + recovery + human-in-the-loop decision
		"get_flowrun": false, "search_flowruns": false, "replay_flowrun": false,
		"list_approval_inbox": false, "decide_approval": false,
	}
	if len(tools) != len(want) {
		t.Fatalf("want %d tools, got %d", len(want), len(tools))
	}
	for _, tl := range tools {
		if _, ok := want[tl.Name()]; !ok {
			t.Fatalf("unexpected tool name %q", tl.Name())
		}
		want[tl.Name()] = true
		var _ toolapp.Tool = tl
	}
	for name, seen := range want {
		if !seen {
			t.Fatalf("missing tool %q", name)
		}
	}
}

func TestValidateInput_RequiredFields(t *testing.T) {
	cases := []struct {
		name    string
		tool    toolapp.Tool
		args    string
		wantErr bool
	}{
		{"create no name", &CreateWorkflow{}, `{"ops":[{"op":"add_node"}]}`, true},
		{"create no ops", &CreateWorkflow{}, `{"name":"a"}`, true},
		{"create no description", &CreateWorkflow{}, `{"name":"a","tags":[],"changeReason":"","ops":[{"op":"add_node"}]}`, true},
		{"create no tags", &CreateWorkflow{}, `{"name":"a","description":"","changeReason":"","ops":[{"op":"add_node"}]}`, true},
		{"create no change reason", &CreateWorkflow{}, `{"name":"a","description":"","tags":[],"ops":[{"op":"add_node"}]}`, true},
		{"create ok", &CreateWorkflow{}, `{"name":"a","description":"","tags":[],"changeReason":"","ops":[{"op":"add_node"}]}`, false},
		{"create stringified ops", &CreateWorkflow{}, `{"name":"a","description":"","tags":[],"changeReason":"","ops":"[{\"op\":\"add_node\"}]"}`, false},
		{"edit no id", &EditWorkflow{}, `{"ops":[{"op":"add_node"}]}`, true},
		{"edit no ops", &EditWorkflow{}, `{"workflowId":"wf_1","ops":[]}`, true},
		{"edit ok", &EditWorkflow{}, `{"workflowId":"wf_1","ops":[{"op":"add_node"}]}`, false},
		{"get no id", &GetWorkflow{}, `{}`, true},
		{"get ok", &GetWorkflow{}, `{"workflowId":"wf_1"}`, false},
		{"revert no id", &RevertWorkflow{}, `{"version":1}`, true},
		{"revert bad version", &RevertWorkflow{}, `{"workflowId":"wf_1","version":0}`, true},
		{"revert stringified version", &RevertWorkflow{}, `{"workflowId":"wf_1","version":"2"}`, false},
		{"revert malformed stringified version", &RevertWorkflow{}, `{"workflowId":"wf_1","version":"2.0"}`, true},
		{"revert boolean version", &RevertWorkflow{}, `{"workflowId":"wf_1","version":true}`, true},
		{"revert ok", &RevertWorkflow{}, `{"workflowId":"wf_1","version":2}`, false},
		{"delete no id", &DeleteWorkflow{}, `{}`, true},
		{"delete ok", &DeleteWorkflow{}, `{"workflowId":"wf_1"}`, false},
		{"capcheck no id", &CapabilityCheckWorkflow{}, `{}`, true},
		{"capcheck ok", &CapabilityCheckWorkflow{}, `{"workflowId":"wf_1"}`, false},
		{"search any", &SearchWorkflow{}, `{}`, false},
		// execution lifecycle (D1)
		{"trigger no id", &TriggerWorkflow{}, `{"payload":{}}`, true},
		{"trigger ok", &TriggerWorkflow{}, `{"workflowId":"wf_1","payload":{"x":1}}`, false},
		{"trigger stringified payload", &TriggerWorkflow{}, `{"workflowId":"wf_1","payload":"{\"x\":1}"}`, false},
		{"trigger array payload rejected", &TriggerWorkflow{}, `{"workflowId":"wf_1","payload":[]}`, true},
		{"trigger ok no payload", &TriggerWorkflow{}, `{"workflowId":"wf_1"}`, false},
		{"stage no id", &StageWorkflow{}, `{}`, true},
		{"stage ok", &StageWorkflow{}, `{"workflowId":"wf_1"}`, false},
		{"activate no id", &ActivateWorkflow{}, `{}`, true},
		{"activate ok", &ActivateWorkflow{}, `{"workflowId":"wf_1"}`, false},
		{"deactivate no id", &DeactivateWorkflow{}, `{}`, true},
		{"deactivate ok", &DeactivateWorkflow{}, `{"workflowId":"wf_1"}`, false},
		{"kill no id", &KillWorkflow{}, `{}`, true},
		{"kill ok", &KillWorkflow{}, `{"workflowId":"wf_1"}`, false},
		// run observability
		{"getrun no id", &GetFlowrun{}, `{}`, true},
		{"getrun ok", &GetFlowrun{}, `{"flowrunId":"fr_1"}`, false},
		{"searchruns any", &SearchFlowruns{}, `{}`, false},
		{"searchruns scoped", &SearchFlowruns{}, `{"workflowId":"wf_1","limit":5}`, false},
		{"replay no id", &ReplayFlowrun{}, `{}`, true},
		{"replay ok", &ReplayFlowrun{}, `{"flowrunId":"fr_1"}`, false},
		{"decide no id", &DecideApproval{}, `{"nodeId":"a","decision":"yes"}`, true},
		{"decide ok", &DecideApproval{}, `{"flowrunId":"fr_1","nodeId":"a","decision":"yes"}`, false},
	}
	for _, c := range cases {
		err := c.tool.ValidateInput([]byte(c.args))
		if (err != nil) != c.wantErr {
			t.Errorf("%s: ValidateInput(%s) err=%v, wantErr=%v", c.name, c.args, err, c.wantErr)
		}
	}
}

func TestDecideApprovalDescriptionUsesInboxAsDiscoverySource(t *testing.T) {
	d := (&DecideApproval{}).Description()
	if !strings.Contains(d, "list_approval_inbox") {
		t.Fatalf("decide_approval must direct the model to the authoritative inbox: %q", d)
	}
	if strings.Contains(d, "Find a parked run + its approval node id with get_flowrun / search_flowruns") {
		t.Fatalf("decide_approval retained the stale discovery guidance: %q", d)
	}
	if !strings.Contains(d, "character-for-character") {
		t.Fatalf("decide_approval must require exact ids from the inbox row: %q", d)
	}
}

func TestCreateWorkflow_ValidateInputMetadataSentinels(t *testing.T) {
	base := `{"name":"a","description":"d","tags":["tag"],"changeReason":"why","ops":[{"op":"add_node"}]}`
	cases := []struct {
		name string
		args string
		want error
	}{
		{"description", strings.Replace(base, `,"description":"d"`, "", 1), ErrDescriptionRequired},
		{"tags", strings.Replace(base, `,"tags":["tag"]`, "", 1), ErrTagsRequired},
		{"changeReason", strings.Replace(base, `,"changeReason":"why"`, "", 1), ErrChangeReasonRequired},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := (&CreateWorkflow{}).ValidateInput([]byte(tc.args))
			if !stderrors.Is(err, tc.want) {
				t.Fatalf("ValidateInput(%s) = %v, want %v", tc.args, err, tc.want)
			}
		})
	}
	for _, args := range []string{
		`{"name":"a","description":"","tags":[],"changeReason":"","ops":[{"op":"add_node"}]}`,
		`{"name":"a","description":"d","tags":"[\"tag\"]","changeReason":"why","ops":"[{\"op\":\"add_node\"}]"}`,
	} {
		if err := (&CreateWorkflow{}).ValidateInput([]byte(args)); err != nil {
			t.Errorf("ValidateInput(%s) = %v, want nil", args, err)
		}
	}
	for _, args := range []string{
		`{"name":"a","description":null,"tags":[],"changeReason":"why","ops":[{"op":"add_node"}]}`,
		`{"name":"a","description":"d","tags":null,"changeReason":"why","ops":[{"op":"add_node"}]}`,
		`{"name":"a","description":"d","tags":[],"changeReason":null,"ops":[{"op":"add_node"}]}`,
	} {
		if err := (&CreateWorkflow{}).ValidateInput([]byte(args)); err == nil {
			t.Errorf("ValidateInput(%s) accepted explicit null metadata", args)
		}
	}
}

func TestDecodeWorkflowOps_HostedModelShapes(t *testing.T) {
	const alias = `[
		{"op":"add_node","id":"start","kind":"trigger","ref":"trg_fixture"},
		{"op":"add_node","id":"process","kind":"action","ref":"fn_fixture","input":{"value":"start.value"}},
		{"op":"add_edge","id":"start_to_process","from":"start","to":"process"}
	]`

	tests := []struct {
		name string
		raw  string
		want string
	}{
		{"native nested", `[{"op":"add_node","node":{"id":"start","kind":"trigger","ref":"trg_fixture"}}]`, `[{"op":"add_node","node":{"id":"start","kind":"trigger","ref":"trg_fixture"}}]`},
		{"stringified native", `"[{\"op\":\"add_node\",\"node\":{\"id\":\"start\",\"kind\":\"trigger\",\"ref\":\"trg_fixture\"}}]"`, `[{"op":"add_node","node":{"id":"start","kind":"trigger","ref":"trg_fixture"}}]`},
		{"top-level body aliases", alias, `[{"node":{"id":"start","kind":"trigger","ref":"trg_fixture"},"op":"add_node"},{"node":{"id":"process","kind":"action","ref":"fn_fixture","input":{"value":"start.value"}},"op":"add_node"},{"edge":{"id":"start_to_process","from":"start","to":"process"},"op":"add_edge"}]`},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := decodeWorkflowOps([]byte(tt.raw))
			if err != nil {
				t.Fatalf("decodeWorkflowOps: %v", err)
			}
			var gotValue any
			var wantValue any
			if err := json.Unmarshal(got, &gotValue); err != nil {
				t.Fatalf("decoded JSON: %v", err)
			}
			if err := json.Unmarshal([]byte(tt.want), &wantValue); err != nil {
				t.Fatalf("test want JSON: %v", err)
			}
			if !reflect.DeepEqual(gotValue, wantValue) {
				t.Fatalf("normalized ops = %s, want %s", got, tt.want)
			}
		})
	}

	for _, raw := range []string{
		`"{}"`,
		`{"op":"add_node","node":{"id":"nested"},"id":"conflict"}`,
		`[{"op":"add_edge","edge":{"id":"e1"},"from":"start"}]`,
		`[{"op":1}]`,
	} {
		if _, err := decodeWorkflowOps([]byte(raw)); err == nil {
			t.Errorf("decodeWorkflowOps(%s) should reject malformed/conflicting shape", raw)
		}
	}
}

func TestDecodeWorkflowTags_HostedModelShapes(t *testing.T) {
	tests := []struct {
		name string
		raw  string
		want []string
	}{
		{"native", `["acceptance","workflow"]`, []string{"acceptance", "workflow"}},
		{"stringified native", `"[\"acceptance\",\"workflow\"]"`, []string{"acceptance", "workflow"}},
		{"empty", `[]`, []string{}},
		{"missing", ``, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := decodeWorkflowTags([]byte(tt.raw))
			if err != nil {
				t.Fatalf("decodeWorkflowTags: %v", err)
			}
			if !reflect.DeepEqual(got, tt.want) {
				t.Fatalf("decoded tags = %#v, want %#v", got, tt.want)
			}
		})
	}
	for _, raw := range []string{`"acceptance,workflow"`, `"{}"`, `{"tag":"acceptance"}`, `["acceptance",1]`} {
		if _, err := decodeWorkflowTags([]byte(raw)); err == nil {
			t.Errorf("decodeWorkflowTags(%s) should reject malformed shape", raw)
		}
	}
}

func TestCreateWorkflow_ExecutesHostedModelOpsVariants(t *testing.T) {
	svc, ctx := newSvc(t)
	create := &CreateWorkflow{svc: svc}
	out, err := create.Execute(ctx, `{"name":"hosted_alias","ops":"[{\"op\":\"add_node\",\"id\":\"start\",\"kind\":\"trigger\",\"ref\":\"trg_fixture\"},{\"op\":\"add_node\",\"id\":\"process\",\"kind\":\"action\",\"ref\":\"fn_fixture\"},{\"op\":\"add_edge\",\"id\":\"start_to_process\",\"from\":\"start\",\"to\":\"process\"}]"}`)
	if err != nil {
		t.Fatalf("create hosted-model variant: %v", err)
	}
	var created struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal([]byte(out), &created); err != nil || created.ID == "" {
		t.Fatalf("create result missing id: %v (%s)", err, out)
	}
	got, err := (&GetWorkflow{svc: svc}).Execute(ctx, `{"workflowId":"`+created.ID+`"}`)
	if err != nil {
		t.Fatalf("get hosted-model variant: %v", err)
	}
	for _, want := range []string{`"id":"start"`, `"id":"process"`, `"id":"start_to_process"`} {
		if !strings.Contains(got, want) {
			t.Fatalf("normalized graph missing %s: %s", want, got)
		}
	}
}

func TestCreateWorkflow_ExecutesHostedModelStringifiedTags(t *testing.T) {
	svc, ctx := newSvc(t)
	create := &CreateWorkflow{svc: svc}
	out, err := create.Execute(ctx, `{"name":"hosted_tags","description":"nightly sync","tags":"[\"acceptance\",\"workflow\"]","changeReason":"TOOL-060","ops":"[{\"op\":\"add_node\",\"id\":\"start\",\"kind\":\"trigger\",\"ref\":\"trg_fixture\"}]"}`)
	if err != nil {
		t.Fatalf("create hosted-model stringified tags: %v", err)
	}
	var created struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal([]byte(out), &created); err != nil || created.ID == "" {
		t.Fatalf("create result missing id: %v (%s)", err, out)
	}
	got, err := (&GetWorkflow{svc: svc}).Execute(ctx, `{"workflowId":"`+created.ID+`"}`)
	if err != nil {
		t.Fatalf("get hosted-model stringified tags: %v", err)
	}
	for _, want := range []string{`"description":"nightly sync"`, `"tags":["acceptance","workflow"]`} {
		if !strings.Contains(got, want) {
			t.Fatalf("metadata missing %s: %s", want, got)
		}
	}
}

func TestCreateWorkflow_DescriptionPinsUserMetadata(t *testing.T) {
	desc := (&CreateWorkflow{}).Description()
	for _, want := range []string{
		"description, tags, changeReason",
		"three metadata slots are always required",
		"at the TOP LEVEL",
		"Never omit user-provided metadata",
		"Hosted-model compatibility",
		"comma-separated prose",
		"never put changeReason inside ops",
	} {
		if !strings.Contains(desc, want) {
			t.Fatalf("create_workflow description missing %q: %s", want, desc)
		}
	}
	params := string((&CreateWorkflow{}).Parameters())
	for _, want := range []string{
		"Pass an empty string when the user supplied none",
		"Pass [] when the user supplied none",
		"exact JSON-encoded array string",
		"never inside ops",
	} {
		if !strings.Contains(params, want) {
			t.Fatalf("create_workflow parameter schema missing %q: %s", want, params)
		}
	}
	var schema struct {
		Required []string `json:"required"`
	}
	if err := json.Unmarshal([]byte(params), &schema); err != nil {
		t.Fatalf("create_workflow schema is invalid JSON: %v", err)
	}
	for _, required := range []string{"name", "description", "tags", "changeReason", "ops"} {
		if !slices.Contains(schema.Required, required) {
			t.Fatalf("create_workflow schema must require %q: %v", required, schema.Required)
		}
	}
}

func TestDeleteWorkflow_DescriptionAndResultContract(t *testing.T) {
	desc := (&DeleteWorkflow{}).Description()
	for _, want := range []string{
		"always dangerous",
		"never downgrade its danger field",
		"NOT restorable",
		"no restore operation",
		"never tell the user it can be recovered",
		"required workflowId key",
		"exact hosted-model id alias",
	} {
		if !strings.Contains(desc, want) {
			t.Fatalf("delete_workflow description missing %q: %s", want, desc)
		}
	}
	if got := (&DeleteWorkflow{}).MinimumDanger(); got != toolapp.DangerDangerous {
		t.Fatalf("delete_workflow minimum danger = %q, want dangerous", got)
	}
	for _, tc := range []struct {
		name string
		args string
		want bool
	}{
		{name: "canonical", args: `{"workflowId":"wf_1"}`, want: true},
		{name: "hosted alias", args: `{"id":"wf_1"}`, want: true},
		{name: "conflicting keys", args: `{"workflowId":"wf_1","id":"wf_2"}`, want: false},
		{name: "filesystem field", args: `{"workflowId":"wf_1","file_path":""}`, want: false},
		{name: "missing", args: `{}`, want: false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if got := (&DeleteWorkflow{}).ValidateInput([]byte(tc.args)) == nil; got != tc.want {
				t.Fatalf("ValidateInput(%s)=%v, want %v", tc.args, got, tc.want)
			}
		})
	}
	if got := (&DeleteWorkflow{}).CallIdentity(json.RawMessage(`{"workflowId":"wf_1","file_path":""}`)); got != "workflow:wf_1" {
		t.Fatalf("CallIdentity must ignore irrelevant fields, got %q", got)
	}

	svc, ctx := newSvc(t)
	created, err := (&CreateWorkflow{svc: svc}).Execute(ctx, `{"name":"delete-contract","description":"","tags":[],"changeReason":"contract test","ops":[{"op":"add_node","node":{"id":"start","kind":"trigger","ref":"trg_contract"}}]}`)
	if err != nil {
		t.Fatalf("create workflow: %v", err)
	}
	var createdRow struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal([]byte(created), &createdRow); err != nil || createdRow.ID == "" {
		t.Fatalf("decode created workflow: %v (%s)", err, created)
	}
	deleted, err := (&DeleteWorkflow{svc: svc}).Execute(ctx, `{"id":"`+createdRow.ID+`"}`)
	if err != nil {
		t.Fatalf("delete workflow: %v", err)
	}
	var result map[string]any
	if err := json.Unmarshal([]byte(deleted), &result); err != nil {
		t.Fatalf("decode delete result: %v (%s)", err, deleted)
	}
	if result["restorable"] != false || result["historyRetained"] != true {
		t.Fatalf("delete result must state the actual recovery boundary: %s", deleted)
	}
}

func TestSearchWorkflow_PrefersDirectMatchesAndReturnsLifecycleFields(t *testing.T) {
	svc, ctx := newSvc(t)
	create := &CreateWorkflow{svc: svc}
	for _, args := range []string{
		`{"name":"invoice_approval","description":"Approve invoices","tags":["invoice","approval"],"ops":[{"op":"add_node","node":{"id":"start","kind":"trigger","ref":"trg_manual"}}]}`,
		`{"name":"retention_policy","description":"Retain records","tags":["retention"],"ops":[{"op":"add_node","node":{"id":"start","kind":"trigger","ref":"trg_manual"}}]}`,
	} {
		if _, err := create.Execute(ctx, args); err != nil {
			t.Fatalf("create fixture: %v", err)
		}
	}

	search := &SearchWorkflow{svc: svc}
	out, err := search.Execute(ctx, `{"query":"invoice"}`)
	if err != nil {
		t.Fatalf("search: %v", err)
	}
	var got struct {
		Count     int `json:"count"`
		Total     int `json:"total"`
		Workflows []struct {
			Name           string   `json:"name"`
			Tags           []string `json:"tags"`
			LifecycleState string   `json:"lifecycleState"`
			Active         bool     `json:"active"`
		} `json:"workflows"`
	}
	if err := json.Unmarshal([]byte(out), &got); err != nil {
		t.Fatalf("decode: %v (%s)", err, out)
	}
	if got.Count != 1 || got.Total != 1 || len(got.Workflows) != 1 {
		t.Fatalf("direct keyword must not return weak semantic neighbors: %+v", got)
	}
	row := got.Workflows[0]
	if row.Name != "invoice_approval" || len(row.Tags) != 2 || row.LifecycleState != "inactive" || row.Active {
		t.Fatalf("search row lost workflow fields: %+v", row)
	}
}

func newSvc(t *testing.T) (*workflowapp.Service, context.Context) {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range workflowstore.Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	svc := workflowapp.NewService(workflowstore.New(ormpkg.Open(sqlDB)), nil, nil, zap.NewNop())
	return svc, reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")
}

type stageResultBinder struct {
	attach     []string
	attachOnce []string
}

func (b *stageResultBinder) Attach(_ context.Context, triggerID, workflowID string) error {
	b.attach = append(b.attach, triggerID+"|"+workflowID)
	return nil
}

func (b *stageResultBinder) AttachOnce(_ context.Context, triggerID, workflowID string) error {
	b.attachOnce = append(b.attachOnce, triggerID+"|"+workflowID)
	return nil
}

func (b *stageResultBinder) AttachReplay(context.Context, string, string) error { return nil }

func (b *stageResultBinder) Detach(string, string) {}

func TestStageWorkflow_ExecuteReturnsNamedSnapshotFromRealService(t *testing.T) {
	svc, ctx := newSvc(t)
	binder := &stageResultBinder{}
	svc.SetExecutionPorts(binder, nil)

	created, err := (&CreateWorkflow{svc: svc}).Execute(ctx, `{"name":"stage_named","description":"","tags":[],"changeReason":"contract test","ops":[{"op":"add_node","node":{"id":"start","kind":"trigger","ref":"trg_a"}}]}`)
	if err != nil {
		t.Fatalf("create workflow: %v", err)
	}
	var row struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal([]byte(created), &row); err != nil || row.ID == "" {
		t.Fatalf("decode created workflow: %v (%s)", err, created)
	}

	out, err := (&StageWorkflow{svc: svc}).Execute(ctx, `{"workflowId":"`+row.ID+`"}`)
	if err != nil {
		t.Fatalf("stage workflow: %v", err)
	}
	var result struct {
		Staged         bool   `json:"staged"`
		WorkflowID     string `json:"workflowId"`
		WorkflowName   string `json:"workflowName"`
		LifecycleState string `json:"lifecycleState"`
		Active         bool   `json:"active"`
	}
	if err := json.Unmarshal([]byte(out), &result); err != nil {
		t.Fatalf("decode stage result: %v (%s)", err, out)
	}
	if !result.Staged || result.WorkflowID != row.ID || result.WorkflowName != "stage_named" || result.LifecycleState != "inactive" || result.Active {
		t.Fatalf("stage result must identify the actual inactive workflow: %+v", result)
	}
	if len(binder.attachOnce) != 1 || binder.attachOnce[0] != "trg_a|"+row.ID {
		t.Fatalf("stage must attach the actual workflow exactly once: %v", binder.attachOnce)
	}
}

func TestActivateWorkflow_ExecuteReturnsNamedSnapshotFromRealService(t *testing.T) {
	svc, ctx := newSvc(t)
	binder := &stageResultBinder{}
	svc.SetExecutionPorts(binder, nil)

	created, err := (&CreateWorkflow{svc: svc}).Execute(ctx, `{"name":"activate_named","description":"","tags":[],"changeReason":"contract test","ops":[{"op":"add_node","node":{"id":"start","kind":"trigger","ref":"trg_a"}}]}`)
	if err != nil {
		t.Fatalf("create workflow: %v", err)
	}
	var row struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal([]byte(created), &row); err != nil || row.ID == "" {
		t.Fatalf("decode created workflow: %v (%s)", err, created)
	}

	out, err := (&ActivateWorkflow{svc: svc}).Execute(ctx, `{"workflowId":"`+row.ID+`"}`)
	if err != nil {
		t.Fatalf("activate workflow: %v", err)
	}
	var result struct {
		WorkflowID     string `json:"workflowId"`
		WorkflowName   string `json:"workflowName"`
		LifecycleState string `json:"lifecycleState"`
		Active         bool   `json:"active"`
	}
	if err := json.Unmarshal([]byte(out), &result); err != nil {
		t.Fatalf("decode activate result: %v (%s)", err, out)
	}
	if result.WorkflowID != row.ID || result.WorkflowName != "activate_named" || result.LifecycleState != "active" || !result.Active {
		t.Fatalf("activate result must identify the actual live workflow: %+v", result)
	}
	if len(binder.attach) != 1 || binder.attach[0] != "trg_a|"+row.ID {
		t.Fatalf("activate must attach the actual workflow exactly once: %v", binder.attach)
	}
}

// TestCreateGetEdit_HappyPath drives create → get → edit through the tools over a real
// Service + in-memory store, asserting the round-trip JSON carries the expected ids.
func TestCreateGetEdit_HappyPath(t *testing.T) {
	svc, ctx := newSvc(t)
	create := &CreateWorkflow{svc: svc}
	get := &GetWorkflow{svc: svc}
	edit := &EditWorkflow{svc: svc}

	createArgs := `{"name":"pipe","ops":[
		{"op":"add_node","node":{"id":"t","kind":"trigger","ref":"trg_a"}},
		{"op":"add_node","node":{"id":"a","kind":"action","ref":"fn_b","input":{"x":"t.v"}}},
		{"op":"add_edge","edge":{"id":"e1","from":"t","to":"a"}}
	]}`
	out, err := create.Execute(ctx, createArgs)
	if err != nil {
		t.Fatalf("create.Execute: %v", err)
	}
	var created struct {
		ID      string `json:"id"`
		Version int    `json:"version"`
		Active  bool   `json:"active"`
	}
	if err := json.Unmarshal([]byte(out), &created); err != nil {
		t.Fatalf("create result: %v (%s)", err, out)
	}
	if created.ID == "" || created.Version != 1 || created.Active {
		t.Fatalf("create result wrong: %+v", created)
	}

	got, err := get.Execute(ctx, `{"workflowId":"`+created.ID+`"}`)
	if err != nil {
		t.Fatalf("get.Execute: %v", err)
	}
	if got == "" {
		t.Fatal("get returned empty")
	}

	editArgs := `{"workflowId":"` + created.ID + `","ops":[{"op":"delete_edge","id":"e1"},{"op":"delete_node","id":"a"}]}`
	editOut, err := edit.Execute(ctx, editArgs)
	if err != nil {
		t.Fatalf("edit.Execute: %v", err)
	}
	var edited struct {
		Version int `json:"version"`
	}
	if err := json.Unmarshal([]byte(editOut), &edited); err != nil {
		t.Fatalf("edit result: %v (%s)", err, editOut)
	}
	if edited.Version != 2 {
		t.Fatalf("edit should produce v2, got %d", edited.Version)
	}
}

func TestCapabilityCheck_Execute_StructuralOnly(t *testing.T) {
	svc, ctx := newSvc(t)
	create := &CreateWorkflow{svc: svc}
	out, err := create.Execute(ctx, `{"name":"cc","ops":[
		{"op":"add_node","node":{"id":"t","kind":"trigger","ref":"trg_a"}},
		{"op":"add_node","node":{"id":"a","kind":"action","ref":"fn_b","input":{"x":"t.v"}}},
		{"op":"add_edge","edge":{"id":"e1","from":"t","to":"a"}}
	]}`)
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	var created struct {
		ID string `json:"id"`
	}
	json.Unmarshal([]byte(out), &created)

	cc := &CapabilityCheckWorkflow{svc: svc}
	res, err := cc.Execute(ctx, `{"workflowId":"`+created.ID+`"}`)
	if err != nil {
		t.Fatalf("capcheck.Execute: %v", err)
	}
	var rep struct {
		OK                bool `json:"ok"`
		StructurallyValid bool `json:"structurallyValid"`
		Resolved          bool `json:"resolved"`
	}
	if err := json.Unmarshal([]byte(res), &rep); err != nil {
		t.Fatalf("capcheck result: %v (%s)", err, res)
	}
	var shape map[string]json.RawMessage
	if err := json.Unmarshal([]byte(res), &shape); err != nil {
		t.Fatalf("capcheck shape: %v (%s)", err, res)
	}
	if got := string(shape["problems"]); got != "[]" {
		t.Fatalf("empty problems must be an array, got %s", got)
	}
	if got := string(shape["warnings"]); got != "[]" {
		t.Fatalf("empty warnings must be an array, got %s", got)
	}
	// No resolver wired → structural-only, valid, OK.
	if !rep.OK || !rep.StructurallyValid || rep.Resolved {
		t.Fatalf("structural-only capcheck wrong: %+v", rep)
	}
}

// TestOpsDoc_SchemaLessTextConvention — F32: the node-result-shapes guidance must tell the agent a
// schema-less callable (a free-form agent, an mcp/function/handler returning a non-object) exposes
// its result under ".text", so it wires <nodeId>.text FROM THE DOC instead of discovering it via a
// guaranteed failed flowrun (capability_check can't see the runtime-only key).
func TestOpsDoc_SchemaLessTextConvention(t *testing.T) {
	for _, want := range []string{"SCHEMA-LESS", "<nodeId>.text", "summarize.text"} {
		if !strings.Contains(opsDoc, want) {
			t.Fatalf("opsDoc must document the schema-less .text convention; missing %q", want)
		}
	}
}

// TestEditWorkflow_DescriptionDisambiguatesFilesystemEdit — the resident filesystem Edit tool has
// file_path/old_string/new_string, while this lazy tool edits a workflow graph with workflowId/ops.
// Keep that distinction explicit because a wrong first call makes the user watch a needless failed
// activity and can trigger a model retry before the real operation.
func TestEditWorkflow_DescriptionDisambiguatesFilesystemEdit(t *testing.T) {
	description := (&EditWorkflow{}).Description()
	for _, want := range []string{
		"NOT the filesystem Edit tool",
		"file_path",
		"old_string",
		"new_string",
		"workflowId",
		"non-empty ops array",
	} {
		if !strings.Contains(description, want) {
			t.Fatalf("edit_workflow description must disambiguate the filesystem Edit tool; missing %q", want)
		}
	}
}

func TestRevertWorkflow_DescriptionDocumentsHostedIntegerCompatibility(t *testing.T) {
	description := (&RevertWorkflow{}).Description()
	for _, want := range []string{
		"positive integer",
		"exact decimal integer string is also accepted",
		"floats, booleans, arrays, and malformed strings are rejected",
		"one call containing BOTH",
		"never omit either key",
		"without another tool call",
	} {
		if !strings.Contains(description, want) {
			t.Fatalf("revert_workflow description must document version compatibility; missing %q", want)
		}
	}
}

// TestEdit_RejectsInvalidConcurrency — F42: a set_meta op carrying an unknown concurrency value must
// error (mirror Create), not be silently swallowed — else the agent believes it set a policy that
// was never applied (the workflow keeps its old policy while the version bumps from other meta).
func TestEdit_RejectsInvalidConcurrency(t *testing.T) {
	svc, ctx := newSvc(t)
	out, err := (&CreateWorkflow{svc: svc}).Execute(ctx, `{"name":"cc","ops":[
		{"op":"add_node","node":{"id":"t","kind":"trigger","ref":"trg_a"}},
		{"op":"add_node","node":{"id":"a","kind":"action","ref":"fn_b","input":{"x":"t.v"}}},
		{"op":"add_edge","edge":{"id":"e1","from":"t","to":"a"}}
	]}`)
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	var created struct {
		ID string `json:"id"`
	}
	json.Unmarshal([]byte(out), &created)
	if _, err := (&EditWorkflow{svc: svc}).Execute(ctx, `{"workflowId":"`+created.ID+`","ops":[{"op":"set_meta","concurrency":"bogus"}]}`); err == nil {
		t.Fatal("edit_workflow with invalid concurrency should error, got nil (silent swallow)")
	}
	if _, err := (&EditWorkflow{svc: svc}).Execute(ctx, `{"workflowId":"`+created.ID+`","ops":[{"op":"set_meta","concurrency":"replace"}]}`); err != nil {
		t.Fatalf("valid concurrency 'replace' rejected: %v", err)
	}
}

// TestTriggerWorkflow_PayloadDescribesEntryShape: round-1 ergo+rename lanes saw agents trial-and-error
// the synthetic payload (guessing flat {amount} before the correct {body:{amount}}). The payload param
// must disclose the per-kind fire-payload shape so the agent doesn't burn failed runs guessing it.
func TestTriggerWorkflow_PayloadDescribesEntryShape(t *testing.T) {
	params := string((&TriggerWorkflow{}).Parameters())
	for _, want := range []string{"body", "fsnotify", "create_trigger", "JSON-encoded object string", "arrays"} {
		if !strings.Contains(params, want) {
			t.Errorf("trigger_workflow payload description must mention %q to disclose the entry-trigger fire-payload shape; got: %s", want, params)
		}
	}
}

// TestTriggerWorkflow_StringifiedPayloadPreservesObject proves the hosted-model compatibility lane
// changes only the encoding, not the payload object that reaches the scheduler.
func TestTriggerWorkflow_StringifiedPayloadPreservesObject(t *testing.T) {
	var args triggerWorkflowArgs
	if err := json.Unmarshal([]byte(`{"workflowId":"wf_1","payload":"{\"body\":{\"amount\":18240}}"}`), &args); err != nil {
		t.Fatalf("stringified payload must decode: %v", err)
	}
	body, ok := args.Payload["body"].(map[string]any)
	if !ok || body["amount"] != float64(18240) {
		t.Fatalf("decoded payload changed shape: workflow=%q payload=%#v", args.WorkflowID, args.Payload)
	}
}
