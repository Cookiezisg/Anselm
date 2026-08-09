package skill

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	skillapp "github.com/sunweilin/anselm/backend/internal/app/skill"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
	skilldomain "github.com/sunweilin/anselm/backend/internal/domain/skill"
)

// saveSkillArgs is the shared create/edit payload (both write a full SKILL.md).
//
// saveSkillArgs 是 create/edit 共享的载荷（两者都全量写 SKILL.md）。
type saveSkillArgs struct {
	Name                   string   `json:"name"`
	Description            string   `json:"description"`
	Body                   string   `json:"body"`
	AllowedTools           []string `json:"allowedTools"`
	Context                string   `json:"context"`
	Agent                  string   `json:"agent"`
	Arguments              []string `json:"arguments"`
	DisableModelInvocation bool     `json:"disableModelInvocation"`
	UserInvocable          bool     `json:"userInvocable"`
}

// UnmarshalJSON keeps the public schema array-shaped while tolerating the exact JSON-array string
// emitted by some managed callers. This is shared by create_skill and edit_skill so a malformed
// wire encoding does not create a failed card followed by a model retry for the same user intent.
//
// UnmarshalJSON 保持公开 schema 为数组,同时兼容部分托管调用方发出的精确 JSON 数组字符串。
// create_skill 与 edit_skill 共用,避免一次用户意图先失败再被模型重试成两张动作卡。
func (a *saveSkillArgs) UnmarshalJSON(data []byte) error {
	var raw struct {
		Name                   string          `json:"name"`
		Description            string          `json:"description"`
		Body                   string          `json:"body"`
		AllowedTools           json.RawMessage `json:"allowedTools"`
		Context                string          `json:"context"`
		Agent                  string          `json:"agent"`
		Arguments              json.RawMessage `json:"arguments"`
		DisableModelInvocation json.RawMessage `json:"disableModelInvocation"`
		UserInvocable          json.RawMessage `json:"userInvocable"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	allowedTools, err := decodeSkillStringArray(raw.AllowedTools)
	if err != nil {
		return fmt.Errorf("allowedTools: %w", err)
	}
	arguments, err := decodeSkillStringArray(raw.Arguments)
	if err != nil {
		return fmt.Errorf("arguments: %w", err)
	}
	disableModelInvocation, err := decodeSkillBool(raw.DisableModelInvocation)
	if err != nil {
		return fmt.Errorf("disableModelInvocation: %w", err)
	}
	userInvocable, err := decodeSkillBool(raw.UserInvocable)
	if err != nil {
		return fmt.Errorf("userInvocable: %w", err)
	}
	*a = saveSkillArgs{
		Name:                   raw.Name,
		Description:            raw.Description,
		Body:                   raw.Body,
		AllowedTools:           allowedTools,
		Context:                raw.Context,
		Agent:                  raw.Agent,
		Arguments:              arguments,
		DisableModelInvocation: disableModelInvocation,
		UserInvocable:          userInvocable,
	}
	return nil
}

// decodeSkillBool accepts the schema-correct boolean and the exact string form emitted by some
// managed callers. It does not accept numbers or arbitrary truthy values.
//
// decodeSkillBool 接受 schema 正确的布尔值，以及部分托管调用方发出的精确字符串形式；不接受数字或
// 任意 truthy 值，避免模型形状错误静默扩大成业务语义。
func decodeSkillBool(raw json.RawMessage) (bool, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return false, nil
	}
	var value bool
	if err := json.Unmarshal(raw, &value); err == nil {
		return value, nil
	}
	var text string
	if err := json.Unmarshal(raw, &text); err != nil {
		return false, fmt.Errorf("must be boolean or an exact boolean string, got %s", string(raw))
	}
	value, err := strconv.ParseBool(strings.TrimSpace(text))
	if err != nil {
		return false, fmt.Errorf("must be boolean or an exact boolean string, got %q", text)
	}
	return value, nil
}

func decodeSkillStringArray(raw json.RawMessage) ([]string, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return nil, nil
	}

	if raw[0] == '[' {
		var values []string
		if err := json.Unmarshal(raw, &values); err != nil {
			return nil, fmt.Errorf("must be an array of strings or an exact JSON array string, got %s", string(raw))
		}
		return values, nil
	}

	var encoded string
	if err := json.Unmarshal(raw, &encoded); err != nil {
		return nil, fmt.Errorf("must be an array of strings or an exact JSON array string, got %s", string(raw))
	}
	encoded = strings.TrimSpace(encoded)
	if encoded == "" {
		return nil, fmt.Errorf("must be an array of strings or an exact JSON array string, got empty string")
	}
	var values []string
	if err := json.Unmarshal([]byte(encoded), &values); err != nil {
		return nil, fmt.Errorf("must be an array of strings or an exact JSON array string, got %q", encoded)
	}
	return values, nil
}

// toInput maps tool args to the app SaveInput; source marks the AI as author.
//
// toInput 把工具 args 映射成 app SaveInput；source 标记 AI 为作者。
func (a saveSkillArgs) toInput() skillapp.SaveInput {
	return skillapp.SaveInput{
		Name:                   a.Name,
		Description:            a.Description,
		Body:                   a.Body,
		AllowedTools:           a.AllowedTools,
		Context:                a.Context,
		Agent:                  a.Agent,
		Arguments:              a.Arguments,
		DisableModelInvocation: a.DisableModelInvocation,
		UserInvocable:          a.UserInvocable,
		Source:                 skilldomain.SourceAI,
	}
}

const saveSkillSchema = `{
	"type": "object",
	"required": ["name", "description", "body"],
	"properties": {
		"name": {"type": "string", "description": "Lowercase slug, e.g. code-review."},
		"description": {"type": "string", "description": "What the skill does AND when to use it (this is how it gets discovered)."},
		"body": {"type": "string", "description": "Markdown instructions ONLY — do NOT begin the body with a YAML frontmatter block (--- ... ---). The platform builds the frontmatter from these arguments (name/description/allowedTools/...); a frontmatter embedded in the body is rejected (it would otherwise be silently treated as content, dropping its allowedTools). May use $ARGUMENTS / $1 / ${CLAUDE_SESSION_ID} placeholders."},
		"allowedTools": {"type": "array", "items": {"type": "string"}, "description": "Tools pre-approved (skip per-call confirmation) while this skill is active. Managed callers may send the exact JSON array as a string; other scalar/object values are invalid."},
		"context": {"type": "string", "enum": ["inline", "fork"], "description": "inline injects into the current dialogue (default); fork runs in an isolated subagent."},
		"agent": {"type": "string", "description": "Case-sensitive built-in subagent type, required when context=fork: Explore (read-only), Plan (planning), or general-purpose (full parent tools)."},
		"arguments": {"type": "array", "items": {"type": "string"}, "description": "Named argument labels for $name substitution. Managed callers may send the exact JSON array as a string; other scalar/object values are invalid."},
		"disableModelInvocation": {"type": "boolean", "description": "If true, the skill is hidden from the model's catalog (user-only trigger). Managed callers may send the exact string \"true\" or \"false\"; other shapes are invalid."},
		"userInvocable": {"type": "boolean", "description": "If true, the skill is available for explicit user invocation. Managed callers may send the exact string \"true\" or \"false\"; other shapes are invalid."}
	}
}`

func validateSave(tool string, args json.RawMessage) error {
	var a struct {
		Name        string `json:"name"`
		Description string `json:"description"`
		Body        string `json:"body"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("%s: bad args: %w", tool, err)
	}
	if strings.TrimSpace(a.Name) == "" {
		return fmt.Errorf("%s: name is required", tool)
	}
	if strings.TrimSpace(a.Description) == "" {
		return fmt.Errorf("%s: description is required", tool)
	}
	if strings.TrimSpace(a.Body) == "" {
		return fmt.Errorf("%s: body is required", tool)
	}
	return nil
}

