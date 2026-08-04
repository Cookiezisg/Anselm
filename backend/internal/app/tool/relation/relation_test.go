package relation

import (
	"encoding/json"
	"errors"
	"testing"

	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
)

// TestGetRelations_Wiring: group shape + kind/id required (reuses the relation domain
// sentinel).
//
// TestGetRelations_Wiring：组形状 + kind/id 必填（复用 relation 域 sentinel）。
func TestGetRelations_Wiring(t *testing.T) {
	tools := RelationTools(nil)
	if len(tools) != 1 || tools[0].Name() != "get_relations" {
		t.Fatalf("group wrong: %v", tools)
	}
	for _, bad := range []string{`{}`, `{"kind":"function"}`, `{"id":"fn_1"}`} {
		if err := tools[0].ValidateInput([]byte(bad)); !errors.Is(err, relationdomain.ErrInvalidRef) {
			t.Fatalf("args %s must reject: %v", bad, err)
		}
	}
	if err := tools[0].ValidateInput([]byte(`{"kind":"function","id":"fn_1"}`)); err != nil {
		t.Fatalf("valid args rejected: %v", err)
	}
}

func TestGetRelations_HostedModelStringifiedDepth(t *testing.T) {
	tool := RelationTools(nil)[0]
	for _, raw := range []string{
		`{"kind":"function","id":"fn_1","depth":"2"}`,
		`{"kind":"function","id":"fn_1","depth":2}`,
	} {
		if err := tool.ValidateInput([]byte(raw)); err != nil {
			t.Fatalf("accepted depth shape rejected: %s: %v", raw, err)
		}
	}
	for _, raw := range []string{
		`{"kind":"function","id":"fn_1","depth":"two"}`,
		`{"kind":"function","id":"fn_1","depth":"2.0"}`,
		`{"kind":"function","id":"fn_1","depth":2.0}`,
		`{"kind":"function","id":"fn_1","depth":0}`,
		`{"kind":"function","id":"fn_1","depth":4}`,
	} {
		if err := tool.ValidateInput([]byte(raw)); err == nil {
			t.Fatalf("accepted malformed depth shape: %s", raw)
		}
	}
	var got getRelationsArgs
	if err := json.Unmarshal([]byte(`{"kind":"function","id":"fn_1","depth":"3"}`), &got); err != nil || got.Depth != 3 {
		t.Fatalf("decoded depth = %+v, err=%v; want 3", got, err)
	}
	if err := tool.ValidateInput([]byte(`{"kind":"function","id":"fn_1"}`)); err != nil {
		t.Fatalf("omitted depth must use default: %v", err)
	}
}
