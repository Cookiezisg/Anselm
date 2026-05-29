// Package modelcapoverride contains store round-trip tests for ModelCapOverride.
//
// Package modelcapoverride 包含 ModelCapOverride store 的往返测试。
package modelcapoverride_test

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"
	modelcapoverridestore "github.com/sunweilin/forgify/backend/internal/infra/store/modelcapoverride"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

func TestStore_UpsertGetListDelete(t *testing.T) {
	gdb, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	require.NoError(t, err)
	require.NoError(t, gdb.AutoMigrate(&modeldomain.ModelCapOverride{}))

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
	require.NoError(t, store.Upsert(ctx, o))

	got, err := store.Get(ctx, "u_test01", "deepseek", "deepseek-v4")
	require.NoError(t, err)
	require.NotNil(t, got)
	assert.Equal(t, "mco_test0000000001", got.ID)
	assert.Equal(t, "deepseek", got.Provider)
	assert.Equal(t, "deepseek-v4", got.ModelID)
	require.NotNil(t, got.ThinkingShape)
	assert.Equal(t, "effort", *got.ThinkingShape)
	require.NotNil(t, got.ContextWindow)
	assert.Equal(t, 256000, *got.ContextWindow)
	require.NotNil(t, got.MaxOutput)
	assert.Equal(t, 16384, *got.MaxOutput)

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
	require.NoError(t, store.Upsert(ctx, o2))

	got2, err := store.Get(ctx, "u_test01", "deepseek", "deepseek-v4")
	require.NoError(t, err)
	require.NotNil(t, got2.ContextWindow)
	assert.Equal(t, 512000, *got2.ContextWindow)

	// List
	list, err := store.List(ctx, "u_test01")
	require.NoError(t, err)
	assert.Len(t, list, 1)

	// User-scoped isolation: other user sees nothing
	ctx2 := reqctxpkg.SetUserID(context.Background(), "u_test02")
	got3, err := store.Get(ctx2, "u_test02", "deepseek", "deepseek-v4")
	require.NoError(t, err)
	assert.Nil(t, got3)

	list2, err := store.List(ctx2, "u_test02")
	require.NoError(t, err)
	assert.Empty(t, list2)

	// Delete
	require.NoError(t, store.Delete(ctx, "u_test01", "deepseek", "deepseek-v4"))

	got4, err := store.Get(ctx, "u_test01", "deepseek", "deepseek-v4")
	require.NoError(t, err)
	assert.Nil(t, got4)

	// Get on missing returns nil, nil (not error)
	got5, err := store.Get(ctx, "u_test01", "anthropic", "claude-opus-4")
	require.NoError(t, err)
	assert.Nil(t, got5)
}

func TestStore_Upsert_MultipleOverrides(t *testing.T) {
	gdb, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	require.NoError(t, err)
	require.NoError(t, gdb.AutoMigrate(&modeldomain.ModelCapOverride{}))

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
		require.NoError(t, store.Upsert(ctx, o))
	}

	list, err := store.List(ctx, "u_multi")
	require.NoError(t, err)
	assert.Len(t, list, 3)
}
