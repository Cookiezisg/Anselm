// Package mcp provides MCP system tools (browse marketplace + install/uninstall/reconnect)
// and the dynamic per-server tool adapters. The 3 management tools are fixed; each installed
// server's tools become individual lazy tools (mcp__server__tool) discovered via search_tools.
//
// Package mcp 提供 MCP 系统工具（逛市场 + 装/卸/重连）与动态的 per-server 工具适配器。3 个管理
// 工具固定；每个已装 server 的工具成为独立 lazy 工具（mcp__server__tool），经 search_tools 发现。
package mcp

import (
	"context"

	mcpapp "github.com/sunweilin/forgify/backend/internal/app/mcp"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	mcpdomain "github.com/sunweilin/forgify/backend/internal/domain/mcp"
)

// MCPTools constructs the fixed MCP management tools (resident). Note: NO danger field —
// danger is the LLM's per-call self-report (S18); these tools carry zero danger logic.
//
// MCPTools 构造固定的 MCP 管理工具（resident）。注意：无 danger 字段——danger 是 LLM 逐次自报
// （S18）；这些工具零 danger 逻辑。
func MCPTools(svc *mcpapp.Service) []toolapp.Tool {
	return []toolapp.Tool{
		&ListMarketplace{svc: svc},
		&InstallServer{svc: svc},
		&UninstallServer{svc: svc},
		&ReconnectMCP{svc: svc},
	}
}

// DynamicTools builds one lazy tool per tool of every connected server in the ctx workspace.
// The host puts these in the search_tools pool (NOT the resident set / Overview) — the LLM
// learns they exist from the catalog (server + tool names) and pulls a schema via search_tools.
//
// DynamicTools 为 ctx workspace 内每个已连接 server 的每个工具建一个 lazy 工具。host 把它们放进
// search_tools 检索池（不进 resident / Overview）——LLM 从 catalog（server + 工具名）得知其存在、
// 经 search_tools 拉 schema。
func DynamicTools(ctx context.Context, svc *mcpapp.Service) ([]toolapp.Tool, error) {
	statuses, err := svc.ListServers(ctx)
	if err != nil {
		return nil, err
	}
	var out []toolapp.Tool
	for _, st := range statuses {
		if !mcpdomain.IsCallable(st.Status) {
			continue
		}
		for _, td := range st.Tools {
			out = append(out, &dynamicTool{
				serverID:    st.ID,
				serverName:  st.Name,
				toolName:    td.Name,
				description: td.Description,
				schema:      td.InputSchema,
				svc:         svc,
			})
		}
	}
	return out, nil
}
