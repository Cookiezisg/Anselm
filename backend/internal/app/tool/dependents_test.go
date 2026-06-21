package tool

import (
	"context"
	"errors"
	"strings"
	"testing"

	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
)

type fakeCounter struct {
	edges []*relationdomain.Relation
	err   error
}

func (f fakeCounter) CountDependents(context.Context, string, string) (int, error) {
	return len(f.edges), f.err
}
func (f fakeCounter) ListDependents(context.Context, string, string) ([]*relationdomain.Relation, error) {
	return f.edges, f.err
}

func twoDeps() []*relationdomain.Relation {
	return []*relationdomain.Relation{
		{FromKind: "agent", FromID: "ag_1"},
		{FromKind: "workflow", FromID: "wf_1"},
	}
}

// TestDependentRefs_NilAndErrorSafe: a delete must never fail because the advisory read did.
func TestDependentRefs_NilAndErrorSafe(t *testing.T) {
	ctx := context.Background()
	if got := DependentRefs(ctx, nil, "function", "fn_1"); got != nil {
		t.Fatalf("nil counter = %v, want nil", got)
	}
	if got := DependentRefs(ctx, fakeCounter{edges: twoDeps()}, "function", "fn_1"); len(got) != 2 || got[0]["id"] != "ag_1" {
		t.Fatalf("refs = %v, want the 2 dependent {kind,id} refs", got)
	}
	if got := DependentRefs(ctx, fakeCounter{err: errors.New("db down")}, "function", "fn_1"); got != nil {
		t.Fatalf("counter error = %v, want nil (advisory; delete must not fail)", got)
	}
}

// TestAnnotateDependents: refs present → folds in the dependent refs + count + note so the agent knows
// EXACTLY which entities to repair (F160); empty leaves the map untouched (no false alarm).
func TestAnnotateDependents(t *testing.T) {
	refs := DependentRefs(context.Background(), fakeCounter{edges: twoDeps()}, "function", "fn_1")
	withDeps := AnnotateDependents(map[string]any{"id": "fn_1", "deleted": true}, refs)
	if withDeps["dependentCount"] != 2 {
		t.Fatalf("dependentCount = %v, want 2", withDeps["dependentCount"])
	}
	if _, ok := withDeps["dependents"]; !ok {
		t.Fatal("positive deps must include the dependent refs (a bare count is unfollowable post-purge)")
	}
	if _, ok := withDeps["note"]; !ok {
		t.Fatal("a positive count must add a repair note")
	}

	noDeps := AnnotateDependents(map[string]any{"id": "fn_1", "deleted": true}, nil)
	if _, ok := noDeps["dependents"]; ok {
		t.Fatal("zero dependents must not add the dependents key (no false alarm)")
	}
}

// TestDependentSuffix: the string-result counterpart — non-empty (and naming the refs) only with deps.
func TestDependentSuffix(t *testing.T) {
	if s := DependentSuffix(nil); s != "" {
		t.Fatalf("no-deps suffix = %q, want empty", s)
	}
	refs := DependentRefs(context.Background(), fakeCounter{edges: twoDeps()}, "agent", "ag_x")
	if s := DependentSuffix(refs); s == "" || !strings.Contains(s, "wf_1") {
		t.Fatalf("positive deps must produce a suffix naming the referencing ids, got %q", s)
	}
}
