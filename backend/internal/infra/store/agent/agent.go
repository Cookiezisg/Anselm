// Package agent is the GORM-backed store for the Agent domain (quadrinity 4th entity).
//
// Package agent 是 Agent domain 的 GORM store（quadrinity 第四元）。
package agent

import (
	"context"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"

	agentdomain "github.com/sunweilin/forgify/backend/internal/domain/agent"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

type Store struct {
	db *gorm.DB
}

func New(db *gorm.DB) *Store { return &Store{db: db} }

// AutoMigrateModels returns all agent models for registration in db.AutoMigrate.
func AutoMigrateModels() []interface{} {
	return []interface{}{
		&agentdomain.Agent{},
		&agentdomain.AgentVersion{},
		&agentdomain.AgentExecution{},
	}
}

func (s *Store) Create(ctx context.Context, a *agentdomain.Agent) error {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return err
	}
	if a.ID == "" {
		a.ID = idgenpkg.New("ag")
	}
	a.UserID = uid
	if err := s.db.WithContext(ctx).Create(a).Error; err != nil {
		if isUniqueViolation(err) {
			return agentdomain.ErrNameDuplicate
		}
		return fmt.Errorf("agentstore.Create: %w", err)
	}
	return nil
}

func (s *Store) Get(ctx context.Context, id string) (*agentdomain.Agent, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	var a agentdomain.Agent
	if err := s.db.WithContext(ctx).
		Where("id = ? AND user_id = ?", id, uid).First(&a).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, agentdomain.ErrNotFound
		}
		return nil, fmt.Errorf("agentstore.Get: %w", err)
	}
	return &a, nil
}

func (s *Store) GetByName(ctx context.Context, name string) (*agentdomain.Agent, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	var a agentdomain.Agent
	if err := s.db.WithContext(ctx).
		Where("name = ? AND user_id = ?", name, uid).First(&a).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, agentdomain.ErrNotFound
		}
		return nil, fmt.Errorf("agentstore.GetByName: %w", err)
	}
	return &a, nil
}

func (s *Store) List(ctx context.Context, userID string, limit int, cursor string) ([]*agentdomain.Agent, string, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	q := s.db.WithContext(ctx).Where("user_id = ?", userID).Order("name asc").Limit(limit + 1)
	if cursor != "" {
		q = q.Where("name > ?", cursor)
	}
	var rows []*agentdomain.Agent
	if err := q.Find(&rows).Error; err != nil {
		return nil, "", fmt.Errorf("agentstore.List: %w", err)
	}
	var next string
	if len(rows) > limit {
		next = rows[limit].Name
		rows = rows[:limit]
	}
	return rows, next, nil
}

func (s *Store) Update(ctx context.Context, a *agentdomain.Agent) error {
	if err := s.db.WithContext(ctx).Save(a).Error; err != nil {
		return fmt.Errorf("agentstore.Update: %w", err)
	}
	return nil
}

func (s *Store) SoftDelete(ctx context.Context, id string) error {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return err
	}
	if err := s.db.WithContext(ctx).
		Where("id = ? AND user_id = ?", id, uid).
		Delete(&agentdomain.Agent{}).Error; err != nil {
		return fmt.Errorf("agentstore.SoftDelete: %w", err)
	}
	return nil
}

func (s *Store) CreateVersion(ctx context.Context, v *agentdomain.AgentVersion) error {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return err
	}
	if v.ID == "" {
		v.ID = idgenpkg.New("agv")
	}
	v.UserID = uid
	if v.Status == "" {
		v.Status = agentdomain.VersionStatusPending
	}
	if err := s.db.WithContext(ctx).Create(v).Error; err != nil {
		return fmt.Errorf("agentstore.CreateVersion: %w", err)
	}
	return nil
}

func (s *Store) GetVersion(ctx context.Context, versionID string) (*agentdomain.AgentVersion, error) {
	var v agentdomain.AgentVersion
	if err := s.db.WithContext(ctx).Where("id = ?", versionID).First(&v).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, agentdomain.ErrNotFound
		}
		return nil, fmt.Errorf("agentstore.GetVersion: %w", err)
	}
	return &v, nil
}

