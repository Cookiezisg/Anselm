package scheduler

import (
	"context"
	"encoding/json"
	"testing"

	approvaldomain "github.com/sunweilin/anselm/backend/internal/domain/approval"
	controldomain "github.com/sunweilin/anselm/backend/internal/domain/control"
	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	workflowdomain "github.com/sunweilin/anselm/backend/internal/domain/workflow"
	flowrunstore "github.com/sunweilin/anselm/backend/internal/infra/store/flowrun"
)

// countingStore wraps the real flowrun store and counts GetNodes reads (the O(N²) re-read R11 cut).
// It embeds *flowrunstore.Store, so the embedded Repository methods + the two concrete run-creation
// methods are promoted unchanged — only GetNodes is intercepted.
//
// countingStore 包真 flowrun store 并数 GetNodes 读（R11 砍掉的 O(N²) 重读）。内嵌 *flowrunstore.Store，
// 故被嵌的 Repository 方法 + 两个具体建-run 方法原样提升——只拦 GetNodes。
type countingStore struct {
	*flowrunstore.Store
	getNodes int
}

func (c *countingStore) GetNodes(ctx context.Context, flowrunID string) ([]*flowrundomain.FlowRunNode, error) {
	c.getNodes++
	return c.Store.GetNodes(ctx, flowrunID)
}

// loopGraph is an N-iteration counter loop: draft (fn_draft returns {n: callCount}) → gate
// (control: retry until n >= threshold, then done) → publish. Each loop turn writes new
// (node_id, iteration) rows, so a per-turn GetNodes re-read would be O(iterations²).
//
// loopGraph 是 N 轮计数循环：draft（fn_draft 返 {n: 调用计数}）→ gate（control：n<阈值 retry、否则 done）
// → publish。每轮写新 (node_id, iteration) 行，故逐轮 GetNodes 重读为 O(轮数²)。
func loopGraph() (workflowdomain.Graph, *fakeControl) {
	g := workflowdomain.Graph{
		Nodes: []workflowdomain.Node{
			node("start", "trigger", "trg_1", nil),
			node("draft", "action", "fn_draft", map[string]string{"seed": "start.v"}),
			node("gate", "control", "ctl_loop", map[string]string{"n": "draft.n"}),
			node("publish", "action", "fn_pub", map[string]string{"out": "gate.n"}),
		},
		Edges: []workflowdomain.Edge{
			edge("e1", "start", "", "draft"),
			edge("e2", "draft", "", "gate"),
			edge("e3", "gate", "done", "publish"),
			edge("e4", "gate", "retry", "draft"), // back edge
		},
	}
	ctl := &fakeControl{byID: map[string][]controldomain.Branch{
		"ctl_loop": {
			{Port: "done", When: "input.n >= 5", Emit: map[string]string{"n": "input.n"}},
			{Port: "retry", When: "true", Emit: map[string]string{}},
		},
	}}
	return g, ctl
}

// mkSvcCounting builds a scheduler whose RunStore counts GetNodes calls.
func mkSvcCounting(t *testing.T, g workflowdomain.Graph, disp *fakeDispatcher, ctl *fakeControl) (*Service, *countingStore) {
	t.Helper()
	base, _ := newStore(t)
	cs := &countingStore{Store: base}
	raw, err := json.Marshal(g)
	if err != nil {
		t.Fatalf("marshal graph: %v", err)
	}
	wf := &fakeWorkflows{
		wf:   &workflowdomain.Workflow{ID: "wf_1", Concurrency: workflowdomain.ConcurrencyAllowAll, ActiveVersionID: "wfv_1", LifecycleState: workflowdomain.LifecycleActive},
		ver:  &workflowdomain.Version{ID: "wfv_1", WorkflowID: "wf_1", Version: 1, Graph: string(raw)},
		pins: map[string]string{},
	}
	if ctl == nil {
		ctl = &fakeControl{byID: map[string][]controldomain.Branch{}}
	}
	svc := NewService(cs, wf, ctl, &fakeApproval{byID: map[string]*approvaldomain.Version{}}, disp, nil, nil)
	return svc, cs
}

