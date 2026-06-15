// Package search is the app layer of the unified search service: one engine
// behind four surfaces (omni/vertical HTTP search, the LLM block palette
// search_blocks, the 8 search_<entity> vertical-search tools, RAG Retrieve)
// plus the Indexer that keeps the projection in sync. It depends only on
// ports — the 12 entity packages plug in as Sources, never the reverse.
//
// Package search 是统一搜索服务的 app 层：一个引擎背四个出口（综搜/垂搜 HTTP、LLM
// 搜积木 search_blocks、8 个 search_<entity> 垂搜工具、RAG 取数 Retrieve），外加保持
// 投影同步的 Indexer。只依赖端口——12 个实体包作为 Source 接入，绝不反向依赖。
package search

import (
	"context"
	"time"

	searchdomain "github.com/sunweilin/foryx/backend/internal/domain/search"
)

// Source is the pull-side port each indexed entity implements: Docs projects
// one entity into rows (empty = gone → delete), Stamps lists live entities
// with their update times for the reconcile diff.
//
// Source 是每个入索实体实现的拉取端口：Docs 把一个实体投影成行（空 = 已无 → 删），
// Stamps 列出活实体及更新时间供对账求差。
type Source interface {
	Type() searchdomain.EntityType
	Docs(ctx context.Context, entityID string) ([]searchdomain.SourceDoc, error)
	Stamps(ctx context.Context) (map[string]time.Time, error)
}

// IncrementalSource is the optional single-chunk path: a conversation indexes
// each completed message by anchor without re-projecting the whole (possibly
// huge) conversation. found=false falls back to full Docs.
//
// IncrementalSource 是可选的单 chunk 路径：对话按 anchor 索每条完成的 message，
// 免整会话（可能很长）重投影。found=false 回退整体 Docs。
type IncrementalSource interface {
	DocAt(ctx context.Context, entityID, anchor string) (doc *searchdomain.SourceDoc, found bool, err error)
}