func (s *Store) GetPending(ctx context.Context, agentID string) (*agentdomain.AgentVersion, error) {
	var v agentdomain.AgentVersion
	if err := s.db.WithContext(ctx).
		Where("agent_id = ? AND status = ?", agentID, agentdomain.VersionStatusPending).
		Order("created_at desc").First(&v).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, agentdomain.ErrNoPending
		}
		return nil, fmt.Errorf("agentstore.GetPending: %w", err)
	}
	return &v, nil
}

func (s *Store) ListVersions(ctx context.Context, agentID string) ([]*agentdomain.AgentVersion, error) {
	var rows []*agentdomain.AgentVersion
	if err := s.db.WithContext(ctx).
		Where("agent_id = ?", agentID).
		Order("created_at desc").Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("agentstore.ListVersions: %w", err)
	}
	return rows, nil
}

func (s *Store) AcceptVersion(ctx context.Context, agentID, versionID string) error {
	now := time.Now().UTC()
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// Flip version to accepted.
		// Get next version number.
		var maxV int
		tx.Model(&agentdomain.AgentVersion{}).
			Where("agent_id = ? AND status = ?", agentID, agentdomain.VersionStatusAccepted).
			Select("COALESCE(MAX(version), 0)").Scan(&maxV)
		nextV := maxV + 1
		if err := tx.Model(&agentdomain.AgentVersion{}).
			Where("id = ?", versionID).
			Updates(map[string]any{
				"status":      agentdomain.VersionStatusAccepted,
				"accepted_at": now,
				"version":     nextV,
			}).Error; err != nil {
			return fmt.Errorf("agentstore.AcceptVersion: flip version: %w", err)
		}
		// Update agent.active_version_id.
		if err := tx.Model(&agentdomain.Agent{}).
			Where("id = ?", agentID).
			Update("active_version_id", versionID).Error; err != nil {
			return fmt.Errorf("agentstore.AcceptVersion: update agent: %w", err)
		}
		return nil
	})
}

func (s *Store) SetNeedsAttention(ctx context.Context, agentID string, val bool) error {
	if err := s.db.WithContext(ctx).
		Model(&agentdomain.Agent{}).
		Where("id = ?", agentID).
		Update("needs_attention", val).Error; err != nil {
		return fmt.Errorf("agentstore.SetNeedsAttention: %w", err)
	}
	return nil
}

func (s *Store) CreateExecution(ctx context.Context, ex *agentdomain.AgentExecution) error {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return err
	}
	if ex.ID == "" {
		ex.ID = idgenpkg.New("agx")
	}
	ex.UserID = uid
	if err := s.db.WithContext(ctx).Create(ex).Error; err != nil {
		return fmt.Errorf("agentstore.CreateExecution: %w", err)
	}
	return nil
}

func (s *Store) GetExecution(ctx context.Context, id string) (*agentdomain.AgentExecution, error) {
	var ex agentdomain.AgentExecution
	if err := s.db.WithContext(ctx).Where("id = ?", id).First(&ex).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, agentdomain.ErrNotFound
		}
		return nil, fmt.Errorf("agentstore.GetExecution: %w", err)
	}
	return &ex, nil
}

func (s *Store) ListExecutions(ctx context.Context, agentID string, limit int, cursor string) ([]*agentdomain.AgentExecution, string, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	q := s.db.WithContext(ctx).Where("agent_id = ?", agentID).Order("started_at desc").Limit(limit + 1)
	if cursor != "" {
		q = q.Where("id < ?", cursor)
	}
	var rows []*agentdomain.AgentExecution
	if err := q.Find(&rows).Error; err != nil {
		return nil, "", fmt.Errorf("agentstore.ListExecutions: %w", err)
	}
	var next string
	if len(rows) > limit {
		next = rows[limit].ID
		rows = rows[:limit]
	}
	return rows, next, nil
}

func (s *Store) UpdateExecution(ctx context.Context, ex *agentdomain.AgentExecution) error {
	if err := s.db.WithContext(ctx).Save(ex).Error; err != nil {
		return fmt.Errorf("agentstore.UpdateExecution: %w", err)
	}
	return nil
}

func isUniqueViolation(err error) bool {
	return err != nil && strings.Contains(err.Error(), "UNIQUE constraint failed")
}
