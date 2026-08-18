package agent

import (
	"encoding/json"
	"errors"
	"reflect"
	"strings"
	"testing"

	agentapp "github.com/sunweilin/anselm/backend/internal/app/agent"
	agentdomain "github.com/sunweilin/anselm/backend/internal/domain/agent"
)

func TestAgentTools_NamesAndCount(t *testing.T) {
	tools := AgentTools(nil, nil, nil) // Name() does not deref svc
	want := map[string]bool{
		"search_agent": true, "get_agent": true, "create_agent": true, "edit_agent": true,
		"revert_agent": true, "delete_agent": true, "invoke_agent": true,
		"search_agent_executions": true, "get_agent_execution": true, "update_agent_meta": true,
	}
	if len(tools) != len(want) {
		t.Fatalf("want %d tools, got %d", len(want), len(tools))
	}
	for _, tl := range tools {
		if !want[tl.Name()] {
			t.Fatalf("unexpected tool %q", tl.Name())
		}
		delete(want, tl.Name())
	}
	if len(want) != 0 {
		t.Fatalf("missing tools: %v", want)
	}
}

func TestCreateAgent_ValidateInput(t *testing.T) {
	tl := &CreateAgent{}
	if err := tl.ValidateInput(json.RawMessage(`{"name":"judge","prompt":"p"}`)); err != nil {
		t.Fatalf("valid args rejected: %v", err)
	}
	if err := tl.ValidateInput(json.RawMessage(`{"name":"judge"}`)); err == nil {
		t.Fatal("missing prompt should fail")
	}
	if err := tl.ValidateInput(json.RawMessage(`{"prompt":"p"}`)); err == nil {
		t.Fatal("missing name should fail")
	}
	if err := tl.ValidateInput(json.RawMessage(`{"name":"judge","prompt":"p","tags":"[\"acceptance\"]"}`)); err != nil {
		t.Fatalf("stringified JSON tags should be accepted: %v", err)
	}
	if err := tl.ValidateInput(json.RawMessage(`{"name":"judge","prompt":"p","tags":"acceptance,planner"}`)); err == nil {
		t.Fatal("comma-joined tags must remain invalid")
	}
}

func TestDecodeAgentTags_HostedModelShapes(t *testing.T) {
	tests := []struct {
		name string
		raw  string
		want []string
	}{
		{"native", `["acceptance","planner"]`, []string{"acceptance", "planner"}},
		{"stringified native", `"[\"acceptance\",\"planner\"]"`, []string{"acceptance", "planner"}},
		{"empty", `[]`, []string{}},
		{"missing", ``, nil},
		{"null", `null`, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := decodeAgentTags([]byte(tt.raw))
			if err != nil {
				t.Fatalf("decodeAgentTags: %v", err)
			}
			if !reflect.DeepEqual(got, tt.want) {
				t.Fatalf("decoded tags = %#v, want %#v", got, tt.want)
			}
		})
	}
	for _, raw := range []string{`"acceptance,planner"`, `"{}"`, `{"tag":"acceptance"}`, `["acceptance",1]`} {
		if _, err := decodeAgentTags([]byte(raw)); err == nil {
			t.Errorf("decodeAgentTags(%s) should reject malformed shape", raw)
		}
	}
}

func TestCreateAgent_Description_PreservesExplicitMetadata(t *testing.T) {
	tl := &CreateAgent{}
	if !strings.Contains(tl.Description(), "MUST pass those fields exactly") {
		t.Fatal("create_agent description must require explicit metadata to be forwarded")
	}
	params := string(tl.Parameters())
	if !strings.Contains(params, "If the user supplied one, pass it exactly") {
		t.Fatal("description schema must require an explicit user description to be forwarded")
	}
	if !strings.Contains(params, "Pass them exactly") {
		t.Fatal("tags schema must require explicit user tags to be forwarded")
	}
}

