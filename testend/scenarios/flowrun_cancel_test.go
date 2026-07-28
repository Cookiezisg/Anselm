package scenarios

// Single-run cancel black-box (scheduler 工单②): a run parked on an approval is the canonical
// long-lived run — POST :cancel must flip it to a terminal `cancelled` (202, the same envelope
// shape as :replay), sweep its parked approval out of the inbox (no dead, undecidable entry), and
// hold both post-terminal guards: a second :cancel and a :replay of a cancelled run are clean 422s.
//
// 单 run cancel 黑盒（scheduler 工单②）：park 在审批上的 run 是标准长命 run——POST :cancel 必须把它
// 翻到终态 `cancelled`（202、与 :replay 同信封形）、把其 parked 审批从收件箱收走（不留死的不可决策
// 项），并守住两条终态后守卫：第二次 :cancel 与对 cancelled run 的 :replay 都是干净 422。

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

func TestFlowrun_CancelParkedRun(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "wf-cancel"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	apfID := wc.POST("/api/v1/approvals", map[string]any{
		"name": "cancel_gate", "template": "approve {{ input.amt }}?", "allowReason": true,
	}).Field(t, "id")
	wfID := wfCreate(t, wc, "cancel_pipe", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
		{"op": "add_node", "node": map[string]any{"id": "human", "kind": "approval", "ref": apfID, "input": map[string]any{"amt": "start.amt"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "human"}},
	})

	// start → parks (the long run: running, awaiting a human forever). 起跑 → 挂起（长 run：running、永等人）。
	var started struct {
		Flowrun struct {
			ID string `json:"id"`
		} `json:"flowrun"`
		Nodes json.RawMessage `json:"nodes"`
	}
	wc.POST("/api/v1/flowruns", map[string]any{"workflowId": wfID, "payload": map[string]any{"amt": "42"}}).OK(t, &started)
	runID := started.Flowrun.ID
	if !strings.Contains(string(started.Nodes), `"parked"`) {
		t.Fatalf("approval must park: %s", started.Nodes)
	}
	var inbox struct {
		Parked []struct {
			FlowRunID string `json:"flowrunId"`
		} `json:"parked"`
	}
	wc.GET("/api/v1/flowrun-inbox").OK(t, &inbox)
	if len(inbox.Parked) != 1 || inbox.Parked[0].FlowRunID != runID {
		t.Fatalf("inbox must list the parked run before cancel: %+v", inbox.Parked)
	}

	// :cancel → 202 {flowrun cancelled, nodes, nextCursor} — the :replay envelope shape.
	// :cancel → 202 {flowrun cancelled, nodes, nextCursor}——:replay 的信封形。
	var out struct {
		Flowrun struct {
			Status string `json:"status"`
		} `json:"flowrun"`
		Nodes json.RawMessage `json:"nodes"`
	}
	r := wc.POST("/api/v1/flowruns/"+runID+":cancel", nil)
	if r.Status != 202 {
		t.Fatalf(":cancel must respond 202, got %d body=%s", r.Status, r.Raw)
	}
	r.OK(t, &out)
	if out.Flowrun.Status != "cancelled" {
		t.Fatalf("run must land cancelled, got %q", out.Flowrun.Status)
	}
	if strings.Contains(string(out.Nodes), `"parked"`) {
		t.Fatalf("no node row may stay parked after cancel: %s", out.Nodes)
	}

	// Inbox holds no dead entry. 收件箱不留死项。
	inbox.Parked = nil
	wc.GET("/api/v1/flowrun-inbox").OK(t, &inbox)
	for _, p := range inbox.Parked {
		if p.FlowRunID == runID {
			t.Fatalf("cancelled run's approval must leave the inbox: %+v", inbox.Parked)
		}
	}

	// Post-terminal guards: cancel-again 422 (first-wins loser semantics on a settled run) and a
	// cancelled run is NOT replayable (:replay accepts only failed).
	// 终态后守卫：再取消 422（已定局 run 上的 first-wins 输家语义）；cancelled 不可 :replay（仅收 failed）。
	wc.POST("/api/v1/flowruns/"+runID+":cancel", nil).Fail(t, 422, "FLOWRUN_NOT_CANCELLABLE")
	wc.POST("/api/v1/flowruns/"+runID+":replay", nil).Fail(t, 422, "FLOWRUN_NOT_REPLAYABLE")
}

