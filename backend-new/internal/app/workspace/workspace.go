// Package workspace owns the workspace CRUD service — the local isolation root's
// lifecycle. It validates names, guards the last workspace, and answers the auth
// middleware's WorkspaceResolver port (Validate).
//
// Package workspace 持有 workspace CRUD service——本地隔离根的生命周期。校验名字、守最后一个
// workspace、应答 auth 中间件的 WorkspaceResolver 端口（Validate）。
package workspace

import (
	"context"
	"fmt"
	"strings"
	"time"
	"unicode/utf8"

	"go.uber.org/zap"

	workspacedomain "github.com/sunweilin/forgify/backend/internal/domain/workspace"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
)

// Service orchestrates Workspace CRUD.
//
// Service 编排 Workspace CRUD。
type Service struct {
	repo workspacedomain.Repository
	log  *zap.Logger
}

// NewService wires dependencies; panics on nil logger.
//
// NewService 装配依赖；nil logger panic。
func NewService(repo workspacedomain.Repository, log *zap.Logger) *Service {
	if log == nil {
		panic("workspace.NewService: logger is nil")
	}
	return &Service{repo: repo, log: log.Named("workspaceapp")}
}

// CreateInput is the validated payload for Create.
//
// CreateInput 是 Create 的校验载荷。
type CreateInput struct {
	Name        string
	AvatarColor string
	Language    string // optional; defaults to zh-CN
}

// UpdateInput is the partial-update payload; nil fields are skipped.
//
// UpdateInput 是部分更新载荷；nil 字段跳过。
type UpdateInput struct {
	Name        *string
	AvatarColor *string
	Language    *string
}

// Create makes a new workspace; name is required and length-bounded, language
// defaults to zh-CN. A duplicate name surfaces ErrNameConflict from the store.
//
// Create 创建新 workspace；name 必填限长，language 默认 zh-CN。重名由 store 冒泡 ErrNameConflict。
func (s *Service) Create(ctx context.Context, in CreateInput) (*workspacedomain.Workspace, error) {
	name, err := cleanName(in.Name)
	if err != nil {
		return nil, err
	}
	lang, err := resolveLanguage(in.Language)
	if err != nil {
		return nil, err
	}
	now := time.Now().UTC()
	w := &workspacedomain.Workspace{
		ID:          idgenpkg.New("ws"),
		Name:        name,
		AvatarColor: strings.TrimSpace(in.AvatarColor),
		Language:    lang,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	if err := s.repo.Save(ctx, w); err != nil {
		return nil, err
	}
	s.log.Info("workspace created", zap.String("workspace_id", w.ID), zap.String("name", w.Name))
	return w, nil
}

// Get returns one workspace by id.
//
// Get 按 id 取 workspace。
func (s *Service) Get(ctx context.Context, id string) (*workspacedomain.Workspace, error) {
	return s.repo.Get(ctx, id)
}

// List returns all workspaces (small set, no pagination).
//
// List 返所有 workspace（量小，不分页）。
func (s *Service) List(ctx context.Context) ([]*workspacedomain.Workspace, error) {
	return s.repo.List(ctx)
}

// Update applies partial fields to a workspace; nil = skip.
//
// Update 部分更新；nil 字段跳过。
func (s *Service) Update(ctx context.Context, id string, in UpdateInput) (*workspacedomain.Workspace, error) {
	w, err := s.repo.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	if in.Name != nil {
		name, err := cleanName(*in.Name)
		if err != nil {
			return nil, err
		}
		w.Name = name
	}
	if in.AvatarColor != nil {
		w.AvatarColor = strings.TrimSpace(*in.AvatarColor)
	}
	if in.Language != nil {
		if !workspacedomain.IsValidLanguage(*in.Language) {
			return nil, workspacedomain.ErrLanguageInvalid
		}
		w.Language = *in.Language
	}
	w.UpdatedAt = time.Now().UTC()
	if err := s.repo.Save(ctx, w); err != nil {
		return nil, err
	}
	return w, nil
}

// Delete removes a workspace, refusing the last one — the isolation root must exist.
//
// Delete 删 workspace，拒删最后一个——隔离根必须存在。
func (s *Service) Delete(ctx context.Context, id string) error {
	n, err := s.repo.Count(ctx)
	if err != nil {
		return fmt.Errorf("workspace.Delete: count: %w", err)
	}
	if n <= 1 {
		return workspacedomain.ErrCannotDeleteLast
	}
	return s.repo.Delete(ctx, id)
}

// TouchLastUsed bumps the last-used timestamp (called on :activate / switch).
//
// TouchLastUsed 刷 last-used 时间戳（:activate / 切换时调）。
func (s *Service) TouchLastUsed(ctx context.Context, id string) error {
	return s.repo.TouchLastUsed(ctx, id)
}

// Validate implements the auth middleware's WorkspaceResolver port: it reports
// whether id names an existing workspace (nil = valid, error = unknown). The
// middleware holds the interface; this matches it by signature, injected at wiring.
//
// Validate 实现 auth 中间件的 WorkspaceResolver 端口：报告 id 是否为已存在 workspace
// （nil=有效，error=未知）。中间件持接口，此处按签名对上，装配时注入。
func (s *Service) Validate(ctx context.Context, id string) error {
	_, err := s.repo.Get(ctx, id)
	return err
}

// cleanName trims, requires non-empty, and bounds the length of a workspace name.
//
// cleanName 去空白、要求非空、限制 workspace 名长度。
func cleanName(raw string) (string, error) {
	name := strings.TrimSpace(raw)
	if name == "" {
		return "", workspacedomain.ErrNameRequired
	}
	if utf8.RuneCountInString(name) > workspacedomain.MaxNameLen {
		return "", workspacedomain.ErrNameTooLong
	}
	return name, nil
}

// resolveLanguage defaults an empty language to zh-CN and validates non-empty ones.
//
// resolveLanguage 把空 language 默认为 zh-CN，非空则校验。
func resolveLanguage(lang string) (string, error) {
	if lang == "" {
		return workspacedomain.LanguageZhCN, nil
	}
	if !workspacedomain.IsValidLanguage(lang) {
		return "", workspacedomain.ErrLanguageInvalid
	}
	return lang, nil
}
