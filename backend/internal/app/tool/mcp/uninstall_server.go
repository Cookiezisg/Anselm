// uninstall_server.go — uninstall_mcp_server system tool: removes a
// previously-installed MCP server from mcp.json + disconnects it. Symmetric
// with install_mcp_server. Permission stays Allow because real user
// consent runs through the LLM-driven ask flow (framework-level Ask
// would pop a UI dialog, breaking the in-LLM orchestration).
//
// uninstall_server.go ——uninstall_mcp_server 系统工具：从 mcp.json 移除已装
// MCP server + 断连。与 install_mcp_server 对称。权限留 Allow，因真用户
// 同意走 LLM 驱动的 ask 流（框架级 Ask 会弹 UI 对话框，破坏 in-LLM 编排）。
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

// UninstallMCPServer implements the uninstall_mcp_server system tool.
//
// UninstallMCPServer 实现 uninstall_mcp_server 系统工具。
type UninstallMCPServer struct {
	svc *mcpapp.Service
}

const uninstallMCPServerDescription = `Uninstall a previously-installed MCP server: removes it from the MCP configuration and disconnects it. Pass the canonical short name the server was installed under (e.g. "playwright", "duckduckgo") — same name returned by list_mcp_marketplace and install_mcp_server.`

var uninstallMCPServerSchema = json.RawMessage(`{
	"type": "object",
	"properties": {
		"name": {"type": "string", "description": "Canonical short name of the installed server (e.g. 'playwright'). Same value as install_mcp_server's name field."}
	},
	"required": ["name"]
}`)

func (t *UninstallMCPServer) Name() string                { return "uninstall_mcp_server" }
func (t *UninstallMCPServer) Description() string         { return uninstallMCPServerDescription }
func (t *UninstallMCPServer) Parameters() json.RawMessage { return uninstallMCPServerSchema }

func (t *UninstallMCPServer) IsReadOnly() bool        { return false }
func (t *UninstallMCPServer) NeedsReadFirst() bool    { return false }
func (t *UninstallMCPServer) RequiresWorkspace() bool { return false }

func (t *UninstallMCPServer) ValidateInput(args json.RawMessage) error {
	var a struct {
		Name string `json:"name"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("uninstall_mcp_server: bad args: %w", err)
	}
	if strings.TrimSpace(a.Name) == "" {
		return errors.New("uninstall_mcp_server: name is required")
	}
	return nil
}

func (t *UninstallMCPServer) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *UninstallMCPServer) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Name string `json:"name"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("uninstall_mcp_server: %w", err)
	}

	if err := t.svc.RemoveServer(ctx, args.Name); err != nil {
		if errors.Is(err, mcpdomain.ErrServerNotFound) {
			return errorJSON("not_installed",
				fmt.Sprintf("No installed server named %q.", args.Name)), nil
		}
		return "", fmt.Errorf("uninstall_mcp_server: %w", err)
	}
	envelope := map[string]any{
		"status": "uninstalled",
		"name":   args.Name,
	}
	b, _ := json.Marshal(envelope)
	return string(b), nil
}
