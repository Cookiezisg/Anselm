// list.go — TaskList system tool: read every active task in the current
// conversation, ordered by creation time. Used by the LLM to decide what
// to do next.
//
// list.go — TaskList 系统工具：读取当前对话所有活跃任务，按创建时间排序；
// LLM 用来决定下一步做什么。
package task

import (
	"context"
	"encoding/json"
	"fmt"

	taskapp "github.com/sunweilin/forgify/backend/internal/app/task"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

const taskListDescription = `List every task on the current conversation's task list.

Usage:
- Returns a JSON array of tasks, each with id / subject / status / activeForm / etc.
- Tasks are ordered by created_at ascending so you see them in the order they were added.
- Soft-deleted tasks are excluded.
- Use this to decide which task to work on next or to summarise progress to the user.`

var taskListSchema = json.RawMessage(`{
	"type": "object",
	"properties": {}
}`)

// TaskList implements the TaskList system tool.
//
// TaskList struct 是 TaskList 系统工具。
type TaskList struct {
	svc *taskapp.Service
}

func (t *TaskList) Name() string                { return "TaskList" }
func (t *TaskList) Description() string         { return taskListDescription }
func (t *TaskList) Parameters() json.RawMessage { return taskListSchema }

func (t *TaskList) IsReadOnly() bool        { return true }
func (t *TaskList) NeedsReadFirst() bool    { return false }
func (t *TaskList) RequiresWorkspace() bool { return false }

func (t *TaskList) ValidateInput(_ json.RawMessage) error { return nil }

func (t *TaskList) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

// Execute pulls the conversation's tasks and returns them as JSON.
//
// Execute 拉取对话任务并返 JSON。
func (t *TaskList) Execute(ctx context.Context, _ string) (string, error) {
	tasks, err := t.svc.List(ctx)
	if err != nil {
		return classifyTaskErr(err, "list"), nil
	}
	out := struct {
		Total int `json:"total"`
		Tasks any `json:"tasks"`
	}{
		Total: len(tasks),
		Tasks: tasks,
	}
	body, err := json.MarshalIndent(out, "", "  ")
	if err != nil {
		return "", fmt.Errorf("TaskList.Execute: marshal: %w", err)
	}
	return string(body), nil
}
