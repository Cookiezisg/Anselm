package workflow

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"testing"

	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
)

func TestSentinels_Unique(t *testing.T) {
	all := []error{
		ErrNotFound, ErrDuplicateName, ErrVersionNotFound, ErrPendingNotFound,
		ErrNoActiveVersion, ErrDAGCycle, ErrInvalidReference, ErrNoTrigger,
		ErrOpInvalid, ErrCapabilityNotFound, ErrMCPServerNotInstalled,
		ErrInvalidNodeModelOverride,
	}
	if len(all) != 12 {
		t.Errorf("expected 12 sentinels (Plan 04 11 + per-node modelOverride), got %d", len(all))
	}
	seen := map[string]bool{}
	for _, e := range all {
		msg := e.Error()
		if !strings.HasPrefix(msg, "workflow: ") {
			t.Errorf("sentinel %q must start with 'workflow: '", msg)
		}
		if seen[msg] {
			t.Errorf("duplicate sentinel message: %q", msg)
		}
		seen[msg] = true
	}
}

func TestSentinels_ErrorsIsCompatible(t *testing.T) {
	wrapped := fmt.Errorf("workflowstore.GetWorkflow: %w",
		fmt.Errorf("workflowapp.Get: %w", ErrNotFound))
	if !errors.Is(wrapped, ErrNotFound) {
		t.Errorf("errors.Is should unwrap to ErrNotFound through %%w chain")
	}
}

func TestNodeType_Whitelist(t *testing.T) {
	valid := []string{
		NodeTypeTrigger, NodeTypeFunction, NodeTypeHandler, NodeTypeMCP,
		NodeTypeSkill, NodeTypeLLM, NodeTypeAgent, NodeTypeHTTP, NodeTypeCondition,
		NodeTypeLoop, NodeTypeParallel, NodeTypeApproval, NodeTypeWait,
		NodeTypeVariable,
	}
	if len(valid) != 14 {
		t.Errorf("expected 14 node types (Plan 04 13 + §14.5b agent), got %d", len(valid))
	}
	for _, nt := range valid {
		if !IsValidNodeType(nt) {
			t.Errorf("IsValidNodeType(%q) = false", nt)
		}
	}
	if IsValidNodeType("frobnicate") {
		t.Errorf("unknown type should be invalid")
	}
}

func TestCapabilityNode_Subset(t *testing.T) {
	caps := []string{NodeTypeFunction, NodeTypeHandler, NodeTypeMCP, NodeTypeSkill, NodeTypeLLM, NodeTypeAgent, NodeTypeHTTP}
	for _, nt := range caps {
		if !IsCapabilityNode(nt) {
			t.Errorf("IsCapabilityNode(%q) = false, want true", nt)
		}
	}
	nonCaps := []string{NodeTypeTrigger, NodeTypeCondition, NodeTypeLoop, NodeTypeParallel, NodeTypeApproval, NodeTypeWait, NodeTypeVariable}
	for _, nt := range nonCaps {
		if IsCapabilityNode(nt) {
			t.Errorf("IsCapabilityNode(%q) = true, want false (non-capability)", nt)
		}
	}
}

func TestOnError_Whitelist(t *testing.T) {
	for _, s := range []string{OnErrorStop, OnErrorContinue, OnErrorBranch} {
		if !IsValidOnError(s) {
			t.Errorf("IsValidOnError(%q) = false", s)
		}
	}
	if IsValidOnError("explode") {
		t.Errorf("unknown OnError should be invalid")
	}
}

func TestVariableType_Whitelist(t *testing.T) {
	for _, v := range []string{VarTypeString, VarTypeNumber, VarTypeInteger, VarTypeBoolean, VarTypeObject, VarTypeArray} {
		if !IsValidVariableType(v) {
			t.Errorf("IsValidVariableType(%q) = false", v)
		}
	}
	if IsValidVariableType("date") {
		t.Errorf("unknown variable type should be invalid")
	}
}

func TestNodeSpec_ModelOverrideMarshalsAsJSON(t *testing.T) {
	ns := NodeSpec{
		ID:   "node_1",
		Type: NodeTypeAgent,
		ModelOverride: &modeldomain.ModelRef{
			APIKeyID: "aki_test",
			ModelID:  "claude-haiku-4-5",
		},
	}
	raw, err := json.Marshal(ns)
	if err != nil {
		t.Fatal(err)
	}
	var got map[string]any
	if err := json.Unmarshal(raw, &got); err != nil {
		t.Fatal(err)
	}
	mo, ok := got["modelOverride"].(map[string]any)
	if !ok {
		t.Fatalf("modelOverride missing or wrong shape: %v", got["modelOverride"])
	}
	if mo["apiKeyId"] != "aki_test" || mo["modelId"] != "claude-haiku-4-5" {
		t.Fatalf("modelOverride wrong content: %v", mo)
	}
}

func TestNodeSpec_NilModelOverrideOmitted(t *testing.T) {
	ns := NodeSpec{ID: "node_1", Type: NodeTypeAgent}
	raw, err := json.Marshal(ns)
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(raw, []byte("modelOverride")) {
		t.Fatalf("nil modelOverride should be omitted, got: %s", raw)
	}
}

func TestErrInvalidNodeModelOverride_Sentinel(t *testing.T) {
	if ErrInvalidNodeModelOverride == nil {
		t.Fatal("sentinel not defined")
	}
	if !strings.HasPrefix(ErrInvalidNodeModelOverride.Error(), "workflow: ") {
		t.Fatalf("sentinel message must start with 'workflow: ', got %q", ErrInvalidNodeModelOverride.Error())
	}
}
