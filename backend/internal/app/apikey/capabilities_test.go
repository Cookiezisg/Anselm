package apikey_test

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	apikeyapp "github.com/sunweilin/forgify/backend/internal/app/apikey"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"
	modelcapoverridestore "github.com/sunweilin/forgify/backend/internal/infra/store/modelcapoverride"
	modelcapspkg "github.com/sunweilin/forgify/backend/internal/pkg/modelcaps"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

func TestResolveCapabilities_NoOverride_ReturnsStatic(t *testing.T) {
	gdb, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	require.NoError(t, err)
	require.NoError(t, gdb.AutoMigrate(&modeldomain.ModelCapOverride{}))

	store := modelcapoverridestore.New(gdb)
	svc := apikeyapp.NewCapabilityService(store)

	ctx := reqctxpkg.SetUserID(context.Background(), "u_cap_test01")

	cap := svc.ResolveCapabilities(ctx, "deepseek", "deepseek-v4")

	// Static rule for deepseek-v4: ContextWindow=1_000_000, MaxOutput=384_000, Thinking=ShapeEffort
	assert.Equal(t, 1_000_000, cap.ContextWindow)
	assert.Equal(t, 384_000, cap.MaxOutput)
	assert.Equal(t, modelcapspkg.ShapeEffort, cap.Thinking)
}

func TestResolveCapabilities_WithOverride_MergesCorrectly(t *testing.T) {
	gdb, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	require.NoError(t, err)
	require.NoError(t, gdb.AutoMigrate(&modeldomain.ModelCapOverride{}))

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
	require.NoError(t, store.Upsert(ctx, o))

	cap := svc.ResolveCapabilities(ctx, "deepseek", "deepseek-v4")

	// ContextWindow should come from override (256000, not static 1_000_000)
	assert.Equal(t, 256000, cap.ContextWindow)
	// MaxOutput from static (not overridden)
	assert.Equal(t, 384_000, cap.MaxOutput)
	// Thinking from override (effort = ShapeEffort)
	assert.Equal(t, modelcapspkg.ShapeEffort, cap.Thinking)
}

func TestResolveCapabilities_NoUser_ReturnsStatic(t *testing.T) {
	gdb, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	require.NoError(t, err)
	require.NoError(t, gdb.AutoMigrate(&modeldomain.ModelCapOverride{}))

	store := modelcapoverridestore.New(gdb)
	svc := apikeyapp.NewCapabilityService(store)

	// No user in context → best-effort fallback to static
	cap := svc.ResolveCapabilities(context.Background(), "anthropic", "claude-opus-4-7")

	assert.Equal(t, 1_000_000, cap.ContextWindow)
	assert.Equal(t, modelcapspkg.ShapeEffort, cap.Thinking)
}

func TestSetAndClearOverride(t *testing.T) {
	gdb, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	require.NoError(t, err)
	require.NoError(t, gdb.AutoMigrate(&modeldomain.ModelCapOverride{}))

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
	require.NoError(t, svc.SetOverride(ctx, "anthropic", "claude-opus-4", o))

	// Verify it resolves with override
	cap := svc.ResolveCapabilities(ctx, "anthropic", "claude-opus-4")
	assert.Equal(t, 200000, cap.ContextWindow)
	assert.Equal(t, modelcapspkg.ShapeBudget, cap.Thinking)

	// List overrides
	list, err := svc.ListOverrides(ctx)
	require.NoError(t, err)
	assert.Len(t, list, 1)

	// Clear override
	require.NoError(t, svc.ClearOverride(ctx, "anthropic", "claude-opus-4"))

	// Should return static now
	cap2 := svc.ResolveCapabilities(ctx, "anthropic", "claude-opus-4")
	// Static cap for claude-opus-4 from the catalog: 200_000 window, ShapeBudget — override deleted
	// (Static for claude-opus-4 family is actually ShapeBudget/200_000; clearing override
	// means back to static — both happen to match here, but the key test is that it doesn't error)
	assert.Equal(t, modelcapspkg.ShapeBudget, cap2.Thinking)

	list2, err := svc.ListOverrides(ctx)
	require.NoError(t, err)
	assert.Empty(t, list2)
}
