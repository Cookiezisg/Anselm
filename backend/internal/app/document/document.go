// Package document owns the Service for the Notion-style document tree (CRUD + path + move).
//
// Package document 持有 Notion-style 文档树的 Service（CRUD + path 计算 + move）。
package document

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"go.uber.org/zap"

	documentdomain "github.com/sunweilin/forgify/backend/internal/domain/document"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
	notificationspkg "github.com/sunweilin/forgify/backend/internal/pkg/notifications"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

type Service struct {
	repo  documentdomain.Repository
	notif notificationspkg.Publisher
	log   *zap.Logger
}

func New(repo documentdomain.Repository, notif notificationspkg.Publisher, log *zap.Logger) *Service {
	if log == nil {
		panic("documentapp.New: logger is nil")
	}
	if notif == nil {
		notif = notificationspkg.New(nil, log)
	}
	return &Service{repo: repo, notif: notif, log: log}
}

type CreateInput = documentdomain.CreateInput
type UpdateInput = documentdomain.UpdateInput
type MoveInput = documentdomain.MoveInput

// Create inserts a new document under parentID (nil = root).
//
// Create 在 parentID 下（nil = root）插入新文档。
func (s *Service) Create(ctx context.Context, in CreateInput) (*documentdomain.Document, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	name := strings.TrimSpace(in.Name)
	if err := validateName(name); err != nil {
		return nil, err
	}
	if err := validateContent(in.Content); err != nil {
		return nil, err
	}

	parentPath := ""
	if in.ParentID != nil {
		parent, err := s.repo.Get(ctx, uid, *in.ParentID)
		if errors.Is(err, documentdomain.ErrNotFound) {
			return nil, documentdomain.ErrParentNotFound
		}
		if err != nil {
			return nil, fmt.Errorf("documentapp.Create: parent lookup: %w", err)
		}
		parentPath = parent.Path
	}

	maxPos, err := s.repo.MaxSiblingPosition(ctx, uid, in.ParentID)
	if err != nil {
		return nil, fmt.Errorf("documentapp.Create: MaxSiblingPosition: %w", err)
	}

	now := time.Now().UTC()
	tags := in.Tags
	if tags == nil {
		tags = []string{}
	}
	d := &documentdomain.Document{
		ID:          newID(),
		UserID:      uid,
		ParentID:    in.ParentID,
		Name:        name,
		Description: strings.TrimSpace(in.Description),
		Content:     in.Content,
		Tags:        tags,
		Position:    maxPos + 1,
		Path:        parentPath + "/" + name,
		SizeBytes:   int64(len(in.Content)),
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	if err := s.repo.Insert(ctx, d); err != nil {
		return nil, fmt.Errorf("documentapp.Create: %w", err)
	}
	s.publish(ctx, d.ID, "created", d.ParentID, d.Path)
	s.log.Info("document created",
		zap.String("doc_id", d.ID),
		zap.String("path", d.Path))
	return d, nil
}

func (s *Service) Get(ctx context.Context, id string) (*documentdomain.Document, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	return s.repo.Get(ctx, uid, id)
}

func (s *Service) GetBatch(ctx context.Context, ids []string) ([]*documentdomain.Document, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	return s.repo.GetBatch(ctx, uid, ids)
}

// ListByParent lists direct children of parentID (nil = root) ordered by position ASC.
//
// ListByParent 列 parentID 直接子节点（nil = root），按 position ASC 排。
func (s *Service) ListByParent(ctx context.Context, parentID *string) ([]*documentdomain.Document, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	return s.repo.ListByParent(ctx, uid, parentID)
}

// ListAll returns every live document for the current user (used by tree endpoint + catalog source).
//
// ListAll 返当前用户所有活跃文档（树端点 + catalog source 用）。
func (s *Service) ListAll(ctx context.Context) ([]*documentdomain.Document, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	return s.repo.ListAll(ctx, uid)
}

func (s *Service) Search(ctx context.Context, query string, limit int) ([]*documentdomain.Document, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	return s.repo.Search(ctx, uid, query, limit)
}

// Update applies a partial change; renaming triggers a subtree path cascade.
//
// Update 部分更新；改名触发整子树 path 级联。
func (s *Service) Update(ctx context.Context, id string, in UpdateInput) (*documentdomain.Document, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	d, err := s.repo.Get(ctx, uid, id)
	if err != nil {
		return nil, err
	}

	renamed := false
	if in.Name != nil {
		newName := strings.TrimSpace(*in.Name)
		if err := validateName(newName); err != nil {
			return nil, err
		}
		if newName != d.Name {
			d.Name = newName
			renamed = true
		}
	}
	if in.Content != nil {
		if err := validateContent(*in.Content); err != nil {
			return nil, err
		}
		d.Content = *in.Content
		d.SizeBytes = int64(len(*in.Content))
	}
	if in.Description != nil {
		d.Description = strings.TrimSpace(*in.Description)
	}
	if in.Tags != nil {
		d.Tags = *in.Tags
	}
	d.UpdatedAt = time.Now().UTC()

	if renamed {
		parentPath := ""
		if d.ParentID != nil {
			parent, err := s.repo.Get(ctx, uid, *d.ParentID)
			if err != nil {
				return nil, fmt.Errorf("documentapp.Update: parent lookup for path recompute: %w", err)
			}
			parentPath = parent.Path
		}
		d.Path = parentPath + "/" + d.Name
	}

	if err := s.repo.Update(ctx, d); err != nil {
		return nil, fmt.Errorf("documentapp.Update: %w", err)
	}
	if renamed {
		if err := s.cascadePathSubtree(ctx, uid, d.ID, d.Path); err != nil {
			s.log.Error("documentapp.Update: path cascade failed", zap.String("doc_id", d.ID), zap.Error(err))
		}
	}
	s.publish(ctx, d.ID, "updated", d.ParentID, d.Path)
	return d, nil
}

// Move relocates the doc under a new parent (nil = root) and renumbers siblings if position given.
//
// Move 把 doc 挂到新父下（nil = root），传 position 时连同 sibling 一起 renumber。
func (s *Service) Move(ctx context.Context, id string, in MoveInput) (*documentdomain.Document, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	d, err := s.repo.Get(ctx, uid, id)
	if err != nil {
		return nil, err
	}

	// Cycle guard: new parent must not be self nor any descendant of self.
	//
	// 防成环：新父不能是自己，也不能是自己的后裔。
	if in.ParentID != nil {
		if *in.ParentID == id {
			return nil, documentdomain.ErrInvalidParent
		}
		isDesc, err := s.repo.IsAncestor(ctx, uid, id, *in.ParentID)
		if err != nil {
			return nil, fmt.Errorf("documentapp.Move: IsAncestor: %w", err)
		}
		if isDesc {
			return nil, documentdomain.ErrInvalidParent
		}
		if _, err := s.repo.Get(ctx, uid, *in.ParentID); err != nil {
			if errors.Is(err, documentdomain.ErrNotFound) {
				return nil, documentdomain.ErrParentNotFound
			}
			return nil, fmt.Errorf("documentapp.Move: new parent lookup: %w", err)
		}
	}

	parentChanged := !samePtrString(d.ParentID, in.ParentID)
	d.ParentID = in.ParentID

	// Place at requested position (or end when nil).
	//
	// 按请求 position 落位（nil 时落到末尾）。
	maxPos, err := s.repo.MaxSiblingPosition(ctx, uid, in.ParentID)
	if err != nil {
		return nil, fmt.Errorf("documentapp.Move: MaxSiblingPosition: %w", err)
	}
	if in.Position == nil {
		d.Position = maxPos + 1
	} else {
		d.Position = *in.Position
	}
	d.UpdatedAt = time.Now().UTC()

	if parentChanged {
		parentPath := ""
		if d.ParentID != nil {
			parent, err := s.repo.Get(ctx, uid, *d.ParentID)
			if err != nil {
				return nil, fmt.Errorf("documentapp.Move: parent path lookup: %w", err)
			}
			parentPath = parent.Path
		}
		d.Path = parentPath + "/" + d.Name
	}

	if err := s.repo.Update(ctx, d); err != nil {
		return nil, fmt.Errorf("documentapp.Move: %w", err)
	}
	if parentChanged {
		if err := s.cascadePathSubtree(ctx, uid, d.ID, d.Path); err != nil {
			s.log.Error("documentapp.Move: path cascade failed", zap.String("doc_id", d.ID), zap.Error(err))
		}
	}
	s.publish(ctx, d.ID, "moved", d.ParentID, d.Path)
	return d, nil
}

// Delete soft-deletes the doc and all descendants atomically.
//
// Delete 软删 doc 及全部后裔（事务原子）。
func (s *Service) Delete(ctx context.Context, id string) (int64, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return 0, err
	}
	d, err := s.repo.Get(ctx, uid, id)
	if err != nil {
		return 0, err
	}
	n, err := s.repo.SoftDeleteSubtree(ctx, uid, id)
	if err != nil {
		return 0, fmt.Errorf("documentapp.Delete: %w", err)
	}
	s.publish(ctx, d.ID, "deleted", d.ParentID, d.Path)
	s.log.Info("document deleted",
		zap.String("doc_id", d.ID),
		zap.String("path", d.Path),
		zap.Int64("deletedCount", n))
	return n, nil
}