// TestAdvance_LoopRead_ConstantGetNodes_R11 proves the amplification is cut: a 5-iteration loop
// drives many walk turns, yet Advance now reads the node set from disk a CONSTANT number of times
// (once at drive entry + once in finalize), independent of iteration count — not once per turn. Before
// R11 the per-turn re-read pulled every row's `result` blob each turn → O(iterations²) bytes.
func TestAdvance_LoopRead_ConstantGetNodes_R11(t *testing.T) {
	g, ctl := loopGraph()
	disp := newDisp() // fn_draft returns {n: callCount}: 1..5, loop ends at n>=5
	svc, cs := mkSvcCounting(t, g, disp, ctl)
	ctx := ctxWS("ws_1")

	id := mustRun(t, svc, ctx, map[string]any{"v": "topic"})
	assertRunStatus(t, cs.Store, ctx, id, flowrundomain.StatusCompleted)

	// The loop ran draft 5 times across ~9 walk turns (each draft/gate iteration is its own turn).
	if disp.actionCalls["fn_draft"] != 5 {
		t.Fatalf("loop should run draft 5 times, got %d", disp.actionCalls["fn_draft"])
	}
	// StartRun → Advance reads once at drive entry + once in finalize = 2 GetNodes for the whole
	// multi-turn drive. The hard bar: it must NOT scale with iteration count (pre-R11 it was ≥ turns).
	// We assert ≤ 3 (a small constant) to be robust to a stray re-read, while still catching any
	// per-turn re-read regression (which would be ~10+ for this loop).
	if cs.getNodes > 3 {
		t.Fatalf("R11 amplification regressed: GetNodes called %d times for a multi-turn loop (want a small constant, not per-turn)", cs.getNodes)
	}
}

// TestAdvance_LoopRead_ByteIdenticalRows_R11 is the durable-correctness bar: the memoized node rows a
// looping run produces are byte-identical to a from-scratch re-run, and re-advancing the completed run
// (idempotent re-walk) adds no rows and re-runs no activity — the carried-in-memory working set must
// not change what is durably recorded.
func TestAdvance_LoopRead_ByteIdenticalRows_R11(t *testing.T) {
	g, ctl := loopGraph()

	// Run A.
	dispA := newDisp()
	svcA, csA := mkSvcCounting(t, g, dispA, ctl)
	ctx := ctxWS("ws_1")
	idA := mustRun(t, svcA, ctx, map[string]any{"v": "topic"})
	assertRunStatus(t, csA.Store, ctx, idA, flowrundomain.StatusCompleted)
	rowsA, _ := csA.Store.GetNodes(ctx, idA)

	// Run B (independent store/svc, same graph + deterministic dispatcher) → identical row content.
	_, ctlB := loopGraph()
	dispB := newDisp()
	svcB, csB := mkSvcCounting(t, g, dispB, ctlB)
	idB := mustRun(t, svcB, ctx, map[string]any{"v": "topic"})
	assertRunStatus(t, csB.Store, ctx, idB, flowrundomain.StatusCompleted)
	rowsB, _ := csB.Store.GetNodes(ctx, idB)

	gotA := normalizeRows(rowsA)
	gotB := normalizeRows(rowsB)
	if string(gotA) != string(gotB) {
		t.Fatalf("memoized rows differ between two runs of the same loop:\nA=%s\nB=%s", gotA, gotB)
	}

	// Idempotent re-advance of the completed run: no new rows, no re-run.
	beforeN := len(rowsA)
	for i := 0; i < 3; i++ {
		if err := svcA.Advance(ctx, idA); err != nil {
			t.Fatalf("re-advance %d: %v", i, err)
		}
	}
	after, _ := csA.Store.GetNodes(ctx, idA)
	if len(after) != beforeN {
		t.Fatalf("idempotency violated: %d rows → %d rows after re-advance", beforeN, len(after))
	}
	if dispA.actionCalls["fn_draft"] != 5 || dispA.actionCalls["fn_pub"] != 1 {
		t.Fatalf("re-advance re-ran activities: %+v", dispA.actionCalls)
	}
}

// normalizeRows projects rows to (node_id, iteration, status, result) sorted deterministically, then
// marshals — so a content comparison is independent of row id / timestamps / row order.
//
// normalizeRows 把行投影成 (node_id, iteration, status, result) 确定排序后 marshal——使内容比较与行 id /
// 时间戳 / 行序无关。
func normalizeRows(rows []*flowrundomain.FlowRunNode) []byte {
	type proj struct {
		NodeID    string         `json:"nodeId"`
		Iteration int            `json:"iteration"`
		Status    string         `json:"status"`
		Result    map[string]any `json:"result"`
	}
	out := make([]proj, 0, len(rows))
	for _, r := range rows {
		out = append(out, proj{NodeID: r.NodeID, Iteration: r.Iteration, Status: r.Status, Result: r.Result})
	}
	// deterministic order: node_id then iteration.
	for i := 0; i < len(out); i++ {
		for j := i + 1; j < len(out); j++ {
			if out[j].NodeID < out[i].NodeID || (out[j].NodeID == out[i].NodeID && out[j].Iteration < out[i].Iteration) {
				out[i], out[j] = out[j], out[i]
			}
		}
	}
	b, _ := json.Marshal(out)
	return b
}
