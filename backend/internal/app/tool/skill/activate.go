// activate.go — activate_skill system tool. LLM calls this to load a
// skill's body, set its allowed-tools as pre-approved on agentstate,
// and either get the substituted body back as the tool result OR see
// the result of a forked subagent that ran the body in isolation.
//
// activate.go ——activate_skill 系统工具。LLM 调它加载 skill body、把
// allowed-tools 在 agentstate 设为预授权，要么拿替换后 body 当 tool
// result，要么看 fork 出去的 subagent 跑完 body 的结果。
package skill

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	skillapp "github.com/sunweilin/forgify/backend/internal/app/skill"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	skilldomain "github.com/sunweilin/forgify/backend/internal/domain/skill"
)

// ErrEmptyName — `name` arg missing or whitespace.
//
// ErrEmptyName：name 缺失或全空白。
var ErrEmptyName = errors.New("name is required and must be non-empty")

const activateSkillDescription = `Load a skill's full instructions. The result is the substituted body text (or, when the skill declares context: fork, the final output of an isolated subagent that ran the body). Activation also pre-approves the skill's allowed-tools for the rest of this conversation.`

var activateSkillSchema = json.RawMessage(`{
	"type": "object",
	"required": ["name"],
	"properties": {
		"name": {
			"type": "string",
			"description": "Skill name (from search_skills result, or known by convention like 'pr-review')."
		},
		"arguments": {
			"type": "array",
			"items": {"type": "string"},
			"description": "Positional arguments substituted into $1, $2, ..., $ARGUMENTS, and named placeholders matching the skill's frontmatter.arguments declaration."
		}
	}
}`)

// ActivateSkill implements the activate_skill system tool.
//
// ActivateSkill struct 是 activate_skill 系统工具。
type ActivateSkill struct {
	svc *skillapp.Service
}

// Identity --------------------------------------------------------------------

func (t *ActivateSkill) Name() string                { return "activate_skill" }
func (t *ActivateSkill) Description() string         { return activateSkillDescription }
func (t *ActivateSkill) Parameters() json.RawMessage { return activateSkillSchema }

// Static metadata -------------------------------------------------------------

// IsReadOnly = false because activate_skill writes to AgentState
// (ActiveSkill side-channel) — even though no disk write happens, the
// state mutation has observable effect on subsequent tool dispatches
// (permission decisions). False keeps it serialized in the same
// execution_group as other state-mutating tools.
//
// IsReadOnly = false：activate_skill 改 AgentState（ActiveSkill 旁路）
// ——虽不写 disk，state 突变影响后续 tool dispatch（权限决策）。false 让
// 其与其他 state-mutating tool 同 execution_group 串行。
func (t *ActivateSkill) IsReadOnly() bool        { return false }
func (t *ActivateSkill) NeedsReadFirst() bool    { return false }
func (t *ActivateSkill) RequiresWorkspace() bool { return false }

// ── Args-dependent hooks ─────────────────────────────────────────────

func (t *ActivateSkill) ValidateInput(args json.RawMessage) error {
	var a struct {
		Name string `json:"name"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("activate_skill.ValidateInput: %w", err)
	}
	if strings.TrimSpace(a.Name) == "" {
		return ErrEmptyName
	}
	return nil
}

func (t *ActivateSkill) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

// ── Execute ──────────────────────────────────────────────────────────

// Execute parses args, calls Service.Activate, and returns the body
// (or fork result) as the tool result. Failure modes mapped to friendly
// strings per §S18 so the LLM can read the situation:
//   - ErrSkillNotFound → suggest search_skills first
//   - ErrBodyTooLarge  → suggest the user shrink the SKILL.md
//   - other errors     → opaque pass-through (rare; logged at Warn)
//
// Execute 解析 args，调 Service.Activate，返 body（或 fork 结果）当 tool
// result。失败映射 §S18 友好字符串：未找到 → 建议先 search_skills；
// body 超大 → 建议用户缩 SKILL.md；其他 → 透传（罕见；Warn log）。
func (t *ActivateSkill) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Name      string   `json:"name"`
		Arguments []string `json:"arguments"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("activate_skill.Execute: parse args: %w", err)
	}

	out, err := t.svc.Activate(ctx, args.Name, args.Arguments)
	if err == nil {
		return out, nil
	}

	switch {
	case errors.Is(err, skilldomain.ErrSkillNotFound):
		return fmt.Sprintf("Skill %q not found. Call search_skills first to see what's available.", args.Name), nil
	case errors.Is(err, skilldomain.ErrBodyTooLarge):
		return fmt.Sprintf("Skill %q body exceeds the %d-byte limit. Ask the user to split long instructions into separate resource files.", args.Name, skilldomain.MaxBodyBytes), nil
	default:
		// Subagent spawn failure / unexpected I/O. Wrap so framework
		// sanitizer (loop/tools.go) strips internal §S16 prefix chain
		// before the LLM sees the inner reason.
		// subagent spawn 失败 / 意外 I/O。包装让 framework sanitizer
		// 剥 §S16 前缀链，LLM 仅看最里层原因。
		return "", fmt.Errorf("activate_skill: %w", err)
	}
}

// ── Compile-time checks ──────────────────────────────────────────────

var _ toolapp.Tool = (*ActivateSkill)(nil)
