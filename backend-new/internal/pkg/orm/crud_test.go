package orm

import (
	"context"
	"errors"
	"testing"
)

func TestCreate_Get_RoundTrip(t *testing.T) {
	db, ctx := newTestDB(t)
	repo := widgets(db)

	w := &widget{ID: "w_1", Name: "alpha", Tags: []string{"a", "b"}, Score: 5}
	if err := repo.Create(ctx, w); err != nil {
		t.Fatalf("create: %v", err)
	}
	// Write auto-stamps workspace (from ctx) + timestamps.
	if w.WorkspaceID != "ws_1" {
		t.Errorf("WorkspaceID = %q, want ws_1 (auto)", w.WorkspaceID)
	}
	if w.CreatedAt.IsZero() || w.UpdatedAt.IsZero() {
		t.Error("create should stamp created/updated")
	}

	got, err := repo.Get(ctx, "w_1")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if got.Name != "alpha" || got.Score != 5 {
		t.Errorf("got %+v", got)
	}
	if len(got.Tags) != 2 || got.Tags[0] != "a" || got.Tags[1] != "b" {
		t.Errorf("json column round-trip failed: %v", got.Tags)
	}
	if got.CreatedAt.IsZero() {
		t.Error("created_at should round-trip non-zero")
	}
}

func TestGet_NotFound(t *testing.T) {
	db, ctx := newTestDB(t)
	if _, err := widgets(db).Get(ctx, "missing"); !errors.Is(err, ErrNotFound) {
		t.Errorf("err = %v, want ErrNotFound", err)
	}
}

func TestCreate_RequiresWorkspaceInCtx(t *testing.T) {
	db, _ := newTestDB(t)
	// No workspace in ctx → write must refuse (isolation safety).
	err := widgets(db).Create(context.Background(), &widget{ID: "w_x"})
	if err == nil {
		t.Error("create without workspace ctx should fail")
	}
}

func TestSave_Upsert_PreservesCreated(t *testing.T) {
	db, ctx := newTestDB(t)
	repo := widgets(db)

	if err := repo.Save(ctx, &widget{ID: "w_1", Name: "first", Score: 1}); err != nil {
		t.Fatalf("save insert: %v", err)
	}
	got1, _ := repo.Get(ctx, "w_1")

	if err := repo.Save(ctx, &widget{ID: "w_1", Name: "second", Score: 2}); err != nil {
		t.Fatalf("save update: %v", err)
	}
	got2, _ := repo.Get(ctx, "w_1")

	if got2.Name != "second" || got2.Score != 2 {
		t.Errorf("upsert did not update: %+v", got2)
	}
	// created_at is preserved across the upsert (both reads come from the DB).
	if !got2.CreatedAt.Equal(got1.CreatedAt) {
		t.Errorf("created_at changed on upsert: %v vs %v", got2.CreatedAt, got1.CreatedAt)
	}
}

func TestDelete_SoftThenNotFound(t *testing.T) {
	db, ctx := newTestDB(t)
	repo := widgets(db)
	if err := repo.Create(ctx, &widget{ID: "w_1", Name: "x"}); err != nil {
		t.Fatalf("create: %v", err)
	}

	found, err := repo.Delete(ctx, "w_1")
	if err != nil || !found {
		t.Fatalf("delete: found=%v err=%v", found, err)
	}

	// Soft-deleted → normal Get misses.
	if _, err := repo.Get(ctx, "w_1"); !errors.Is(err, ErrNotFound) {
		t.Errorf("soft-deleted row should not be found, err=%v", err)
	}
	// Unscoped still sees it, with deleted_at set.
	got, err := repo.Unscoped().WhereEq("id", "w_1").First(ctx)
	if err != nil {
		t.Fatalf("unscoped first: %v", err)
	}
	if got.DeletedAt == nil {
		t.Error("deleted_at should be set after soft delete")
	}
}
