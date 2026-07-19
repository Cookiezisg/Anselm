package mcp

import (
	"context"
	"encoding/json"

	loopapp "github.com/sunweilin/anselm/backend/internal/app/loop"
	mcpapp "github.com/sunweilin/anselm/backend/internal/app/mcp"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
	mcpinfra "github.com/sunweilin/anselm/backend/internal/infra/mcp"
)

// dynamicTool wraps one tool of one installed server as a standard tool.Tool. Name is
// "mcp__<server>__<tool>" (LLM tool names disallow ':'); Parameters is the server's own
// inputSchema verbatim; Execute forwards to Service.CallTool bound to the server's mcp_ id.
// danger is the LLM's per-call self-report — this adapter carries zero danger logic (S18).
//
// dynamicTool 把某 server 的一个工具包成标准 tool.Tool。Name 是 "mcp__<server>__<tool>"
// （LLM tool 名不许冒号）；Parameters 原样用 server 的 inputSchema；Execute 转发到绑定该 server
// mcp_ id 的 Service.CallTool。danger 由 LLM 逐次自报——本适配器零 danger 逻辑（S18）。
type dynamicTool struct {
	serverID    string // mcp_ id (closure-bound; Execute routes by it, not by name)
	serverName  string
	toolName    string
	description string
	schema      json.RawMessage
	svc         *mcpapp.Service
}

var _ toolapp.Tool = (*dynamicTool)(nil)

// TouchEntity self-reports the bound server for the conversation ledger (the loop's marker
// interface) — the mcp_ id, converging with install_mcp_server's ledger key so one server
// aggregates under one item id (the name-prefix fallback would split it, F166's dual-key wart).
//
// TouchEntity 为对话台账自报绑定 server(loop 标记接口)——报 mcp_ id,与 install_mcp_server 的
// 台账键收敛,一个 server 聚成一个 item(名字前缀回退会劈成两行,F166 双键老疣)。
func (t *dynamicTool) TouchEntity() (kind, id, name string) {
	return relationdomain.EntityKindMCP, t.serverID, t.serverName
}

func (t *dynamicTool) Name() string                { return "mcp__" + t.serverName + "__" + t.toolName }
func (t *dynamicTool) Description() string         { return t.description }
func (t *dynamicTool) Parameters() json.RawMessage { return t.schema }

// ValidateInput defers to the MCP server's own validation (the upstream tool checks args).
//
// ValidateInput 交给 MCP server 自身校验（上游工具检查 args）。
func (t *dynamicTool) ValidateInput(json.RawMessage) error { return nil }

func (t *dynamicTool) Execute(ctx context.Context, argsJSON string) (string, error) {
	// Stream the MCP server's progress notifications (if it emits any) live under this tool_call;
	// the final tool result is still the return value. nil-safe off a streamed turn (no-op → plain call).
	//
	// 把 MCP server 的进度通知（若发）实时流在本 tool_call 下；最终结果仍是返回值。非流式 turn 下 nil 安全
	// （no-op → 普通调用）。
	prog := loopapp.ToolProgress(ctx)
	defer prog.Close()
	ctx = mcpinfra.WithProgress(ctx, prog.Print)
	// triggeredBy "" → the service derives chat/agent from ctx (this adapter only runs in the loop).
	//
	// triggeredBy 传 "" → service 从 ctx 推 chat/agent（本适配器只在 loop 内跑）。
	return t.svc.CallTool(ctx, t.serverID, t.toolName, json.RawMessage(argsJSON), "")
}
