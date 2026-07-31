package scenarios

import (
	"encoding/json"
	"fmt"
	"net/url"
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

// TestWorkflow_DeepLoopPersistsEveryIteration is the real HTTP/durable counterpart to the old
// scheduler-only 25-iteration probe. The action's input deliberately uses the documented
// has(previous) ? previous : seed form, so the loop exercises scopeFor across every turn instead
// of accidentally resetting to the trigger payload. It also checks the execution ledger's
// flowrunIteration join key, not just the final answer.
func TestWorkflow_DeepLoopPersistsEveryIteration(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	wc := c.WS(c.POST("/api/v1/workspaces", map[string]any{"name": "wf-deep-loop"}).OK(t, nil).Field(t, "id"))

	stepFn := fnCreate(t, wc, "deep_loop_step", "def increment(n: int) -> dict:\n    return {'n': n + 1}\n")
	finishFn := fnCreate(t, wc, "deep_loop_finish", "def finish(n: int) -> dict:\n    return {'final': n}\n")
	ctlID := wc.POST("/api/v1/controls", map[string]any{
		"name":   "deep_loop_gate",
		"inputs": []map[string]any{{"name": "n", "type": "number"}},
		"branches": []map[string]any{
			{"port": "done", "when": "input.n >= 25", "emit": map[string]string{"n": "input.n"}},
			{"port": "retry", "when": "true"},
		},
	}).Field(t, "id")

	wfID := wfCreate(t, wc, "deep_loop", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
		{"op": "add_node", "node": map[string]any{
			"id": "step", "kind": "action", "ref": stepFn,
			"input": map[string]any{"n": "has(step.n) ? step.n : start.n"},
		}},
		{"op": "add_node", "node": map[string]any{
			"id": "gate", "kind": "control", "ref": ctlID,
			"input": map[string]any{"n": "step.n"},
		}},
		{"op": "add_node", "node": map[string]any{
			"id": "finish", "kind": "action", "ref": finishFn,
			"input": map[string]any{"n": "gate.n"},
		}},
		{"op": "add_edge", "edge": map[string]any{"id": "e-start-step", "from": "start", "to": "step"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e-step-gate", "from": "step", "to": "gate"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e-gate-done", "from": "gate", "to": "finish", "fromPort": "done"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e-gate-retry", "from": "gate", "to": "step", "fromPort": "retry"}},
	})

	runID, status, nodes := runAndWait(t, wc, wfID, map[string]any{"n": 0}, 120000)
	if status != "completed" {
		t.Fatalf("25-iteration loop must complete, got %s nodes=%s", status, nodes)
	}

	type deepNode struct {
		NodeID    string         `json:"nodeId"`
		Status    string         `json:"status"`
		Iteration int            `json:"iteration"`
		Result    map[string]any `json:"result"`
	}
	// GET /flowruns/{id} is deliberately paged. Walk it instead of trusting the first 50-node
	// snapshot; a long loop must remain fully inspectable through the public REST surface.
	var rows []deepNode
	cursor := ""
	pagesFetched := 0
	for page := 0; page < 10; page++ {
		pagesFetched++
		path := "/api/v1/flowruns/" + runID + "?limit=10"
		if cursor != "" {
			path += "&cursor=" + url.QueryEscape(cursor)
		}
		var got struct {
			Nodes      []deepNode `json:"nodes"`
			NextCursor string     `json:"nextCursor"`
		}
		r := wc.GET(path)
		if r.Status != 200 {
			t.Fatalf("deep loop node page %d failed: %d %s", page+1, r.Status, r.Raw)
		}
		// Decode the envelope body; the harness also exposes the same cursor as NextCursor.
		if err := json.Unmarshal(r.Data, &got); err != nil {
			t.Fatalf("decode deep loop node page %d: %v %s", page+1, err, r.Data)
		}
		rows = append(rows, got.Nodes...)
		if got.NextCursor == "" {
			break
		}
		cursor = got.NextCursor
		if page == 9 {
			t.Fatal("deep loop node pagination did not terminate within 10 pages")
		}
	}
	if pagesFetched < 2 {
		t.Fatalf("deep loop pagination must exercise more than one public node page, fetched %d", pagesFetched)
	}
	counts := map[string]int{}
	iterations := map[string]map[int]bool{}
	for _, row := range rows {
		counts[row.NodeID]++
		if iterations[row.NodeID] == nil {
			iterations[row.NodeID] = map[int]bool{}
		}
		if iterations[row.NodeID][row.Iteration] {
			t.Fatalf("node %s executed more than once at iteration %d: %+v", row.NodeID, row.Iteration, rows)
		}
		iterations[row.NodeID][row.Iteration] = true
		if row.Status != "completed" {
			t.Fatalf("deep loop node must complete: %+v", row)
		}
	}
	if counts["start"] != 1 || counts["step"] != 25 || counts["gate"] != 25 || counts["finish"] != 1 || len(rows) != 52 {
		t.Fatalf("deep loop must persist 1 start + 25 step + 25 gate + 1 finish rows, counts=%v total=%d nodes=%s", counts, len(rows), nodes)
	}
	for _, id := range []string{"step", "gate"} {
		for i := 0; i < 25; i++ {
			if !iterations[id][i] {
				t.Fatalf("%s missing durable iteration %d: %+v", id, i, iterations[id])
			}
		}
	}
	if !iterations["start"][0] || !iterations["finish"][24] {
		t.Fatalf("loop boundary iterations wrong: start=%v finish=%v", iterations["start"], iterations["finish"])
	}
	if !strings.Contains(string(nodes), `"final":25`) {
		t.Fatalf("finish must observe the accumulated value 25, nodes=%s", nodes)
	}

	// The execution log must carry the same (flowrun,node,iteration) identity as the durable
	// node rows; without this, a long loop is impossible to audit or join in the activity view.
	var page struct {
		Executions []struct {
			FlowrunID        string `json:"flowrunId"`
			FlowrunNodeID    string `json:"flowrunNodeId"`
			FlowrunIteration int    `json:"flowrunIteration"`
			Status           string `json:"status"`
		} `json:"executions"`
	}
	wc.GET("/api/v1/functions/"+stepFn+"/executions").OK(t, &page)
	seenExecIterations := map[int]bool{}
	for _, exec := range page.Executions {
		if exec.FlowrunID != runID {
			continue
		}
		if exec.FlowrunNodeID != "step" || exec.Status != "ok" {
			t.Fatalf("step execution provenance wrong: %+v", exec)
		}
		if seenExecIterations[exec.FlowrunIteration] {
			t.Fatalf("duplicate step execution iteration %d: %+v", exec.FlowrunIteration, page.Executions)
		}
		seenExecIterations[exec.FlowrunIteration] = true
	}
	if len(seenExecIterations) != 25 {
		t.Fatalf("step execution log must expose all 25 flowrun iterations, got %d: %+v", len(seenExecIterations), page.Executions)
	}
}
