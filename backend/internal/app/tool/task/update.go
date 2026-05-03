// update.go — TaskUpdate system tool: change a task's status or other
// fields. Pointer fields in the schema map to "set" semantics — omit a
// field to leave it unchanged. Status transitions are validated against
// the whitelist; status:"deleted" soft-deletes via the Service.
//
// update.go — TaskUpdate 系统工具：改任务状态或其他字段。schema 字段缺
// 即"不变"；status 按白名单校验；status:"deleted" 走 Service 软删。
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

const taskUpdateDescription = `Update a task's status or other fields.

Usage:
- ` + "`task_id`" + ` is the ID returned by TaskCreate (or seen in TaskList).
- Provide only the fields you want to change; omitted fields stay as-is.
- ` + "`status`" + ` transitions: pending → in_progress → completed. Use "deleted" to remove a task; the deletion broadcasts an SSE update so any UI drops it.
- ` + "`subject`" + ` / ` + "`description`" + ` / ` + "`active_form`" + ` / ` + "`owner`" + ` are simple replacements.
- ` + "`blocked_by`" + ` replaces the entire dependency list (pass [] to clear).
- Returns the updated task as JSON.`

var taskUpdateSchema = json.RawMessage(`{
	"type": "object",
	"required": ["task_id"],
	"properties": {
		"task_id": {
			"type": "string",
			"description": "ID of the task to update."
		},
		"subject": {
			"type": "string",
			"description": "New imperative title (must be non-empty if provided)."
		},
		"description": {
			"type": "string",
			"description": "New context note (empty string clears it)."
		},
		"active_form": {
			"type": "string",
			"description": "New present-continuous form."
		},
		"status": {
			"type": "string",
			"enum": ["pending", "in_progress", "completed", "deleted"],
			"description": "New status. \"deleted\" soft-deletes the task."
		},
		"owner": {
			"type": "string",
			"description": "New owner identifier."
		},
		"blocked_by": {
			"type": "array",
			"items": {"type": "string"},
			"description": "Replacement list of task IDs that must complete before this one starts. Pass [] to clear."
		}
	}
}`)

// TaskUpdate implements the TaskUpdate system tool.
//
// TaskUpdate struct 是 TaskUpdate 系统工具。
type TaskUpdate struct {
	svc *taskapp.Service
}

func (t *TaskUpdate) Name() string                { return "TaskUpdate" }
func (t *TaskUpdate) Description() string         { return taskUpdateDescription }
func (t *TaskUpdate) Parameters() json.RawMessage { return taskUpdateSchema }

func (t *TaskUpdate) IsReadOnly() bool        { return false }
func (t *TaskUpdate) NeedsReadFirst() bool    { return false }
func (t *TaskUpdate) RequiresWorkspace() bool { return false }

// ValidateInput rejects empty task_id and out-of-whitelist status.
//
// ValidateInput 拒空 task_id 与白名单外 status。
func (t *TaskUpdate) ValidateInput(args json.RawMessage) error {
	var a updateRaw
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("TaskUpdate.ValidateInput: %w", err)
	}
	if strings.TrimSpace(a.TaskID) == "" {
		return errors.New("task_id is required")
	}
	if a.Status != nil && !taskdomain.IsValidStatus(*a.Status) {
		return taskdomain.ErrInvalidStatus
	}
	return nil
}

func (t *TaskUpdate) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

// updateRaw is the JSON payload shape; pointer fields encode "set vs
// leave unchanged" semantics.
//
// updateRaw 是 JSON 载荷形态；指针字段编码"设值 vs 不变"语义。
type updateRaw struct {
	TaskID      string    `json:"task_id"`
	Subject     *string   `json:"subject"`
	Description *string   `json:"description"`
	ActiveForm  *string   `json:"active_form"`
	Status      *string   `json:"status"`
	Owner       *string   `json:"owner"`
	BlockedBy   *[]string `json:"blocked_by"`
}

// Execute applies the partial update via Service. status:"deleted"
// triggers Service.Delete instead so the soft-delete + final-snapshot
// SSE broadcast happens in one place.
//
// Execute 通过 Service 应用部分更新；status:"deleted" 走 Service.Delete
// 让软删 + 最终 SSE 广播集中一处。
func (t *TaskUpdate) Execute(ctx context.Context, argsJSON string) (string, error) {
	var raw updateRaw
	if err := json.Unmarshal([]byte(argsJSON), &raw); err != nil {
		return "", fmt.Errorf("TaskUpdate.Execute: %w", err)
	}

	// Special case: status:"deleted" → Service.Delete (sets deleted_at).
	// 特例：status:"deleted" → Service.Delete（置 deleted_at）。
	if raw.Status != nil && *raw.Status == taskdomain.StatusDeleted {
		if err := t.svc.Delete(ctx, raw.TaskID); err != nil {
			return classifyTaskErr(err, "delete"), nil
		}
		return fmt.Sprintf(`{"deleted":true,"id":%q}`, raw.TaskID), nil
	}

	updated, err := t.svc.Update(ctx, raw.TaskID, taskapp.UpdateInput{
		Subject:     raw.Subject,
		Description: raw.Description,
		ActiveForm:  raw.ActiveForm,
		Status:      raw.Status,
		Owner:       raw.Owner,
		BlockedBy:   raw.BlockedBy,
	})
	if err != nil {
		return classifyTaskErr(err, "update"), nil
	}
	return marshalIndent(updated)
}
