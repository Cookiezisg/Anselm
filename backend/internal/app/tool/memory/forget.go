package memory

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	memoryapp "github.com/sunweilin/anselm/backend/internal/app/memory"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	memorydomain "github.com/sunweilin/anselm/backend/internal/domain/memory"
)

const forgetMemoryDescription = `This call is always dangerous and requires explicit user approval; never downgrade its danger field. Permanently delete a memory by name when the fact is obsolete or wrong. This cannot be undone and has no restore operation: set danger="dangerous" and wait for the user's approval before calling it. The markdown file is removed and the memory will no longer appear in future context.`

var forgetMemorySchema = json.RawMessage(`{
	"type": "object",
	"required": ["name"],
	"properties": {
		"name": {"type": "string", "description": "Memory name (slug) to delete."}
	}
}`)

// ForgetMemory implements the forget_memory system tool.
//
// ForgetMemory 是 forget_memory 系统工具的实现。
type ForgetMemory struct{ svc *memoryapp.Service }

func (t *ForgetMemory) Name() string { return "forget_memory" }

// MinimumDanger makes the irreversible file deletion a fact of the tool, not a model opinion.
//
// MinimumDanger 将不可逆文件删除定义为工具事实，而不是模型意见。
func (t *ForgetMemory) MinimumDanger() toolapp.DangerLevel { return toolapp.DangerDangerous }

func (t *ForgetMemory) Description() string         { return forgetMemoryDescription }
func (t *ForgetMemory) Parameters() json.RawMessage { return forgetMemorySchema }

func (t *ForgetMemory) ValidateInput(args json.RawMessage) error {
	var a struct {
		Name string `json:"name"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("forget_memory: bad args: %w", err)
	}
	if strings.TrimSpace(a.Name) == "" {
		return ErrEmptyName
	}
	return nil
}

func (t *ForgetMemory) Execute(ctx context.Context, argsJSON string) (string, error) {
	var a struct {
		Name string `json:"name"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
		return "", fmt.Errorf("forget_memory: %w", err)
	}
	if err := t.svc.Delete(ctx, a.Name); err != nil {
		if errors.Is(err, memorydomain.ErrNotFound) {
			return fmt.Sprintf("Memory %q not found (already gone?).", a.Name), nil
		}
		return "", err
	}
	return fmt.Sprintf("Forgot memory %q.", a.Name), nil
}
