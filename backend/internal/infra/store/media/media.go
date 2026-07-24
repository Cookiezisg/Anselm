// Package media is the SQLite repository for regenerable media derivatives and task-scoped
// perception evidence. The unique keys are the cache contract: concurrent duplicate requests
// converge on one pending record instead of starting duplicate processing.
package media

import (
	"context"
	"errors"
	"fmt"

	mediadomain "github.com/sunweilin/anselm/backend/internal/domain/media"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

var Schema = []string{
	`CREATE TABLE IF NOT EXISTS attachment_derivatives (
		id TEXT PRIMARY KEY, workspace_id TEXT NOT NULL, attachment_id TEXT NOT NULL,
		kind TEXT NOT NULL, source_sha256 TEXT NOT NULL, params_hash TEXT NOT NULL, params_json TEXT NOT NULL DEFAULT '',
		status TEXT NOT NULL CHECK (status IN ('pending','running','ready','failed','cancelled')),
		blob_sha256 TEXT NOT NULL DEFAULT '', mime_type TEXT NOT NULL DEFAULT '', size_bytes INTEGER NOT NULL DEFAULT 0,
		width INTEGER NOT NULL DEFAULT 0, height INTEGER NOT NULL DEFAULT 0, duration_ms INTEGER NOT NULL DEFAULT 0,
		error_code TEXT NOT NULL DEFAULT '', created_at DATETIME NOT NULL, updated_at DATETIME NOT NULL
	)`,
	`CREATE UNIQUE INDEX IF NOT EXISTS idx_attachment_derivatives_identity ON attachment_derivatives(workspace_id, attachment_id, kind, source_sha256, params_hash)`,
	`CREATE INDEX IF NOT EXISTS idx_attachment_derivatives_attachment ON attachment_derivatives(workspace_id, attachment_id, created_at DESC)`,
	`CREATE TABLE IF NOT EXISTS attachment_perceptions (
		id TEXT PRIMARY KEY, workspace_id TEXT NOT NULL, attachment_id TEXT NOT NULL,
		kind TEXT NOT NULL, source_sha256 TEXT NOT NULL, task_hash TEXT NOT NULL,
		provider TEXT NOT NULL, model TEXT NOT NULL, params_hash TEXT NOT NULL, params_json TEXT NOT NULL DEFAULT '',
		status TEXT NOT NULL CHECK (status IN ('pending','running','ready','failed','cancelled')),
		capsule_json TEXT NOT NULL DEFAULT '', input_tokens INTEGER NOT NULL DEFAULT 0, output_tokens INTEGER NOT NULL DEFAULT 0,
		error_code TEXT NOT NULL DEFAULT '', created_at DATETIME NOT NULL, updated_at DATETIME NOT NULL
	)`,
	`CREATE UNIQUE INDEX IF NOT EXISTS idx_attachment_perceptions_identity ON attachment_perceptions(workspace_id, attachment_id, kind, source_sha256, task_hash, provider, model, params_hash)`,
	`CREATE INDEX IF NOT EXISTS idx_attachment_perceptions_attachment ON attachment_perceptions(workspace_id, attachment_id, created_at DESC)`,
}

type Store struct {
	derivatives *ormpkg.Repo[mediadomain.Derivative]
	perceptions *ormpkg.Repo[mediadomain.Perception]
}

func New(db *ormpkg.DB) *Store {
	return &Store{
		derivatives: ormpkg.For[mediadomain.Derivative](db, "attachment_derivatives"),
		perceptions: ormpkg.For[mediadomain.Perception](db, "attachment_perceptions"),
	}
}

var _ mediadomain.Repository = (*Store)(nil)

func (s *Store) ClaimDerivative(ctx context.Context, want *mediadomain.Derivative) (*mediadomain.Derivative, bool, error) {
	if got, err := s.derivatives.WhereEq("attachment_id", want.AttachmentID).WhereEq("kind", want.Kind).
		WhereEq("source_sha256", want.SourceSHA256).WhereEq("params_hash", want.ParamsHash).First(ctx); err == nil {
		return got, false, nil
	} else if !errors.Is(err, ormpkg.ErrNotFound) {
		return nil, false, fmt.Errorf("mediastore.ClaimDerivative find: %w", err)
	}
	if err := s.derivatives.Create(ctx, want); err == nil {
		return want, true, nil
	} else if !errors.Is(err, ormpkg.ErrConflict) {
		return nil, false, fmt.Errorf("mediastore.ClaimDerivative create: %w", err)
	}
	got, err := s.derivatives.WhereEq("attachment_id", want.AttachmentID).WhereEq("kind", want.Kind).
		WhereEq("source_sha256", want.SourceSHA256).WhereEq("params_hash", want.ParamsHash).First(ctx)
	if err != nil {
		return nil, false, fmt.Errorf("mediastore.ClaimDerivative concurrent read: %w", err)
	}
	return got, false, nil
}

func (s *Store) ClaimPerception(ctx context.Context, want *mediadomain.Perception) (*mediadomain.Perception, bool, error) {
	query := s.perceptions.WhereEq("attachment_id", want.AttachmentID).WhereEq("kind", want.Kind).
		WhereEq("source_sha256", want.SourceSHA256).WhereEq("task_hash", want.TaskHash).WhereEq("provider", want.Provider).
		WhereEq("model", want.Model).WhereEq("params_hash", want.ParamsHash)
	if got, err := query.First(ctx); err == nil {
		return got, false, nil
	} else if !errors.Is(err, ormpkg.ErrNotFound) {
		return nil, false, fmt.Errorf("mediastore.ClaimPerception find: %w", err)
	}
	if err := s.perceptions.Create(ctx, want); err == nil {
		return want, true, nil
	} else if !errors.Is(err, ormpkg.ErrConflict) {
		return nil, false, fmt.Errorf("mediastore.ClaimPerception create: %w", err)
	}
	got, err := s.perceptions.WhereEq("attachment_id", want.AttachmentID).WhereEq("kind", want.Kind).
		WhereEq("source_sha256", want.SourceSHA256).WhereEq("task_hash", want.TaskHash).WhereEq("provider", want.Provider).
		WhereEq("model", want.Model).WhereEq("params_hash", want.ParamsHash).First(ctx)
	if err != nil {
		return nil, false, fmt.Errorf("mediastore.ClaimPerception concurrent read: %w", err)
	}
	return got, false, nil
}

func (s *Store) GetDerivative(ctx context.Context, id string) (*mediadomain.Derivative, error) {
	row, err := s.derivatives.Get(ctx, id)
	if err != nil {
		if errors.Is(err, ormpkg.ErrNotFound) {
			return nil, mediadomain.ErrNotFound
		}
		return nil, fmt.Errorf("mediastore.GetDerivative: %w", err)
	}
	return row, nil
}

func (s *Store) GetPerception(ctx context.Context, id string) (*mediadomain.Perception, error) {
	row, err := s.perceptions.Get(ctx, id)
	if err != nil {
		if errors.Is(err, ormpkg.ErrNotFound) {
			return nil, mediadomain.ErrNotFound
		}
		return nil, fmt.Errorf("mediastore.GetPerception: %w", err)
	}
	return row, nil
}

func (s *Store) SaveDerivative(ctx context.Context, derivative *mediadomain.Derivative) error {
	if !mediadomain.ValidStatus(derivative.Status) {
		return mediadomain.ErrInvalidRequest
	}
	if err := s.derivatives.Save(ctx, derivative); err != nil {
		return fmt.Errorf("mediastore.SaveDerivative: %w", err)
	}
	return nil
}

func (s *Store) SavePerception(ctx context.Context, perception *mediadomain.Perception) error {
	if !mediadomain.ValidStatus(perception.Status) {
		return mediadomain.ErrInvalidRequest
	}
	if err := s.perceptions.Save(ctx, perception); err != nil {
		return fmt.Errorf("mediastore.SavePerception: %w", err)
	}
	return nil
}

func (s *Store) ListPendingDerivatives(ctx context.Context, limit int) ([]*mediadomain.Derivative, error) {
	if limit <= 0 {
		limit = 100
	}
	rows, err := s.derivatives.WhereEq("status", mediadomain.StatusPending).Order("created_at ASC").Limit(limit).Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("mediastore.ListPendingDerivatives: %w", err)
	}
	return rows, nil
}

