// Package mcp is the orm-backed implementation of mcpdomain.Repository: one mcp_servers
// table (soft-deleted, workspace-isolated via orm ,ws tag) whose config_enc column holds
// the AES-GCM-encrypted {env, headers} blob. The store encrypts on Save / decrypts on Get
// via an internal serverRow, so the domain.Server stays pure plaintext.
//
// Package mcp 是 mcpdomain.Repository 的 orm 实现：一张 mcp_servers 表（软删、经 orm ,ws tag
// workspace 隔离），其 config_enc 列存 AES-GCM 加密的 {env, headers} blob。store 经内部 serverRow
// 在 Save 加密 / Get 解密，使 domain.Server 保持纯明文。
package mcp

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	cryptodomain "github.com/sunweilin/forgify/backend/internal/domain/crypto"
	mcpdomain "github.com/sunweilin/forgify/backend/internal/domain/mcp"
	ormpkg "github.com/sunweilin/forgify/backend/internal/pkg/orm"
)

// Schema is the mcp_servers DDL (idempotent), collected by cmd/server via db.Migrate.
// config_enc holds encrypted {env, headers}; (workspace_id, name) is unique among live rows.
//
// Schema 是 mcp_servers DDL（幂等），由 cmd/server 经 db.Migrate 汇总。config_enc 存加密的
// {env, headers}；(workspace_id, name) 在未删行中唯一。
var Schema = []string{
	`CREATE TABLE IF NOT EXISTS mcp_servers (
		id           TEXT PRIMARY KEY,
		workspace_id TEXT NOT NULL,
		name         TEXT NOT NULL,
		description  TEXT NOT NULL DEFAULT '',
		transport    TEXT NOT NULL,
		runtime      TEXT NOT NULL DEFAULT '',
		command      TEXT NOT NULL DEFAULT '',
		args         TEXT NOT NULL DEFAULT '[]',
		url          TEXT NOT NULL DEFAULT '',
		config_enc   TEXT NOT NULL DEFAULT '',
		timeout_sec  INTEGER NOT NULL DEFAULT 0,
		source       TEXT NOT NULL DEFAULT 'manual',
		registry_id  TEXT NOT NULL DEFAULT '',
		created_at   DATETIME NOT NULL,
		updated_at   DATETIME NOT NULL,
		deleted_at   DATETIME
	)`,
	`CREATE UNIQUE INDEX IF NOT EXISTS idx_mcp_ws_name ON mcp_servers(workspace_id, name) WHERE deleted_at IS NULL`,
	`CREATE INDEX IF NOT EXISTS idx_mcp_ws_created ON mcp_servers(workspace_id, created_at DESC, id DESC) WHERE deleted_at IS NULL`,
	`CREATE TABLE IF NOT EXISTS mcp_calls (
		id              TEXT PRIMARY KEY,
		workspace_id    TEXT NOT NULL,
		server_id       TEXT NOT NULL,
		tool            TEXT NOT NULL,
		status          TEXT NOT NULL CHECK (status IN ('ok','failed','cancelled','timeout')),
		triggered_by    TEXT NOT NULL CHECK (triggered_by IN ('chat','agent','workflow','manual')),
		input           TEXT NOT NULL DEFAULT 'null',
		output          TEXT NOT NULL DEFAULT '',
		error_message   TEXT NOT NULL DEFAULT '',
		elapsed_ms      INTEGER NOT NULL DEFAULT 0,
		started_at      DATETIME NOT NULL,
		ended_at        DATETIME NOT NULL,
		conversation_id TEXT NOT NULL DEFAULT '',
		message_id      TEXT NOT NULL DEFAULT '',
		tool_call_id    TEXT NOT NULL DEFAULT '',
		created_at      DATETIME NOT NULL
	)`,
	`CREATE INDEX IF NOT EXISTS idx_mcl_ws_server ON mcp_calls(workspace_id, server_id, created_at DESC, id DESC)`,
}

// serverRow is the on-disk shape; config_enc carries the encrypted {env, headers}. Env and
// Headers themselves are NOT columns — they live only inside config_enc.
//
// serverRow 是落盘形态；config_enc 载加密的 {env, headers}。Env/Headers 本身不是列——只活在
// config_enc 内。
type serverRow struct {
	ID          string     `db:"id,pk"`
	WorkspaceID string     `db:"workspace_id,ws"`
	Name        string     `db:"name"`
	Description string     `db:"description"`
	Transport   string     `db:"transport"`
	Runtime     string     `db:"runtime"`
	Command     string     `db:"command"`
	Args        []string   `db:"args,json"`
	URL         string     `db:"url"`
	ConfigEnc   string     `db:"config_enc"`
	TimeoutSec  int        `db:"timeout_sec"`
	Source      string     `db:"source"`
	RegistryID  string     `db:"registry_id"`
	CreatedAt   time.Time  `db:"created_at,created"`
	UpdatedAt   time.Time  `db:"updated_at,updated"`
	DeletedAt   *time.Time `db:"deleted_at,deleted"`
}

// configBlob is the plaintext shape encrypted into config_enc.
//
// configBlob 是加密进 config_enc 前的明文形态。
type configBlob struct {
	Env     map[string]string `json:"env,omitempty"`
	Headers map[string]string `json:"headers,omitempty"`
}

