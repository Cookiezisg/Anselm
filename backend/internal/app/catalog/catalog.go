// Package catalog is the service layer for the Capability Catalog.
//
// Package catalog 提供 Capability Catalog 的 service 层：按需现查 + mechanical 拼装。
package catalog

import (
	"context"
	"fmt"
	"sync"
	"time"

	"go.uber.org/zap"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// Generator is the optional summary builder seam; nil (the default) → mechanical.
// Kept as a port for a future size-gated compression/retrieval strategy; not wired today.
//
// Generator 是可选的 summary 构建缝；nil（默认）→ mechanical。
// 留作将来按规模触发的压缩/检索策略，本次不接。
type Generator interface {
	Generate(ctx context.Context, items []catalogdomain.Item, gMap map[string]catalogdomain.Granularity) (*catalogdomain.Catalog, error)
}

// Service builds the capability catalog on demand from registered sources.
//
// Service 按需从已注册 source 构建能力清单；无后台、无缓存、无磁盘。
type Service struct {
	log *zap.Logger

	sourcesMu sync.RWMutex
	sources   []catalogdomain.CatalogSource
}

// New constructs a Service. Register sources, then call Get / GetForSystemPrompt.
//
// New 构造 Service；注册 source 后即可 Get / GetForSystemPrompt。
func New(log *zap.Logger) *Service {
	if log == nil {
		panic("catalog.New: logger is nil")
	}
	return &Service{log: log}
}

// RegisterSource adds a source; safe at any time.
//
// RegisterSource 加 source，任意时点安全。
func (s *Service) RegisterSource(src catalogdomain.CatalogSource) {
	s.sourcesMu.Lock()
	defer s.sourcesMu.Unlock()
	s.sources = append(s.sources, src)
}

func (s *Service) snapshotSources() []catalogdomain.CatalogSource {
	s.sourcesMu.RLock()
	defer s.sourcesMu.RUnlock()
	out := make([]catalogdomain.CatalogSource, len(s.sources))
	copy(out, s.sources)
	return out
}

// build collects items from all sources (scoped to the ctx user) and assembles
// the mechanical capability list. Caller MUST supply a ctx with userID.
// All sources failing → ErrAllSourcesFailed; partial failure → use what succeeded.
//
// build 现查所有 source（按 ctx 用户）拼 mechanical 清单；ctx 必须带 userID。
// 全失败 → ErrAllSourcesFailed；部分失败 → 用成功的拼。
func (s *Service) build(ctx context.Context) (*catalogdomain.Catalog, error) {
	if _, ok := reqctxpkg.GetUserID(ctx); !ok {
		return nil, fmt.Errorf("catalog.build: %w", reqctxpkg.ErrMissingUserID)
	}
	sources := s.snapshotSources()

	items := []catalogdomain.Item{}
	gMap := map[string]catalogdomain.Granularity{}
	invokeMap := map[string]string{}
	failed := 0
	for _, src := range sources {
		srcItems, err := src.ListItems(ctx)
		if err != nil {
			s.log.Warn("catalog source ListItems failed; substituting empty",
				zap.String("source", src.Name()), zap.Error(err))
			failed++
			continue
		}
		items = append(items, srcItems...)
		gMap[src.Name()] = src.Granularity()
		invokeMap[src.Name()] = src.InvokeTool()
	}
	if len(sources) > 0 && failed == len(sources) {
		return nil, fmt.Errorf("catalogapp.build: all %d sources failed: %w",
			len(sources), catalogdomain.ErrAllSourcesFailed)
	}

	cat := assemble(items, gMap, invokeMap)
	cat.GeneratedAt = time.Now().UTC()
	return cat, nil
}

// Get builds the current catalog on demand (HTTP inspection).
//
// Get 按需构建当前 catalog（HTTP 巡检）。
func (s *Service) Get(ctx context.Context) (*catalogdomain.Catalog, error) {
	return s.build(ctx)
}

// GetForSystemPrompt builds the capability list for chat injection; "" on any failure.
//
// GetForSystemPrompt 为 chat 注入构建能力清单；任何失败返 ""（聊天照常）。
func (s *Service) GetForSystemPrompt(ctx context.Context) string {
	cat, err := s.build(ctx)
	if err != nil {
		s.log.Warn("catalog build failed; omitting capability section", zap.Error(err))
		return ""
	}
	return cat.Summary
}
