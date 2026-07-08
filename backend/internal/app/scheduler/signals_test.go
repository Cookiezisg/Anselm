package scheduler

import (
	"context"
	"strings"
	"sync"
	"testing"

	entitystreamapp "github.com/sunweilin/anselm/backend/internal/app/entitystream"
	approvaldomain "github.com/sunweilin/anselm/backend/internal/domain/approval"
	controldomain "github.com/sunweilin/anselm/backend/internal/domain/control"
	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	streamdomain "github.com/sunweilin/anselm/backend/internal/domain/stream"
	workflowdomain "github.com/sunweilin/anselm/backend/internal/domain/workflow"
)

// sigBridge captures every published event (mutex-guarded: the F174 pool publishes from worker
// goroutines).
//
// sigBridge 捕获每条发布事件（带锁：F174 池从 worker 协程发布）。
type sigBridge struct {
	mu     sync.Mutex
	events []streamdomain.Event
}

func (b *sigBridge) Publish(_ context.Context, e streamdomain.Event) (streamdomain.Envelope, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.events = append(b.events, e)
	return streamdomain.Envelope{}, nil
}
func (b *sigBridge) Subscribe(_ context.Context, _ int64) (<-chan streamdomain.Envelope, func(), error) {
	return nil, func() {}, nil
}

// signals returns the captured Signal frames of one node type. 按节点型取捕获的 Signal 帧。
func (b *sigBridge) signals(nodeType string) []streamdomain.Signal {
	b.mu.Lock()
	defer b.mu.Unlock()
	var out []streamdomain.Signal
	for _, e := range b.events {
		if s, ok := e.Frame.(streamdomain.Signal); ok && s.Node.Type == nodeType {
			out = append(out, s)
		}
	}
	return out
}

// TestSignals_ControlTickCarriesPortAndTerminalIsDurable pins the two W6 stream upgrades on one
// control-gated run: ① the node tick for a control node carries the chosen branch as `port`
// (emit-time available — R-11's lazy GET retires) while staying EPHEMERAL (E2: flowrun_nodes is
// the reconnect truth); ② the run's terminal lands as ONE DURABLE run_terminal signal (it must
// survive a reconnect — R-10's poll fallback retires).
//
// TestSignals_ControlTickCarriesPortAndTerminalIsDurable 在一条经 control 门的 run 上钉两项 W6
// 流升级：① control 节点的 tick 以 `port` 捎带选中分支（emit 时已在手——R-11 惰性 GET 退役）且保持
// **ephemeral**（E2：flowrun_nodes 是重连真相）；② run 终态落为**一条 durable** run_terminal 信号
// （必须活过重连——R-10 poll 兜底退役）。
func TestSignals_ControlTickCarriesPortAndTerminalIsDurable(t *testing.T) {
	g := workflowdomain.Graph{
		Nodes: []workflowdomain.Node{
			node("start", "trigger", "trg_1", nil),
			node("gate", "control", "ctl_1", map[string]string{"v": "start.v"}),
			node("p", "action", "fn_p", map[string]string{"x": "gate.out"}),
		},
		Edges: []workflowdomain.Edge{
			edge("e1", "start", "", "gate"),
			edge("e2", "gate", "pass", "p"),
		},
	}
	ctl := &fakeControl{byID: map[string][]controldomain.Branch{
		"ctl_1": {{Port: "pass", When: "true", Emit: map[string]string{"out": "input.v"}}},
	}}
	disp := newDisp()
	svc, store := mkSvc(t, g, disp, ctl, nil, "")
	b := &sigBridge{}
	svc.SetEntitiesBridge(b)
	ctx := ctxWS("ws_1")
	id := mustRun(t, svc, ctx, map[string]any{"v": "go"})
	assertRunStatus(t, store, ctx, id, flowrundomain.StatusCompleted)

	// ① The gate's tick carries port=pass and is ephemeral. 门 tick 带 port 且 ephemeral。
	var gateTick *streamdomain.Signal
	for _, s := range b.signals(entitystreamapp.NodeRun) {
		if strings.Contains(string(s.Node.Content), `"nodeId":"gate"`) {
			sc := s
			gateTick = &sc
			break
		}
	}
	if gateTick == nil {
		t.Fatal("no node tick for the control gate")
	}
	if !strings.Contains(string(gateTick.Node.Content), `"port":"pass"`) {
		t.Fatalf("control tick lacks the chosen port: %s", gateTick.Node.Content)
	}
	if !gateTick.Ephemeral {
		t.Fatalf("node ticks must stay ephemeral (E2), got durable: %s", gateTick.Node.Content)
	}
	// Non-routing nodes carry no port key at all (absence, not an empty string). 非路由节点无 port 键。
	for _, s := range b.signals(entitystreamapp.NodeRun) {
		if strings.Contains(string(s.Node.Content), `"nodeId":"p"`) && strings.Contains(string(s.Node.Content), `"port"`) {
			t.Fatalf("action tick must not carry a port: %s", s.Node.Content)
		}
	}

	// ② Exactly one DURABLE terminal signal with the run id + status. 恰一条 durable 终态信号。
	terms := b.signals(entitystreamapp.NodeRunTerminal)
	if len(terms) != 1 {
		t.Fatalf("want exactly 1 run_terminal signal, got %d", len(terms))
	}
	if terms[0].Ephemeral {
		t.Fatal("run_terminal must be durable (survive reconnect)")
	}
	if !strings.Contains(string(terms[0].Node.Content), `"status":"completed"`) ||
		!strings.Contains(string(terms[0].Node.Content), id) {
		t.Fatalf("terminal content = %s, want completed + %s", terms[0].Node.Content, id)
	}
}

