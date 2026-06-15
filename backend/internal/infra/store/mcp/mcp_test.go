package mcp

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"testing"

	_ "github.com/glebarez/go-sqlite"

	mcpdomain "github.com/sunweilin/foryx/backend/internal/domain/mcp"
	cryptoinfra "github.com/sunweilin/foryx/backend/internal/infra/crypto"
	ormpkg "github.com/sunweilin/foryx/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/foryx/backend/internal/pkg/reqctx"
)

func newStore(t *testing.T) (*Store, *sql.DB) {
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
	enc, err := cryptoinfra.NewAESGCMEncryptor(make([]byte, 32))
	if err != nil {
		t.Fatalf("encryptor: %v", err)
	}
	return New(ormpkg.Open(sqlDB), enc), sqlDB
}

func ctxWS(id string) context.Context { return reqctxpkg.SetWorkspaceID(context.Background(), id) }

func TestStore_EncryptRoundTrip(t *testing.T) {
	s, _ := newStore(t)
	ctx := ctxWS("ws_1")
	srv := &mcpdomain.Server{
		ID: "mcp_1", Name: "github", Transport: "stdio", Runtime: "node",
		Command: "npx", Args: []string{"-y", "@x/y"},
		Env: map[string]string{"GITHUB_TOKEN": "secret123"},
	}
	if err := s.Save(ctx, srv); err != nil {
		t.Fatalf("save: %v", err)
	}
	got, err := s.GetByID(ctx, "mcp_1")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if got.Env["GITHUB_TOKEN"] != "secret123" {
		t.Fatalf("env roundtrip failed: %v", got.Env)
	}
	if got.Command != "npx" || len(got.Args) != 2 || got.Runtime != "node" {
		t.Fatalf("fields lost: %+v", got)
	}
}

// TestStore_SecretEncryptedAtRest: the secret must not appear in plaintext in config_enc.
//
// TestStore_SecretEncryptedAtRest：secret 不得在 config_enc 列明文出现。
func TestStore_SecretEncryptedAtRest(t *testing.T) {
	s, db := newStore(t)
	ctx := ctxWS("ws_1")
	_ = s.Save(ctx, &mcpdomain.Server{
		ID: "mcp_1", Name: "x", Transport: "stdio",
		Env: map[string]string{"K": "secret123"},
	})
	var enc string
	if err := db.QueryRow("SELECT config_enc FROM mcp_servers WHERE id='mcp_1'").Scan(&enc); err != nil {
		t.Fatalf("query: %v", err)
	}
	if enc == "" {
		t.Fatal("config_enc empty — not encrypted")
	}
	if strings.Contains(enc, "secret123") {
		t.Fatal("secret leaked as plaintext in config_enc")
	}
}

func TestStore_RemoteHeadersRoundTrip(t *testing.T) {
	s, _ := newStore(t)
	ctx := ctxWS("ws_1")
	_ = s.Save(ctx, &mcpdomain.Server{
		ID: "mcp_r", Name: "netdata", Transport: "streamable-http",
		URL:     "https://app.netdata.cloud/api/v1/mcp",
		Headers: map[string]string{"Authorization": "Bearer tok"},
	})
	got, err := s.GetByName(ctx, "netdata")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if !got.IsRemote() || got.Headers["Authorization"] != "Bearer tok" {
		t.Fatalf("remote headers lost: %+v", got)
	}
}

func TestStore_WorkspaceIsolation(t *testing.T) {
	s, _ := newStore(t)
	_ = s.Save(ctxWS("ws_1"), &mcpdomain.Server{ID: "mcp_a", Name: "a", Transport: "stdio"})
	if _, err := s.GetByID(ctxWS("ws_2"), "mcp_a"); !errors.Is(err, mcpdomain.ErrServerNotFound) {
		t.Fatalf("cross-workspace read should be NotFound, got %v", err)
	}
}

func TestStore_NameConflict(t *testing.T) {
	s, _ := newStore(t)
	ctx := ctxWS("ws_1")
	_ = s.Save(ctx, &mcpdomain.Server{ID: "mcp_a", Name: "dup", Transport: "stdio"})
	err := s.Save(ctx, &mcpdomain.Server{ID: "mcp_b", Name: "dup", Transport: "stdio"})
	if !errors.Is(err, mcpdomain.ErrNameConflict) {
		t.Fatalf("want ErrNameConflict, got %v", err)
	}
}

func TestStore_DeleteSoft(t *testing.T) {
	s, _ := newStore(t)
	ctx := ctxWS("ws_1")
	_ = s.Save(ctx, &mcpdomain.Server{ID: "mcp_a", Name: "a", Transport: "stdio"})
	if err := s.Delete(ctx, "mcp_a"); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if _, err := s.GetByID(ctx, "mcp_a"); !errors.Is(err, mcpdomain.ErrServerNotFound) {
		t.Fatalf("deleted server should be NotFound, got %v", err)
	}
}
