package todo

import (
	"context"
	"encoding/json"
	"fmt"

	todoapp "github.com/sunweilin/forgify/backend/internal/app/todo"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

const todoListDescription = `List active todos of the current conversation, in creation order. Returns {total, todos:[...]}.`

var todoListSchema = json.RawMessage(`{
	"type": "object",
	"properties": {}
}`)

// TodoList implements the TodoList system tool.
//
// TodoList 是 TodoList 系统工具的实现。
type TodoList struct {
	svc *todoapp.Service
}

func (t *TodoList) Name() string                { return "TodoList" }
func (t *TodoList) Description() string         { return todoListDescription }
func (t *TodoList) Parameters() json.RawMessage { return todoListSchema }

func (t *TodoList) IsReadOnly() bool        { return true }
func (t *TodoList) NeedsReadFirst() bool    { return false }
func (t *TodoList) RequiresWorkspace() bool { return false }

func (t *TodoList) ValidateInput(_ json.RawMessage) error { return nil }

func (t *TodoList) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *TodoList) Execute(ctx context.Context, _ string) (string, error) {
	todos, err := t.svc.List(ctx)
	if err != nil {
		return classifyTodoErr(err, "list"), nil
	}
	out := struct {
		Total int `json:"total"`
		Todos any `json:"todos"`
	}{
		Total: len(todos),
		Todos: todos,
	}
	body, err := json.MarshalIndent(out, "", "  ")
	if err != nil {
		return "", fmt.Errorf("TodoList.Execute: marshal: %w", err)
	}
	return string(body), nil
}
