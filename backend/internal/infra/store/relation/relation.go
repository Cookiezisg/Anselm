// Package relation is the GORM-backed relationdomain.Repository implementation.
//
// Package relation 是 relationdomain.Repository 的 GORM 实现。
package relation

import (
	"context"
	"encoding/json"
	"fmt"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	relationdomain "github.com/sunweilin/forgify/backend/internal/domain/relation"
	paginationpkg "github.com/sunweilin/forgify/backend/internal/pkg/pagination"
)

// Store is the GORM implementation of relationdomain.Repository.
//
// Store 是 relationdomain.Repository 的 GORM 实现。
type Store struct {
	db *gorm.DB
}

// New constructs a Store bound to the given *gorm.DB.
//
// New 基于给定 *gorm.DB 构造 Store。
func New(db *gorm.DB) *Store {
	return &Store{db: db}
}

// Insert adds a single relation; conflict on uq_rel returns the GORM error wrapped.
//
// Insert 插入单条 relation；uq_rel 冲突时返包装后的 GORM 错。
func (s *Store) Insert(ctx context.Context, r *relationdomain.Relation) error {
	if err := s.db.WithContext(ctx).Create(r).Error; err != nil {
		return fmt.Errorf("relationstore.Insert: %w", err)
	}
	return nil
}

// InsertBatch adds multiple relations in one statement; ON CONFLICT DO NOTHING for idempotency.
//
// InsertBatch 一条语句插多行；ON CONFLICT DO NOTHING 保证幂等。
func (s *Store) InsertBatch(ctx context.Context, rels []*relationdomain.Relation) error {
	if len(rels) == 0 {
		return nil
	}
	err := s.db.WithContext(ctx).
		Clauses(clause.OnConflict{DoNothing: true}).
		Create(rels).Error
	if err != nil {
		return fmt.Errorf("relationstore.InsertBatch: %w", err)
	}
	return nil
}

// UpdateAttrs writes only the Attrs JSON column for the given id; marshals map to JSON manually
// because GORM's serializer:json only applies when Create/Save is used with the struct.
//
// UpdateAttrs 仅更新指定 id 的 Attrs JSON 列；手工 json.Marshal——GORM serializer:json
// 仅在 Create/Save 整 struct 时启用，直接 .Update(column, map) 不走 serializer。
func (s *Store) UpdateAttrs(ctx context.Context, id string, attrs map[string]any) error {
	if attrs == nil {
		attrs = map[string]any{}
	}
	raw, err := json.Marshal(attrs)
	if err != nil {
		return fmt.Errorf("relationstore.UpdateAttrs: %w", err)
	}
	res := s.db.WithContext(ctx).
		Model(&relationdomain.Relation{}).
		Where("id = ?", id).
		Update("attrs", string(raw))
	if res.Error != nil {
		return fmt.Errorf("relationstore.UpdateAttrs: %w", res.Error)
	}
	return nil
}

// DeleteByIDs hard-deletes rows by ID list; empty list is a no-op.
//
// DeleteByIDs 按 ID 列表硬删；空列表为 no-op。
func (s *Store) DeleteByIDs(ctx context.Context, ids []string) error {
	if len(ids) == 0 {
		return nil
	}
	err := s.db.WithContext(ctx).
		Where("id IN ?", ids).
		Delete(&relationdomain.Relation{}).Error
	if err != nil {
		return fmt.Errorf("relationstore.DeleteByIDs: %w", err)
	}
	return nil
}

// ListByFromAndKinds returns existing edges for (user, from_kind, from_id) within kind scope.
//
// ListByFromAndKinds 返指定 user/from 实体在 kind 范围内的现有边。
func (s *Store) ListByFromAndKinds(ctx context.Context, userID, fromKind, fromID string, kinds []string) ([]*relationdomain.Relation, error) {
	var rows []*relationdomain.Relation
	q := s.db.WithContext(ctx).
		Where("user_id = ? AND from_kind = ? AND from_id = ?", userID, fromKind, fromID)
	if len(kinds) > 0 {
		q = q.Where("kind IN ?", kinds)
	}
	if err := q.Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("relationstore.ListByFromAndKinds: %w", err)
	}
	return rows, nil
}

