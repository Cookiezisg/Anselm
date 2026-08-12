package apikey

import (
	"context"
	"database/sql"
	"errors"
	"testing"
	"time"

	_ "github.com/glebarez/go-sqlite"

	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func newStore(t *testing.T) *Store {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	return New(ormpkg.Open(sqlDB))
}

func ctxWS(id string) context.Context {
	return reqctxpkg.SetWorkspaceID(context.Background(), id)
}

func seed(t *testing.T, s *Store, ctx context.Context, id, provider, name string) {
	t.Helper()
	k := &apikeydomain.APIKey{
		ID: id, Provider: provider, DisplayName: name,
		KeyEncrypted: "enc", KeyMasked: "***", TestStatus: apikeydomain.TestStatusPending,
	}
	if err := s.Save(ctx, k); err != nil {
		t.Fatalf("seed %s: %v", id, err)
	}
}

func TestStore_SaveGet_AutoStampsWorkspace(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	seed(t, s, ctx, "aki_1", "openai", "main")

	got, err := s.Get(ctx, "aki_1")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if got.WorkspaceID != "ws_1" {
		t.Errorf("workspace not auto-stamped: %q", got.WorkspaceID)
	}
	if got.Provider != "openai" || got.DisplayName != "main" {
		t.Errorf("got %+v", got)
	}
}

func TestStore_WorkspaceIsolation(t *testing.T) {
	s := newStore(t)
	seed(t, s, ctxWS("ws_1"), "aki_1", "openai", "main")
	// ws_2 must not see ws_1's key — orm auto-isolation. apikey is the first
	// workspace-scoped table to actually exercise it.
	if _, err := s.Get(ctxWS("ws_2"), "aki_1"); !errors.Is(err, apikeydomain.ErrNotFound) {
		t.Errorf("cross-workspace Get should miss, err = %v", err)
	}
}

func TestStore_DuplicateDisplayName_Conflict(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	seed(t, s, ctx, "aki_1", "openai", "dup")
	err := s.Save(ctx, &apikeydomain.APIKey{
		ID: "aki_2", Provider: "anthropic", DisplayName: "dup",
		KeyEncrypted: "e", KeyMasked: "*", TestStatus: "pending",
	})
	if !errors.Is(err, apikeydomain.ErrDisplayNameConflict) {
		t.Errorf("dup display name: err = %v, want ErrDisplayNameConflict", err)
	}
}

func TestStore_SameNameDifferentWorkspace_OK(t *testing.T) {
	s := newStore(t)
	seed(t, s, ctxWS("ws_1"), "aki_1", "openai", "main")
	// Uniqueness is per-workspace, so the same display name elsewhere is fine.
	if err := s.Save(ctxWS("ws_2"), &apikeydomain.APIKey{
		ID: "aki_2", Provider: "openai", DisplayName: "main",
		KeyEncrypted: "e", KeyMasked: "*", TestStatus: "pending",
	}); err != nil {
		t.Errorf("same name in different workspace should be allowed, got %v", err)
	}
}

func TestStore_List_ProviderFilter(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	seed(t, s, ctx, "aki_1", "openai", "a")
	seed(t, s, ctx, "aki_2", "anthropic", "b")

	rows, _, err := s.List(ctx, apikeydomain.ListFilter{Provider: "openai", Limit: 50})
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(rows) != 1 || rows[0].Provider != "openai" {
		t.Errorf("provider filter failed: %+v", rows)
	}
}

func TestStore_UpdateTestResult_StoresRawResponse(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	seed(t, s, ctx, "aki_1", "openai", "a")

	raw := `{"data":[{"id":"gpt-5"}]}`
	if err := s.UpdateTestResult(ctx, "aki_1", apikeydomain.TestStatusOK, "", raw); err != nil {
		t.Fatalf("update: %v", err)
	}
	got, _ := s.Get(ctx, "aki_1")
	if got.TestStatus != apikeydomain.TestStatusOK || got.TestResponse != raw {
		t.Errorf("probe result not persisted: status=%q response=%q", got.TestStatus, got.TestResponse)
	}
	if got.LastTestedAt == nil {
		t.Error("last_tested_at should be set")
	}
}

func TestStore_ListProbed(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	seed(t, s, ctx, "aki_1", "openai", "a")
	_ = s.UpdateTestResult(ctx, "aki_1", apikeydomain.TestStatusOK, "", `{"data":[]}`)

	probed, err := s.ListProbed(ctx)
	if err != nil {
		t.Fatalf("list probed: %v", err)
	}
	if len(probed) != 1 || probed[0].Provider != "openai" || probed[0].TestStatus != apikeydomain.TestStatusOK {
		t.Errorf("probed = %+v", probed)
	}
}

func TestStore_Delete_SoftThenMiss(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	seed(t, s, ctx, "aki_1", "openai", "a")
	if _, err := s.repo.WhereEq("id", "aki_1").Updates(ctx, map[string]any{
		"key_encrypted":  "ciphertext",
		"key_masked":     "sk-xxxx",
		"base_url":       "https://example.test/v1",
		"api_format":     "openai-compatible",
		"test_status":    "ok",
		"test_error":     "old error",
		"test_response":  `{"data":[{"id":"model"}]}`,
		"last_tested_at": time.Now().UTC(),
	}); err != nil {
		t.Fatalf("seed credential material: %v", err)
	}

	if err := s.Delete(ctx, "aki_1"); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if _, err := s.Get(ctx, "aki_1"); !errors.Is(err, apikeydomain.ErrNotFound) {
		t.Errorf("deleted should miss, err = %v", err)
	}
	if err := s.Delete(ctx, "aki_1"); !errors.Is(err, apikeydomain.ErrNotFound) {
		t.Errorf("re-delete should ErrNotFound, err = %v", err)
	}

	// The audit identity remains unscoped, but no credential/config/probe material may remain.
	// 审计身份可由 unscoped 读到，但凭证、连接配置和探测材料必须全部清空。
	got, err := s.repo.Unscoped().WhereEq("id", "aki_1").First(ctx)
	if err != nil {
		t.Fatalf("unscoped deleted row: %v", err)
	}
	if got.DeletedAt == nil {
		t.Fatal("deleted_at should be set")
	}
	if got.KeyEncrypted != "" || got.KeyMasked != "" || got.BaseURL != "" || got.APIFormat != "" ||
		got.TestStatus != "" || got.TestError != "" || got.TestResponse != "" || got.LastTestedAt != nil {
		t.Errorf("deleted api key retained material: %+v", got)
	}
}