// CreateSkill authors a brand-new skill (name conflict → error).
//
// CreateSkill 创作一个全新 skill（同名冲突 → 报错）。
type CreateSkill struct{ svc *skillapp.Service }

func (t *CreateSkill) Name() string { return "create_skill" }

func (t *CreateSkill) Description() string {
	return "Author a NEW skill — a reusable instruction pack you can later activate. Required: name, description, body. Optional: allowedTools (array of tool names to pre-approve), context (inline or fork), agent (case-sensitive Explore, Plan, or general-purpose for fork), arguments (array of named placeholders), disableModelInvocation, userInvocable. Use this to codify a workflow you just performed into a repeatable capability. Fails if the name already exists (use edit_skill to change one)."
}

func (t *CreateSkill) Parameters() json.RawMessage { return json.RawMessage(saveSkillSchema) }

func (t *CreateSkill) ValidateInput(args json.RawMessage) error {
	return validateSave("create_skill", args)
}

func (t *CreateSkill) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args saveSkillArgs
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("create_skill: bad args: %w", err)
	}
	sk, err := t.svc.Create(ctx, args.toInput())
	if err != nil {
		return "", fmt.Errorf("create_skill: %w", err)
	}
	return toolapp.ToJSON(map[string]any{"created": sk.Name}), nil
}

