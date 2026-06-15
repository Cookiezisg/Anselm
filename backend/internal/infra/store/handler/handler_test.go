package handler

import (
	"context"
	"database/sql"
	"errors"
	"testing"
	"time"

	_ "github.com/glebarez/go-sqlite"

	handlerdomain "github.com/sunweilin/foryx/backend/internal/domain/handler"
	ormpkg "github.com/sunweilin/foryx/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/foryx/backend/internal/pkg/reqctx"
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

func ctxWS(id string) context.Context { return reqctxpkg.SetWorkspaceID(context.Background(), id) }

func mkHandler(t *testing.T, s *Store, ctx context.Context, id, name, activeVer string) {
	t.Helper()
	if err := s.SaveHandler(ctx, &handlerdomain.Handler{ID: id, Name: name, ActiveVersionID: activeVer, Tags: []string{}}); err != nil {
		t.Fatalf("SaveHandler %s: %v", id, err)
	}
}

func mkVer(t *testing.T, s *Store, ctx context.Context, id, hID string, n int) {
	t.Helper()
	v := &handlerdomain.Version{
		ID: id, HandlerID: hID, Version: n,
		Methods: []handlerdomain.MethodSpec{}, InitArgsSchema: []handlerdomain.InitArgSpec{},
		Dependencies: []string{}, EnvStatus: handlerdomain.EnvStatusPending,
	}
	if err := s.SaveVersion(ctx, v); err != nil {
		t.Fatalf("SaveVersion %s: %v", id, err)
	}
}

func TestHandler_RoundTrip_WorkspaceFilled(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	mkHandler(t, s, ctx, "hd_1", "alpha", "")
	got, err := s.GetHandler(ctx, "hd_1")
	if err != nil || got.Name != "alpha" || got.WorkspaceID != "ws_1" {
		t.Fatalf("round-trip: %+v err=%v", got, err)
	}
}

func TestHandler_DuplicateName_And_Isolation(t *testing.T) {
	s := newStore(t)
	mkHandler(t, s, ctxWS("ws_1"), "hd_1", "dup", "")
	if err := s.SaveHandler(ctxWS("ws_1"), &handlerdomain.Handler{ID: "hd_2", Name: "dup", Tags: []string{}}); !errors.Is(err, handlerdomain.ErrDuplicateName) {
		t.Fatalf("want ErrDuplicateName, got %v", err)
	}
	mkHandler(t, s, ctxWS("ws_2"), "hd_3", "dup", "") // same name OK in another workspace
	if _, err := s.GetHandler(ctxWS("ws_2"), "hd_1"); !errors.Is(err, handlerdomain.ErrNotFound) {
		t.Fatalf("cross-workspace read should be NotFound, got %v", err)
	}
}

func TestHandler_ConfigEncryptedRoundTrip(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	mkHandler(t, s, ctx, "hd_1", "a", "")
	if ct, _ := s.GetConfigEncrypted(ctx, "hd_1"); ct != "" {
		t.Fatalf("fresh config should be empty, got %q", ct)
	}
	if err := s.UpdateConfigEncrypted(ctx, "hd_1", "CIPHERTEXT"); err != nil {
		t.Fatalf("update config: %v", err)
	}
	if ct, _ := s.GetConfigEncrypted(ctx, "hd_1"); ct != "CIPHERTEXT" {
		t.Fatalf("config round-trip: got %q", ct)
	}
	if err := s.ClearConfig(ctx, "hd_1"); err != nil {
		t.Fatalf("clear: %v", err)
	}
	if ct, _ := s.GetConfigEncrypted(ctx, "hd_1"); ct != "" {
		t.Fatalf("cleared config should be empty, got %q", ct)
	}
}

func TestVersion_TrimProtectsActive(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	mkHandler(t, s, ctx, "hd_1", "a", "hdv_1") // active = oldest (revert scenario)
	for i := 1; i <= 5; i++ {
		mkVer(t, s, ctx, "hdv_"+string(rune('0'+i)), "hd_1", i)
	}
	if err := s.TrimOldestVersions(ctx, "hd_1", 3); err != nil {
		t.Fatalf("trim: %v", err)
	}
	if _, err := s.GetVersion(ctx, "hdv_1"); err != nil {
		t.Fatalf("active v1 must survive trim, got %v", err)
	}
	if _, err := s.GetVersion(ctx, "hdv_2"); !errors.Is(err, handlerdomain.ErrVersionNotFound) {
		t.Fatalf("v2 should be trimmed, got %v", err)
	}
}

func TestCalls_SaveListAggregates(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	now := time.Now().UTC()
	save := func(id, status string) {
		c := &handlerdomain.Call{
			ID: id, HandlerID: "hd_1", VersionID: "hdv_1", Method: "fetch", Status: status,
			TriggeredBy: handlerdomain.TriggeredByChat, Input: map[string]any{}, StartedAt: now, EndedAt: now,
		}
		if err := s.SaveCall(ctx, c); err != nil {
			t.Fatalf("SaveCall %s: %v", id, err)
		}
	}
	save("hcl_1", handlerdomain.CallStatusOK)
	save("hcl_2", handlerdomain.CallStatusFailed)
	rows, _, err := s.ListCalls(ctx, handlerdomain.CallFilter{HandlerID: "hd_1"})
	if err != nil || len(rows) != 2 {
		t.Fatalf("list: rows=%d err=%v", len(rows), err)
	}
	agg, err := s.ComputeCallAggregates(ctx, handlerdomain.CallFilter{HandlerID: "hd_1"})
	if err != nil || agg.OKCount != 1 || agg.FailedCount != 1 {
		t.Fatalf("aggregates: %+v err=%v", agg, err)
	}
	if _, err := s.GetCallByID(ctx, "hcl_missing"); !errors.Is(err, handlerdomain.ErrCallNotFound) {
		t.Fatalf("missing call should be ErrCallNotFound, got %v", err)
	}
}

// TestCalls_LogsOnGetNotList: logs persist and return on Get; lists blank them.
//
// TestCalls_LogsOnGetNotList：logs 落盘、Get 读回；列表置空。
func TestCalls_LogsOnGetNotList(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	now := time.Now().UTC()
	c := &handlerdomain.Call{
		ID: "hcl_logs", HandlerID: "hd_1", VersionID: "hdv_1", Method: "fetch",
		Status: handlerdomain.CallStatusOK, TriggeredBy: handlerdomain.TriggeredByChat,
		Input: map[string]any{}, Logs: "yield a\nprint b\n", StartedAt: now, EndedAt: now,
	}
	if err := s.SaveCall(ctx, c); err != nil {
		t.Fatalf("SaveCall: %v", err)
	}
	one, err := s.GetCallByID(ctx, "hcl_logs")
	if err != nil || one.Logs != "yield a\nprint b\n" {
		t.Fatalf("get should carry logs: %+v err=%v", one, err)
	}
	rows, _, err := s.ListCalls(ctx, handlerdomain.CallFilter{HandlerID: "hd_1"})
	if err != nil || len(rows) == 0 {
		t.Fatalf("list: %v", err)
	}
	for _, r := range rows {
		if r.Logs != "" {
			t.Fatalf("list must blank logs, got %q on %s", r.Logs, r.ID)
		}
	}
}
