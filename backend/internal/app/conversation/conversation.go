// Package conversation (app layer) owns the Service: create, list, rename,
// and delete conversation threads.
//
// All three conversation packages (domain / app / store) declare
// `package conversation`; external callers alias at import.
//
// Package conversation（app 层）负责 Service：创建、列出、改名、删除对话线程。
package conversation

import (
	"context"
	"fmt"
	"strings"
	"time"

	"go.uber.org/zap"

	convdomain "github.com/sunweilin/forgify/backend/internal/domain/conversation"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// Service orchestrates conversation CRUD.
//
// Service 编排对话 CRUD。
type Service struct {
	repo convdomain.Repository
	log  *zap.Logger
}

// NewService wires Service dependencies. Panics on nil logger.
//
// NewService 装配依赖。nil logger 立刻 panic。
func NewService(repo convdomain.Repository, log *zap.Logger) *Service {
	if log == nil {
		panic("conversation.NewService: logger is nil")
	}
	return &Service{repo: repo, log: log}
}

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
	return c, nil
}

// List returns a paginated page of the current user's conversations.
//
// List 返回当前用户对话的一页（分页）。
func (s *Service) List(ctx context.Context, filter convdomain.ListFilter) ([]*convdomain.Conversation, string, error) {
	return s.repo.List(ctx, filter)
}

// Get fetches a single conversation by id, scoped to ctx user.
//
// Get 按 id 取一个对话，按 ctx 用户过滤。
func (s *Service) Get(ctx context.Context, id string) (*convdomain.Conversation, error) {
	return s.repo.Get(ctx, id)
}

// Rename updates the title of a conversation.
//
// Rename 更新对话的 title。
func (s *Service) Rename(ctx context.Context, id, title string) (*convdomain.Conversation, error) {
	return s.Update(ctx, id, &title, nil)
}

// Update applies a partial PATCH to the conversation. Each field is a
// nil-means-skip pointer; pass &"" to explicitly clear. systemPrompt is the
// per-conversation override that chat layer prepends to assistant turns
// (Phase 5 catalog block + locale hint still get appended to whatever this
// returns).
//
// Update 部分更新对话。每字段是 nil-skip 指针；传 &"" 显式清空。
// systemPrompt 是按对话覆盖；chat 层仍会追加 catalog/locale。
func (s *Service) Update(ctx context.Context, id string, title, systemPrompt *string) (*convdomain.Conversation, error) {
	c, err := s.repo.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	if title != nil {
		c.Title = strings.TrimSpace(*title)
	}
	if systemPrompt != nil {
		c.SystemPrompt = *systemPrompt
	}
	c.UpdatedAt = time.Now().UTC()
	if err := s.repo.Save(ctx, c); err != nil {
		return nil, err
	}
	return c, nil
}

// Delete soft-deletes a conversation.
//
// Delete 软删除一个对话。
func (s *Service) Delete(ctx context.Context, id string) error {
	return s.repo.Delete(ctx, id)
}

func newID() string { return idgenpkg.New("cv") }
