// dispatch_mcp.go — MCPDispatcher. Reads node.Config keys `serverName`
// + `tool` + `args` and calls mcpapp.Service.CallTool. Result is a raw
// JSON string (MCP wire format) returned on the default "out" port.
//
// dispatch_mcp.go —— MCPDispatcher;CallTool 返 raw JSON string,挂 "out"
// port。

package scheduler

import (
	"context"
	"encoding/json"
	"fmt"

	mcpapp "github.com/sunweilin/forgify/backend/internal/app/mcp"
)

// MCPDispatcher bridges workflow mcp nodes to mcpapp.Service.CallTool.
//
// MCPDispatcher 桥接 workflow mcp 节点到 mcpapp.CallTool。
type MCPDispatcher struct {
	svc *mcpapp.Service
}

// NewMCPDispatcher constructs MCPDispatcher.
//
// NewMCPDispatcher 构造 MCPDispatcher。
func NewMCPDispatcher(svc *mcpapp.Service) *MCPDispatcher {
	return &MCPDispatcher{svc: svc}
}

// Dispatch reads serverName + tool + args from node.Config.
//
// Dispatch 读 serverName + tool + args 调 MCP。
func (d *MCPDispatcher) Dispatch(ctx context.Context, in DispatchInput) DispatchOutput {
	serverName, _ := in.Node.Config["serverName"].(string)
	tool, _ := in.Node.Config["tool"].(string)
	if serverName == "" {
		return DispatchOutput{Error: fmt.Errorf("mcp node %q: serverName required", in.Node.ID)}
	}
	if tool == "" {
		return DispatchOutput{Error: fmt.Errorf("mcp node %q: tool required", in.Node.ID)}
	}
	args, _ := in.Node.Config["args"].(map[string]any)
	argsJSON, err := json.Marshal(args)
	if err != nil {
		return DispatchOutput{Error: fmt.Errorf("mcp node %q: marshal args: %w", in.Node.ID, err)}
	}

	result, err := d.svc.CallTool(ctx, serverName, tool, argsJSON)
	if err != nil {
		return DispatchOutput{Error: err}
	}
	return DispatchOutput{Outputs: map[string]any{"out": result}}
}
