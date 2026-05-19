// Package mcphealth is the GORM-backed mcpdomain.HealthHistoryRepository.
//
// Package mcphealth 是 mcpdomain.HealthHistoryRepository 的 GORM 实现。
package mcphealth

import (
	"context"
	"fmt"
	"time"

	"gorm.io/gorm"

	mcpdomain "github.com/sunweilin/forgify/backend/internal/domain/mcp"
)

type Store struct {
	db *gorm.DB
}

func New(db *gorm.DB) *Store { return &Store{db: db} }

func (s *Store) Insert(ctx context.Context, snap *mcpdomain.HealthSnapshot) error {
	if err := s.db.WithContext(ctx).Create(snap).Error; err != nil {
		return fmt.Errorf("mcphealthstore.Insert: %w", err)
	}
	return nil
}

func (s *Store) ListSince(ctx context.Context, userID, serverName string, since time.Time) ([]*mcpdomain.HealthSnapshot, error) {
	var rows []*mcpdomain.HealthSnapshot
	err := s.db.WithContext(ctx).
		Where("user_id = ? AND server_name = ? AND checked_at >= ?", userID, serverName, since).
		Order("checked_at DESC").
		Find(&rows).Error
	if err != nil {
		return nil, fmt.Errorf("mcphealthstore.ListSince: %w", err)
	}
	return rows, nil
}
