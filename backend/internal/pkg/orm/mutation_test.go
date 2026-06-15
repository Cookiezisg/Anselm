package orm

import (
	"context"
	"testing"

	reqctxpkg "github.com/sunweilin/foryx/backend/internal/pkg/reqctx"
)

func TestUpdates(t *testing.T) {
	db, ctx := newTestDB(t)
	r := widgets(db)
	mustCreate(t, r, ctx, "w_1", "old", 1)

	n, err := r.WhereEq("id", "w_1").Updates(ctx, map[string]any{"name": "new", "score": 9})
	if err != nil || n != 1 {
		t.Fatalf("updates: n=%d err=%v", n, err)
	}
	got, _ := r.Get(ctx, "w_1")
	if got.Name != "new" || got.Score != 9 {
		t.Errorf("got %+v", got)
	}
}

func TestUpdate_SingleColumn(t *testing.T) {
	db, ctx := newTestDB(t)
	r := widgets(db)
	mustCreate(t, r, ctx, "w_1", "x", 1)

	n, err := r.WhereEq("id", "w_1").Update(ctx, "score", 42)
	if err != nil || n != 1 {
		t.Fatalf("update: n=%d err=%v", n, err)
	}
	got, _ := r.Get(ctx, "w_1")
	if got.Score != 42 {
		t.Errorf("score = %d, want 42", got.Score)
	}
}

func TestUpdate_StaysWithinWorkspace(t *testing.T) {
	db, ctx := newTestDB(t)
	r := widgets(db)
	mustCreate(t, r, ctx, "w_1", "x", 1)

	ctx2 := reqctxpkg.SetWorkspaceID(context.Background(), "ws_2")
	n, err := r.WhereEq("id", "w_1").Update(ctx2, "score", 99)
	if err != nil {
		t.Fatalf("update: %v", err)
	}
	if n != 0 {
		t.Errorf("cross-workspace update should affect 0 rows, got %d", n)
	}
}

func TestPluck(t *testing.T) {
	db, ctx := newTestDB(t)
	r := widgets(db)
	mustCreate(t, r, ctx, "w_1", "a", 1)
	mustCreate(t, r, ctx, "w_2", "b", 2)

	var names []string
	if err := r.Order("id ASC").Pluck(ctx, "name", &names); err != nil {
		t.Fatalf("pluck: %v", err)
	}
	if len(names) != 2 || names[0] != "a" || names[1] != "b" {
		t.Errorf("pluck names = %v", names)
	}
}
