// Package modelcapoverride is the GORM-backed CapOverrideRepository for domain model.
//
// Package modelcapoverride 是 domain model.CapOverrideRepository 的 GORM 实现。
package modelcapoverride

import (
	"context"
	"errors"
	"fmt"

	"gorm.io/gorm"

	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
)

// Store is the GORM implementation of CapOverrideRepository.
//
// Store 是 CapOverrideRepository 的 GORM 实现。
type Store struct {
	db *gorm.DB
}

// New constructs a Store bound to the given *gorm.DB.
//
// New 基于给定 *gorm.DB 构造 Store。
func New(db *gorm.DB) *Store {
	return &Store{db: db}
}

// Upsert inserts or replaces by (userID, provider, modelID). GORM Save covers
// both insert and full-row update on primary-key match.
//
// Upsert 按 (userID, provider, modelID) 插入或整行替换，GORM Save 统一处理。
func (s *Store) Upsert(ctx context.Context, o *modeldomain.ModelCapOverride) error {
	if err := s.db.WithContext(ctx).Save(o).Error; err != nil {
		return fmt.Errorf("modelcapoverridestore.Upsert: %w", err)
	}
	return nil
}

// Get returns nil, nil when no live row matches the (userID, provider, modelID) triple.
//
// Get 在三元组无活跃记录时返回 nil, nil。
func (s *Store) Get(ctx context.Context, userID, provider, modelID string) (*modeldomain.ModelCapOverride, error) {
	var o modeldomain.ModelCapOverride
	err := s.db.WithContext(ctx).
		Where("user_id = ? AND provider = ? AND model_id = ?", userID, provider, modelID).
		First(&o).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("modelcapoverridestore.Get: %w", err)
	}
	return &o, nil
}

// List returns all active overrides for the given user.
//
// List 返回给定用户的所有活跃覆盖。
func (s *Store) List(ctx context.Context, userID string) ([]*modeldomain.ModelCapOverride, error) {
	var rows []*modeldomain.ModelCapOverride
	if err := s.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("modelcapoverridestore.List: %w", err)
	}
	return rows, nil
}

// Delete soft-deletes by (userID, provider, modelID); silently no-ops if absent
// because a redundant delete is harmless in this domain.
//
// Delete 按 (userID, provider, modelID) 软删；不存在时静默无操作（重复删除无害）。
func (s *Store) Delete(ctx context.Context, userID, provider, modelID string) error {
	if err := s.db.WithContext(ctx).
		Where("user_id = ? AND provider = ? AND model_id = ?", userID, provider, modelID).
		Delete(&modeldomain.ModelCapOverride{}).Error; err != nil {
		return fmt.Errorf("modelcapoverridestore.Delete: %w", err)
	}
	return nil
}