func TestInvokeAgent_RequiresAgentID(t *testing.T) {
	tl := &InvokeAgent{}
	if err := tl.ValidateInput(json.RawMessage(`{}`)); err == nil {
		t.Fatal("missing agentId should fail")
	}
	// input is now required: a missing/misnamed task (e.g. a "prompt" key) must fail loudly rather
	// than run the agent with empty input and return a misleading ok:true. {} is allowed.
	if err := tl.ValidateInput(json.RawMessage(`{"agentId":"ag_1"}`)); err == nil {
		t.Fatal("missing input should fail")
	}
	if err := tl.ValidateInput(json.RawMessage(`{"agentId":"ag_1","input":{}}`)); err != nil {
		t.Fatalf("valid args (agentId + input) rejected: %v", err)
	}
	if err := tl.ValidateInput(json.RawMessage(`{"agentId":"ag_1","input":"review this"}`)); err != nil {
		t.Fatalf("plain-text task should be accepted: %v", err)
	}
	if err := tl.ValidateInput(json.RawMessage(`{"agentId":"ag_1","input":["not","an","object"]}`)); err == nil {
		t.Fatal("array input must remain invalid")
	}
}

func TestAgentInputMap_HostedModelShapes(t *testing.T) {
	tests := []struct {
		name string
		raw  string
		want map[string]any
	}{
		{name: "native object", raw: `{"task":"review"}`, want: map[string]any{"task": "review"}},
		{name: "stringified object", raw: `"{\"task\":\"review\"}"`, want: map[string]any{"task": "review"}},
		{name: "plain task", raw: `"review this"`, want: map[string]any{"prompt": "review this"}},
		{name: "empty plain task", raw: `""`, want: map[string]any{"prompt": ""}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var got agentInputMap
			if err := json.Unmarshal([]byte(tt.raw), &got); err != nil {
				t.Fatalf("unmarshal: %v", err)
			}
			if !reflect.DeepEqual(map[string]any(got), tt.want) {
				t.Fatalf("input = %#v, want %#v", got, tt.want)
			}
		})
	}
	for _, raw := range []string{`["task"]`, `42`, `true`} {
		var got agentInputMap
		if err := json.Unmarshal([]byte(raw), &got); err == nil {
			t.Errorf("input %s should be rejected", raw)
		}
	}
}

// TestConfigProps_AgentChainRedirect — F31: forbidding ag_ refs must point the agent at the real
// composition path (a workflow agent node), so it doesn't burn a turn hand-rolling an HTTP wrapper.
func TestConfigProps_AgentChainRedirect(t *testing.T) {
	if !strings.Contains(configProps, "workflow with an agent node") {
		t.Fatalf("the tools-field desc must redirect agent-chaining to the workflow path")
	}
}

// TestEditAgent_ValidateInput_NoPromptRequired — edit_agent now MERGES, so a partial edit overlays
// only provided fields; agentId alone is valid (prompt no longer required), missing agentId still fails.
func TestEditAgent_ValidateInput_NoPromptRequired(t *testing.T) {
	tl := &EditAgent{}
	if err := tl.ValidateInput(json.RawMessage(`{"agentId":"ag_1","tools":[]}`)); err != nil {
		t.Fatalf("agentId-only partial edit must be valid: %v", err)
	}
	if err := tl.ValidateInput(json.RawMessage(`{"tools":[]}`)); err == nil {
		t.Fatal("missing agentId should fail")
	}
}

func TestGetAgent_DescriptionMatchesPartialEditContract(t *testing.T) {
	tl := &GetAgent{}
	desc := tl.Description()
	if !strings.Contains(desc, "partial patch") || !strings.Contains(desc, "preserves every omitted field") {
		t.Fatalf("get_agent must describe edit_agent's partial-preserve contract, got %q", desc)
	}
	if strings.Contains(desc, "replaces the whole config") {
		t.Fatalf("get_agent must not advertise the stale full-replace contract, got %q", desc)
	}
}

