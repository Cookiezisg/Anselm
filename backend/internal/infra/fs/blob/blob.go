// Package blob is a content-addressed (SHA-256) blob store on the local filesystem: an
// attachment's bytes live at <base>/workspaces/<wsID>/blobs/<sha[:2]>/<sha>, keyed by content
// hash so identical uploads dedupe to one file. Workspace id comes from ctx (one tree per
// workspace = isolation), the same seam the file-backed memory / skill stores use. Bytes never
// enter SQLite — attachment.Repository holds only metadata pointing here by sha.
//
// Package blob 是本地文件系统上内容寻址（SHA-256）的 blob 存储：附件字节在
// <base>/workspaces/<wsID>/blobs/<sha[:2]>/<sha>，按内容哈希寻址，相同上传 dedup 成一份。
// workspace id 取自 ctx（每 workspace 一棵树 = 隔离），与文件式 memory / skill store 同一条缝。
// 字节绝不进 SQLite——attachment.Repository 只存按 sha 指过来的元数据。
package blob

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// Store is the file-backed CAS blob store. base is the ~/.forgify root (injected at boot, M7;
// a temp dir in tests); each workspace's blobs dir lives under it.
//
// Store 是文件式 CAS blob 存储。base 是 ~/.forgify 根（boot 装配 M7；测试用 temp）；各 workspace
// 的 blobs 目录在其下。
type Store struct {
	base string
}

// New builds a Store rooted at base.
//
// New 构造以 base 为根的 Store。
func New(base string) *Store { return &Store{base: base} }

func (s *Store) dir(ctx context.Context) (string, error) {
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return "", err
	}
	return filepath.Join(s.base, "workspaces", wsID, "blobs"), nil
}

// path returns (shardDir, blobPath) for a sha; rejects a non-hex sha (defense against traversal,
// since the sha is part of the on-disk path).
//
// path 返回某 sha 的 (分片目录, blob 路径)；拒绝非 hex 的 sha（防穿越，sha 进入磁盘路径）。
func (s *Store) path(ctx context.Context, sha string) (shardDir, blobPath string, err error) {
	if !isSHA256Hex(sha) {
		return "", "", fmt.Errorf("blob: invalid sha256 %q", sha)
	}
	dir, err := s.dir(ctx)
	if err != nil {
		return "", "", err
	}
	shardDir = filepath.Join(dir, sha[:2])
	return shardDir, filepath.Join(shardDir, sha), nil
}

// Put writes data under its sha atomically (temp + rename); a no-op if the blob already exists
// (content-addressed dedup — the same bytes hash to the same path).
//
// Put 把 data 按其 sha 原子写入（temp + rename）；blob 已存在则 no-op（内容寻址 dedup——相同字节
// 哈希到同一路径）。
func (s *Store) Put(ctx context.Context, sha string, data []byte) error {
	shardDir, p, err := s.path(ctx, sha)
	if err != nil {
		return err
	}
	if _, statErr := os.Stat(p); statErr == nil {
		return nil // dedup: already stored
	}
	if err := os.MkdirAll(shardDir, 0o755); err != nil {
		return fmt.Errorf("blob.Put mkdir: %w", err)
	}
	tmp := p + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return fmt.Errorf("blob.Put write: %w", err)
	}
	if err := os.Rename(tmp, p); err != nil {
		_ = os.Remove(tmp)
		return fmt.Errorf("blob.Put rename: %w", err)
	}
	return nil
}

// Get reads a blob by sha; wraps os.ErrNotExist when absent (an integrity gap — a row points at
// a blob that was GC'd or never written).
//
// Get 按 sha 读 blob；不存在时包 os.ErrNotExist（完整性缺口——行指向被 GC 或从未写入的 blob）。
func (s *Store) Get(ctx context.Context, sha string) ([]byte, error) {
	_, p, err := s.path(ctx, sha)
	if err != nil {
		return nil, err
	}
	data, err := os.ReadFile(p)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("blob.Get %s: %w", sha, os.ErrNotExist)
		}
		return nil, fmt.Errorf("blob.Get: %w", err)
	}
	return data, nil
}

// Exists reports whether a blob is stored.
//
// Exists 报告 blob 是否已存。
func (s *Store) Exists(ctx context.Context, sha string) (bool, error) {
	_, p, err := s.path(ctx, sha)
	if err != nil {
		return false, err
	}
	if _, statErr := os.Stat(p); statErr == nil {
		return true, nil
	} else if os.IsNotExist(statErr) {
		return false, nil
	} else {
		return false, statErr
	}
}

// Sweep removes every blob in the ctx workspace whose sha is not in keep (orphan GC), plus any
// stale .tmp files. A missing blobs dir (brand-new workspace) is a no-op. Returns the count removed.
//
// Sweep 删除 ctx workspace 内 sha 不在 keep 中的所有 blob（孤儿 GC），并清残留 .tmp。blobs 目录
// 不存在（全新 workspace）= no-op。返回删除数。
func (s *Store) Sweep(ctx context.Context, keep map[string]bool) (int, error) {
	dir, err := s.dir(ctx)
	if err != nil {
		return 0, err
	}
	shards, err := os.ReadDir(dir)
	if os.IsNotExist(err) {
		return 0, nil
	}
	if err != nil {
		return 0, fmt.Errorf("blob.Sweep: %w", err)
	}
	removed := 0
	for _, shard := range shards {
		if !shard.IsDir() {
			continue
		}
		shardPath := filepath.Join(dir, shard.Name())
		entries, err := os.ReadDir(shardPath)
		if err != nil {
			continue
		}
		for _, e := range entries {
			name := e.Name()
			if strings.HasSuffix(name, ".tmp") {
				_ = os.Remove(filepath.Join(shardPath, name)) // stale temp from a crashed write
				continue
			}
			if !keep[name] {
				if err := os.Remove(filepath.Join(shardPath, name)); err == nil {
					removed++
				}
			}
		}
	}
	return removed, nil
}

// isSHA256Hex reports whether s is exactly 64 lowercase hex chars.
//
// isSHA256Hex 报告 s 是否恰为 64 个小写 hex 字符。
func isSHA256Hex(s string) bool {
	if len(s) != 64 {
		return false
	}
	for i := 0; i < len(s); i++ {
		c := s[i]
		if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')) {
			return false
		}
	}
	return true
}
