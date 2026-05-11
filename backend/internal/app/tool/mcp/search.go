// search.go — search_mcp system tool. LLM calls this to discover what
// MCP tools (across all connected servers) are relevant to a query.
// Result is the top-K ToolDef list as a JSON string the LLM reads to
// pick its next call_mcp invocation.
//
// search.go ——search_mcp 系统工具。LLM 调它发现哪些 MCP 工具（跨所有
// connected server）与 query 相关。返 top-K ToolDef 列表 JSON 字符串供
// LLM 读 + 选下一步 call_mcp。
package mcp

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	mcpapp "github.com/sunweilin/forgify/backend/internal/app/mcp"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

// defaultTopK is what search returns when the LLM omits top_k. 5 keeps
// the result small enough that the LLM doesn't burn context window on
// long descriptions but big enough to give it real choice.
//
// defaultTopK 是 LLM 省略 top_k 时的返回数。5 让结果不烧 LLM context
// （长描述）同时给真选择空间。
const defaultTopK = 5

// ── Validation sentinels ─────────────────────────────────────────────

// ErrEmptyQuery — `query` arg missing or whitespace.
//
// ErrEmptyQuery：query 缺失或全空白。
var ErrEmptyQuery = errors.New("query is required and must be non-empty")

// ── Description & schema ─────────────────────────────────────────────

const searchMCPDescription = `Search across all connected MCP servers for tools matching a natural-language query. Returns the top K candidate tools (server name, tool name, description, inputSchema) — use the inputSchema to build args for a subsequent call_mcp invocation. Prefer native tools (Read/Write/Edit/Bash/Grep/Glob/WebFetch/WebSearch) when they suffice; reach for MCP for external integrations (browser, GitHub, SQL, etc.).`

var searchMCPSchema = json.RawMessage(`{
	"type": "object",
	"required": ["query"],
	"properties": {
		"query": {
			"type": "string",
			"description": "Natural-language description of what tool you need (e.g. 'open URL in browser', 'search GitHub PRs', 'query SQLite')."
		},
		"top_k": {
			"type": "integer",
			"minimum": 1,
			"maximum": 20,
			"description": "How many candidate tools to return. Default 5; max 20."
		}
	}
}`)

// ── Tool struct & 9 methods ──────────────────────────────────────────

// SearchMCP implements the search_mcp system tool.
//
// SearchMCP struct 是 search_mcp 系统工具。
type SearchMCP struct {
	svc *mcpapp.Service
}

// Identity --------------------------------------------------------------------

func (t *SearchMCP) Name() string                { return "search_mcp_tools" }
func (t *SearchMCP) Description() string         { return searchMCPDescription }
func (t *SearchMCP) Parameters() json.RawMessage { return searchMCPSchema }

// Static metadata -------------------------------------------------------------

func (t *SearchMCP) IsReadOnly() bool        { return true }
func (t *SearchMCP) NeedsReadFirst() bool    { return false }
func (t *SearchMCP) RequiresWorkspace() bool { return false }

// ── Args-dependent hooks ─────────────────────────────────────────────

func (t *SearchMCP) ValidateInput(args json.RawMessage) error {
	var a struct {
		Query string `json:"query"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("search_mcp.ValidateInput: %w", err)
	}
	if strings.TrimSpace(a.Query) == "" {
		return ErrEmptyQuery
	}
	return nil
}

func (t *SearchMCP) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

// ── Execute ──────────────────────────────────────────────────────────

// Execute parses args, calls Service.Search, and returns the result as
// a JSON string. Failure paths return friendly strings (per §S18) so
// the LLM can read the situation rather than getting an opaque tool
// failure.
//
// Execute 解析 args，调 Service.Search，返结果 JSON 字符串。失败路径返
// 友好字符串（§S18）让 LLM 自决，不给不透明 tool 失败。
func (t *SearchMCP) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Query string `json:"query"`
		TopK  int    `json:"top_k"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("search_mcp.Execute: parse args: %w", err)
	}
	topK := args.TopK
	if topK <= 0 {
		topK = defaultTopK
	}

	tools, err := t.svc.Search(ctx, args.Query, topK)
	if err != nil {
		// LLM-resolution failure or transient. err.Error() is sanitized by
		// the framework boundary (loop/tools.go) before reaching the LLM
		// even when this string is itself wrapped — pass through verbatim.
		// LLM 解析失败或瞬态。framework boundary（loop/tools.go）会清洗
		// err.Error() 的 §S16 wrap 链；此处可原样透传。
		return fmt.Sprintf("Search failed: %s", err.Error()), nil
	}

	if len(tools) == 0 {
		return "No MCP tools found. No MCP server is currently connected — install one via list_mcp_marketplace + install_mcp_server.", nil
	}

	body, err := json.MarshalIndent(tools, "", "  ")
	if err != nil {
		return "", fmt.Errorf("search_mcp.Execute: marshal result: %w", err)
	}
	return string(body), nil
}

// ── Compile-time checks ──────────────────────────────────────────────

var _ toolapp.Tool = (*SearchMCP)(nil)
