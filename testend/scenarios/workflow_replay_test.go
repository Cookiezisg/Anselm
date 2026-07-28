package scenarios

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// TestWorkflow_FailedReplayReusesCompletedNodes proves the public replay contract end to end:
// a real resident handler fails once, the run is durable-failed, :replay clears only that failed
// node, and the same handler succeeds on its second call while the already-completed function is
// not executed again. The node rows and both execution ledgers share the original run identity.
//
// TestWorkflow_FailedReplayReusesCompletedNodes 经公开 HTTP 面证明 replay 契约：真实驻留 handler
// 第一次失败，run 持久化为 failed；:replay 只清 failed 节点；同一 handler 第二次成功，而已经完成的
// function 不会重跑。节点行与两张执行台账都保留原 run 身份。
func TestWorkflow_FailedReplayReusesCompletedNodes(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	wc := c.WS(c.POST("/api/v1/workspaces", map[string]any{"name": "wf-replay-recovery"}).OK(t, nil).Field(t, "id"))

	stableFn := fnCreate(t, wc, "replay_stable", "def stable() -> dict:\n    return {'stable': 'kept'}\n")
	finishFn := fnCreate(t, wc, "replay_finish", "def finish(n: int) -> dict:\n    return {'final': n}\n")
	hdID := hdCreate(t, wc, "replay_flaky", map[string]any{
		"initBody": "self.count = 0",
		"methods": []map[string]any{{
			"name":   "flaky",
			"inputs": []any{},
			"body":   "self.count += 1\nif self.count == 1:\n    raise RuntimeError('first attempt fails')\nreturn {'n': self.count}",
		}},
	})

	wfID := wfCreate(t, wc, "failed_replay_recovery", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
		{"op": "add_node", "node": map[string]any{"id": "stable", "kind": "action", "ref": stableFn}},
		{"op": "add_node", "node": map[string]any{"id": "flaky", "kind": "action", "ref": hdID + ".flaky"}},
		{"op": "add_node", "node": map[string]any{
			"id": "finish", "kind": "action", "ref": finishFn,
			"input": map[string]any{"n": "flaky.n"},
		}},
		{"op": "add_edge", "edge": map[string]any{"id": "e-start-stable", "from": "start", "to": "stable"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e-stable-flaky", "from": "stable", "to": "flaky"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e-flaky-finish", "from": "flaky", "to": "finish"}},
	})

	runID, status, firstNodes := runAndWait(t, wc, wfID, map[string]any{}, 60000)
	if status != "failed" {
		t.Fatalf("first replay probe must fail at the flaky node, got %s nodes=%s", status, firstNodes)
	}

	type nodeRow struct {
		NodeID    string         `json:"nodeId"`
		Status    string         `json:"status"`
		Iteration int            `json:"iteration"`
		Result    map[string]any `json:"result"`
		Error     string         `json:"error"`
	}
	var failedRows []nodeRow
	if err := json.Unmarshal(firstNodes, &failedRows); err != nil {
		t.Fatalf("decode failed replay rows: %v %s", err, firstNodes)
	}
	failedByNode := make(map[string]nodeRow, len(failedRows))
	for _, row := range failedRows {
		failedByNode[row.NodeID] = row
	}
	if failedByNode["stable"].Status != "completed" {
		t.Fatalf("stable node must be durably completed before failure: %+v", failedByNode)
	}
	if failedByNode["flaky"].Status != "failed" || failedByNode["flaky"].Iteration != 0 || failedByNode["flaky"].Error == "" {
		t.Fatalf("flaky node must retain its failed row and surfaced error: %+v", failedByNode["flaky"])
	}
	if _, ok := failedByNode["finish"]; ok {
		t.Fatalf("finish must not run after fail-fast handler node: %+v", failedByNode)
	}

	// The handler ledger is the first proof that this was a real callable, not a mocked dispatcher.
	// handler 台账先证明这里跑的是真实 callable，而非 scheduler mock。
	var calls struct {
		Calls []struct {
			Status           string `json:"status"`
			FlowrunID        string `json:"flowrunId"`
			FlowrunNodeID    string `json:"flowrunNodeId"`
			FlowrunIteration int    `json:"flowrunIteration"`
		} `json:"calls"`
	}
	wc.GET("/api/v1/handlers/"+hdID+"/calls?flowrunId="+runID).OK(t, &calls)
	if len(calls.Calls) != 1 || calls.Calls[0].Status != "failed" || calls.Calls[0].FlowrunID != runID || calls.Calls[0].FlowrunNodeID != "flaky" || calls.Calls[0].FlowrunIteration != 0 {
		t.Fatalf("first handler attempt must be an auditable failed workflow call: %+v", calls.Calls)
	}

	var replay struct {
		Flowrun struct {
			ID          string `json:"id"`
			Status      string `json:"status"`
			ReplayCount int    `json:"replayCount"`
		} `json:"flowrun"`
		Nodes []nodeRow `json:"nodes"`
	}
	wc.POST("/api/v1/flowruns/"+runID+":replay", nil).OK(t, &replay)
	if replay.Flowrun.ID != runID || replay.Flowrun.Status != "completed" || replay.Flowrun.ReplayCount != 1 {
		t.Fatalf("replay must synchronously complete the same run once: %+v", replay.Flowrun)
	}

	rowsByNode := make(map[string]nodeRow, len(replay.Nodes))
	for _, row := range replay.Nodes {
		if _, duplicate := rowsByNode[row.NodeID]; duplicate {
			t.Fatalf("replay response must contain one row per node, got duplicate %s: %+v", row.NodeID, replay.Nodes)
		}
		rowsByNode[row.NodeID] = row
	}
	for _, id := range []string{"start", "stable", "flaky", "finish"} {
		row, ok := rowsByNode[id]
		if !ok || row.Status != "completed" || row.Iteration != 0 {
			t.Fatalf("replayed node %s must be completed once at iteration 0: %+v", id, row)
		}
	}
	if rowsByNode["finish"].Result["final"] != float64(2) {
		t.Fatalf("finish must observe the handler's second-call result, got %+v", rowsByNode["finish"].Result)
	}

	// The handler has exactly two attempts: failed original + successful replay, both joined to the
	// same durable (run,node,iteration) identity.
	// handler 恰两次：原始失败 + replay 成功，且都挂在同一个耐久 (run,node,iteration) 身份上。
	calls = struct {
		Calls []struct {
			Status           string `json:"status"`
			FlowrunID        string `json:"flowrunId"`
			FlowrunNodeID    string `json:"flowrunNodeId"`
			FlowrunIteration int    `json:"flowrunIteration"`
		} `json:"calls"`
	}{}
	wc.GET("/api/v1/handlers/"+hdID+"/calls?flowrunId="+runID).OK(t, &calls)
	if len(calls.Calls) != 2 {
		t.Fatalf("replay must append exactly one handler call, got %+v", calls.Calls)
	}
	seenCallStatus := map[string]bool{}
	for _, call := range calls.Calls {
		if call.FlowrunID != runID || call.FlowrunNodeID != "flaky" || call.FlowrunIteration != 0 {
			t.Fatalf("handler replay provenance wrong: %+v", call)
		}
		seenCallStatus[call.Status] = true
	}
	if !seenCallStatus["failed"] || !seenCallStatus["ok"] {
		t.Fatalf("handler ledger must contain one failed and one ok attempt: %+v", calls.Calls)
	}

	var stableExecutions struct {
		Executions []struct {
			Status           string `json:"status"`
			FlowrunID        string `json:"flowrunId"`
			FlowrunNodeID    string `json:"flowrunNodeId"`
			FlowrunIteration int    `json:"flowrunIteration"`
		} `json:"executions"`
	}
	wc.GET("/api/v1/functions/"+stableFn+"/executions?flowrunId="+runID).OK(t, &stableExecutions)
	if len(stableExecutions.Executions) != 1 || stableExecutions.Executions[0].Status != "ok" || stableExecutions.Executions[0].FlowrunNodeID != "stable" || stableExecutions.Executions[0].FlowrunIteration != 0 {
		t.Fatalf("completed stable node must be reused, not re-executed on replay: %+v", stableExecutions.Executions)
	}

	var finishExecutions struct {
		Executions []struct {
			Status           string `json:"status"`
			FlowrunID        string `json:"flowrunId"`
			FlowrunNodeID    string `json:"flowrunNodeId"`
			FlowrunIteration int    `json:"flowrunIteration"`
		} `json:"executions"`
	}
	wc.GET("/api/v1/functions/"+finishFn+"/executions?flowrunId="+runID).OK(t, &finishExecutions)
	if len(finishExecutions.Executions) != 1 || finishExecutions.Executions[0].Status != "ok" || finishExecutions.Executions[0].FlowrunNodeID != "finish" || finishExecutions.Executions[0].FlowrunIteration != 0 {
		t.Fatalf("finish must execute once after the replayed node succeeds: %+v", finishExecutions.Executions)
	}

	// A completed run is terminal-final and cannot be replayed a second time.
	// completed run 已终局，不得第二次 replay。
	wc.POST("/api/v1/flowruns/"+runID+":replay", nil).Fail(t, 422, "FLOWRUN_NOT_REPLAYABLE")
}

