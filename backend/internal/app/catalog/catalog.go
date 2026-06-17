// Package catalog (app layer) builds the capability overview on demand from
// registered sources: no store, no cache, no background — each call re-scans the
// current truth and assembles the grouped name+description menu. Workspace scoping
// is handled inside each source's ListItems (orm auto-isolation), so this layer
// passes no workspace id.
//
// Package catalog（app 层）按需从已注册 source 构建能力概览：无 store、无缓存、无后台——
// 每次调用现扫当前真实状态并拼出分组的 name+description 菜单。workspace 隔离在各 source 的
// ListItems 内（orm 自动），本层不传 workspace id。
package catalog

import (
	"context"
	"sync"

	"go.uber.org/zap"

	catalogdomain "github.com/sunweilin/anselm/backend/internal/domain/catalog"
)

// Service aggregates registered CatalogSources into the overview.
//
// Service 把已注册的 CatalogSource 聚合成概览。
type Service struct {
	log *zap.Logger

	mu      sync.RWMutex
	sources []catalogdomain.CatalogSource
}

// New constructs a Service. Register sources (at boot), then Get / GetForSystemPrompt.
//
// New 构造 Service；注册 source（boot 装配）后即可 Get / GetForSystemPrompt。
func NewService(log *zap.Logger) *Service {
	if log == nil {
		panic("catalogapp.New: logger is nil")
	}
	return &Service{log: log}
}

var _ catalogdomain.SystemPromptProvider = (*Service)(nil)

// RegisterSource adds a source; safe at any time.
//
// RegisterSource 加 source，任意时点安全。
func (s *Service) RegisterSource(src catalogdomain.CatalogSource) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.sources = append(s.sources, src)
}

func (s *Service) snapshot() []catalogdomain.CatalogSource {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]catalogdomain.CatalogSource, len(s.sources))
	copy(out, s.sources)
	return out
}

// build scans every source and assembles the menu. All sources failing →
// ErrAllSourcesFailed (a system fault); partial failure → render what succeeded.
//
// build 扫所有 source 拼菜单。全失败 → ErrAllSourcesFailed（系统故障）；部分失败 → 用成功的渲染。
func (s *Service) build(ctx context.Context) (*catalogdomain.Catalog, error) {
	sources := s.snapshot()
	var items []catalogdomain.Item
	failed := 0
	for _, src := range sources {
		srcItems, err := src.ListItems(ctx)
		if err != nil {
			s.log.Warn("catalog source failed; skipping",
				zap.String("source", src.Name()), zap.Error(err))
			failed++
			continue
		}
		items = append(items, srcItems...)
	}
	if len(sources) > 0 && failed == len(sources) {
		return nil, catalogdomain.ErrAllSourcesFailed
	}
	return assemble(items), nil
}

// Get builds the current catalog on demand (HTTP inspection).
//
// Get 按需构建当前 catalog（HTTP 巡检）。
func (s *Service) Get(ctx context.Context) (*catalogdomain.Catalog, error) {
	return s.build(ctx)
}

// GetForSystemPrompt builds the menu text for chat injection; "" on any failure so
// the conversation proceeds without a capability section.
//
// GetForSystemPrompt 为 chat 注入构建菜单文本；任何失败返 ""，使对话照常（无能力段）。
func (s *Service) GetForSystemPrompt(ctx context.Context) string {
	cat, err := s.build(ctx)
	if err != nil {
		s.log.Warn("catalog build failed; omitting capability section", zap.Error(err))
		return ""
	}
	return cat.Summary
}
