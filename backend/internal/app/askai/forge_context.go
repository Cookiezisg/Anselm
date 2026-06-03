package askai

import (
	"context"
	"fmt"
	"strings"

	agentapp "github.com/sunweilin/forgify/backend/internal/app/agent"
	documentapp "github.com/sunweilin/forgify/backend/internal/app/document"
	functionapp "github.com/sunweilin/forgify/backend/internal/app/function"
	handlerapp "github.com/sunweilin/forgify/backend/internal/app/handler"
	workflowapp "github.com/sunweilin/forgify/backend/internal/app/workflow"
)

// BuildFunctionContext renders the function's current state into a system
// prompt for the iterate flow. LLM sees: role + current code + tool guidance.
//
// BuildFunctionContext 把 function 当前状态渲染成 iterate 流的 system prompt。
// LLM 看到：角色 + 当前代码 + 工具引导。
func BuildFunctionContext(ctx context.Context, id string, svc *functionapp.Service) (string, error) {
	if svc == nil {
		return "", fmt.Errorf("BuildFunctionContext: function service nil")
	}
	fn, err := svc.Get(ctx, id)
	if err != nil {
		return "", fmt.Errorf("BuildFunctionContext: %w", err)
	}
	if fn.ActiveVersionID == "" {
		return "", fmt.Errorf("BuildFunctionContext: function %s has no active version", id)
	}
	v, err := svc.GetVersion(ctx, fn.ActiveVersionID)
	if err != nil {
		return "", fmt.Errorf("BuildFunctionContext: get version: %w", err)
	}

	var sb strings.Builder
	sb.WriteString("You are helping the user iterate on a Python function in the Forgify forge library.\n\n")
	sb.WriteString("=== Current function state ===\n")
	fmt.Fprintf(&sb, "ID: %s\nName: %s\nDescription: %s\n\n", fn.ID, fn.Name, fn.Description)
	sb.WriteString("Code:\n```python\n")
	sb.WriteString(v.Code)
	sb.WriteString("\n```\n\n")
	if len(v.Parameters) > 0 {
		sb.WriteString("Parameters:\n")
		for _, p := range v.Parameters {
			fmt.Fprintf(&sb, "- %s: %s (required=%v)\n", p.Name, p.Type, p.Required)
		}
		sb.WriteString("\n")
	}

	sb.WriteString("=== Task ===\n")
	sb.WriteString("Read the user's request below. Briefly explain your plan, then call `edit_function` ")
	sb.WriteString(fmt.Sprintf("with id=%q + ops to produce a pending version. Do NOT call create_* tools; ", id))
	sb.WriteString("do NOT modify other forges. After edit_function succeeds, summarize what changed for the user.\n")
	return sb.String(), nil
}

// BuildAgentContext renders the agent's current state into a system prompt for the iterate flow.
//
// BuildAgentContext 把 agent 当前状态渲染成 iterate 流的 system prompt。
func BuildAgentContext(ctx context.Context, id string, svc *agentapp.Service) (string, error) {
	if svc == nil {
		return "", fmt.Errorf("BuildAgentContext: agent service nil")
	}
	a, err := svc.Get(ctx, id)
	if err != nil {
		return "", fmt.Errorf("BuildAgentContext: %w", err)
	}
	if a.ActiveVersionID == "" {
		return "", fmt.Errorf("BuildAgentContext: agent %s has no active version", id)
	}
	v, err := svc.GetVersion(ctx, a.ActiveVersionID)
	if err != nil {
		return "", fmt.Errorf("BuildAgentContext: get version: %w", err)
	}

	var sb strings.Builder
	sb.WriteString("You are helping the user iterate on an agent (a configured LLM worker) in the Forgify forge library.\n\n")
	sb.WriteString("=== Current agent state ===\n")
	fmt.Fprintf(&sb, "ID: %s\nName: %s\nDescription: %s\n\n", a.ID, a.Name, a.Description)
	sb.WriteString("Prompt:\n```\n")
	sb.WriteString(v.Prompt)
	sb.WriteString("\n```\n\n")
	if len(v.Tools) > 0 {
		sb.WriteString("Tools:\n")
		for _, t := range v.Tools {
			fmt.Fprintf(&sb, "- %s\n", t.Ref)
		}
		sb.WriteString("\n")
	}
	if v.OutputSchema != nil {
		fmt.Fprintf(&sb, "Output schema: kind=%s\n\n", v.OutputSchema.Kind)
	}

	sb.WriteString("=== Task ===\n")
	sb.WriteString("Read the user's request below. Briefly explain your plan, then call `edit_agent` ")
	fmt.Fprintf(&sb, "with id=%q to produce a pending version. Do NOT call create_* tools; ", id)
	sb.WriteString("do NOT modify other forges. After edit_agent succeeds, summarize what changed for the user.\n")
	return sb.String(), nil
}

