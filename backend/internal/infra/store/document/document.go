// Package document is the GORM-backed documentdomain.Repository (user-scoped tree CRUD).
//
// Package document 是 documentdomain.Repository 的 GORM 实现（按 user_id 作用域 + 树状 CRUD）。
package document

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"gorm.io/gorm"

	documentdomain "github.com/sunweilin/forgify/backend/internal/domain/document"
)

type Store struct {
	db *gorm.DB
}

func New(db *gorm.DB) *Store { return &Store{db: db} }

var _ documentdomain.Repository = (*Store)(nil)

func AutoMigrateModels() []interface{} {
	return []interface{}{&documentdomain.Document{}}
}

func (s *Store) Insert(ctx context.Context, d *documentdomain.Document) error {
	if err := s.db.WithContext(ctx).Create(d).Error; err != nil {
		if isDocumentDuplicateName(err) {
			return documentdomain.ErrNameConflict
		}
		return fmt.Errorf("documentstore.Insert: %w", err)
	}
	return nil
}

func (s *Store) Get(ctx context.Context, userID, id string) (*documentdomain.Document, error) {
	var d documentdomain.Document
	err := s.db.WithContext(ctx).Where("user_id = ? AND id = ?", userID, id).First(&d).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, documentdomain.ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("documentstore.Get: %w", err)
	}
	return &d, nil
}

func (s *Store) GetBatch(ctx context.Context, userID string, ids []string) ([]*documentdomain.Document, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	var rows []*documentdomain.Document
	if err := s.db.WithContext(ctx).
		Where("user_id = ? AND id IN ?", userID, ids).
		Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("documentstore.GetBatch: %w", err)
	}
	return rows, nil
}

func (s *Store) ListByParent(ctx context.Context, userID string, parentID *string) ([]*documentdomain.Document, error) {
	q := s.db.WithContext(ctx).Where("user_id = ?", userID)
	if parentID == nil {
		q = q.Where("parent_id IS NULL")
	} else {
		q = q.Where("parent_id = ?", *parentID)
	}
	var rows []*documentdomain.Document
	if err := q.Order("position ASC, created_at ASC").Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("documentstore.ListByParent: %w", err)
	}
	return rows, nil
}

func (s *Store) ListAll(ctx context.Context, userID string) ([]*documentdomain.Document, error) {
	var rows []*documentdomain.Document
	if err := s.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("path ASC").
		Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("documentstore.ListAll: %w", err)
	}
	return rows, nil
}

func (s *Store) Search(ctx context.Context, userID, query string, limit int) ([]*documentdomain.Document, error) {
	if limit <= 0 {
		limit = 50
	}
	like := "%" + query + "%"
	var rows []*documentdomain.Document
	if err := s.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Where("name LIKE ? OR description LIKE ?", like, like).
		Order("updated_at DESC").
		Limit(limit).
		Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("documentstore.Search: %w", err)
	}
	return rows, nil
}

func (s *Store) Update(ctx context.Context, d *documentdomain.Document) error {
	if err := s.db.WithContext(ctx).Save(d).Error; err != nil {
		if isDocumentDuplicateName(err) {
			return documentdomain.ErrNameConflict
		}
		return fmt.Errorf("documentstore.Update: %w", err)
	}
	return nil
}

func (s *Store) UpdateBatch(ctx context.Context, docs []*documentdomain.Document) error {
	if len(docs) == 0 {
		return nil
	}
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		for _, d := range docs {
			if err := tx.Save(d).Error; err != nil {
				return fmt.Errorf("documentstore.UpdateBatch: id=%s: %w", d.ID, err)
			}
		}
		return nil
	})
}

// SoftDeleteSubtree walks descendants via BFS then soft-deletes all in one statement.
//
// SoftDeleteSubtree 经 BFS 收集后裔 ID，再一次性 GORM 软删（单 UPDATE deleted_at）。
func (s *Store) SoftDeleteSubtree(ctx context.Context, userID, id string) (int64, error) {
	ids, err := s.collectDescendantIDs(ctx, userID, id)
	if err != nil {
		return 0, fmt.Errorf("documentstore.SoftDeleteSubtree: %w", err)
	}
	if len(ids) == 0 {
		return 0, documentdomain.ErrNotFound
	}
	res := s.db.WithContext(ctx).
		Where("user_id = ? AND id IN ?", userID, ids).
		Delete(&documentdomain.Document{})
	if res.Error != nil {
		return 0, fmt.Errorf("documentstore.SoftDeleteSubtree: %w", res.Error)
	}
	return res.RowsAffected, nil
}

