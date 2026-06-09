// Package attachment owns the Service for uploaded files: hash → content-addressed blob store +
// metadata row, download, soft-delete, and orphan-blob GC. The bytes live in a BlobStore (a port,
// implemented by infra/fs/blob); the metadata lives in attachmentdomain.Repository. Workspace
// isolation is automatic at both layers (orm + blob both key off ctx). LLM injection (turning an
// attachment into a provider content part) is R0052 — this layer only stores and serves bytes.
//
// Package attachment 持有上传文件的 Service：哈希 → 内容寻址 blob 存储 + 元数据行、下载、软删、
// 孤儿 blob GC。字节在 BlobStore（端口，infra/fs/blob 实现）；元数据在 attachmentdomain.Repository。
// workspace 隔离两层都自动（orm + blob 都据 ctx）。LLM 注入（把附件变成 provider content part）是
// R0052——本层只存与取字节。
package attachment

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"path/filepath"

	"go.uber.org/zap"

	attachmentdomain "github.com/sunweilin/forgify/backend/internal/domain/attachment"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
)

// BlobStore is the content-addressed byte store (port; infra/fs/blob implements it). Put is a
// no-op when the sha already exists (dedup); Sweep is orphan GC against a keep-set.
//
// BlobStore 是内容寻址字节存储（端口；infra/fs/blob 实现）。sha 已存在时 Put 为 no-op（dedup）；
// Sweep 按保留集做孤儿 GC。
type BlobStore interface {
	Put(ctx context.Context, sha string, data []byte) error
	Get(ctx context.Context, sha string) ([]byte, error)
	Exists(ctx context.Context, sha string) (bool, error)
	Sweep(ctx context.Context, keep map[string]bool) (int, error)
}

// Service is the attachment application façade.
//
// Service 是附件应用 façade。
type Service struct {
	repo  attachmentdomain.Repository
	blobs BlobStore
	log   *zap.Logger
}

// New constructs a Service; panics on nil logger, repo, or blobs (all required).
//
// New 构造 Service；nil logger/repo/blobs panic（皆必需）。
func New(repo attachmentdomain.Repository, blobs BlobStore, log *zap.Logger) *Service {
	if log == nil {
		panic("attachmentapp.New: nil logger")
	}
	if repo == nil || blobs == nil {
		panic("attachmentapp.New: repo and blobs are required")
	}
	return &Service{repo: repo, blobs: blobs, log: log}
}

// Upload validates size, hashes the bytes, stores the blob (dedup), and inserts the metadata row.
// The blob is written before the row so a row never points at a missing blob.
//
// Upload 校验大小、哈希字节、存 blob（dedup）、插元数据行。blob 先于行写入，故行绝不指向缺失 blob。
func (s *Service) Upload(ctx context.Context, filename, mime string, data []byte) (*attachmentdomain.Attachment, error) {
	if len(data) == 0 {
		return nil, attachmentdomain.ErrEmpty
	}
	if int64(len(data)) > attachmentdomain.MaxBytes {
		return nil, attachmentdomain.ErrTooLarge
	}
	sum := sha256.Sum256(data)
	sha := hex.EncodeToString(sum[:])
	if err := s.blobs.Put(ctx, sha, data); err != nil {
		return nil, fmt.Errorf("attachmentapp.Upload: blob: %w", err)
	}
	a := &attachmentdomain.Attachment{
		ID:        idgenpkg.New("att"),
		SHA256:    sha,
		Filename:  filepath.Base(filename), // display only; blob is keyed by sha, not name
		MimeType:  mime,
		SizeBytes: int64(len(data)),
		Kind:      attachmentdomain.KindFromMIME(mime, filename),
	}
	if err := s.repo.Insert(ctx, a); err != nil {
		return nil, err
	}
	return a, nil
}

// Get fetches one attachment's metadata.
//
// Get 取一个附件的元数据。
func (s *Service) Get(ctx context.Context, id string) (*attachmentdomain.Attachment, error) {
	return s.repo.Get(ctx, id)
}

// Download returns an attachment's metadata + its blob bytes.
//
// Download 返回附件元数据 + 其 blob 字节。
func (s *Service) Download(ctx context.Context, id string) (*attachmentdomain.Attachment, []byte, error) {
	a, err := s.repo.Get(ctx, id)
	if err != nil {
		return nil, nil, err
	}
	data, err := s.blobs.Get(ctx, a.SHA256)
	if err != nil {
		return nil, nil, fmt.Errorf("attachmentapp.Download: %w", err)
	}
	return a, data, nil
}

// Delete soft-deletes the metadata row; the blob is reclaimed later by GC if no live row
// references its sha (another attachment may share it).
//
// Delete 软删元数据行；若无活跃行引用其 sha（另一附件可能共享），blob 稍后由 GC 回收。
func (s *Service) Delete(ctx context.Context, id string) error {
	return s.repo.SoftDelete(ctx, id)
}

// GC sweeps orphan blobs in the ctx workspace: blobs whose sha is referenced by no live row.
//
// GC 清 ctx workspace 的孤儿 blob：sha 无活跃行引用的 blob。
func (s *Service) GC(ctx context.Context) (int, error) {
	shas, err := s.repo.ListLiveSHAs(ctx)
	if err != nil {
		return 0, err
	}
	keep := make(map[string]bool, len(shas))
	for _, sha := range shas {
		keep[sha] = true
	}
	return s.blobs.Sweep(ctx, keep)
}