// TestFlowrun_CancelInFlightAgent proves the other cancellation face: an agent already inside a
// provider call is interrupted, its node is not misreported as failed, and the scheduler remains
// usable for the next manual run.
func TestFlowrun_CancelInFlightAgent(t *testing.T) {
	t.Parallel()
	wc, mock := agentSetup(t)
	agID := agCreate(t, wc, map[string]any{
		"name": "cancelled worker", "description": "in-flight cancel probe", "prompt": "answer briefly",
	})
	wfID := wfCreate(t, wc, "cancel_agent_pipe", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
		{"op": "add_node", "node": map[string]any{"id": "work", "kind": "agent", "ref": agID, "input": map[string]any{"task": "start.task"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "work"}},
	})

	// Keep the provider call in flight long enough to issue :cancel. The second scripted response
	// is reserved for the post-cancel run, proving the queue is not poisoned by the interruption.
	mock.Enqueue(agModel, harness.LLMTurn{Text: "should be cancelled", StallMS: 8000}, harness.LLMTurn{Text: "after cancel"})
	// POST /flowruns itself waits for the synchronous manual run to finish before replying, so fire
	// it in the background and discover the durable running row through the list endpoint.
	done := make(chan struct{})
	go func() {
		defer close(done)
		_, _ = wc.Try("POST", "/api/v1/flowruns", map[string]any{"workflowId": wfID, "payload": map[string]any{"task": "long task"}})
	}()
	runID := ""
	harness.Eventually(t, 15000, "in-flight agent run becomes running", func() bool {
		for _, row := range listRunRows(t, wc, "?workflowId="+wfID) {
			if row.Status == "running" && len(mock.DumpsFor(agModel)) > 0 {
				runID = row.ID
				return true
			}
		}
		return false
	})

	var cancelled struct {
		Flowrun struct {
			Status string `json:"status"`
		} `json:"flowrun"`
		Nodes json.RawMessage `json:"nodes"`
	}
	r := wc.POST("/api/v1/flowruns/"+runID+":cancel", nil)
	if r.Status != 202 {
		t.Fatalf("in-flight :cancel must respond 202, got %d/%s body=%s", r.Status, r.Code, r.Raw)
	}
	r.OK(t, &cancelled)
	if cancelled.Flowrun.Status != "cancelled" {
		t.Fatalf("in-flight agent run must land cancelled, got %+v", cancelled.Flowrun)
	}
	if strings.Contains(string(cancelled.Nodes), `"status":"failed"`) || strings.Contains(string(cancelled.Nodes), `"status":"running"`) {
		t.Fatalf("cancelled run must not expose a lying failed/running agent node: %s", cancelled.Nodes)
	}
	<-done

	var second struct {
		Flowrun struct {
			ID string `json:"id"`
		} `json:"flowrun"`
	}
	wc.POST("/api/v1/flowruns", map[string]any{"workflowId": wfID, "payload": map[string]any{"task": "follow-up"}}).OK(t, &second)
	harness.Eventually(t, 30000, "scheduler accepts a fresh run after cancellation", func() bool {
		var got struct {
			Flowrun struct {
				Status string `json:"status"`
			} `json:"flowrun"`
		}
		r := wc.GET("/api/v1/flowruns/" + second.Flowrun.ID)
		if r.Status != 200 {
			return false
		}
		_ = json.Unmarshal(r.Data, &got)
		return got.Flowrun.Status == "completed"
	})
}
