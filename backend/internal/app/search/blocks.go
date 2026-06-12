package search

import (
	"context"
	"strings"

	searchdomain "github.com/sunweilin/forgify/backend/internal/domain/search"
)

const (
	blocksDefaultLimit = 8
	blocksMaxLimit     = 20
)

// BlockHit is one wireable palette result: Ref drops straight into a workflow
// node (fn_<id> / hd_<id>.<method> / mcp:<server>/<tool> / agent / control /
// approval ids).
//
// BlockHit 是一个可接线的面板结果：Ref 直接可填 workflow 节点（fn_<id> /
// hd_<id>.<method> / mcp:<server>/<tool> / agent/control/approval id）。
type BlockHit struct {
	Ref      string `json:"ref"`
	Kind     string `json:"kind"`
	EntityID string `json:"entityId"`
	Name     string `json:"name"`
	Snippet  string `json:"snippet,omitempty"`
}

// SearchBlocks is the LLM palette query (§7.4): six block kinds only, folded
// per (entity, anchor) so each handler method / mcp tool is its own hit, and
// every result carries a wireable ref. Hits without one (an mcp server card)
// are dropped — un-wireable results are noise here.
//
// SearchBlocks 是 LLM 积木面板查询（§7.4）：仅六类积木、按 (entity, anchor) 折叠
// （每个 handler 方法 / mcp 工具各自成命中）、每条结果带可接线 ref。没有 ref 的
// 命中（mcp server 卡）丢弃——不可接线的结果在这里是噪声。
func (s *Service) SearchBlocks(ctx context.Context, query string, kinds []searchdomain.EntityType, limit int) ([]BlockHit, error) {
	if strings.TrimSpace(query) == "" {
		return nil, searchdomain.ErrQueryRequired
	}
	if len(kinds) == 0 {
		kinds = searchdomain.BlockEntityTypes
	}
	for _, k := range kinds {
		if !searchdomain.IsBlockEntityType(k) {
			return nil, searchdomain.ErrTypeInvalid
		}
	}
	if limit <= 0 {
		limit = blocksDefaultLimit
	}
	if limit > blocksMaxLimit {
		limit = blocksMaxLimit
	}
	hits, err := s.window(ctx, &searchdomain.Query{Q: query, Types: kinds, IncludeArchived: true}, false)
	if err != nil {
		return nil, err
	}
	out := make([]BlockHit, 0, limit)
	for _, h := range hits {
		if h.RefHint == "" {
			continue
		}
		out = append(out, BlockHit{
			Ref:      h.RefHint,
			Kind:     string(h.EntityType),
			EntityID: h.EntityID,
			Name:     h.Name,
			Snippet:  h.Snippet,
		})
		if len(out) == limit {
			break
		}
	}
	return out, nil
}
