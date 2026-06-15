package orm

import (
	"context"
	"errors"
	"testing"

	reqctxpkg "github.com/sunweilin/foryx/backend/internal/pkg/reqctx"
)

func TestFind_WhereOrder(t *testing.T) {
	db, ctx := newTestDB(t)
	r := widgets(db)
	mustCreate(t, r, ctx, "w_1", "a", 1)
	mustCreate(t, r, ctx, "w_2", "b", 2)
	mustCreate(t, r, ctx, "w_3", "a", 3)

	got, err := r.WhereEq("name", "a").Order("score ASC").Find(ctx)
	if err != nil {
		t.Fatalf("find: %v", err)
	}
	if len(got) != 2 || got[0].ID != "w_1" || got[1].ID != "w_3" {
		t.Errorf("got ids %v", ids(got))
	}
}

func TestWhereIn(t *testing.T) {
	db, ctx := newTestDB(t)
	r := widgets(db)
	mustCreate(t, r, ctx, "w_1", "a", 1)
	mustCreate(t, r, ctx, "w_2", "b", 2)
	mustCreate(t, r, ctx, "w_3", "c", 3)

	got, err := r.WhereIn("id", "w_1", "w_3").Find(ctx)
	if err != nil {
		t.Fatalf("find: %v", err)
	}
	if len(got) != 2 {
		t.Errorf("WhereIn want 2, got %d", len(got))
	}
}

func TestWhereIn_Empty(t *testing.T) {
	db, ctx := newTestDB(t)
	r := widgets(db)
	mustCreate(t, r, ctx, "w_1", "a", 1)

	got, err := r.WhereIn("id").Find(ctx) // empty IN → matches nothing
	if err != nil {
		t.Fatalf("find: %v", err)
	}
	if len(got) != 0 {
		t.Errorf("empty WhereIn should match nothing, got %d", len(got))
	}
}

func TestCount_Exists(t *testing.T) {
	db, ctx := newTestDB(t)
	r := widgets(db)
	mustCreate(t, r, ctx, "w_1", "a", 1)
	mustCreate(t, r, ctx, "w_2", "b", 2)

	if n, err := r.Query().Count(ctx); err != nil || n != 2 {
		t.Errorf("count = %d, err = %v, want 2", n, err)
	}
	if ok, _ := r.WhereEq("name", "b").Exists(ctx); !ok {
		t.Error("Exists(name=b) should be true")
	}
	if ok, _ := r.WhereEq("name", "zzz").Exists(ctx); ok {
		t.Error("Exists(name=zzz) should be false")
	}
}

func TestWorkspaceIsolation(t *testing.T) {
	db, ctx1 := newTestDB(t)
	r := widgets(db)
	mustCreate(t, r, ctx1, "w_1", "x", 1)

	ctx2 := reqctxpkg.SetWorkspaceID(context.Background(), "ws_2")
	if _, err := r.Get(ctx2, "w_1"); !errors.Is(err, ErrNotFound) {
		t.Errorf("cross-workspace Get must miss, err=%v", err)
	}
	if got, err := r.Query().Find(ctx2); err != nil || len(got) != 0 {
		t.Errorf("cross-workspace Find must be empty, got %d err %v", len(got), err)
	}
	if all, err := r.CrossWorkspace().Find(ctx2); err != nil || len(all) != 1 {
		t.Errorf("CrossWorkspace should see 1, got %d err %v", len(all), err)
	}
}

func TestLimit(t *testing.T) {
	db, ctx := newTestDB(t)
	r := widgets(db)
	mustCreate(t, r, ctx, "w_1", "a", 1)
	mustCreate(t, r, ctx, "w_2", "b", 2)
	mustCreate(t, r, ctx, "w_3", "c", 3)

	got, err := r.Order("id ASC").Limit(2).Find(ctx)
	if err != nil || len(got) != 2 {
		t.Errorf("limit 2 → %d rows, err %v", len(got), err)
	}
}

func ids(ws []*widget) []string {
	out := make([]string, len(ws))
	for i, w := range ws {
		out[i] = w.ID
	}
	return out
}
