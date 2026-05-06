// call.go — call_mcp system tool. LLM uses this to invoke a specific
// tool on a specific MCP server, after picking from search_mcp results.
// Result is the server's tool output as a string.
//
// call.go ——call_mcp 系统工具。LLM 选完 search_mcp 候选后用它调具体
// server 的具体 tool。返 server 工具输出字符串。
package mcp

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	mcpapp "github.com/sunweilin/forgify/backend/internal/app/mcp"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	mcpdomain "github.com/sunweilin/forgify/backend/internal/domain/mcp"
)

// ── Validation sentinels ─────────────────────────────────────────────

// ErrEmptyServer / ErrEmptyTool — required-field guards. Args itself is
// optional (some MCP tools take no args).
//
// ErrEmptyServer / ErrEmptyTool 必填字段守卫。Args 自身可选（部分 MCP
// 工具无参数）。
var (
	ErrEmptyServer = errors.New("server is required and must be non-empty")
	ErrEmptyTool   = errors.New("tool is required and must be non-empty")
)

// ── Description & schema ─────────────────────────────────────────────

const callMCPDescription = `Invoke a specific tool on a specific MCP server. Returns the server's response as text.

Workflow:
1. Call search_mcp first to discover candidate tools and their schemas.
2. Pick a tool from the search result.
3. Call call_mcp with the matching server / tool / args. The args
   object MUST conform to the tool's inputSchema (returned by
   search_mcp).

If the tool fails (server error, timeout, permission denied), the
result string explains what happened so you can adjust args, pick a
different tool, or surrender.`

var callMCPSchema = json.RawMessage(`{
	"type": "object",
	"required": ["server", "tool", "args"],
	"properties": {
		"server": {
			"type": "string",
			"description": "MCP server name (e.g. 'github', 'playwright', 'sqlite')."
		},
		"tool": {
			"type": "string",
			"description": "Tool name as returned by search_mcp (no 'mcp__' prefix)."
		},
		"args": {
			"type": "object",
			"description": "Arguments matching the tool's inputSchema. Use {} when the tool takes no arguments.",
			"additionalProperties": true
		}
	}
}`)

// ── Tool struct & 9 methods ──────────────────────────────────────────

// CallMCP implements the call_mcp system tool.
//
// CallMCP struct 是 call_mcp 系统工具。
type CallMCP struct {
	svc *mcpapp.Service
}

// Identity --------------------------------------------------------------------

func (t *CallMCP) Name() string                { return "call_mcp" }
func (t *CallMCP) Description() string         { return callMCPDescription }
func (t *CallMCP) Parameters() json.RawMessage { return callMCPSchema }

// Static metadata -------------------------------------------------------------

// IsReadOnly is conservatively false: an MCP tool may write/mutate.
// LLM should set destructive=true on the call_mcp invocation when the
// underlying MCP tool is destructive (e.g. github.delete_repo).
//
// IsReadOnly 保守取 false：MCP 工具可能写。LLM 应在调底层 MCP 工具是
// destructive（如 github.delete_repo）时给 call_mcp 调用设 destructive=true。
func (t *CallMCP) IsReadOnly() bool        { return false }
func (t *CallMCP) NeedsReadFirst() bool    { return false }
func (t *CallMCP) RequiresWorkspace() bool { return false }

// ── Args-dependent hooks ─────────────────────────────────────────────

func (t *CallMCP) ValidateInput(args json.RawMessage) error {
	var a struct {
		Server string `json:"server"`
		Tool   string `json:"tool"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("call_mcp.ValidateInput: %w", err)
	}
	if strings.TrimSpace(a.Server) == "" {
		return ErrEmptyServer
	}
	if strings.TrimSpace(a.Tool) == "" {
		return ErrEmptyTool
	}
	return nil
}

func (t *CallMCP) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

// ── Execute ──────────────────────────────────────────────────────────

// Execute parses args, dispatches to Service.CallTool, and returns the
// server's response. Each known sentinel maps to a friendly message so
// the LLM can read the failure mode and react (re-search, pick another
// server, surrender). Per §S18 / ask.go pattern.
//
// Execute 解析 args，派发到 Service.CallTool，返 server 响应。每个已知
// sentinel 映射到友好消息让 LLM 看清失败原因并自决（重搜 / 换 server /
// 放弃）。按 §S18 / ask.go 模式。
func (t *CallMCP) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Server string          `json:"server"`
		Tool   string          `json:"tool"`
		Args   json.RawMessage `json:"args"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("call_mcp.Execute: parse args: %w", err)
	}

	out, err := t.svc.CallTool(ctx, args.Server, args.Tool, args.Args)
	if err != nil {
		return mapCallToolErrorToFriendly(args.Server, args.Tool, err), nil
	}
	return out, nil
}

// mapCallToolErrorToFriendly converts known mcpdomain sentinels into
// LLM-readable strings the chat layer wraps in a tool_result block.
// Unknown errors are surfaced verbatim with a 'CallTool failed' prefix
// so they're still searchable and the LLM can still react.
//
// mapCallToolErrorToFriendly 把已知 mcpdomain sentinel 转成 LLM 可读字符串，
// 由 chat 层包成 tool_result block。未知错误前缀 'CallTool failed' 原样
// 暴露——可搜索 + LLM 仍可反应。
func mapCallToolErrorToFriendly(server, tool string, err error) string {
	switch {
	case errors.Is(err, mcpdomain.ErrServerNotFound):
		return fmt.Sprintf("MCP server %q is not configured. Use search_mcp to see available servers, or ask the user to install/configure %q first.", server, server)
	case errors.Is(err, mcpdomain.ErrServerNotConnected):
		return fmt.Sprintf("MCP server %q is not connected (status check failed). The user may need to fix the server's configuration or click 'Reconnect' in the MCP settings panel.", server)
	case errors.Is(err, mcpdomain.ErrToolNotFound):
		return fmt.Sprintf("MCP tool %q does not exist on server %q. Use search_mcp to discover the correct tool name.", tool, server)
	case errors.Is(err, mcpdomain.ErrToolCallTimeout):
		return fmt.Sprintf("MCP call %s/%s timed out. The tool may be slow (browser automation, big query) — consider re-trying with a more specific query, or asking the user to extend the per-server timeout in mcp.json.", server, tool)
	case errors.Is(err, mcpdomain.ErrToolCallFailed):
		return fmt.Sprintf("MCP call %s/%s failed: %v", server, tool, err)
	default:
		return fmt.Sprintf("call_mcp %s/%s failed: %v", server, tool, err)
	}
}

// ── Compile-time checks ──────────────────────────────────────────────

var _ toolapp.Tool = (*CallMCP)(nil)
