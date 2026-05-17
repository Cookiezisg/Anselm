// Package conversation owns the conversation CRUD Service (create / list / rename / delete).
//
// Package conversation 持有对话 CRUD Service（创建 / 列表 / 改名 / 删除）。
package conversation

import (
	"context"
	"fmt"
	"strings"
	"time"

	"go.uber.org/zap"

	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	convdomain "github.com/sunweilin/forgify/backend/internal/domain/conversation"
	documentdomain "github.com/sunweilin/forgify/backend/internal/domain/document"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
	notificationspkg "github.com/sunweilin/forgify/backend/internal/pkg/notifications"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// UpdateInput is the conversation PATCH payload; nil fields are skipped.
//
// UpdateInput 是 conversation PATCH 载荷;nil 字段跳过。
type UpdateInput struct {
	Title             *string
	SystemPrompt      *string
	AttachedDocuments *[]documentdomain.AttachedDocument
	Archived          *bool
	Pinned            *bool
	// ModelOverride: nil = skip, **ptr 内层 nil = clear override, 内层 non-nil = 设置。
	// §12.3 per-conv override; validated against keys.HasKeyForProvider before save.
	ModelOverride **modeldomain.ModelRef
}

// Service orchestrates conversation CRUD.
//
// Service 编排对话 CRUD。
type Service struct {
	repo  convdomain.Repository
	notif notificationspkg.Publisher
	keys  apikeydomain.KeyProvider // §12.3 optional; nil = skip override validation
	log   *zap.Logger
}

// NewService wires dependencies; panics on nil logger; nil notif → no-op.
//
// NewService 装配依赖；nil logger panic；nil notif → no-op 兜底。
func NewService(repo convdomain.Repository, notif notificationspkg.Publisher, log *zap.Logger) *Service {
	if log == nil {
		panic("conversation.NewService: logger is nil")
	}
	if notif == nil {
		notif = notificationspkg.New(nil, log)
	}
	return &Service{repo: repo, notif: notif, log: log}
}

// SetKeyProvider enables §12.3 ModelOverride validation; call once during DI wire-up.
//
// SetKeyProvider 启用 §12.3 ModelOverride 校验；装配阶段调一次。
func (s *Service) SetKeyProvider(keys apikeydomain.KeyProvider) { s.keys = keys }

// Create makes a new conversation with the given title (may be empty).
//
// Create 创建一个新对话，title 可为空。
func (s *Service) Create(ctx context.Context, title string) (*convdomain.Conversation, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, fmt.Errorf("conversation.Service.Create: %w", err)
	}
	now := time.Now().UTC()
	c := &convdomain.Conversation{
		ID:        newID(),
		UserID:    uid,
		Title:     strings.TrimSpace(title),
		CreatedAt: now,
		UpdatedAt: now,
	}
	if err := s.repo.Save(ctx, c); err != nil {
		return nil, err
	}
	s.log.Info("conversation created",
		zap.String("conversation_id", c.ID),
		zap.String("user_id", uid))
	s.notif.Publish(ctx, "conversation", c.ID,
		map[string]any{"action": "created", "title": c.Title}, c.ID)
	return c, nil
}

// List returns a paginated page of conversations.
//
// List 返回对话的一页。
func (s *Service) List(ctx context.Context, filter convdomain.ListFilter) ([]*convdomain.Conversation, string, error) {
	return s.repo.List(ctx, filter)
}

// Get fetches one conversation by id, scoped to ctx user.
//
// Get 按 id 取对话，按 ctx 用户过滤。
func (s *Service) Get(ctx context.Context, id string) (*convdomain.Conversation, error) {
	return s.repo.Get(ctx, id)
}

// Rename updates the conversation title.
//
// Rename 更新对话标题。
func (s *Service) Rename(ctx context.Context, id, title string) (*convdomain.Conversation, error) {
	return s.Update(ctx, id, UpdateInput{Title: &title})
}

// Update applies a PATCH (nil = skip, &"" = clear for strings, &[] = clear for slice).
//
// Update 部分更新(nil 跳过；&"" 清空字符串;&[] 清空切片)。
func (s *Service) Update(ctx context.Context, id string, in UpdateInput) (*convdomain.Conversation, error) {
	c, err := s.repo.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	if in.Title != nil {
		c.Title = strings.TrimSpace(*in.Title)
	}
	if in.SystemPrompt != nil {
		c.SystemPrompt = *in.SystemPrompt
	}
	if in.AttachedDocuments != nil {
		c.AttachedDocuments = *in.AttachedDocuments
	}
	archivedChanged := false
	if in.Archived != nil && c.Archived != *in.Archived {
		c.Archived = *in.Archived
		archivedChanged = true
	}
	pinnedChanged := false
	if in.Pinned != nil && c.Pinned != *in.Pinned {
		c.Pinned = *in.Pinned
		pinnedChanged = true
	}
	overrideChanged := false
	if in.ModelOverride != nil {
		newRef := *in.ModelOverride
		if newRef != nil {
			// validate both fields + provider has api-key (§12.3 F1).
			if strings.TrimSpace(newRef.Provider) == "" {
				return nil, modeldomain.ErrProviderRequired
			}
			if strings.TrimSpace(newRef.ModelID) == "" {
				return nil, modeldomain.ErrModelIDRequired
			}
			if s.keys != nil {
				has, hkErr := s.keys.HasKeyForProvider(ctx, strings.TrimSpace(newRef.Provider))
				if hkErr != nil {
					return nil, fmt.Errorf("conversation.Service.Update: %w", hkErr)
				}
				if !has {
					return nil, modeldomain.ErrProviderHasNoKey
				}
			}
		}
		c.ModelOverride = newRef
		overrideChanged = true
	}
	c.UpdatedAt = time.Now().UTC()
	if err := s.repo.Save(ctx, c); err != nil {
		return nil, err
	}
	action := "updated"
	switch {
	case archivedChanged && c.Archived:
		action = "archived"
	case archivedChanged && !c.Archived:
		action = "unarchived"
	case pinnedChanged && c.Pinned:
		action = "pinned"
	case pinnedChanged && !c.Pinned:
		action = "unpinned"
	case overrideChanged:
		action = "model_override"
	}
	s.notif.Publish(ctx, "conversation", c.ID,
		map[string]any{"action": action, "title": c.Title, "archived": c.Archived, "pinned": c.Pinned}, c.ID)
	return c, nil
}

// Delete soft-deletes a conversation.
//
// Delete 软删除对话。
func (s *Service) Delete(ctx context.Context, id string) error {
	if err := s.repo.Delete(ctx, id); err != nil {
		return err
	}
	s.notif.Publish(ctx, "conversation", id,
		map[string]any{"action": "deleted"}, id)
	return nil
}

func newID() string { return idgenpkg.New("cv") }
