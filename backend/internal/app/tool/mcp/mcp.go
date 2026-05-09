// Package mcp provides the MCP system tools — the LLM's interface to
// user-configured MCP servers (mcp.md §8) plus the curated marketplace.
//
// Imported as `mcptool` per §S13 nested sub-package alias rule.
//
// Two-step search/call pattern (vs flat-registering every server's
// tools): avoids the 70k-token startup hit Claude Code etc. take when
// users configure many servers. LLM calls search_mcp_tools(query) to
// discover top-K candidates, then call_mcp_tool(server, tool, args)
// to invoke. Splits the LLM's "discover" from "act" so a) catalog
// routing hints can influence "discover" without the LLM committing
// to a call, and b) the LLM gets a chance to read the schema and
// build correct args before invoking.
//
// Marketplace flow (V3, 2026-05-09): list_mcp_marketplace returns the
// full curated catalog (~21 entries) → install_mcp_server (two-phase
// confirm) → uninstall_mcp_server. No keyword search step — the
// curated list is small enough that the LLM picks directly.
//
// Failure paths follow the §S18 / ask.go pattern: every failure is
// converted to a friendly tool_result string so the LLM can read the
// situation and decide. No Go errors escape Execute except for
// genuine framework-level bugs (parse failures).
//
// Package mcp 提供 MCP 系统工具——LLM 与已配 server 的交互（mcp.md §8）+
// curated marketplace。按 §S13 嵌套子包别名规则导入为 `mcptool`。
//
// 两步 search/call（vs flat 注册）：避开 Claude Code 等 70k token 启动
// 开销。Marketplace V3（2026-05-09）：list_mcp_marketplace 返完整 ~21
// 条 → install_mcp_server（两阶段 confirm）→ uninstall_mcp_server。
// 无关键词搜索——curated 太小 LLM 直接选。
package mcp

import (
	mcpapp "github.com/sunweilin/forgify/backend/internal/app/mcp"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

// MCPTools constructs the five MCP system tools sharing one Service.
// Two for installed-server interaction (search_mcp_tools / call_mcp_tool),
// three for marketplace flow (list_mcp_marketplace + install_mcp_server +
// uninstall_mcp_server).
//
// MCPTools 用一个 Service 构造 5 个 MCP 系统工具。两个走已装 server 交互
// （search_mcp_tools / call_mcp_tool），三个走 marketplace 流程
// （list_mcp_marketplace + install_mcp_server + uninstall_mcp_server）。
func MCPTools(svc *mcpapp.Service) []toolapp.Tool {
	return []toolapp.Tool{
		&SearchMCP{svc: svc},
		&CallMCP{svc: svc},
		&ListMCPMarketplace{svc: svc},
		&InstallMCPServer{svc: svc},
		&UninstallMCPServer{svc: svc},
	}
}
