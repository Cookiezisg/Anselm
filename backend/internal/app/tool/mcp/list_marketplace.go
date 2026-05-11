// list_marketplace.go — list_mcp_marketplace system tool: returns the
// full curated marketplace catalog (~21 entries) so the LLM can pick
// what to install. V3 (2026-05-09) replaces the V2 search-based tool
// — the curated catalog is small enough that full enumeration costs
// less context than burning a round trip + LLM rerank on a keyword
// AND-match that empirically missed obvious matches.
//
// list_marketplace.go ——list_mcp_marketplace 系统工具：返 curated
// marketplace 全部 ~21 条让 LLM 自己挑装哪个。V3（2026-05-09）替代 V2
// 基于搜索的工具——curated 太小，全列入 context 比 LLM rerank +
// 关键词 AND-match（实测漏 playwright/browser/github/slack 等明显项）
// 性价比更高。
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
// ListMCPMarketplace 实现 list_mcp_marketplace 系统工具。
type ListMCPMarketplace struct {
	svc *mcpapp.Service
}

const listMarketplaceDescription = `List the curated MCP marketplace catalog. Use when an MCP capability is needed but no matching server is currently installed (search_mcp_tools returned nothing).

Returns a JSON array sorted tier-asc then name-asc. Each entry carries:
- name: canonical id used by install_mcp_server
- description, runtime (node/python), homepage, category
- tier: 0=zero-config, 1=one API key, 2=OAuth device-code, 3=DB connection string
- requiredEnv / requiredArgs (with setupURL when an external key/account is needed)
- notes: first-run gotchas worth relaying to the user

After choosing a server, call install_mcp_server({name}) to begin the install. See that tool's docs for the two-phase confirmation flow.`

var listMarketplaceSchema = json.RawMessage(`{
	"type": "object",
	"properties": {}
}`)

// Identity --------------------------------------------------------------------
func (t *ListMCPMarketplace) Name() string                { return "list_mcp_marketplace" }
func (t *ListMCPMarketplace) Description() string         { return listMarketplaceDescription }
func (t *ListMCPMarketplace) Parameters() json.RawMessage { return listMarketplaceSchema }

// Static metadata -------------------------------------------------------------
func (t *ListMCPMarketplace) IsReadOnly() bool        { return true }
func (t *ListMCPMarketplace) NeedsReadFirst() bool    { return false }
func (t *ListMCPMarketplace) RequiresWorkspace() bool { return false }

// Args-dependent hooks --------------------------------------------------------
func (t *ListMCPMarketplace) ValidateInput(json.RawMessage) error { return nil }

func (t *ListMCPMarketplace) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

// ── Execute ───────────────────────────────────────────────────────────

func (t *ListMCPMarketplace) Execute(ctx context.Context, _ string) (string, error) {
	all, err := t.svc.ListRegistry(ctx)
	if err != nil {
		return "", fmt.Errorf("list_mcp_marketplace: %w", err)
	}
	return marshalMarketplaceResults(all), nil
}

// marshalMarketplaceResults renders RegistryEntry slice as the JSON
// shape the LLM consumes — slimmer than the full RegistryEntry to
// avoid burning tokens on InstallCmd internals. LLM only needs
// name/description/category/tier/runtime/homepage + user-supplied
// requirements + notes.
//
// marshalMarketplaceResults 把 RegistryEntry 切片渲染成 LLM 消费的 JSON——
// 比完整 RegistryEntry 瘦避免在 InstallCmd 内部细节烧 token。
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