// ListByToAndKinds is the mirror of ListByFromAndKinds for SyncIncoming.
//
// ListByToAndKinds 是 ListByFromAndKinds 的对称版本，给 SyncIncoming 用。
func (s *Store) ListByToAndKinds(ctx context.Context, userID, toKind, toID string, kinds []string) ([]*relationdomain.Relation, error) {
	var rows []*relationdomain.Relation
	q := s.db.WithContext(ctx).
		Where("user_id = ? AND to_kind = ? AND to_id = ?", userID, toKind, toID)
	if len(kinds) > 0 {
		q = q.Where("kind IN ?", kinds)
	}
	if err := q.Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("relationstore.ListByToAndKinds: %w", err)
	}
	return rows, nil
}

// List returns rows matching filter (user-scoped) with (created_at, id) cursor pagination.
//
// List 返按 filter 过滤的边（user 作用域），(created_at, id) 元组 cursor 分页。
func (s *Store) List(ctx context.Context, userID string, filter relationdomain.Filter, cursor string, limit int) ([]*relationdomain.Relation, string, bool, error) {
	if limit <= 0 {
		limit = 200
	}
	if limit > 500 {
		limit = 500
	}
	q := s.db.WithContext(ctx).Where("user_id = ?", userID)
	if filter.FromKind != "" {
		q = q.Where("from_kind = ?", filter.FromKind)
	}
	if filter.FromID != "" {
		q = q.Where("from_id = ?", filter.FromID)
	}
	if filter.ToKind != "" {
		q = q.Where("to_kind = ?", filter.ToKind)
	}
	if filter.ToID != "" {
		q = q.Where("to_id = ?", filter.ToID)
	}
	if filter.Kind != "" {
		q = q.Where("kind = ?", filter.Kind)
	}
	if cursor != "" {
		var c paginationpkg.Cursor
		if err := paginationpkg.DecodeCursor(cursor, &c); err != nil {
			return nil, "", false, fmt.Errorf("relationstore.List: %w", err)
		}
		q = q.Where("(created_at, id) < (?, ?)", c.CreatedAt, c.ID)
	}
	var rows []*relationdomain.Relation
	if err := q.Order("created_at DESC, id DESC").
		Limit(limit + 1).
		Find(&rows).Error; err != nil {
		return nil, "", false, fmt.Errorf("relationstore.List: %w", err)
	}
	hasMore := len(rows) > limit
	var nextCursor string
	if hasMore {
		last := rows[limit-1]
		c, err := paginationpkg.EncodeCursor(paginationpkg.Cursor{CreatedAt: last.CreatedAt, ID: last.ID})
		if err != nil {
			return nil, "", false, fmt.Errorf("relationstore.List: %w", err)
		}
		nextCursor = c
		rows = rows[:limit]
	}
	return rows, nextCursor, hasMore, nil
}

// ListAll returns every edge for the user (used by relgraph snapshot, no limit).
//
// ListAll 返该 user 所有边（给 relgraph 快照用，无上限）。
func (s *Store) ListAll(ctx context.Context, userID string) ([]*relationdomain.Relation, error) {
	var rows []*relationdomain.Relation
	if err := s.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("created_at DESC, id DESC").
		Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("relationstore.ListAll: %w", err)
	}
	return rows, nil
}

// PurgeEntity hard-deletes all rows where from=(kind,id) OR to=(kind,id); returns count deleted.
//
// PurgeEntity 硬删所有 from=(kind,id) 或 to=(kind,id) 的边；返删除条数。
func (s *Store) PurgeEntity(ctx context.Context, userID, kind, id string) (int64, error) {
	res := s.db.WithContext(ctx).
		Where("user_id = ? AND ((from_kind = ? AND from_id = ?) OR (to_kind = ? AND to_id = ?))",
			userID, kind, id, kind, id).
		Delete(&relationdomain.Relation{})
	if res.Error != nil {
		return 0, fmt.Errorf("relationstore.PurgeEntity: %w", res.Error)
	}
	return res.RowsAffected, nil
}
