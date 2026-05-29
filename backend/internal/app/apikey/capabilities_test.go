package apikey_test

import (
	"context"
	"testing"
	"time"

	apikeyapp "github.com/sunweilin/forgify/backend/internal/app/apikey"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"
	modelcapoverridestore "github.com/sunweilin/forgify/backend/internal/infra/store/modelcapoverride"
	modelcapspkg "github.com/sunweilin/forgify/backend/internal/pkg/modelcaps"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

func TestResolveCapabilities_NoOverride_ReturnsStatic(t *testing.T) {
	gdb, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	if err := gdb.AutoMigrate(&modeldomain.ModelCapOverride{}); err != nil {
		t.Fatalf("automigrate: %v", err)
	}

	store := modelcapoverridestore.New(gdb)
	svc := apikeyapp.NewCapabilityService(store)

	ctx := reqctxpkg.SetUserID(context.Background(), "u_cap_test01")

	cap := svc.ResolveCapabilities(ctx, "deepseek", "deepseek-v4")

	// Static rule for deepseek-v4: ContextWindow=1_000_000, MaxOutput=384_000, Thinking=ShapeEffort
	if cap.ContextWindow != 1_000_000 {
		t.Errorf("ContextWindow: got %d, want %d", cap.ContextWindow, 1_000_000)
	}
	if cap.MaxOutput != 384_000 {
		t.Errorf("MaxOutput: got %d, want %d", cap.MaxOutput, 384_000)
	}
	if cap.Thinking != modelcapspkg.ShapeEffort {
		t.Errorf("Thinking: got %v, want %v", cap.Thinking, modelcapspkg.ShapeEffort)
	}
}

func TestResolveCapabilities_WithOverride_MergesCorrectly(t *testing.T) {
	gdb, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	if err := gdb.AutoMigrate(&modeldomain.ModelCapOverride{}); err != nil {
		t.Fatalf("automigrate: %v", err)
	}

	store := modelcapoverridestore.New(gdb)
	svc := apikeyapp.NewCapabilityService(store)

	ctx := reqctxpkg.SetUserID(context.Background(), "u_cap_test02")

	// Override: user says deepseek-v4 actually has 256000 context window (override the static 1M)
	win := 256000
	shape := "effort"
	o := &modeldomain.ModelCapOverride{
		ID:            "mco_captest000000001",
		UserID:        "u_cap_test02",
		Provider:      "deepseek",
		ModelID:       "deepseek-v4",
		ContextWindow: &win,
		ThinkingShape: &shape,
		UpdatedAt:     time.Now().UTC(),
	}
	if err := store.Upsert(ctx, o); err != nil {
		t.Fatalf("upsert override: %v", err)
	}

	cap := svc.ResolveCapabilities(ctx, "deepseek", "deepseek-v4")

	// ContextWindow should come from override (256000, not static 1_000_000)
	if cap.ContextWindow != 256000 {
		t.Errorf("ContextWindow: got %d, want %d", cap.ContextWindow, 256000)
	}
	// MaxOutput from static (not overridden)
	if cap.MaxOutput != 384_000 {
		t.Errorf("MaxOutput: got %d, want %d", cap.MaxOutput, 384_000)
	}
	// Thinking from override (effort = ShapeEffort)
	if cap.Thinking != modelcapspkg.ShapeEffort {
		t.Errorf("Thinking: got %v, want %v", cap.Thinking, modelcapspkg.ShapeEffort)
	}
}

func TestResolveCapabilities_NoUser_ReturnsStatic(t *testing.T) {
	gdb, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	if err := gdb.AutoMigrate(&modeldomain.ModelCapOverride{}); err != nil {
		t.Fatalf("automigrate: %v", err)
	}

	store := modelcapoverridestore.New(gdb)
	svc := apikeyapp.NewCapabilityService(store)

	// No user in context → best-effort fallback to static
	cap := svc.ResolveCapabilities(context.Background(), "anthropic", "claude-opus-4-7")

	if cap.ContextWindow != 1_000_000 {
		t.Errorf("ContextWindow: got %d, want %d", cap.ContextWindow, 1_000_000)
	}
	if cap.Thinking != modelcapspkg.ShapeEffort {
		t.Errorf("Thinking: got %v, want %v", cap.Thinking, modelcapspkg.ShapeEffort)
	}
}

func TestSetAndClearOverride(t *testing.T) {
	gdb, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	if err := gdb.AutoMigrate(&modeldomain.ModelCapOverride{}); err != nil {
		t.Fatalf("automigrate: %v", err)
	}

	store := modelcapoverridestore.New(gdb)
	svc := apikeyapp.NewCapabilityService(store)

	ctx := reqctxpkg.SetUserID(context.Background(), "u_cap_test03")

	win := 200000
	shape := "budget"
	o := &modeldomain.ModelCapOverride{
		Provider:      "anthropic",
		ModelID:       "claude-opus-4",
		ContextWindow: &win,
		ThinkingShape: &shape,
	}
	if err := svc.SetOverride(ctx, "anthropic", "claude-opus-4", o); err != nil {
		t.Fatalf("SetOverride: %v", err)
	}

	// Verify it resolves with override
	cap := svc.ResolveCapabilities(ctx, "anthropic", "claude-opus-4")
	if cap.ContextWindow != 200000 {
		t.Errorf("ContextWindow: got %d, want %d", cap.ContextWindow, 200000)
	}
	if cap.Thinking != modelcapspkg.ShapeBudget {
		t.Errorf("Thinking: got %v, want %v", cap.Thinking, modelcapspkg.ShapeBudget)
	}

	// List overrides
	list, err := svc.ListOverrides(ctx)
	if err != nil {
		t.Fatalf("ListOverrides: %v", err)
	}
	if len(list) != 1 {
		t.Errorf("len(list): got %d, want 1", len(list))
	}

	// Clear override
	if err := svc.ClearOverride(ctx, "anthropic", "claude-opus-4"); err != nil {
		t.Fatalf("ClearOverride: %v", err)
	}

	// Should return static now
	cap2 := svc.ResolveCapabilities(ctx, "anthropic", "claude-opus-4")
	// Static cap for claude-opus-4 family is ShapeBudget/200_000; clearing override
	// means back to static — both happen to match here, but the key test is no error.
	if cap2.Thinking != modelcapspkg.ShapeBudget {
		t.Errorf("Thinking after clear: got %v, want %v", cap2.Thinking, modelcapspkg.ShapeBudget)
	}

	list2, err := svc.ListOverrides(ctx)
	if err != nil {
		t.Fatalf("ListOverrides after clear: %v", err)
	}
	if len(list2) != 0 {
		t.Errorf("len(list2): got %d, want 0", len(list2))
	}
}