func TestRevertAgent_AcceptsIntegerAndIntegerString(t *testing.T) {
	tl := &RevertAgent{}
	for _, raw := range []string{
		`{"agentId":"ag_1","version":1}`,
		`{"agentId":"ag_1","version":"1"}`,
		`{"agentId":"ag_1","version":" 1 "}`,
	} {
		if err := tl.ValidateInput(json.RawMessage(raw)); err != nil {
			t.Fatalf("valid revert args rejected for %s: %v", raw, err)
		}
	}
	for _, raw := range []string{
		`{"agentId":"ag_1"}`,
		`{"agentId":"ag_1","version":0}`,
		`{"agentId":"ag_1","version":"nope"}`,
		`{"agentId":"ag_1","version":1.5}`,
	} {
		if err := tl.ValidateInput(json.RawMessage(raw)); err == nil {
			t.Fatalf("invalid revert args unexpectedly accepted for %s", raw)
		}
	}
}

func TestRevertAgent_DescriptionMakesRequiredKeysExplicit(t *testing.T) {
	tl := &RevertAgent{}
	if !strings.Contains(tl.Description(), "required JSON keys are exactly agentId") {
		t.Fatalf("revert_agent must make the exact required key explicit, got %q", tl.Description())
	}
	if !strings.Contains(string(tl.Parameters()), `"required":["agentId","version"]`) {
		t.Fatalf("revert_agent schema must retain both required keys, got %s", tl.Parameters())
	}
}

// TestEditAgent_RejectsMetaFields — F171: name/description/tags are NOT in edit_agent's versioned config
// (they live on the agent row, changed via update_agent_meta). edit_agent must REJECT them loudly with a
// pointer, not silently swallow them (it used to return success with the meta change lost).
func TestEditAgent_RejectsMetaFields(t *testing.T) {
	tl := &EditAgent{}
	for _, args := range []string{
		`{"agentId":"ag_1","tags":["demo"]}`,
		`{"agentId":"ag_1","name":"renamed"}`,
		`{"agentId":"ag_1","description":"new desc"}`,
	} {
		if err := tl.ValidateInput(json.RawMessage(args)); !errors.Is(err, ErrAgentMetaNotInEdit) {
			t.Fatalf("edit_agent must reject meta field in %s, got %v", args, err)
		}
	}
	// A real config edit (prompt) is still fine.
	if err := tl.ValidateInput(json.RawMessage(`{"agentId":"ag_1","prompt":"new prompt"}`)); err != nil {
		t.Fatalf("a config-only edit must pass, got %v", err)
	}
}

// TestMergeConfig_PreservesOmittedClearsExplicit — the heart of the edit_agent merge fix: a prompt-only
// edit must KEEP the agent's mounted skill/knowledge/tools (the old full-replace silently wiped them at a
// measured ~40% drop rate), while an explicitly-empty field still clears it.
func TestMergeConfig_PreservesOmittedClearsExplicit(t *testing.T) {
	current := agentapp.Config{
		Prompt:    "old prompt",
		Skill:     "reviewer",
		Knowledge: []string{"doc_1"},
		Tools:     []agentdomain.ToolRef{{Ref: "fn_1"}},
	}
	// Prompt-only edit: prompt changes, everything else PRESERVED.
	got := mergeConfig(current, []byte(`{"agentId":"ag_1","prompt":"new prompt","changeReason":"tweak"}`))
	if got.Prompt != "new prompt" {
		t.Fatalf("prompt must update, got %q", got.Prompt)
	}
	if got.Skill != "reviewer" || len(got.Knowledge) != 1 || len(got.Tools) != 1 {
		t.Fatalf("omitted skill/knowledge/tools must be PRESERVED, got %+v", got)
	}
	if got.ChangeReason != "tweak" {
		t.Fatalf("changeReason must apply, got %q", got.ChangeReason)
	}
	// An explicitly-empty field still clears it (a provided value wins, even when empty).
	cleared := mergeConfig(current, []byte(`{"agentId":"ag_1","tools":[]}`))
	if len(cleared.Tools) != 0 {
		t.Fatalf("explicit empty tools must clear, got %+v", cleared.Tools)
	}
	if cleared.Prompt != "old prompt" || len(cleared.Knowledge) != 1 {
		t.Fatalf("non-tools fields must stay preserved, got %+v", cleared)
	}
}
