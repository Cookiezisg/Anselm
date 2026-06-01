package scheduler

import (
	"testing"

	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
)

func twoTriggerGraph() workflowdomain.Graph {
	return workflowdomain.Graph{
		Nodes: []workflowdomain.NodeSpec{
			{ID: "tA", Type: workflowdomain.NodeTypeTrigger},
			{ID: "tB", Type: workflowdomain.NodeTypeTrigger},
			{ID: "fn", Type: workflowdomain.NodeTypeFunction},
		},
	}
}

// TestSelectTriggerNode_PicksNamed verifies a multi-trigger workflow enters from the requested node.
func TestSelectTriggerNode_PicksNamed(t *testing.T) {
	g := twoTriggerGraph()
	got := selectTriggerNode(g, "tB")
	if got == nil || got.ID != "tB" {
		t.Errorf("selectTriggerNode(tB) = %+v, want tB", got)
	}
}

// TestSelectTriggerNode_EmptyFallsBackToFirst verifies an empty want uses the first trigger (single-trigger path).
func TestSelectTriggerNode_EmptyFallsBackToFirst(t *testing.T) {
	g := twoTriggerGraph()
	got := selectTriggerNode(g, "")
	if got == nil || got.ID != "tA" {
		t.Errorf("selectTriggerNode(\"\") = %+v, want tA (first)", got)
	}
}

// TestSelectTriggerNode_StaleIdFallsBackToFirst verifies a want naming a missing/non-trigger node
// falls back to the first trigger rather than dead-ending (the run still starts).
func TestSelectTriggerNode_StaleIdFallsBackToFirst(t *testing.T) {
	g := twoTriggerGraph()
	if got := selectTriggerNode(g, "fn"); got == nil || got.ID != "tA" {
		t.Errorf("non-trigger want should fall back to tA, got %+v", got)
	}
	if got := selectTriggerNode(g, "ghost"); got == nil || got.ID != "tA" {
		t.Errorf("missing want should fall back to tA, got %+v", got)
	}
}
