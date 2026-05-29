// Package modelcapoverride contains store round-trip tests for ModelCapOverride.
//
// Package modelcapoverride 包含 ModelCapOverride store 的往返测试。
package modelcapoverride_test

import (
	"context"
	"testing"
	"time"

	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"
	modelcapoverridestore "github.com/sunweilin/forgify/backend/internal/infra/store/modelcapoverride"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

func TestStore_UpsertGetListDelete(t *testing.T) {
	gdb, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	if err := gdb.AutoMigrate(&modeldomain.ModelCapOverride{}); err != nil {
		t.Fatalf("automigrate: %v", err)
	}

	store := modelcapoverridestore.New(gdb)
	ctx := reqctxpkg.SetUserID(context.Background(), "u_test01")

	shape := "effort"
	win := 256000
	maxOut := 16384
	o := &modeldomain.ModelCapOverride{
		ID:            "mco_test0000000001",
		UserID:        "u_test01",
		Provider:      "deepseek",
		ModelID:       "deepseek-v4",
		ThinkingShape: &shape,
		ContextWindow: &win,
		MaxOutput:     &maxOut,
		CreatedAt:     time.Now().UTC(),
		UpdatedAt:     time.Now().UTC(),
	}

	// Upsert → Get
	if err := store.Upsert(ctx, o); err != nil {
		t.Fatalf("upsert: %v", err)
	}

	got, err := store.Get(ctx, "u_test01", "deepseek", "deepseek-v4")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if got == nil {
		t.Fatal("got: want non-nil")
	}
	if got.ID != "mco_test0000000001" {
		t.Errorf("ID: got %q, want %q", got.ID, "mco_test0000000001")
	}
	if got.Provider != "deepseek" {
		t.Errorf("Provider: got %q, want %q", got.Provider, "deepseek")
	}
	if got.ModelID != "deepseek-v4" {
		t.Errorf("ModelID: got %q, want %q", got.ModelID, "deepseek-v4")
	}
	if got.ThinkingShape == nil {
		t.Fatal("ThinkingShape: want non-nil")
	}
	if *got.ThinkingShape != "effort" {
		t.Errorf("ThinkingShape: got %q, want %q", *got.ThinkingShape, "effort")
	}
	if got.ContextWindow == nil {
		t.Fatal("ContextWindow: want non-nil")
	}
	if *got.ContextWindow != 256000 {
		t.Errorf("ContextWindow: got %d, want %d", *got.ContextWindow, 256000)
	}
	if got.MaxOutput == nil {
		t.Fatal("MaxOutput: want non-nil")
	}
	if *got.MaxOutput != 16384 {
		t.Errorf("MaxOutput: got %d, want %d", *got.MaxOutput, 16384)
	}

	// Upsert again (update) — change ContextWindow
	win2 := 512000
	o2 := &modeldomain.ModelCapOverride{
		ID:            "mco_test0000000001", // same id, same unique triple
		UserID:        "u_test01",
		Provider:      "deepseek",
		ModelID:       "deepseek-v4",
		ThinkingShape: &shape,
		ContextWindow: &win2,
		MaxOutput:     &maxOut,
		UpdatedAt:     time.Now().UTC(),
	}
	if err := store.Upsert(ctx, o2); err != nil {
		t.Fatalf("upsert2: %v", err)
	}

	got2, err := store.Get(ctx, "u_test01", "deepseek", "deepseek-v4")
	if err != nil {
		t.Fatalf("get2: %v", err)
	}
	if got2.ContextWindow == nil {
		t.Fatal("ContextWindow2: want non-nil")
	}
	if *got2.ContextWindow != 512000 {
		t.Errorf("ContextWindow2: got %d, want %d", *got2.ContextWindow, 512000)
	}

	// List
	list, err := store.List(ctx, "u_test01")
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(list) != 1 {
		t.Errorf("list len: got %d, want 1", len(list))
	}

	// User-scoped isolation: other user sees nothing
	ctx2 := reqctxpkg.SetUserID(context.Background(), "u_test02")
	got3, err := store.Get(ctx2, "u_test02", "deepseek", "deepseek-v4")
	if err != nil {
		t.Fatalf("get ctx2: %v", err)
	}
	if got3 != nil {
		t.Errorf("got3: want nil for different user, got %+v", got3)
	}

	list2, err := store.List(ctx2, "u_test02")
	if err != nil {
		t.Fatalf("list ctx2: %v", err)
	}
	if len(list2) != 0 {
		t.Errorf("list2 len: got %d, want 0", len(list2))
	}

	// Delete
	if err := store.Delete(ctx, "u_test01", "deepseek", "deepseek-v4"); err != nil {
		t.Fatalf("delete: %v", err)
	}

	got4, err := store.Get(ctx, "u_test01", "deepseek", "deepseek-v4")
	if err != nil {
		t.Fatalf("get after delete: %v", err)
	}
	if got4 != nil {
		t.Errorf("got4: want nil after delete, got %+v", got4)
	}

	// Get on missing returns nil, nil (not error)
	got5, err := store.Get(ctx, "u_test01", "anthropic", "claude-opus-4")
	if err != nil {
		t.Fatalf("get missing: %v", err)
	}
	if got5 != nil {
		t.Errorf("got5: want nil for missing entry, got %+v", got5)
	}
}

func TestStore_Upsert_MultipleOverrides(t *testing.T) {
	gdb, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	if err := gdb.AutoMigrate(&modeldomain.ModelCapOverride{}); err != nil {
		t.Fatalf("automigrate: %v", err)
	}

	store := modelcapoverridestore.New(gdb)
	ctx := reqctxpkg.SetUserID(context.Background(), "u_multi")

	type entry struct{ provider, modelID, id string }
	entries := []entry{
		{"deepseek", "deepseek-v4", "mco_multi000000001"},
		{"anthropic", "claude-opus-4", "mco_multi000000002"},
		{"openai", "gpt-5", "mco_multi000000003"},
	}
	win := 100000
	for _, e := range entries {
		o := &modeldomain.ModelCapOverride{
			ID:            e.id,
			UserID:        "u_multi",
			Provider:      e.provider,
			ModelID:       e.modelID,
			ContextWindow: &win,
			UpdatedAt:     time.Now().UTC(),
		}
		if err := store.Upsert(ctx, o); err != nil {
			t.Fatalf("upsert %s/%s: %v", e.provider, e.modelID, err)
		}
	}

	list, err := store.List(ctx, "u_multi")
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(list) != 3 {
		t.Errorf("list len: got %d, want 3", len(list))
	}
}
