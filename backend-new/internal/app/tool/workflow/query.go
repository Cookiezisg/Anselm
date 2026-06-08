package workflow

import (
	"context"
	"encoding/json"
	"fmt"

	workflowapp "github.com/sunweilin/forgify/backend/internal/app/workflow"
)

// --- search_workflow -------------------------------------------------------

type SearchWorkflow struct{ svc *workflowapp.Service }

func (t *SearchWorkflow) Name() string { return "search_workflow" }

func (t *SearchWorkflow) Description() string {
	return "Find workflows by case-insensitive substring over name / description / tags. Returns id + name + description + lifecycle state; empty query lists all. Use get_workflow for the full graph."
}

func (t *SearchWorkflow) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"query": {"type": "string", "description": "Substring to match; omit or empty to list all."}
		}
	}`)
}

func (t *SearchWorkflow) ValidateInput(json.RawMessage) error { return nil }

func (t *SearchWorkflow) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Query string `json:"query"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("search_workflow: bad args: %w", err)
	}
	wfs, err := t.svc.Search(ctx, args.Query)
	if err != nil {
		return "", fmt.Errorf("search_workflow: %w", err)
	}
	type slim struct {
		ID             string `json:"id"`
		Name           string `json:"name"`
		Description    string `json:"description"`
		LifecycleState string `json:"lifecycleState"`
		Active         bool   `json:"active"`
	}
	out := make([]slim, 0, len(wfs))
	for _, w := range wfs {
		out = append(out, slim{ID: w.ID, Name: w.Name, Description: w.Description, LifecycleState: w.LifecycleState, Active: w.Active})
	}
	return toJSON(map[string]any{"count": len(out), "workflows": out}), nil
}

// --- get_workflow ----------------------------------------------------------

type GetWorkflow struct{ svc *workflowapp.Service }

func (t *GetWorkflow) Name() string { return "get_workflow" }

func (t *GetWorkflow) Description() string {
	return "Get one workflow with its active version's full graph (nodes + edges), lifecycle state, and concurrency policy."
}

func (t *GetWorkflow) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["workflowId"],
		"properties": {"workflowId": {"type": "string"}}
	}`)
}

func (t *GetWorkflow) ValidateInput(args json.RawMessage) error {
	var a struct {
		WorkflowID string `json:"workflowId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("get_workflow: bad args: %w", err)
	}
	if a.WorkflowID == "" {
		return fmt.Errorf("get_workflow: workflowId is required")
	}
	return nil
}

func (t *GetWorkflow) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		WorkflowID string `json:"workflowId"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("get_workflow: bad args: %w", err)
	}
	w, err := t.svc.Get(ctx, args.WorkflowID)
	if err != nil {
		return "", fmt.Errorf("get_workflow: %w", err)
	}
	return toJSON(w), nil
}