// CountDescendants exposes the read-only count for the testend "delete will affect N children" confirmation.
//
// CountDescendants 给 testend "删将影响 N 个子节点" 二次确认用。
func (s *Service) CountDescendants(ctx context.Context, id string) (int64, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return 0, err
	}
	return s.repo.CountDescendants(ctx, uid, id)
}

// cascadePathSubtree rebuilds Path for every descendant after a rename / move; rootPath is the already-updated root path.
//
// cascadePathSubtree 在 rename / move 后重算整子树 Path；rootPath 是已更新的根 path。
func (s *Service) cascadePathSubtree(ctx context.Context, userID, rootID, rootPath string) error {
	type pathed struct {
		id   string
		path string
	}
	queue := []pathed{{id: rootID, path: rootPath}}
	var updates []*documentdomain.Document
	for len(queue) > 0 {
		cur := queue[0]
		queue = queue[1:]
		curID := cur.id
		kids, err := s.repo.ListByParent(ctx, userID, &curID)
		if err != nil {
			return err
		}
		for _, kid := range kids {
			kid.Path = cur.path + "/" + kid.Name
			updates = append(updates, kid)
			queue = append(queue, pathed{id: kid.ID, path: kid.Path})
		}
	}
	if len(updates) == 0 {
		return nil
	}
	return s.repo.UpdateBatch(ctx, updates)
}

func (s *Service) publish(ctx context.Context, id, action string, parentID *string, path string) {
	payload := map[string]any{
		"action": action,
		"path":   path,
	}
	if parentID != nil {
		payload["parentId"] = *parentID
	}
	s.notif.Publish(ctx, "document", id, payload, "")
}

func validateName(name string) error {
	if name == "" {
		return documentdomain.ErrInvalidName
	}
	if len(name) > documentdomain.MaxNameLength {
		return documentdomain.ErrInvalidName
	}
	// Path separator would corrupt the dotted-path scheme; reject.
	//
	// 路径分隔符会污染 path 字段拼接；拒绝。
	if strings.ContainsRune(name, '/') {
		return documentdomain.ErrInvalidName
	}
	return nil
}

func validateContent(content string) error {
	if len(content) > documentdomain.MaxContentBytes {
		return documentdomain.ErrContentTooLarge
	}
	return nil
}

func samePtrString(a, b *string) bool {
	if a == nil && b == nil {
		return true
	}
	if a == nil || b == nil {
		return false
	}
	return *a == *b
}

func newID() string { return idgenpkg.New("doc") }