// BuildHandlerContext renders the handler's current state for iterate.
//
// BuildHandlerContext 把 handler 当前状态渲染成 iterate system prompt。
func BuildHandlerContext(ctx context.Context, id string, svc *handlerapp.Service) (string, error) {
	if svc == nil {
		return "", fmt.Errorf("BuildHandlerContext: handler service nil")
	}
	h, err := svc.Get(ctx, id)
	if err != nil {
		return "", fmt.Errorf("BuildHandlerContext: %w", err)
	}
	if h.ActiveVersionID == "" {
		return "", fmt.Errorf("BuildHandlerContext: handler %s has no active version", id)
	}
	v, err := svc.GetVersion(ctx, h.ActiveVersionID)
	if err != nil {
		return "", fmt.Errorf("BuildHandlerContext: get version: %w", err)
	}

	var sb strings.Builder
	sb.WriteString("You are helping the user iterate on a stateful Python class handler in Forgify.\n\n")
	sb.WriteString("=== Current handler state ===\n")
	fmt.Fprintf(&sb, "ID: %s\nName: %s\nDescription: %s\n\n", h.ID, h.Name, h.Description)
	if v.Imports != "" {
		sb.WriteString("Imports:\n```python\n")
		sb.WriteString(v.Imports)
		sb.WriteString("\n```\n\n")
	}
	if v.InitBody != "" {
		sb.WriteString("Init body:\n```python\n")
		sb.WriteString(v.InitBody)
		sb.WriteString("\n```\n\n")
	}
	if len(v.Methods) > 0 {
		sb.WriteString("Methods:\n")
		for _, m := range v.Methods {
			fmt.Fprintf(&sb, "- %s: %s\n", m.Name, m.Description)
		}
		sb.WriteString("\n")
	}

	sb.WriteString("=== Task ===\n")
	sb.WriteString("Read the user's request. Plan briefly, then call `edit_handler` with ")
	sb.WriteString(fmt.Sprintf("id=%q + ops to produce a pending version. ", id))
	sb.WriteString("Do NOT call create_* tools; do NOT modify other handlers.\n")
	return sb.String(), nil
}

// BuildWorkflowContext renders the workflow's current graph for iterate.
//
// BuildWorkflowContext 把 workflow 当前 graph 渲染成 iterate system prompt。
func BuildWorkflowContext(ctx context.Context, id string, svc *workflowapp.Service) (string, error) {
	if svc == nil {
		return "", fmt.Errorf("BuildWorkflowContext: workflow service nil")
	}
	w, err := svc.Get(ctx, id)
	if err != nil {
		return "", fmt.Errorf("BuildWorkflowContext: %w", err)
	}
	if w.ActiveVersionID == "" {
		return "", fmt.Errorf("BuildWorkflowContext: workflow %s has no active version", id)
	}
	v, err := svc.GetVersion(ctx, w.ActiveVersionID)
	if err != nil {
		return "", fmt.Errorf("BuildWorkflowContext: get version: %w", err)
	}

	var sb strings.Builder
	sb.WriteString("You are helping the user iterate on a DAG-based workflow in Forgify.\n\n")
	sb.WriteString("=== Current workflow state ===\n")
	fmt.Fprintf(&sb, "ID: %s\nName: %s\nDescription: %s\n\n", w.ID, w.Name, w.Description)
	if v.GraphParsed != nil {
		fmt.Fprintf(&sb, "Nodes (%d):\n", len(v.GraphParsed.Nodes))
		for _, n := range v.GraphParsed.Nodes {
			fmt.Fprintf(&sb, "  - %s [%s]\n", n.ID, n.Type)
		}
		fmt.Fprintf(&sb, "Edges (%d):\n", len(v.GraphParsed.Edges))
		for _, e := range v.GraphParsed.Edges {
			fmt.Fprintf(&sb, "  - %s → %s\n", e.From, e.To)
		}
		sb.WriteString("\n")
	}
	sb.WriteString("=== Task ===\n")
	sb.WriteString("Read the user's request. Plan briefly, then call `edit_workflow` with ")
	sb.WriteString(fmt.Sprintf("id=%q + ops (add_node / update_node / delete_node / add_edge / delete_edge / set_meta) ", id))
	sb.WriteString("to produce a pending version. Do NOT call create_* tools; do NOT modify other workflows.\n")
	return sb.String(), nil
}

// BuildDocumentContext renders the document's current body for iterate.
//
// BuildDocumentContext 把 document 当前 body 渲染成 iterate system prompt。
func BuildDocumentContext(ctx context.Context, id string, svc *documentapp.Service) (string, error) {
	if svc == nil {
		return "", fmt.Errorf("BuildDocumentContext: document service nil")
	}
	d, err := svc.Get(ctx, id)
	if err != nil {
		return "", fmt.Errorf("BuildDocumentContext: %w", err)
	}
	var sb strings.Builder
	sb.WriteString("You are helping the user iterate on a markdown document in Forgify.\n\n")
	sb.WriteString("=== Current document state ===\n")
	fmt.Fprintf(&sb, "ID: %s\nName: %s\nDescription: %s\nPath: %s\n\n", d.ID, d.Name, d.Description, d.Path)
	sb.WriteString("Body:\n```markdown\n")
	sb.WriteString(d.Content)
	sb.WriteString("\n```\n\n")
	sb.WriteString("=== Task ===\n")
	sb.WriteString("Read the user's request. Briefly explain your plan, then call `edit_document` ")
	sb.WriteString(fmt.Sprintf("with id=%q + the new markdown body to persist. ", id))
	sb.WriteString("Do NOT create other documents; do NOT touch other entities.\n")
	return sb.String(), nil
}
