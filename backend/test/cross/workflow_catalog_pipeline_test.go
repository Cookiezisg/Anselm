//go:build pipeline

package catalog

import (
	"encoding/json"
	"strings"
	"testing"

	workflowapp "github.com/sunweilin/forgify/backend/internal/app/workflow"
	th "github.com/sunweilin/forgify/backend/test/harness"
)

// createWorkflowForCatalog builds a minimal workflow (set_meta + one trigger node).
//
// createWorkflowForCatalog 建最小 workflow（set_meta + trigger 节点）供 catalog 测试。
func createWorkflowForCatalog(t *testing.T, h *th.Harness, name, desc string) string {
	t.Helper()
	ctx := h.LocalCtx()

	rawMeta, _ := json.Marshal(map[string]any{
		"name":        name,
		"description": desc,
	})
	rawNode, _ := json.Marshal(map[string]any{
		"node": map[string]any{
			"id":     "n1",
			"type":   "trigger",
			"config": map[string]any{"kind": "manual"},
		},
	})
	ops := []workflowapp.Op{
		{Type: "set_meta", Raw: rawMeta},
		{Type: "add_node", Raw: rawNode},
	}
	w, _, err := h.Workflow.Create(ctx, workflowapp.CreateInput{Ops: ops})
	if err != nil {
		t.Fatalf("create workflow %q: %v", name, err)
	}
	return w.ID
}

func TestCatalog_WorkflowIncluded_E2E(t *testing.T) {
	h := th.New(t)

	wfID := createWorkflowForCatalog(t, h, "nightly_report", "Generates nightly status report")

	cat, err := h.Catalog.Get(h.LocalCtx())
	if err != nil {
		t.Fatalf("Catalog.Get: %v", err)
	}

	ids := cat.Coverage["workflow"]
	if !contains(ids, wfID) {
		t.Errorf("Coverage[workflow]=%v missing workflow ID %q", ids, wfID)
	}
	if !strings.Contains(cat.Summary, "nightly_report") {
		t.Errorf("Summary missing workflow name 'nightly_report': %q", cat.Summary)
	}
	if !strings.Contains(cat.Summary, "[trigger_workflow]") {
		t.Errorf("Summary missing invoke tool '[trigger_workflow]': %q", cat.Summary)
	}
}