// TestSignals_ApprovalDecidedTickCarriesPort pins the approval asymmetry fix: an approval gets NO
// tick from Advance past parked (the resolved row pre-exists when the run re-enters, computeReady
// skips it), so DecideApproval itself must emit the decided tick — completed, with the decision
// port, read back from the record-once row.
//
// TestSignals_ApprovalDecidedTickCarriesPort 钉 approval 不对称修复：approval 越过 parked 后
// Advance 不会再 tick 它（run 重入时已决行已存在、computeReady 跳过），故 DecideApproval 自己必须
// 发已决 tick——completed、带决策 port、从 record-once 行读回。
func TestSignals_ApprovalDecidedTickCarriesPort(t *testing.T) {
	apf := &fakeApproval{byID: map[string]*approvaldomain.Version{
		"apf_1": {Template: "approve {{ input.amt }}?", AllowReason: true},
	}}
	disp := newDisp()
	svc, store := mkSvc(t, approvalGraph(), disp, nil, apf, "")
	b := &sigBridge{}
	svc.SetEntitiesBridge(b)
	ctx := ctxWS("ws_1")
	id := mustRun(t, svc, ctx, map[string]any{"v": "9"})
	assertRunStatus(t, store, ctx, id, flowrundomain.StatusRunning) // parked at human

	if err := svc.DecideApproval(ctx, id, "human", "yes", "fine"); err != nil {
		t.Fatalf("DecideApproval: %v", err)
	}
	assertRunStatus(t, store, ctx, id, flowrundomain.StatusCompleted)

	var decided *streamdomain.Signal
	for _, s := range b.signals(entitystreamapp.NodeRun) {
		c := string(s.Node.Content)
		if strings.Contains(c, `"nodeId":"human"`) && strings.Contains(c, `"status":"completed"`) {
			sc := s
			decided = &sc
			break
		}
	}
	if decided == nil {
		t.Fatal("no decided tick for the approval node")
	}
	if !strings.Contains(string(decided.Node.Content), `"port":"yes"`) {
		t.Fatalf("decided tick lacks the decision port: %s", decided.Node.Content)
	}
}