// Store implements mcpdomain.Repository over pkg/orm with config_enc encryption.
type Store struct {
	servers   *ormpkg.Repo[serverRow]
	calls     *ormpkg.Repo[mcpdomain.Call]
	encryptor cryptodomain.Encryptor
}

// New binds the store to the mcp_servers + mcp_calls tables + the encryptor used for config_enc.
func New(db *ormpkg.DB, encryptor cryptodomain.Encryptor) *Store {
	return &Store{
		servers:   ormpkg.For[serverRow](db, "mcp_servers"),
		calls:     ormpkg.For[mcpdomain.Call](db, "mcp_calls"),
		encryptor: encryptor,
	}
}

var _ mcpdomain.Repository = (*Store)(nil)

func (s *Store) Save(ctx context.Context, srv *mcpdomain.Server) error {
	row, err := s.toRow(ctx, srv)
	if err != nil {
		return err
	}
	if err := s.servers.Save(ctx, row); err != nil {
		if errors.Is(err, ormpkg.ErrConflict) {
			return mcpdomain.ErrNameConflict
		}
		return fmt.Errorf("mcpstore.Save: %w", err)
	}
	return nil
}

func (s *Store) GetByID(ctx context.Context, id string) (*mcpdomain.Server, error) {
	row, err := s.servers.Get(ctx, id)
	if errors.Is(err, ormpkg.ErrNotFound) {
		return nil, mcpdomain.ErrServerNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("mcpstore.GetByID: %w", err)
	}
	return s.fromRow(ctx, row)
}

func (s *Store) GetByName(ctx context.Context, name string) (*mcpdomain.Server, error) {
	row, err := s.servers.WhereEq("name", name).First(ctx)
	if errors.Is(err, ormpkg.ErrNotFound) {
		return nil, mcpdomain.ErrServerNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("mcpstore.GetByName: %w", err)
	}
	return s.fromRow(ctx, row)
}

func (s *Store) List(ctx context.Context) ([]*mcpdomain.Server, error) {
	rows, err := s.servers.Order("created_at DESC, id DESC").Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("mcpstore.List: %w", err)
	}
	out := make([]*mcpdomain.Server, 0, len(rows))
	for _, r := range rows {
		srv, err := s.fromRow(ctx, r)
		if err != nil {
			return nil, err
		}
		out = append(out, srv)
	}
	return out, nil
}

func (s *Store) Delete(ctx context.Context, id string) error {
	ok, err := s.servers.Delete(ctx, id) // soft-delete
	if err != nil {
		return fmt.Errorf("mcpstore.Delete: %w", err)
	}
	if !ok {
		return mcpdomain.ErrServerNotFound
	}
	return nil
}

// toRow encrypts {env, headers} into config_enc.
//
// toRow 把 {env, headers} 加密进 config_enc。
func (s *Store) toRow(ctx context.Context, srv *mcpdomain.Server) (*serverRow, error) {
	blob, err := json.Marshal(configBlob{Env: srv.Env, Headers: srv.Headers})
	if err != nil {
		return nil, fmt.Errorf("mcpstore.toRow: marshal config: %w", err)
	}
	enc, err := s.encryptor.Encrypt(ctx, blob)
	if err != nil {
		return nil, fmt.Errorf("mcpstore.toRow: encrypt: %w", err)
	}
	return &serverRow{
		ID: srv.ID, WorkspaceID: srv.WorkspaceID, Name: srv.Name, Description: srv.Description,
		Transport: srv.Transport, Runtime: srv.Runtime, Command: srv.Command, Args: srv.Args,
		URL: srv.URL, ConfigEnc: string(enc), TimeoutSec: srv.TimeoutSec,
		Source: srv.Source, RegistryID: srv.RegistryID,
		CreatedAt: srv.CreatedAt, UpdatedAt: srv.UpdatedAt,
	}, nil
}

// fromRow decrypts config_enc back into Env + Headers.
//
// fromRow 把 config_enc 解密回 Env + Headers。
func (s *Store) fromRow(ctx context.Context, r *serverRow) (*mcpdomain.Server, error) {
	srv := &mcpdomain.Server{
		ID: r.ID, WorkspaceID: r.WorkspaceID, Name: r.Name, Description: r.Description,
		Transport: r.Transport, Runtime: r.Runtime, Command: r.Command, Args: r.Args,
		URL: r.URL, TimeoutSec: r.TimeoutSec, Source: r.Source, RegistryID: r.RegistryID,
		CreatedAt: r.CreatedAt, UpdatedAt: r.UpdatedAt,
	}
	if r.ConfigEnc != "" {
		plain, err := s.encryptor.Decrypt(ctx, []byte(r.ConfigEnc))
		if err != nil {
			return nil, fmt.Errorf("mcpstore.fromRow: decrypt: %w", err)
		}
		var blob configBlob
		if err := json.Unmarshal(plain, &blob); err != nil {
			return nil, fmt.Errorf("mcpstore.fromRow: unmarshal config: %w", err)
		}
		srv.Env = blob.Env
		srv.Headers = blob.Headers
	}
	return srv, nil
}
