// get.go — TaskGet system tool: fetch a single task by ID from the
// current conversation.
//
// get.go — TaskGet 系统工具：按 ID 从当前对话取单条任务。
package task

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	taskapp "github.com/sunweilin/forgify/backend/internal/app/task"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

const taskGetDescription = `Fetch one task by ID from the current conversation's task list.

Usage:
- ` + "`task_id`" + ` is the ID returned by TaskCreate (or seen in TaskList output).
- Returns the task as JSON, or a not-found message if the ID does not belong to this conversation.`

var taskGetSchema = json.RawMessage(`{
	"type": "object",
	"required": ["task_id"],
	"properties": {
		"task_id": {
			"type": "string",
			"description": "ID of the task to fetch (e.g. tk_abc123…)."
		}
	}
}`)

// TaskGet implements the TaskGet system tool.
//
// TaskGet struct 是 TaskGet 系统工具。
type TaskGet struct {
	svc *taskapp.Service
}

func (t *TaskGet) Name() string                { return "TaskGet" }
func (t *TaskGet) Description() string         { return taskGetDescription }
func (t *TaskGet) Parameters() json.RawMessage { return taskGetSchema }

func (t *TaskGet) IsReadOnly() bool        { return true }
func (t *TaskGet) NeedsReadFirst() bool    { return false }
func (t *TaskGet) RequiresWorkspace() bool { return false }

func (t *TaskGet) ValidateInput(args json.RawMessage) error {
	var a struct {
		TaskID string `json:"task_id"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("TaskGet.ValidateInput: %w", err)
	}
	if strings.TrimSpace(a.TaskID) == "" {
		return errors.New("task_id is required")
	}
	return nil
}

func (t *TaskGet) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *TaskGet) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		TaskID string `json:"task_id"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("TaskGet.Execute: %w", err)
	}
	got, err := t.svc.Get(ctx, args.TaskID)
	if err != nil {
		return classifyTaskErr(err, "get"), nil
	}
	return marshalIndent(got)
}
