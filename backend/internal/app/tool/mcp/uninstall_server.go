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

const uninstallMCPServerDescription = `Uninstall a previously-installed MCP server. Removes it from mcp.json and disconnects the subprocess. Pass the local alias the server was installed under (e.g. "duckduckgo-search"), NOT the registry namespace name.

For Docker-runtime servers, the container is removed automatically (--rm) but the cached image stays in the docker daemon's image cache. Run ` + "`docker image prune`" + ` manually to reclaim disk space if many docker MCP images accumulate.`

var uninstallMCPServerSchema = json.RawMessage(`{
	"type": "object",
	"properties": {
		"alias": {"type": "string", "description": "Local alias of the server to uninstall (e.g. 'duckduckgo-search'). NOT the registry namespace name."}
	},
	"required": ["alias"]
}`)

func (t *UninstallMCPServer) Name() string                { return "uninstall_mcp_server" }
func (t *UninstallMCPServer) Description() string         { return uninstallMCPServerDescription }
func (t *UninstallMCPServer) Parameters() json.RawMessage { return uninstallMCPServerSchema }

func (t *UninstallMCPServer) IsReadOnly() bool        { return false }
func (t *UninstallMCPServer) NeedsReadFirst() bool    { return false }
func (t *UninstallMCPServer) RequiresWorkspace() bool { return false }

func (t *UninstallMCPServer) ValidateInput(args json.RawMessage) error {
	var a struct {
		Alias string `json:"alias"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("uninstall_mcp_server: bad args: %w", err)
	}
	if strings.TrimSpace(a.Alias) == "" {
		return errors.New("uninstall_mcp_server: alias is required")
	}
	return nil
}

func (t *UninstallMCPServer) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *UninstallMCPServer) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Alias string `json:"alias"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("uninstall_mcp_server: %w", err)
	}

	if err := t.svc.RemoveServer(ctx, args.Alias); err != nil {
		if errors.Is(err, mcpdomain.ErrServerNotFound) {
			return errorJSON("not_installed",
				fmt.Sprintf("No installed server with alias %q. Use the MCP servers UI or check ~/.forgify/mcp.json for current aliases.", args.Alias)), nil
		}
		return "", fmt.Errorf("uninstall_mcp_server: %w", err)
	}
	envelope := map[string]any{
		"status":  "uninstalled",
		"alias":   args.Alias,
		"message": fmt.Sprintf("Server %q uninstalled and disconnected.", args.Alias),
	}
	b, _ := json.Marshal(envelope)
	return string(b), nil
}
