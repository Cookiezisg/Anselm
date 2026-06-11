package mcp

import (
	"context"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
	mcpdomain "github.com/sunweilin/forgify/backend/internal/domain/mcp"
)

// AsCatalogSource returns this Service's CatalogSource adapter. An mcp server is a CONTAINER
// entity: one catalog item per connected server, carrying name + description + ALL its tool
// names (Members). Tools themselves live in the lazy pool (loaded via search_tools); the
// catalog only tells the LLM which servers exist and what tools each offers.
//
// AsCatalogSource 返回本 Service 的 CatalogSource 适配器。mcp server 是容器实体：每个已连接 server
// 一条 catalog item，带 名 + 描述 + 全部工具名（Members）。工具本身在 lazy 池（经 search_tools 加载）；
// catalog 只告诉 LLM 有哪些 server、各自有哪些工具。
func (s *Service) AsCatalogSource() catalogdomain.CatalogSource {
	return &mcpCatalogSource{svc: s}
}

type mcpCatalogSource struct{ svc *Service }

func (c *mcpCatalogSource) Name() string { return "mcp" }

// ListItems reports every ready/degraded server as name + description + all tool names. A
// failed server is omitted (the LLM can't use it); users see it via the HTTP management page.
//
// ListItems 把每个 ready/degraded server 报为 名 + 描述 + 全部工具名。failed 的略过（LLM 用不了）；
// 用户在 HTTP 管理页看得到。
func (c *mcpCatalogSource) ListItems(ctx context.Context) ([]catalogdomain.Item, error) {
	servers, err := c.svc.repo.List(ctx)
	if err != nil {
		return nil, err
	}
	c.svc.mu.RLock()
	defer c.svc.mu.RUnlock()
	items := make([]catalogdomain.Item, 0, len(servers))
	for _, srv := range servers {
		st := c.svc.states[srv.ID]
		if st == nil || !mcpdomain.IsCallable(st.Status) {
			continue
		}
		items = append(items, catalogdomain.Item{
			Source:      "mcp",
			ID:          srv.ID,
			Name:        srv.Name,
			Description: srv.Description,
			Members:     toolNames(st.Tools),
		})
	}
	return items, nil
}

func toolNames(tools []mcpdomain.ToolDef) []string {
	out := make([]string, len(tools))
	for i, t := range tools {
		out[i] = t.Name
	}
	return out
}