var _ toolapp.Tool = (*CreateSkill)(nil)

// EditSkill overwrites an existing skill (read it first with get_skill to preserve content).
//
// EditSkill 覆盖一个已存在的 skill（先 get_skill 读取以保留内容）。
type EditSkill struct{ svc *skillapp.Service }

func (t *EditSkill) Name() string { return "edit_skill" }

func (t *EditSkill) Description() string {
	return "Overwrite an existing skill's SKILL.md (full replacement). Call get_skill first to retrieve the current content, modify it, then pass the complete new version here. Fails if the skill doesn't exist (use create_skill)."
}

// HaltOnRepeat marks a missing target as a terminal rejection for this turn. A model retry cannot
// make an absent skill appear, and repeating it only creates duplicate red cards; a later user turn
// receives a fresh ledger and may intentionally try again after creating the skill.
//
// HaltOnRepeat 将目标缺失视为本回合终局拒绝。模型重试不会让不存在的 skill 出现，只会制造重复红卡；
// 下一条用户消息拥有新台账，skill 创建后仍可有意重试。
func (*EditSkill) HaltOnRepeat(_ string, errorText string) bool {
	return strings.Contains(strings.ToLower(errorText), "skill not found")
}

func (t *EditSkill) Parameters() json.RawMessage { return json.RawMessage(saveSkillSchema) }

func (t *EditSkill) ValidateInput(args json.RawMessage) error {
	return validateSave("edit_skill", args)
}

func (t *EditSkill) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args saveSkillArgs
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("edit_skill: bad args: %w", err)
	}
	sk, err := t.svc.Replace(ctx, args.toInput())
	if err != nil {
		return "", fmt.Errorf("edit_skill: %w", err)
	}
	return toolapp.ToJSON(map[string]any{"updated": sk.Name}), nil
}

var _ toolapp.Tool = (*EditSkill)(nil)

// DeleteSkill removes a skill directory.
//
// DeleteSkill 删除一个 skill 目录。
type DeleteSkill struct {
	svc  *skillapp.Service
	deps toolapp.DependentCounter
}

func (t *DeleteSkill) Name() string { return "delete_skill" }

func (t *DeleteSkill) MinimumDanger() toolapp.DangerLevel { return toolapp.DangerDangerous }

func (t *DeleteSkill) Description() string {
	return "This call is always dangerous and requires explicit user approval; never downgrade its danger field. Delete a skill permanently (removes its directory). Cannot be undone. The result reports how many agents equipped it (and may now fail) — check get_relations BEFORE deleting."
}

func (t *DeleteSkill) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["name"],
		"properties": {"name": {"type": "string"}}
	}`)
}

func (t *DeleteSkill) ValidateInput(args json.RawMessage) error {
	var a struct {
		Name string `json:"name"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("delete_skill: bad args: %w", err)
	}
	if strings.TrimSpace(a.Name) == "" {
		return ErrNameRequired
	}
	return nil
}

func (t *DeleteSkill) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Name string `json:"name"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("delete_skill: bad args: %w", err)
	}
	// Skill is name-as-id, so its relation id is the skill name (agents equip skills by name).
	// skill 是名即 id，故其 relation id 就是 skill 名（agent 按名 equip skill）。
	deps := toolapp.DependentRefs(ctx, t.deps, relationdomain.EntityKindSkill, args.Name)
	if err := t.svc.Delete(ctx, args.Name); err != nil {
		return "", fmt.Errorf("delete_skill: %w", err)
	}
	return toolapp.ToJSON(toolapp.AnnotateDependents(map[string]any{"deleted": args.Name}, deps)), nil
}

var _ toolapp.Tool = (*DeleteSkill)(nil)
