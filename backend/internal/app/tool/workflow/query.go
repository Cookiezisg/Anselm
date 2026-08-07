package workflow

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	searchapp "github.com/sunweilin/anselm/backend/internal/app/search"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	workflowapp "github.com/sunweilin/anselm/backend/internal/app/workflow"
	searchdomain "github.com/sunweilin/anselm/backend/internal/domain/search"
	workflowdomain "github.com/sunweilin/anselm/backend/internal/domain/workflow"
)

// --- search_workflow -------------------------------------------------------

type SearchWorkflow struct {
	svc     *workflowapp.Service
	content *searchapp.Service // nil → legacy substring only. nil → 仅原子串路径。
}

func (t *SearchWorkflow) Name() string { return "search_workflow" }

func (t *SearchWorkflow) Description() string {
	return "Find workflows by keyword + semantic relevance over name / description / tags. Direct name/description/tag matches take precedence over weak semantic-only matches. Returns id + name + description + tags + lifecycle state + active status; empty query lists all. Use get_workflow for the full graph."
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
	// A direct directory keyword is a stronger user signal than weak semantic
	// neighbors. Preserve semantic-only recall when there is no direct match.
	if strings.TrimSpace(args.Query) != "" {
		direct, err := t.svc.Search(ctx, args.Query)
		if err != nil {
			return "", fmt.Errorf("search_workflow: %w", err)
		}
		if len(direct) > 0 {
			return workflowSearchJSON(direct), nil
		}
	}
	if body, ok := toolapp.ContentSearch(ctx, t.content, searchdomain.TypeWorkflow, args.Query, "workflows"); ok {
		var page struct {
			Count      int                       `json:"count"`
			Total      int                       `json:"total"`
			NextCursor string                    `json:"nextCursor"`
			Workflows  []searchdomain.EntitySlim `json:"workflows"`
		}
		if err := json.Unmarshal([]byte(body), &page); err != nil {
			return "", fmt.Errorf("search_workflow: decode content search: %w", err)
		}
		rows := make([]workflowSearchRow, 0, len(page.Workflows))
		for _, hit := range page.Workflows {
			w, err := t.svc.Get(ctx, hit.ID)
			if err != nil {
				return "", fmt.Errorf("search_workflow: hydrate %s: %w", hit.ID, err)
			}
			rows = append(rows, workflowSearchRow{
				EntitySlim:     hit,
				Tags:           append([]string{}, w.Tags...),
				LifecycleState: w.LifecycleState,
				Active:         w.Active,
			})
		}
		return toolapp.ToJSON(toolapp.SlimPageResult(len(rows), page.Total, page.NextCursor, "workflows", rows)), nil
	}
	wfs, err := t.svc.Search(ctx, args.Query)
	if err != nil {
		return "", fmt.Errorf("search_workflow: %w", err)
	}
	return workflowSearchJSON(wfs), nil
}

type workflowSearchRow struct {
	searchdomain.EntitySlim
	Tags           []string `json:"tags"`
	LifecycleState string   `json:"lifecycleState"`
	Active         bool     `json:"active"`
}

func workflowSearchJSON(wfs []*workflowdomain.Workflow) string {
	out := make([]workflowSearchRow, 0, len(wfs))
	for _, w := range wfs {
		out = append(out, workflowSearchRow{
			EntitySlim: searchdomain.EntitySlim{ID: w.ID, Name: w.Name, Description: w.Description},
			Tags:       append([]string{}, w.Tags...), LifecycleState: w.LifecycleState, Active: w.Active,
		})
	}
	return toolapp.ToJSON(map[string]any{"count": len(out), "total": len(out), "workflows": out})
}

// --- get_workflow ----------------------------------------------------------

type GetWorkflow struct{ svc *workflowapp.Service }

func (t *GetWorkflow) Name() string { return "get_workflow" }

func (t *GetWorkflow) Description() string {
	return "Get one workflow with its active version's full graph (nodes + edges), lifecycle state, and concurrency policy. Pass exactly one of workflowId (the exact wf_... ID) or workflowName (the exact workflow name). If the user gives a name, use workflowName directly; do not guess an ID, do not use file_path, and do not call the filesystem tools."
}

func (t *GetWorkflow) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"additionalProperties": false,
		"properties": {
			"workflowId": {"type": "string", "description": "Exact workflow entity ID (wf_...). Use this OR workflowName."},
			"workflowName": {"type": "string", "description": "Exact user-facing workflow name. Use this OR workflowId; do not use a filesystem path."}
		}
	}`)
}

func (t *GetWorkflow) ValidateInput(args json.RawMessage) error {
	_, err := decodeWorkflowTarget(args, "get_workflow")
	return err
}

func (t *GetWorkflow) NormalizeArguments(args json.RawMessage) (json.RawMessage, bool) {
	return normalizeWorkflowTargetArguments(args)
}

func (t *GetWorkflow) Execute(ctx context.Context, argsJSON string) (string, error) {
	target, err := decodeWorkflowTarget([]byte(argsJSON), "get_workflow")
	if err != nil {
		return "", err
	}
	var w *workflowdomain.Workflow
	if target.WorkflowID != "" {
		w, err = t.svc.Get(ctx, target.WorkflowID)
	} else {
		w, err = t.svc.GetByName(ctx, target.WorkflowName)
	}
	if err != nil {
		return "", fmt.Errorf("get_workflow: %w", err)
	}
	return toolapp.ToJSON(w), nil
}
