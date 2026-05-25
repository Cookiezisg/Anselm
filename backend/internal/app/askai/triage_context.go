package askai

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	workflowapp "github.com/sunweilin/forgify/backend/internal/app/workflow"
	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
)

// BuildTriageContext renders a failed (or any) flowrun's full state into a
// system prompt for the triage flow. Includes flowrun overview, all node
// records, and the workflow's graph for reference.
//
// BuildTriageContext 把 flowrun 全状态渲染成 triage system prompt。
// 包含 flowrun 概览、所有节点记录、workflow graph 供参考。
func BuildTriageContext(
	ctx context.Context,
	flowrunID string,
	flowrunRepo flowrundomain.Repository,
	workflowSvc *workflowapp.Service,
) (string, error) {
	if flowrunRepo == nil {
		return "", fmt.Errorf("BuildTriageContext: flowrun repo nil")
	}
	run, err := flowrunRepo.Get(ctx, flowrunID)
	if err != nil {
		return "", fmt.Errorf("BuildTriageContext: get run: %w", err)
	}

	var sb strings.Builder
	sb.WriteString("You are debugging a workflow execution (flowrun). The user clicked \"AI Triage\" ")
	sb.WriteString("on this run because they want help understanding why it behaved as it did and how to fix it.\n\n")

	sb.WriteString("=== Flowrun overview ===\n")
	fmt.Fprintf(&sb, "ID: %s\n", run.ID)
	fmt.Fprintf(&sb, "Workflow ID: %s\n", run.WorkflowID)
	fmt.Fprintf(&sb, "Status: %s\n", run.Status)
	fmt.Fprintf(&sb, "Trigger: %s\n", run.TriggerKind)
	fmt.Fprintf(&sb, "Started: %s\n", run.StartedAt.Format("2006-01-02 15:04:05 MST"))
	if run.EndedAt != nil {
		fmt.Fprintf(&sb, "Ended:   %s (elapsed %dms)\n", run.EndedAt.Format("2006-01-02 15:04:05 MST"), run.ElapsedMs)
	}
	if run.ErrorCode != "" || run.ErrorMessage != "" {
		fmt.Fprintf(&sb, "Error: %s — %s\n", run.ErrorCode, run.ErrorMessage)
	}
	sb.WriteString("\n")

	// All nodes that fired in this run
	nodes, _, err := flowrunRepo.ListNodes(ctx, flowrundomain.NodeFilter{FlowrunID: flowrunID, Limit: 1000})
	if err == nil && len(nodes) > 0 {
		sb.WriteString("=== Node executions (chronological) ===\n")
		for _, n := range nodes {
			fmt.Fprintf(&sb, "[%s] %s (type=%s, attempts=%d, %dms) — %s\n",
				n.Status, n.NodeID, n.NodeType, n.Attempts, n.ElapsedMs, n.StartedAt.Format("15:04:05"))
			if n.ErrorCode != "" || n.ErrorMessage != "" {
				fmt.Fprintf(&sb, "  error: %s — %s\n", n.ErrorCode, n.ErrorMessage)
			}
			if input := snapshotJSON(n.Input, 600); input != "" {
				fmt.Fprintf(&sb, "  input: %s\n", input)
			}
			if output := snapshotJSON(n.Output, 600); output != "" {
				fmt.Fprintf(&sb, "  output: %s\n", output)
			}
		}
		sb.WriteString("\n")
	}

	// Workflow graph for reference
	if workflowSvc != nil {
		w, err := workflowSvc.Get(ctx, run.WorkflowID)
		if err == nil && w.ActiveVersionID != "" {
			v, err := workflowSvc.GetVersion(ctx, w.ActiveVersionID)
			if err == nil && v.GraphParsed != nil {
				sb.WriteString("=== Workflow graph (active version) ===\n")
				fmt.Fprintf(&sb, "Workflow: %s — %s\n", w.Name, w.Description)
				fmt.Fprintf(&sb, "Nodes (%d):\n", len(v.GraphParsed.Nodes))
				for _, n := range v.GraphParsed.Nodes {
					cfgJSON := snapshotJSON(n.Config, 300)
					fmt.Fprintf(&sb, "  - %s [%s] config=%s\n", n.ID, n.Type, cfgJSON)
				}
				fmt.Fprintf(&sb, "Edges (%d):\n", len(v.GraphParsed.Edges))
				for _, e := range v.GraphParsed.Edges {
					fmt.Fprintf(&sb, "  - %s → %s\n", e.From, e.To)
				}
				sb.WriteString("\n")
			}
		}
	}

	sb.WriteString("=== Task ===\n")
	sb.WriteString("1. Analyze the failure (or behavior) — look for which node went wrong, what the error means,\n")
	sb.WriteString("   and whether upstream node outputs match downstream expectations.\n")
	sb.WriteString("2. If you need more context (function code, handler implementation, recent successful runs),\n")
	sb.WriteString("   use the read/search tools available to you.\n")
	sb.WriteString("3. Explain the root cause in plain language for the user.\n")
	sb.WriteString("4. If you can propose a fix, call `edit_function` / `edit_handler` / `edit_workflow` (by type) or `edit_document`\n")
	sb.WriteString("   to produce a pending version. The user will review and accept the diff.\n")
	sb.WriteString("5. Do NOT auto-rerun the workflow — user will manually retry after accepting your fix.\n")
	sb.WriteString("6. Do NOT create new entities — only modify existing ones.\n")
	return sb.String(), nil
}

// snapshotJSON marshals v as compact JSON, truncating with "…(<len>B truncated)" when over limit.
//
// snapshotJSON 把 v 序列化为紧凑 JSON，超 limit 截断并标注"…(<len>B truncated)"。
func snapshotJSON(v any, limit int) string {
	if v == nil {
		return ""
	}
	raw, err := json.Marshal(v)
	if err != nil {
		return fmt.Sprintf("<unrenderable: %v>", err)
	}
	s := string(raw)
	if len(s) > limit {
		return s[:limit] + fmt.Sprintf("…(%dB truncated)", len(s)-limit)
	}
	return s
}
