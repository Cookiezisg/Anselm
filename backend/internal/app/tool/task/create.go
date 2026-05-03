// create.go — TaskCreate system tool: add a new task to the current
// conversation's task list. Returns the freshly-minted Task as JSON so
// the LLM has the assigned ID handy for follow-up TaskUpdate calls.
//
// create.go — TaskCreate 系统工具：往当前对话的任务列表加一条新任务；
// 返回新铸 Task 的 JSON，让 LLM 后续 TaskUpdate 时直接用上分配的 ID。
package task

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	taskapp "github.com/sunweilin/forgify/backend/internal/app/task"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	taskdomain "github.com/sunweilin/forgify/backend/internal/domain/task"
)

const taskCreateDescription = `Create a new task on the current conversation's task list.

Usage:
- Use this when planning multi-step work the user can watch progress on.
- ` + "`subject`" + ` is the imperative verb-first title (e.g. "Run tests", "Fix login bug").
- ` + "`description`" + ` (optional) is a longer note for context.
- ` + "`active_form`" + ` (optional) is the present-continuous form shown in the UI's "in_progress" spinner (e.g. "Running tests").
- ` + "`blocked_by`" + ` (optional) is a list of task IDs that must complete before this one can start.
- New tasks start in status "pending". Use TaskUpdate to move them to "in_progress" / "completed".
- The returned JSON includes the assigned task ID — keep it for follow-up TaskUpdate calls.`

var taskCreateSchema = json.RawMessage(`{
	"type": "object",
	"required": ["subject"],
	"properties": {
		"subject": {
			"type": "string",
			"description": "Imperative one-line title (e.g. \"Run tests\")."
		},
		"description": {
			"type": "string",
			"description": "Longer note for context."
		},
		"active_form": {
			"type": "string",
			"description": "Present continuous form (e.g. \"Running tests\")."
		},
		"blocked_by": {
			"type": "array",
			"items": {"type": "string"},
			"description": "Task IDs that must complete before this one starts."
		}
	}
}`)

// TaskCreate implements the TaskCreate system tool.
//
// TaskCreate struct 是 TaskCreate 系统工具。
type TaskCreate struct {
	svc *taskapp.Service
}

func (t *TaskCreate) Name() string                { return "TaskCreate" }
func (t *TaskCreate) Description() string         { return taskCreateDescription }
func (t *TaskCreate) Parameters() json.RawMessage { return taskCreateSchema }

func (t *TaskCreate) IsReadOnly() bool        { return false }
func (t *TaskCreate) NeedsReadFirst() bool    { return false }
func (t *TaskCreate) RequiresWorkspace() bool { return false }

// ValidateInput rejects empty subject pre-Execute.
//
// ValidateInput 在 Execute 前拒绝空 subject。
func (t *TaskCreate) ValidateInput(args json.RawMessage) error {
	var a struct {
		Subject string `json:"subject"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("TaskCreate.ValidateInput: %w", err)
	}
	if strings.TrimSpace(a.Subject) == "" {
		return taskdomain.ErrSubjectRequired
	}
	return nil
}

func (t *TaskCreate) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

// Execute creates the task via Service and returns the new entity as
// indented JSON.
//
// Execute 通过 Service 创建任务，返新 entity 的缩进 JSON。
func (t *TaskCreate) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Subject     string   `json:"subject"`
		Description string   `json:"description"`
		ActiveForm  string   `json:"active_form"`
		BlockedBy   []string `json:"blocked_by"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("TaskCreate.Execute: %w", err)
	}
	created, err := t.svc.Create(ctx, taskapp.CreateInput{
		Subject:     args.Subject,
		Description: args.Description,
		ActiveForm:  args.ActiveForm,
		BlockedBy:   args.BlockedBy,
	})
	if err != nil {
		return classifyTaskErr(err, "create"), nil
	}
	return marshalIndent(created)
}

// ── shared helpers ───────────────────────────────────────────────────────────

// classifyTaskErr converts a Service error into an LLM-friendly string.
// Sentinels become recoverable hints; anything else surfaces with a
// generic prefix so the LLM doesn't latch onto wrapping noise.
//
// classifyTaskErr 把 Service 错转友好字符串。Sentinel 给可恢复提示；其他
// 走通用前缀，避免 LLM 抓到包装噪声。
func classifyTaskErr(err error, op string) string {
	switch {
	case errors.Is(err, taskdomain.ErrNotFound):
		return "Task not found in this conversation."
	case errors.Is(err, taskdomain.ErrSubjectRequired):
		return "Task subject is required and must be non-empty."
	case errors.Is(err, taskdomain.ErrInvalidStatus):
		return "Invalid status. Allowed: pending, in_progress, completed, deleted."
	}
	return fmt.Sprintf("Task %s failed: %v", op, err)
}

// marshalIndent emits the entity as pretty-printed JSON the LLM can
// quote back if useful.
//
// marshalIndent 输出 entity 的缩进 JSON，方便 LLM 引用。
func marshalIndent(v any) (string, error) {
	body, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return "", fmt.Errorf("marshal: %w", err)
	}
	return string(body), nil
}