func (s *Store) ListPendingPerceptions(ctx context.Context, limit int) ([]*mediadomain.Perception, error) {
	if limit <= 0 {
		limit = 100
	}
	rows, err := s.perceptions.WhereEq("status", mediadomain.StatusPending).Order("created_at ASC").Limit(limit).Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("mediastore.ListPendingPerceptions: %w", err)
	}
	return rows, nil
}

// RequeueRunning is the crash-recovery half of media processing. A running row can only survive a
// process death because graceful workers terminalise their work; at the next boot it is safe to
// return it to pending and retry from the immutable original.
func (s *Store) RequeueRunning(ctx context.Context) (int, error) {
	n, err := s.derivatives.WhereEq("status", mediadomain.StatusRunning).Update(ctx, "status", mediadomain.StatusPending)
	if err != nil {
		return 0, fmt.Errorf("mediastore.RequeueRunning derivatives: %w", err)
	}
	m, err := s.perceptions.WhereEq("status", mediadomain.StatusRunning).Update(ctx, "status", mediadomain.StatusPending)
	if err != nil {
		return 0, fmt.Errorf("mediastore.RequeueRunning perceptions: %w", err)
	}
	return int(n + m), nil
}

func (s *Store) ListReadyDerivativeBlobs(ctx context.Context) ([]string, error) {
	rows, err := s.derivatives.WhereEq("status", mediadomain.StatusReady).Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("mediastore.ListReadyDerivativeBlobs: %w", err)
	}
	seen := make(map[string]bool, len(rows))
	out := make([]string, 0, len(rows))
	for _, row := range rows {
		if row.BlobSHA256 != "" && !seen[row.BlobSHA256] {
			seen[row.BlobSHA256] = true
			out = append(out, row.BlobSHA256)
		}
	}
	return out, nil
}

func (s *Store) ListReadyDerivatives(ctx context.Context) ([]*mediadomain.Derivative, error) {
	rows, err := s.derivatives.WhereEq("status", mediadomain.StatusReady).Order("updated_at ASC").Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("mediastore.ListReadyDerivatives: %w", err)
	}
	return rows, nil
}
