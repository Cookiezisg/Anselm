// catalogsource.go — MCP implements catalogdomain.CatalogSource so
// app/catalog can include MCP servers in the system-prompt summary.
// Per catalog.md §12: mcp is PerServer (one entry per server, no
// merging across servers — different servers expose different tools
// and merging would lose information).
//
// MCP server description is synthesized from the server's tools/list
// (each MCP tool has its own description, but we don't have a
// server-level description from the MCP spec). We join the first
// ~3 tool descriptions as a hint so the catalog generator can write
// a sensible per-server line.
//
// Servers in connecting/failed states (status != ready && != degraded)
// are SKIPPED — per CatalogSource V1 contract: "ListItems must return
// current truth; partial state should NOT appear". The catalog naturally
// picks them up on the next 1s tick once they reach ready.
//
// catalogsource.go ——MCP 实现 catalogdomain.CatalogSource 让 app/catalog
// 把 MCP server 纳入 system-prompt summary。catalog.md §12：mcp 是
// PerServer（per-server 一条，不跨 server 合——不同 server 暴露不同 tool，
// 合并丢信息）。
//
// MCP server description 从 server 的 tools/list 合成（每个 MCP tool 有
// 自己 description，但 MCP spec 没 server 级 description）。取前 3 个
// tool description 让 catalog generator 能写有意义的 per-server 行。
//
// connecting / failed 状态 server 跳过——CatalogSource V1 契约 "ListItems
// 必须返当前真实状态；半成品不该出现"。catalog 在下次 1s tick server 进
// ready 后自然 pickup。
package mcp

import (
	"context"
	"fmt"
	"strings"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
	mcpdomain "github.com/sunweilin/forgify/backend/internal/domain/mcp"
)

// maxToolsInDescription caps how many tool names + descriptions we
// concatenate into the per-server description string. 3 is enough for
// the LLM generator to get the server's flavor without burning prompt
// budget on the full tools list.
//
// maxToolsInDescription 限定多少 tool 名+描述拼进 per-server description。
// 3 让 generator 知道 server 风格而不烧 prompt budget 列全 tool。
const maxToolsInDescription = 3

// AsCatalogSource returns the CatalogSource port adapter for this Service.
// main.go calls this once at boot and registers the result with
// catalogapp.Service.RegisterSource.
//
// AsCatalogSource 返本 Service 的 CatalogSource port 适配器。main.go 在
// boot 调一次 + 把结果注册到 catalogapp.Service.RegisterSource。
func (s *Service) AsCatalogSource() catalogdomain.CatalogSource {
	return &mcpCatalogSource{svc: s}
}

type mcpCatalogSource struct {
	svc *Service
}

func (c *mcpCatalogSource) Name() string                           { return "mcp" }
func (c *mcpCatalogSource) Granularity() catalogdomain.Granularity { return catalogdomain.PerServer }

func (c *mcpCatalogSource) ListItems(ctx context.Context) ([]catalogdomain.Item, error) {
	servers := c.svc.ListServers(ctx)
	items := make([]catalogdomain.Item, 0, len(servers))
	for _, srv := range servers {
		// V1 contract: skip servers not yet usable so the catalog
		// generator doesn't summarize half-loaded state.
		// V1 契约：跳未可用 server 让 generator 不汇总半加载态。
		if srv.Status != mcpdomain.StatusReady && srv.Status != mcpdomain.StatusDegraded {
			continue
		}
		items = append(items, catalogdomain.Item{
			Source:      "mcp",
			ID:          srv.Name,
			Name:        srv.Name,
			Description: synthesizeServerDescription(srv),
		})
	}
	return items, nil
}

// synthesizeServerDescription builds a per-server line from the server's
// tools/list. Format:
//
//	"<N> tools (e.g. tool_a: short desc; tool_b: ...)"
//
// Empty tool list (rare — server with zero tools) yields a placeholder
// rather than empty string so the catalog row stays informative.
//
// synthesizeServerDescription 从 server tools/list 构 per-server 行。空
// tool 列表（少见——0 tool 的 server）给占位避免空串让 catalog 行无信息。
func synthesizeServerDescription(srv mcpdomain.ServerStatus) string {
	if len(srv.Tools) == 0 {
		return fmt.Sprintf("%s server (no tools exposed)", srv.Name)
	}
	var sb strings.Builder
	fmt.Fprintf(&sb, "%d tool", len(srv.Tools))
	if len(srv.Tools) != 1 {
		sb.WriteByte('s')
	}
	sb.WriteString(" (e.g. ")
	for i, td := range srv.Tools {
		if i >= maxToolsInDescription {
			fmt.Fprintf(&sb, ", ...+%d more", len(srv.Tools)-i)
			break
		}
		if i > 0 {
			sb.WriteString("; ")
		}
		desc := td.Description
		if len(desc) > 60 {
			desc = desc[:60] + "..."
		}
		fmt.Fprintf(&sb, "%s: %s", td.Name, desc)
	}
	sb.WriteByte(')')
	return sb.String()
}
