// Package cataloghistory is the GORM-backed catalogdomain.HistoryRepository (§4.7).
//
// Package cataloghistory 是 catalogdomain.HistoryRepository 的 GORM 实现(§4.7)。
package cataloghistory

import (
	"context"
	"errors"
	"fmt"

	"gorm.io/gorm"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
)

const maxHistoryRows = 50

type Store struct {
	db *gorm.DB
}

func New(db *gorm.DB) *Store { return &Store{db: db} }

var _ catalogdomain.HistoryRepository = (*Store)(nil)

func AutoMigrateModels() []interface{} {
	return []interface{}{&catalogdomain.HistoryEntry{}}
}

// Save inserts a new row, then trims to the most recent maxHistoryRows.
//
// Save 插入新行并修剪到最近 maxHistoryRows。
func (s *Store) Save(ctx context.Context, h *catalogdomain.HistoryEntry) error {
	if err := s.db.WithContext(ctx).Create(h).Error; err != nil {
		return fmt.Errorf("cataloghistory.Save: %w", err)
	}
	// Trim oldest rows beyond cap. Simple approach: count + delete extras.
	//
	// 越界删旧行:count + 一条 DELETE。
	var ids []string
	subq := s.db.WithContext(ctx).
		Model(&catalogdomain.HistoryEntry{}).
		Order("generated_at DESC, id DESC").
		Offset(maxHistoryRows).
		Pluck("id", &ids)
	if subq.Error != nil {
		return fmt.Errorf("cataloghistory.Save: pluck trim ids: %w", subq.Error)
	}
	if len(ids) > 0 {
		if err := s.db.WithContext(ctx).
			Where("id IN ?", ids).
			Delete(&catalogdomain.HistoryEntry{}).Error; err != nil {
			return fmt.Errorf("cataloghistory.Save: trim delete: %w", err)
		}
	}
	return nil
}

func (s *Store) ListRecent(ctx context.Context, limit int) ([]*catalogdomain.HistoryEntry, error) {
	if limit <= 0 || limit > maxHistoryRows {
		limit = maxHistoryRows
	}
	var rows []*catalogdomain.HistoryEntry
	if err := s.db.WithContext(ctx).
		Order("generated_at DESC, id DESC").
		Limit(limit).
		Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("cataloghistory.ListRecent: %w", err)
	}
	return rows, nil
}

func (s *Store) GetByVersion(ctx context.Context, version int) (*catalogdomain.HistoryEntry, error) {
	var h catalogdomain.HistoryEntry
	err := s.db.WithContext(ctx).Where("version = ?", version).First(&h).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, fmt.Errorf("cataloghistory.GetByVersion: version %d not found", version)
	}
	if err != nil {
		return nil, fmt.Errorf("cataloghistory.GetByVersion: %w", err)
	}
	return &h, nil
}
