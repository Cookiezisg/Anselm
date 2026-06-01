package function

import (
	"context"
	"encoding/json"
	"testing"

	functiondomain "github.com/sunweilin/forgify/backend/internal/domain/function"
)

func mkOp(t *testing.T, op string, body map[string]any) Op {
	t.Helper()
	body["op"] = op
	raw, _ := json.Marshal(body)
	return Op{Type: op, Raw: raw}
}

// TestApplyOps_SetKindPolling verifies set_kind + set_polling_interval accumulate into the draft so
// Create/Edit persist a polling version (the plumbing behind the create_function kind param).
func TestApplyOps_SetKindPolling(t *testing.T) {
	s := &Service{}
	ops := []Op{
		mkOp(t, "set_meta", map[string]any{"name": "gmail_poller"}),
		mkOp(t, "set_code", map[string]any{"code": "def poll(lastCursor):\n    return {\"events\": [], \"nextCursor\": \"x\"}"}),
		mkOp(t, "set_kind", map[string]any{"kind": "polling"}),
		mkOp(t, "set_polling_interval", map[string]any{"interval": "30s"}),
	}
	draft, _, err := s.ApplyOps(context.Background(), nil, ops, "")
	if err != nil {
		t.Fatalf("ApplyOps: %v", err)
	}
	if draft.Kind != functiondomain.KindPolling {
		t.Errorf("Kind = %q, want polling", draft.Kind)
	}
	if draft.PollingInterval != "30s" {
		t.Errorf("PollingInterval = %q, want 30s", draft.PollingInterval)
	}
}

// TestApplyOps_SetKindInvalid verifies an unknown kind is rejected (not silently stored).
func TestApplyOps_SetKindInvalid(t *testing.T) {
	s := &Service{}
	ops := []Op{
		mkOp(t, "set_meta", map[string]any{"name": "f"}),
		mkOp(t, "set_code", map[string]any{"code": "def main():\n    return {}"}),
		mkOp(t, "set_kind", map[string]any{"kind": "webhook"}),
	}
	if _, _, err := s.ApplyOps(context.Background(), nil, ops, ""); err == nil {
		t.Fatalf("expected error for invalid kind, got nil")
	}
}

// TestApplyOps_KindDefaultsNormal verifies a function without set_kind leaves Kind empty in the draft
// (normalizeKind later defaults it to normal at persist).
func TestApplyOps_KindDefaultsNormal(t *testing.T) {
	s := &Service{}
	ops := []Op{
		mkOp(t, "set_meta", map[string]any{"name": "f"}),
		mkOp(t, "set_code", map[string]any{"code": "def main():\n    return {}"}),
	}
	draft, _, err := s.ApplyOps(context.Background(), nil, ops, "")
	if err != nil {
		t.Fatalf("ApplyOps: %v", err)
	}
	if draft.Kind != "" {
		t.Errorf("Kind = %q, want empty (→ normal at persist)", draft.Kind)
	}
	if normalizeKind(draft.Kind) != functiondomain.KindNormal {
		t.Errorf("normalizeKind(%q) = %q, want normal", draft.Kind, normalizeKind(draft.Kind))
	}
}
