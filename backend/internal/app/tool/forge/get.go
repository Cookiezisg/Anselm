// get.go — get_forge system tool: returns full details of a single forge,
// including its complete Python code and recent test summary.
//
// get.go — get_forge 系统工具：返回单个 forge 的完整详情，包括完整 Python 代码和近期测试摘要。
package forge

import (
	"context"
	"encoding/json"
	"fmt"

	forgeapp "github.com/sunweilin/forgify/backend/internal/app/forge"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

// GetForge implements the get_forge system tool.
//
// GetForge 实现 get_forge 系统工具。
type GetForge struct {
	svc *forgeapp.Service
}

// ── Identity ──────────────────────────────────────────────────────────────────

func (t *GetForge) Name() string { return "get_forge" }

func (t *GetForge) Description() string {
	return "Get the full details of a specific forge including its complete Python code " +
		"and recent test summary. Use this to verify a candidate forge before running it."
}

func (t *GetForge) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"forge_id": {"type": "string", "description": "The forge ID (f_xxx) to retrieve"}
		},
		"required": ["forge_id"]
	}`)
}

// ── Static metadata ───────────────────────────────────────────────────────────

func (t *GetForge) IsReadOnly() bool        { return true }
func (t *GetForge) NeedsReadFirst() bool    { return false }
func (t *GetForge) RequiresWorkspace() bool { return false }

// ── Args-dependent hooks ──────────────────────────────────────────────────────


func (t *GetForge) ValidateInput(json.RawMessage) error { return nil }

func (t *GetForge) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

// ── Execute ───────────────────────────────────────────────────────────────────

func (t *GetForge) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		ForgeID string `json:"forge_id"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("get_forge: bad args: %w", err)
	}
	detail, err := t.svc.GetDetail(ctx, args.ForgeID)
	if err != nil {
		return "", fmt.Errorf("get_forge: %w", err)
	}
	var params, ret any
	if err := json.Unmarshal([]byte(detail.Parameters), &params); err != nil {
		return "", fmt.Errorf("get_forge: corrupted parameters for forge %q: %w", args.ForgeID, err)
	}
	if err := json.Unmarshal([]byte(detail.ReturnSchema), &ret); err != nil {
		return "", fmt.Errorf("get_forge: corrupted return_schema for forge %q: %w", args.ForgeID, err)
	}
	out := map[string]any{
		"id": detail.ID, "name": detail.Name, "description": detail.Description,
		"code": detail.Code, "parameters": params, "returnSchema": ret,
		"tags": detail.Tags, "versionCount": detail.VersionCount,
		"testSummary": map[string]any{
			"total":        detail.TestSummary.Total,
			"lastPassRate": detail.TestSummary.LastPassRate,
			"lastRunAt":    detail.TestSummary.LastRunAt,
		},
	}
	b, _ := json.Marshal(out)
	return string(b), nil
}
