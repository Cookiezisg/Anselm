package scenarios

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// TestWorkflow_LargeParallelFanoutAndJoin is the real HTTP/persistence counterpart to the
// scheduler walk probe: eight action branches fan out from one trigger, two four-input joins
// re-converge them, and a final action consumes both join results. It proves the durable graph
// does not run a join early, drop a branch, or execute any (node, iteration) twice.
func TestWorkflow_LargeParallelFanoutAndJoin(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	wc := c.WS(c.POST("/api/v1/workspaces", map[string]any{"name": "wf-large-graph"}).OK(t, nil).Field(t, "id"))

	branchFn := fnCreate(t, wc, "parallel_branch", "def branch(seed: str, label: str) -> dict:\n    return {'label': label + ':' + seed}\n")
	joinFn := fnCreate(t, wc, "parallel_join", "def join(a: str, b: str, c: str, d: str) -> dict:\n    return {'joined': a + ',' + b + ',' + c + ',' + d}\n")
	finishFn := fnCreate(t, wc, "parallel_finish", "def finish(left: str, right: str) -> dict:\n    return {'complete': left + '|' + right}\n")

	ops := []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
	}
	for i := 1; i <= 8; i++ {
		id := fmt.Sprintf("p%d", i)
		ops = append(ops, map[string]any{"op": "add_node", "node": map[string]any{
			"id": id, "kind": "action", "ref": branchFn,
			"input": map[string]any{"seed": "start.seed", "label": fmt.Sprintf("'%s'", id)},
		}})
		ops = append(ops, map[string]any{"op": "add_edge", "edge": map[string]any{
			"id": "e-start-" + id, "from": "start", "to": id,
		}})
	}

	ops = append(ops,
		map[string]any{"op": "add_node", "node": map[string]any{
			"id": "join_left", "kind": "action", "ref": joinFn,
			"input": map[string]any{"a": "p1.label", "b": "p2.label", "c": "p3.label", "d": "p4.label"},
		}},
		map[string]any{"op": "add_node", "node": map[string]any{
			"id": "join_right", "kind": "action", "ref": joinFn,
			"input": map[string]any{"a": "p5.label", "b": "p6.label", "c": "p7.label", "d": "p8.label"},
		}},
	)
	for i := 1; i <= 4; i++ {
		id := fmt.Sprintf("p%d", i)
		ops = append(ops, map[string]any{"op": "add_edge", "edge": map[string]any{
			"id": "e-" + id + "-join-left", "from": id, "to": "join_left",
		}})
	}
	for i := 5; i <= 8; i++ {
		id := fmt.Sprintf("p%d", i)
		ops = append(ops, map[string]any{"op": "add_edge", "edge": map[string]any{
			"id": "e-" + id + "-join-right", "from": id, "to": "join_right",
		}})
	}
	ops = append(ops,
		map[string]any{"op": "add_node", "node": map[string]any{
			"id": "finish", "kind": "action", "ref": finishFn,
			"input": map[string]any{"left": "join_left.joined", "right": "join_right.joined"},
		}},
		map[string]any{"op": "add_edge", "edge": map[string]any{"id": "e-left-finish", "from": "join_left", "to": "finish"}},
		map[string]any{"op": "add_edge", "edge": map[string]any{"id": "e-right-finish", "from": "join_right", "to": "finish"}},
	)

	wfID := wfCreate(t, wc, "large_parallel_join", ops)
	_, status, nodes := runAndWait(t, wc, wfID, map[string]any{"seed": "large"}, 60000)
	if status != "completed" {
		t.Fatalf("large parallel graph must complete, got %s nodes=%s", status, nodes)
	}

	var rows []struct {
		NodeID    string         `json:"nodeId"`
		Status    string         `json:"status"`
		Iteration int            `json:"iteration"`
		Result    map[string]any `json:"result"`
	}
	if err := json.Unmarshal(nodes, &rows); err != nil {
		t.Fatalf("decode large graph nodes: %v %s", err, nodes)
	}
	if len(rows) != 12 {
		t.Fatalf("large graph must persist exactly 12 node rows, got %d: %s", len(rows), nodes)
	}
	seen := make(map[string]bool, len(rows))
	for _, row := range rows {
		if seen[row.NodeID] {
			t.Fatalf("node %s executed more than once at iteration %d", row.NodeID, row.Iteration)
		}
		seen[row.NodeID] = true
		if row.Status != "completed" || row.Iteration != 0 {
			t.Fatalf("node %s must complete once at iteration 0: %+v", row.NodeID, row)
		}
	}
	for _, id := range []string{"start", "p1", "p2", "p3", "p4", "p5", "p6", "p7", "p8", "join_left", "join_right", "finish"} {
		if !seen[id] {
			t.Fatalf("large graph lost node %s: %v", id, seen)
		}
	}
	want := "p1:large,p2:large,p3:large,p4:large|p5:large,p6:large,p7:large,p8:large"
	if !strings.Contains(string(nodes), want) {
		t.Fatalf("final join must carry every branch's result in declaration order; want %q in %s", want, nodes)
	}
}