// collectDescendantIDs returns [id, ...all descendants] via BFS; empty when root id not found.
//
// collectDescendantIDs 经 BFS 返 [id, ...所有后裔]；id 不存在返空切片。
func (s *Store) collectDescendantIDs(ctx context.Context, userID, id string) ([]string, error) {
	var root documentdomain.Document
	err := s.db.WithContext(ctx).
		Where("user_id = ? AND id = ?", userID, id).
		First(&root).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	ids := []string{id}
	frontier := []string{id}
	for len(frontier) > 0 {
		var children []*documentdomain.Document
		if err := s.db.WithContext(ctx).
			Where("user_id = ? AND parent_id IN ?", userID, frontier).
			Find(&children).Error; err != nil {
			return nil, err
		}
		frontier = frontier[:0]
		for _, c := range children {
			ids = append(ids, c.ID)
			frontier = append(frontier, c.ID)
		}
	}
	return ids, nil
}

// IsAncestor walks descendant's parent chain to detect cycle; returns false when candidate sits nowhere above.
//
// IsAncestor 沿 descendant 的 parent 链向上爬检测成环；candidate 不在祖先链上返 false。
func (s *Store) IsAncestor(ctx context.Context, userID, candidateAncestorID, descendantID string) (bool, error) {
	if candidateAncestorID == descendantID {
		return true, nil
	}
	cursor := descendantID
	for i := 0; i < 10_000; i++ { // depth bound — wraps misshapen data instead of looping forever
		var row documentdomain.Document
		err := s.db.WithContext(ctx).
			Select("parent_id").
			Where("user_id = ? AND id = ?", userID, cursor).
			First(&row).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return false, nil
		}
		if err != nil {
			return false, fmt.Errorf("documentstore.IsAncestor: %w", err)
		}
		if row.ParentID == nil {
			return false, nil
		}
		if *row.ParentID == candidateAncestorID {
			return true, nil
		}
		cursor = *row.ParentID
	}
	return false, fmt.Errorf("documentstore.IsAncestor: parent chain exceeds depth bound (corrupt data?)")
}

func (s *Store) CountChildren(ctx context.Context, userID, id string) (int64, error) {
	var n int64
	if err := s.db.WithContext(ctx).
		Model(&documentdomain.Document{}).
		Where("user_id = ? AND parent_id = ?", userID, id).
		Count(&n).Error; err != nil {
		return 0, fmt.Errorf("documentstore.CountChildren: %w", err)
	}
	return n, nil
}

func (s *Store) CountDescendants(ctx context.Context, userID, id string) (int64, error) {
	ids, err := s.collectDescendantIDs(ctx, userID, id)
	if err != nil {
		return 0, fmt.Errorf("documentstore.CountDescendants: %w", err)
	}
	if len(ids) == 0 {
		return 0, nil
	}
	// minus 1 because collectDescendantIDs includes the root id.
	return int64(len(ids) - 1), nil
}

// ListSubtreeIDs is the public BFS wrapper around the internal helper.
//
// ListSubtreeIDs 是内部 BFS helper 的对外封装。
func (s *Store) ListSubtreeIDs(ctx context.Context, userID, rootID string) ([]string, error) {
	return s.collectDescendantIDs(ctx, userID, rootID)
}

func (s *Store) MaxSiblingPosition(ctx context.Context, userID string, parentID *string) (int, error) {
	q := s.db.WithContext(ctx).Model(&documentdomain.Document{}).Where("user_id = ?", userID)
	if parentID == nil {
		q = q.Where("parent_id IS NULL")
	} else {
		q = q.Where("parent_id = ?", *parentID)
	}
	var max *int
	if err := q.Select("MAX(position)").Row().Scan(&max); err != nil {
		return -1, fmt.Errorf("documentstore.MaxSiblingPosition: %w", err)
	}
	if max == nil {
		return -1, nil
	}
	return *max, nil
}

func isDocumentDuplicateName(err error) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	return strings.Contains(msg, "UNIQUE constraint failed") &&
		(strings.Contains(msg, "documents.name") ||
			strings.Contains(msg, "idx_documents_parent_name_active") ||
			strings.Contains(msg, "uniq_documents_parent_name"))
}
