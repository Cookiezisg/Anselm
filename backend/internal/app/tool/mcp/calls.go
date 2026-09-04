package mcp

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	mcpapp "github.com/sunweilin/anselm/backend/internal/app/mcp"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	mcpdomain "github.com/sunweilin/anselm/backend/internal/domain/mcp"
)

// calls.go gives the LLM the mcp_calls read surface — every other executable kind
// (function / handler / agent / trigger / flowrun) already pairs its execution log with
// search/get tools; MCP recorded calls but offered no way to read them back.
//
// calls.go 给 LLM 开 mcp_calls 读取面——其余可执行体（function/handler/agent/trigger/flowrun）
// 的执行日志都配了 search/get 工具；MCP 一直在记账却没有读回的口。

// --- search_mcp_calls --------------------------------------------------------

type SearchMCPCalls struct{ svc *mcpapp.Service }

func (t *SearchMCPCalls) Name() string { return "search_mcp_calls" }

func (t *SearchMCPCalls) Description() string {
	return "List an MCP server's tool-call history (most recent first) with an ok/failed rollup. serverId accepts either the canonical mcp_ server id or the server name shown by the MCP catalog. Filter by tool name or status (ok|failed|cancelled|timeout). When the user asks for full details of a failed MCP call, search the exact server and tool with status=failed, then use get_mcp_call on the newest matching id; do not infer diagnostics from the immediate tool result or invoke the MCP tool again."
}

func (t *SearchMCPCalls) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["serverId"],
		"properties": {
			"serverId": {"type": "string", "description": "Canonical mcp_ server id or the server name shown by the MCP catalog."},
			"tool": {"type": "string", "description": "Optional tool-name filter."},
			"status": {"type": "string", "description": "Optional: ok | failed | cancelled | timeout."},
			"limit": {"type": "integer", "description": "Optional page size (default 50); prefer a JSON integer such as 2. The exact decimal string \"2\" is also accepted from managed callers; other strings are invalid."},
			"cursor": {"type": "string", "description": "Opaque pagination cursor."}
		}
	}`)
}

func (t *SearchMCPCalls) ValidateInput(args json.RawMessage) error {
	var a struct {
		ServerID string `json:"serverId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("search_mcp_calls: bad args: %w", err)
	}
	if a.ServerID == "" {
		return ErrServerIDRequired
	}
	return nil
}

type searchMCPCallsArgs struct {
	ServerID string `json:"serverId"`
	Tool     string `json:"tool"`
	Status   string `json:"status"`
	Limit    int    `json:"limit"`
	Cursor   string `json:"cursor"`
}

// UnmarshalJSON keeps the public schema strongly typed while tolerating the exact decimal-string
// scalar emitted by some managed callers. A first-call type rejection creates a visible red card
// and an avoidable retry; floats, arrays, booleans, and non-numeric strings remain invalid.
func (a *searchMCPCallsArgs) UnmarshalJSON(data []byte) error {
	var raw struct {
		ServerID string          `json:"serverId"`
		Tool     string          `json:"tool"`
		Status   string          `json:"status"`
		Limit    json.RawMessage `json:"limit"`
		Cursor   string          `json:"cursor"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	limit, err := decodeSearchMCPCallsInt(raw.Limit)
	if err != nil {
		return fmt.Errorf("limit: %w", err)
	}
	*a = searchMCPCallsArgs{
		ServerID: raw.ServerID,
		Tool:     raw.Tool,
		Status:   raw.Status,
		Limit:    limit,
		Cursor:   raw.Cursor,
	}
	return nil
}

func decodeSearchMCPCallsInt(raw json.RawMessage) (int, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return 0, nil
	}
	var value int
	if err := json.Unmarshal(raw, &value); err == nil {
		return value, nil
	}
	var text string
	if err := json.Unmarshal(raw, &text); err != nil {
		return 0, fmt.Errorf("must be integer or an exact decimal integer string, got %s", string(raw))
	}
	value, err := strconv.Atoi(strings.TrimSpace(text))
	if err != nil {
		return 0, fmt.Errorf("must be integer or an exact decimal integer string, got %q", text)
	}
	return value, nil
}

func (t *SearchMCPCalls) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args searchMCPCallsArgs
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("search_mcp_calls: bad args: %w", err)
	}
	serverID, err := t.svc.ResolveServerID(ctx, args.ServerID)
	if err != nil {
		return "", fmt.Errorf("search_mcp_calls: resolve serverId: %w", err)
	}
	res, err := t.svc.SearchCalls(ctx, mcpdomain.CallFilter{
		ServerID: serverID,
		Tool:     args.Tool,
		Status:   args.Status,
		Limit:    args.Limit,
		Cursor:   args.Cursor,
	})
	if err != nil {
		return "", fmt.Errorf("search_mcp_calls: %w", err)
	}
	return toolapp.ToJSON(res), nil
}

// --- get_mcp_call ------------------------------------------------------------

type GetMCPCall struct{ svc *mcpapp.Service }

func (t *GetMCPCall) Name() string { return "get_mcp_call" }

func (t *GetMCPCall) Description() string {
	return "Get one MCP tool-call record (input, output, error, logs, timing) by its id. logs is the persisted diagnostic record and may include progress output plus a server stderr tail labeled server-level and may predate this call; report that caveat when showing the stderr tail. The timing fields are exact machine timestamps: omit them from prose unless the user asks for a named field; if asked, copy the returned string character-for-character and never use a field label or placeholder as its value."
}

func (t *GetMCPCall) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["callId"],
		"properties": {"callId": {"type": "string"}}
	}`)
}

func (t *GetMCPCall) ValidateInput(args json.RawMessage) error {
	var a struct {
		CallID string `json:"callId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("get_mcp_call: bad args: %w", err)
	}
	if a.CallID == "" {
		return ErrCallIDRequired
	}
	return nil
}

func (t *GetMCPCall) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		CallID string `json:"callId"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("get_mcp_call: bad args: %w", err)
	}
	c, err := t.svc.GetCall(ctx, args.CallID)
	if err != nil {
		return "", fmt.Errorf("get_mcp_call: %w", err)
	}
	return toolapp.ToJSON(c), nil
}
