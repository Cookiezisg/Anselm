package mcp

import (
	"context"
	"encoding/json"
	"fmt"

	mcpapp "github.com/sunweilin/forgify/backend/internal/app/mcp"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	mcpdomain "github.com/sunweilin/forgify/backend/internal/domain/mcp"
)

// ListMCPMarketplace implements the list_mcp_marketplace system tool.
//
// ListMCPMarketplace 是 list_mcp_marketplace 系统工具的实现。
type ListMCPMarketplace struct {
	svc *mcpapp.Service
}

const listMarketplaceDescription = `List the curated MCP marketplace when a capability is needed but no installed server matches (search_mcp_tools came up empty). Returns entries (name, description, runtime, category, tier 0–3, requiredEnv/requiredArgs, notes) sorted by tier then name. Then call install_mcp_server with the chosen name.`

var listMarketplaceSchema = json.RawMessage(`{
	"type": "object",
	"properties": {}
}`)

func (t *ListMCPMarketplace) Name() string                { return "list_mcp_marketplace" }
func (t *ListMCPMarketplace) Description() string         { return listMarketplaceDescription }
func (t *ListMCPMarketplace) Parameters() json.RawMessage { return listMarketplaceSchema }

func (t *ListMCPMarketplace) IsReadOnly() bool        { return true }
func (t *ListMCPMarketplace) NeedsReadFirst() bool    { return false }
func (t *ListMCPMarketplace) RequiresWorkspace() bool { return false }

func (t *ListMCPMarketplace) ValidateInput(json.RawMessage) error { return nil }

func (t *ListMCPMarketplace) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}


func (t *ListMCPMarketplace) Execute(ctx context.Context, _ string) (string, error) {
	all, err := t.svc.ListRegistry(ctx)
	if err != nil {
		return "", fmt.Errorf("list_mcp_marketplace: %w", err)
	}
	return marshalMarketplaceResults(all), nil
}

// marshalMarketplaceResults renders RegistryEntry as a slim LLM-facing JSON shape (no InstallCmd internals).
//
// marshalMarketplaceResults 把 RegistryEntry 渲染成瘦 LLM-facing JSON（不含 InstallCmd 内部）。
func marshalMarketplaceResults(entries []mcpdomain.RegistryEntry) string {
	type result struct {
		Name         string                     `json:"name"`
		Description  string                     `json:"description"`
		Category     string                     `json:"category,omitempty"`
		Tier         int                        `json:"tier"`
		Runtime      string                     `json:"runtime"`
		Homepage     string                     `json:"homepage,omitempty"`
		RequiredEnv  []mcpdomain.EnvRequirement `json:"requiredEnv,omitempty"`
		RequiredArgs []mcpdomain.ArgRequirement `json:"requiredArgs,omitempty"`
		Notes        string                     `json:"notes,omitempty"`
	}
	out := make([]result, 0, len(entries))
	for _, e := range entries {
		out = append(out, result{
			Name:         e.Name,
			Description:  e.Description,
			Category:     e.Category,
			Tier:         e.Tier,
			Runtime:      e.Runtime,
			Homepage:     e.Homepage,
			RequiredEnv:  e.RequiredEnv,
			RequiredArgs: e.RequiredArgs,
			Notes:        e.Notes,
		})
	}
	b, _ := json.Marshal(out)
	return string(b)
}
