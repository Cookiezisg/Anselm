// run.go — run_forge system tool: executes a user forge in the Python sandbox.
// File-path arguments starting with "att_" are auto-resolved to attachment
// storage paths. Output is truncated at 50KB to protect LLM context.
//
// run.go — run_forge 系统工具：在 Python 沙箱中执行用户 forge。
// 以 "att_" 开头的文件路径参数自动解析为附件存储路径。
// 输出截断 50KB 保护 LLM context。
package forge

import (
	"context"
	"encoding/json"
	"fmt"

	forgeapp "github.com/sunweilin/forgify/backend/internal/app/forge"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
)

// maxOutputBytes caps RunForge's serialized output to prevent runaway forges
// from blowing up LLM context (e.g., a forge that prints a 100MB list).
//
// maxOutputBytes 限制 RunForge 序列化后的输出大小，防止失控 forge 把 LLM
// context 撑爆（例如打印 100MB 列表的 forge）。
const maxOutputBytes = 50 * 1024

// RunForge implements the run_forge system tool.
//
// RunForge 实现 run_forge 系统工具。
type RunForge struct {
	svc        *forgeapp.Service
	attachRepo chatdomain.Repository
}

// ── Identity ──────────────────────────────────────────────────────────────────

func (t *RunForge) Name() string { return "run_forge" }

func (t *RunForge) Description() string {
	return "Execute a user forge with the given input. " +
		"Returns the forge output. Execution failures return ok=false (not an error). " +
		"File paths starting with 'att_' are resolved automatically from uploaded attachments. " +
		"Output is truncated at 50KB; if you expect huge output, have the forge write to a file instead."
}

func (t *RunForge) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"forge_id": {"type": "string", "description": "Forge to execute"},
			"input":    {"type": "object", "description": "Input parameters matching the forge's signature"}
		},
		"required": ["forge_id", "input"]
	}`)
}

// ── Static metadata ───────────────────────────────────────────────────────────

func (t *RunForge) IsReadOnly() bool        { return false }
func (t *RunForge) NeedsReadFirst() bool    { return false }
func (t *RunForge) RequiresWorkspace() bool { return false }

// ── Args-dependent hooks ──────────────────────────────────────────────────────

func (t *RunForge) IsConcurrencySafe(json.RawMessage) bool { return false }

func (t *RunForge) ValidateInput(json.RawMessage) error { return nil }

func (t *RunForge) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

// ── Execute ───────────────────────────────────────────────────────────────────

func (t *RunForge) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		ForgeID string         `json:"forge_id"`
		Input   map[string]any `json:"input"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("run_forge: bad args: %w", err)
	}
	resolved, err := resolveAttachments(ctx, t.attachRepo, args.Input)
	if err != nil {
		return "", fmt.Errorf("run_forge: resolve attachments: %w", err)
	}
	result, err := t.svc.RunForge(ctx, args.ForgeID, resolved)
	if err != nil {
		return "", fmt.Errorf("run_forge: %w", err)
	}

	// Truncate oversized output. Marshal the candidate first to measure
	// its actual JSON-encoded size; if too big, replace with a notice string
	// so the LLM sees a clear signal instead of a partial broken value.
	//
	// 截断超大输出。先 marshal 候选值看实际 JSON 编码后大小；过大就替换为提示
	// 字符串，让 LLM 看到明确信号而非部分损坏的值。
	output := result.Output
	if rawOut, err := json.Marshal(output); err == nil && len(rawOut) > maxOutputBytes {
		output = fmt.Sprintf("[output truncated: %d bytes exceeds %d-byte limit; "+
			"have the forge write to a file or return a smaller summary]", len(rawOut), maxOutputBytes)
	}

	b, _ := json.Marshal(map[string]any{
		"ok":         result.OK,
		"output":     output,
		"error":      result.ErrorMsg,
		"elapsed_ms": result.ElapsedMs,
	})
	return string(b), nil
}
