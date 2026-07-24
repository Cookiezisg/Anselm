// Package modelprofile is the SQLite repository for learned external-model
// runtime profiles. It stores only opaque route fingerprints and counters.
package modelprofile

import (
	"context"
	"errors"
	"fmt"

	profiledomain "github.com/sunweilin/anselm/backend/internal/domain/modelprofile"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

var Schema = []string{
	`CREATE TABLE IF NOT EXISTS model_runtime_profiles (
		id                        TEXT PRIMARY KEY,
		workspace_id              TEXT NOT NULL,
		identity_key              TEXT NOT NULL,
		provider                  TEXT NOT NULL,
		api_key_id                TEXT NOT NULL,
		model_id                  TEXT NOT NULL,
		request_class             TEXT NOT NULL CHECK (request_class IN ('text','multimodal')),
		endpoint_fingerprint      TEXT NOT NULL,
		credential_fingerprint    TEXT NOT NULL,
		config_fingerprint        TEXT NOT NULL,
		highest_success_predicted INTEGER NOT NULL DEFAULT 0,
		highest_success_actual    INTEGER NOT NULL DEFAULT 0,
		lowest_overflow_predicted INTEGER NOT NULL DEFAULT 0,
		successes                 INTEGER NOT NULL DEFAULT 0,
		overflows                 INTEGER NOT NULL DEFAULT 0,
		recovered_overflows       INTEGER NOT NULL DEFAULT 0,
		expires_at                DATETIME NOT NULL,
		created_at                DATETIME NOT NULL,
		updated_at                DATETIME NOT NULL
	)`,
	`CREATE UNIQUE INDEX IF NOT EXISTS idx_model_runtime_profiles_identity ON model_runtime_profiles(workspace_id, identity_key)`,
	`CREATE INDEX IF NOT EXISTS idx_model_runtime_profiles_expiry ON model_runtime_profiles(workspace_id, expires_at)`,
}

type Store struct {
	repo *ormpkg.Repo[profiledomain.Profile]
}

func New(db *ormpkg.DB) *Store {
	return &Store{repo: ormpkg.For[profiledomain.Profile](db, "model_runtime_profiles")}
}

var _ profiledomain.Repository = (*Store)(nil)

func (s *Store) Find(ctx context.Context, identityKey string) (*profiledomain.Profile, bool, error) {
	p, err := s.repo.WhereEq("identity_key", identityKey).First(ctx)
	if errors.Is(err, ormpkg.ErrNotFound) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, fmt.Errorf("modelprofilestore.Find: %w", err)
	}
	return p, true, nil
}

func (s *Store) Save(ctx context.Context, profile *profiledomain.Profile) error {
	if err := s.repo.Save(ctx, profile); err != nil {
		return fmt.Errorf("modelprofilestore.Save: %w", err)
	}
	return nil
}
