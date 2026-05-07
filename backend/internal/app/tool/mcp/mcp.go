// Package mcp provides the search_mcp + call_mcp system tools — the
// LLM's interface to user-configured MCP servers (mcp.md §8).
//
// Imported as `mcptool` per §S13 nested sub-package alias rule.
//
// Two-step search/call pattern (vs flat-registering every server's
// tools): avoids the 70k-token startup hit Claude Code etc. take when
// users configure many servers. LLM calls search_mcp(query) to
// discover top-K candidates, then call_mcp(server, tool, args) to
// invoke. Splits the LLM's "discover" from "act" so a) catalog
// routing hints can influence "discover" without the LLM committing
// to a call, and b) the LLM gets a chance to read the schema and
// build correct args before invoking.
//
// Failure paths follow the §S18 / ask.go pattern: every failure is
// converted to a friendly tool_result string so the LLM can read the
// situation and decide (re-search with a different query, pick a
// different server, surrender). No Go errors escape Execute except
// for genuine framework-level bugs (parse failures).
//
// Package mcp 提供 search_mcp + call_mcp 系统工具——LLM 与用户配置的
// MCP server 的接口（mcp.md §8）。按 §S13 嵌套子包别名规则导入为
// `mcptool`。
//
// 两步 search/call 模式（vs flat 注册）：避开 Claude Code 等 70k token
// 启动开销。LLM 先 search_mcp(query) 发现候选，再 call_mcp(server, tool,
// args) 调用。拆"发现"与"行动"——a) catalog routing hint 影响发现而 LLM
// 不必承诺；b) LLM 有机会读 schema 构造正确 args 再调。
//
// 失败路径按 §S18 / ask.go：每个失败转友好 tool_result 字符串让 LLM 自
// 决（换 query 再搜 / 换 server / 放弃）。除框架级 bug（解析失败）外
// Execute 不抛 Go err。
package mcp

import (
	mcpapp "github.com/sunweilin/forgify/backend/internal/app/mcp"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
)

// MCPTools constructs the five MCP system tools sharing one Service.
// Two for installed-server interaction (search_mcp_tools / call_mcp_tool),
// three for marketplace flow (search_mcp_marketplace + install_mcp_server +
// uninstall_mcp_server). picker / keys / factory are needed by the
// marketplace search's LLM rerank — pass nil to skip registering it
// (tests without LLM access).
//
// MCPTools 用一个 Service 构造 5 个 MCP 系统工具。两个走已装 server 交互
// （search_mcp_tools / call_mcp_tool），三个走 marketplace 流程
// （search_mcp_marketplace + install_mcp_server + uninstall_mcp_server）。
// picker / keys / factory 给 marketplace search 的 LLM 重排用——传 nil 跳过
// 注册（无 LLM access 的测试）。
func MCPTools(
	svc *mcpapp.Service,
	picker modeldomain.ModelPicker,
	keys apikeydomain.KeyProvider,
	factory *llminfra.Factory,
) []toolapp.Tool {
	tools := []toolapp.Tool{
		&SearchMCP{svc: svc},
		&CallMCP{svc: svc},
	}
	// Marketplace search needs LLM rerank — skip if any LLM dep is nil
	// (e.g. unit tests that build MCPTools without a configured factory).
	// marketplace search 需 LLM 重排——任一 LLM 依赖 nil 时跳过注册（如未配
	// factory 的单测）。
	if picker != nil && keys != nil && factory != nil {
		tools = append(tools, &SearchMarketplaceMCP{svc: svc, picker: picker, keys: keys, factory: factory})
	}
	tools = append(tools,
		&InstallMCPServer{svc: svc},
		&UninstallMCPServer{svc: svc},
	)
	return tools
}