// TestWorkflow_ReplayKeepsOriginalFunctionPin proves the version boundary users depend on when
// recovering a failed run: editing a function after failure does not silently change that run's
// replay. The pinned v1 fails twice; only a fresh run sees active v2 and completes.
//
// TestWorkflow_ReplayKeepsOriginalFunctionPin 证明失败 run 的版本边界：失败后编辑 function 不会悄悄
// 改变该 run 的 replay。钉死的 v1 两次都失败；只有 fresh run 才看到 active v2 并完成。
func TestWorkflow_ReplayKeepsOriginalFunctionPin(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	wc := c.WS(c.POST("/api/v1/workspaces", map[string]any{"name": "wf-replay-pin"}).OK(t, nil).Field(t, "id"))

	fnID := fnCreate(t, wc, "replay_pinned_function", "def f() -> dict:\n    raise RuntimeError('v1 broken')\n")
	wfID := wfCreate(t, wc, "replay_function_pin", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
		{"op": "add_node", "node": map[string]any{"id": "boom", "kind": "action", "ref": fnID}},
		{"op": "add_edge", "edge": map[string]any{"id": "e-start-boom", "from": "start", "to": "boom"}},
	})

	firstRun, status, _ := runAndWait(t, wc, wfID, map[string]any{}, 60000)
	if status != "failed" {
		t.Fatalf("v1 function run must fail before the edit, got %s", status)
	}

	// Change the active function to a known-good v2 after the run already captured its pin.
	// run 已捕获 pin 后，把 active function 编辑成确定可用的 v2。
	wc.POST("/api/v1/functions/"+fnID+":edit", map[string]any{
		"ops": []map[string]any{{"op": "set_code", "code": "def f() -> dict:\n    return {'version': 'v2'}\n"}},
	}).OK(t, nil)

	var replay struct {
		Flowrun struct {
			ID          string `json:"id"`
			Status      string `json:"status"`
			ReplayCount int    `json:"replayCount"`
		} `json:"flowrun"`
	}
	wc.POST("/api/v1/flowruns/"+firstRun+":replay", nil).OK(t, &replay)
	if replay.Flowrun.ID != firstRun || replay.Flowrun.Status != "failed" || replay.Flowrun.ReplayCount != 1 {
		t.Fatalf("replay must remain failed under the original function pin: %+v", replay.Flowrun)
	}

	var replayExecs struct {
		Executions []struct {
			VersionID        string `json:"versionId"`
			Status           string `json:"status"`
			FlowrunID        string `json:"flowrunId"`
			FlowrunNodeID    string `json:"flowrunNodeId"`
			FlowrunIteration int    `json:"flowrunIteration"`
		} `json:"executions"`
	}
	wc.GET("/api/v1/functions/"+fnID+"/executions?flowrunId="+firstRun).OK(t, &replayExecs)
	if len(replayExecs.Executions) != 2 {
		t.Fatalf("failed replay must append one v1 execution, got %+v", replayExecs.Executions)
	}
	oldVersion := replayExecs.Executions[0].VersionID
	if oldVersion == "" {
		t.Fatalf("pinned v1 execution must expose versionId: %+v", replayExecs.Executions)
	}
	for _, exec := range replayExecs.Executions {
		if exec.VersionID != oldVersion || exec.Status != "failed" || exec.FlowrunID != firstRun || exec.FlowrunNodeID != "boom" || exec.FlowrunIteration != 0 {
			t.Fatalf("replay must use the original v1 execution pin: %+v", replayExecs.Executions)
		}
	}

	// A new run is the explicit opt-in to the edited version; it must complete and carry a new pin.
	// fresh run 才是显式切到编辑后版本的入口；它应完成并带新 pin。
	freshRun, freshStatus, freshNodes := runAndWait(t, wc, wfID, map[string]any{}, 60000)
	if freshStatus != "completed" || !strings.Contains(string(freshNodes), `"version":"v2"`) {
		t.Fatalf("fresh run must use v2 and complete, status=%s nodes=%s", freshStatus, freshNodes)
	}
	var freshExecs struct {
		Executions []struct {
			VersionID        string `json:"versionId"`
			Status           string `json:"status"`
			FlowrunID        string `json:"flowrunId"`
			FlowrunNodeID    string `json:"flowrunNodeId"`
			FlowrunIteration int    `json:"flowrunIteration"`
		} `json:"executions"`
	}
	wc.GET("/api/v1/functions/"+fnID+"/executions?flowrunId="+freshRun).OK(t, &freshExecs)
	if len(freshExecs.Executions) != 1 || freshExecs.Executions[0].Status != "ok" || freshExecs.Executions[0].VersionID == oldVersion || freshExecs.Executions[0].FlowrunNodeID != "boom" || freshExecs.Executions[0].FlowrunIteration != 0 {
		t.Fatalf("fresh run must execute the edited v2 exactly once: %+v", freshExecs.Executions)
	}
}
