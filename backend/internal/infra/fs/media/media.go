// Package media stores regenerable derivative bytes outside the original attachment CAS. Keeping
// this tree separate is deliberate: attachment GC owns user originals, while media GC may reclaim
// any proxy safely without risking an original or the inverse.
package media

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

type Store struct{ base string }

func New(base string) *Store { return &Store{base: base} }

func (s *Store) dir(ctx context.Context) (string, error) {
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return "", err
	}
	return filepath.Join(s.base, "workspaces", wsID, "media"), nil
}

// Put hashes and atomically persists one regenerated artifact. The return hash is its only
// durable file reference; identical derivatives share bytes but never cross a workspace boundary.
func (s *Store) Put(ctx context.Context, data []byte) (string, error) {
	sum := sha256.Sum256(data)
	sha := hex.EncodeToString(sum[:])
	dir, err := s.dir(ctx)
	if err != nil {
		return "", err
	}
	shard := filepath.Join(dir, sha[:2])
	p := filepath.Join(shard, sha)
	if _, err := os.Stat(p); err == nil {
		return sha, nil
	} else if !errors.Is(err, os.ErrNotExist) {
		return "", fmt.Errorf("mediafs.Put stat: %w", err)
	}
	if err := os.MkdirAll(shard, 0o755); err != nil {
		return "", fmt.Errorf("mediafs.Put mkdir: %w", err)
	}
	tmp := p + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return "", fmt.Errorf("mediafs.Put write: %w", err)
	}
	if err := os.Rename(tmp, p); err != nil {
		_ = os.Remove(tmp)
		return "", fmt.Errorf("mediafs.Put rename: %w", err)
	}
	return sha, nil
}

func (s *Store) Get(ctx context.Context, sha string) ([]byte, error) {
	if !validSHA(sha) {
		return nil, fmt.Errorf("mediafs.Get: invalid sha256")
	}
	dir, err := s.dir(ctx)
	if err != nil {
		return nil, err
	}
	b, err := os.ReadFile(filepath.Join(dir, sha[:2], sha))
	if err != nil {
		return nil, fmt.Errorf("mediafs.Get: %w", err)
	}
	return b, nil
}

// Sweep reclaims only derived bytes absent from the durable ready-record keep set. Stale temp
// files from a killed processor are reclaimed as well.
func (s *Store) Sweep(ctx context.Context, keep map[string]bool) (int, error) {
	dir, err := s.dir(ctx)
	if err != nil {
		return 0, err
	}
	shards, err := os.ReadDir(dir)
	if errors.Is(err, os.ErrNotExist) {
		return 0, nil
	}
	if err != nil {
		return 0, fmt.Errorf("mediafs.Sweep: %w", err)
	}
	removed := 0
	for _, shard := range shards {
		if !shard.IsDir() {
			continue
		}
		entries, err := os.ReadDir(filepath.Join(dir, shard.Name()))
		if err != nil {
			continue
		}
		for _, entry := range entries {
			name := entry.Name()
			path := filepath.Join(dir, shard.Name(), name)
			if strings.HasSuffix(name, ".tmp") || !keep[name] {
				if err := os.Remove(path); err == nil && !strings.HasSuffix(name, ".tmp") {
					removed++
				}
			}
		}
	}
	return removed, nil
}

func validSHA(sha string) bool {
	if len(sha) != 64 {
		return false
	}
	for _, c := range sha {
		if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')) {
			return false
		}
	}
	return true
}
