package skill

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"strings"

	skillapp "github.com/sunweilin/anselm/backend/internal/app/skill"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
)

// ActivateSkill is the core skill tool: load → substitute → inject (inline) or fork.
//
// ActivateSkill 是核心 skill 工具：加载 → 替换 → 注入（inline）或 fork。
type ActivateSkill struct{ svc *skillapp.Service }

func (t *ActivateSkill) Name() string { return "activate_skill" }

func (t *ActivateSkill) Description() string {
	return "Activate a skill — load its instructions, substitute $ARGUMENTS/$1.. placeholders, and either inject the rendered instructions into your context (inline skills) or run them in an isolated subagent (fork skills). Returns the rendered instructions (inline) or the subagent's result (fork). Find skills in the capability catalog."
}

func (t *ActivateSkill) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["name"],
		"properties": {
			"name": {"type": "string", "description": "Skill name (a slug, from the catalog)."},
			"arguments": {"type": "array", "items": {"type": "string"}, "description": "Positional arguments for $1/$ARGUMENTS substitution. Managed callers may send the exact JSON array as a string; other scalar/object values are invalid."}
		}
	}`)
}

func (t *ActivateSkill) ValidateInput(args json.RawMessage) error {
	var a activateSkillArgs
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("activate_skill: bad args: %w", err)
	}
	if strings.TrimSpace(a.Name) == "" {
		return ErrNameRequired
	}
	return nil
}

func (t *ActivateSkill) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args activateSkillArgs
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("activate_skill: bad args: %w", err)
	}
	out, err := t.svc.Activate(ctx, args.Name, args.Arguments)
	if err != nil {
		return "", fmt.Errorf("activate_skill: %w", err)
	}
	return out, nil
}

type activateSkillArgs struct {
	Name      string
	Arguments []string
}

// UnmarshalJSON keeps the public schema array-shaped while tolerating the exact JSON-array string
// emitted by some managed callers. It never turns arbitrary text, numbers, objects, or mixed
// arrays into arguments.
func (a *activateSkillArgs) UnmarshalJSON(data []byte) error {
	var raw struct {
		Name      string          `json:"name"`
		Arguments json.RawMessage `json:"arguments"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	arguments, err := decodeActivateSkillArguments(raw.Arguments)
	if err != nil {
		return fmt.Errorf("arguments: %w", err)
	}
	*a = activateSkillArgs{Name: raw.Name, Arguments: arguments}
	return nil
}

func decodeActivateSkillArguments(raw json.RawMessage) ([]string, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return nil, nil
	}

	if raw[0] == '[' {
		var arguments []string
		if err := json.Unmarshal(raw, &arguments); err != nil {
			return nil, fmt.Errorf("must be an array of strings or an exact JSON array string, got %s", string(raw))
		}
		return arguments, nil
	}

	var encoded string
	if err := json.Unmarshal(raw, &encoded); err != nil {
		return nil, fmt.Errorf("must be an array of strings or an exact JSON array string, got %s", string(raw))
	}
	encoded = strings.TrimSpace(encoded)
	if encoded == "" {
		return nil, fmt.Errorf("must be an array of strings or an exact JSON array string, got empty string")
	}
	var arguments []string
	if err := json.Unmarshal([]byte(encoded), &arguments); err != nil {
		return nil, fmt.Errorf("must be an array of strings or an exact JSON array string, got %q", encoded)
	}
	return arguments, nil
}

var _ toolapp.Tool = (*ActivateSkill)(nil)

// GetSkill reads a skill's full SKILL.md without activating it (supports edit-after-read).
//
// GetSkill 读取 skill 的完整 SKILL.md 而不激活（支撑先读后改）。
type GetSkill struct{ svc *skillapp.Service }

func (t *GetSkill) Name() string { return "get_skill" }

func (t *GetSkill) Description() string {
	return "Read one skill's full content (frontmatter + body) WITHOUT activating it — useful before edit_skill to see the current text."
}

func (t *GetSkill) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["name"],
		"properties": {"name": {"type": "string"}}
	}`)
}

func (t *GetSkill) ValidateInput(args json.RawMessage) error {
	var a struct {
		Name string `json:"name"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("get_skill: bad args: %w", err)
	}
	if strings.TrimSpace(a.Name) == "" {
		return ErrNameRequired
	}
	return nil
}

func (t *GetSkill) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Name string `json:"name"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("get_skill: bad args: %w", err)
	}
	sk, err := t.svc.Get(ctx, args.Name)
	if err != nil {
		return "", fmt.Errorf("get_skill: %w", err)
	}
	return toolapp.ToJSON(sk), nil
}

var _ toolapp.Tool = (*GetSkill)(nil)
