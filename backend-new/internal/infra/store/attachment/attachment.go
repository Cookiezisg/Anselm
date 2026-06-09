// Package attachment is the orm-backed attachmentdomain.Repository: the att_ metadata table.
// Workspace isolation + soft-delete are automatic (orm fills/filters from ctx). The blob bytes
// live in a separate content-addressed store (infra/fs/blob) keyed by the sha256 column here.
//
// Package attachment 是 attachmentdomain.Repository 的 orm 实现：att_ 元数据表。workspace 隔离 +
// 软删自动（orm 据 ctx 填/过滤）。blob 字节在另一个内容寻址存储（infra/fs/blob），按此处 sha256 列寻址。
package attachment

import (
	"context"
	"errors"
	"fmt"

	attachmentdomain "github.com/sunweilin/forgify/backend/internal/domain/attachment"
	ormpkg "github.com/sunweilin/forgify/backend/internal/pkg/orm"
)

// Schema is the attachments DDL (business table, soft-delete per D1). The partial index serves
// the GC keep-set query (live sha by workspace). sha256 is NOT unique — many rows may share one
// blob (content-addressed dedup at the blob layer, one row per upload).
//
// Schema 是 attachments 表 DDL（业务表，软删 D1）。partial 索引服务 GC 保留集查询（按 workspace 取
// 活跃 sha）。sha256 **不唯一**——多行可共享一个 blob（dedup 在 blob 层，每次上传一行）。
var Schema = []string{
	`CREATE TABLE IF NOT EXISTS attachments (
		id           TEXT PRIMARY KEY,
		workspace_id TEXT NOT NULL,
		sha256       TEXT NOT NULL,
		filename     TEXT NOT NULL DEFAULT '',
		mime_type    TEXT NOT NULL DEFAULT '',
		size_bytes   INTEGER NOT NULL DEFAULT 0,
		kind         TEXT NOT NULL,
		created_at   DATETIME NOT NULL,
		deleted_at   DATETIME
	)`,
	`CREATE INDEX IF NOT EXISTS idx_attachments_ws_sha ON attachments(workspace_id, sha256) WHERE deleted_at IS NULL`,
}

// Store implements attachmentdomain.Repository over pkg/orm.
//
// Store 基于 pkg/orm 实现 attachmentdomain.Repository。
type Store struct {
	repo *ormpkg.Repo[attachmentdomain.Attachment]
}

// New constructs a Store bound to the attachments table.
//
// New 构造绑定 attachments 表的 Store。
func New(db *ormpkg.DB) *Store {
	return &Store{repo: ormpkg.For[attachmentdomain.Attachment](db, "attachments")}
}

var _ attachmentdomain.Repository = (*Store)(nil)

func (s *Store) Insert(ctx context.Context, a *attachmentdomain.Attachment) error {
	if err := s.repo.Create(ctx, a); err != nil {
		return fmt.Errorf("attachmentstore.Insert: %w", err)
	}
	return nil
}

func (s *Store) Get(ctx context.Context, id string) (*attachmentdomain.Attachment, error) {
	a, err := s.repo.Get(ctx, id)
	if errors.Is(err, ormpkg.ErrNotFound) {
		return nil, attachmentdomain.ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("attachmentstore.Get: %w", err)
	}
	return a, nil
}

func (s *Store) GetBatch(ctx context.Context, ids []string) ([]*attachmentdomain.Attachment, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	rows, err := s.repo.WhereIn("id", toAny(ids)...).Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("attachmentstore.GetBatch: %w", err)
	}
	return rows, nil
}

func (s *Store) SoftDelete(ctx context.Context, id string) error {
	found, err := s.repo.Delete(ctx, id)
	if err != nil {
		return fmt.Errorf("attachmentstore.SoftDelete: %w", err)
	}
	if !found {
		return attachmentdomain.ErrNotFound
	}
	return nil
}

// ListLiveSHAs returns the distinct sha256 of every live attachment in the ctx workspace.
//
// ListLiveSHAs 返 ctx workspace 内每个活跃附件的去重 sha256。
func (s *Store) ListLiveSHAs(ctx context.Context) ([]string, error) {
	rows, err := s.repo.Query().Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("attachmentstore.ListLiveSHAs: %w", err)
	}
	seen := make(map[string]bool, len(rows))
	out := make([]string, 0, len(rows))
	for _, a := range rows {
		if !seen[a.SHA256] {
			seen[a.SHA256] = true
			out = append(out, a.SHA256)
		}
	}
	return out, nil
}

// toAny widens a []string to []any for orm WhereIn variadic args.
//
// toAny 把 []string 拓宽为 []any 以喂 orm WhereIn 变长参数。
func toAny(ss []string) []any {
	out := make([]any, len(ss))
	for i, v := range ss {
		out[i] = v
	}
	return out
}
