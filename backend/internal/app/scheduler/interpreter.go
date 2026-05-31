package scheduler

import (
	"context"
	"fmt"

	workflowapp "github.com/sunweilin/forgify/backend/internal/app/workflow"
	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
)

// Interpreter is the durable execution engine (ADR-016): one goroutine walks the pinned graph
// from the trigger node; each agent/tool node is an activity journaled as node_started →
// node_completed/node_failed; a case node is pure control flow journaled as branch_taken. Run
// and Resume share one loop — both consult the journal before each step (copy-hit, ADR-019), so a
// crash-replay copies recorded results/decisions and only re-runs the first un-journaled step.
// M3 scope adds case (per-branch CEL guard, first-true-wins) + payload data flow; fork-join/loop
// land next in M3.
//
// Interpreter 是 durable 执行引擎;Run/Resume 同一套 walk,重放命中已记账步/分支抄结果、不重跑。
type Interpreter struct {
	journal  flowrundomain.JournalRepository
	dispatch Dispatcher
}

func New(journal flowrundomain.JournalRepository, dispatch Dispatcher) *Interpreter {
	return &Interpreter{journal: journal, dispatch: dispatch}
}

// Run executes a fresh flowrun with the trigger payload. Resume replays an existing one after a
// crash with the same payload (the flowrun's persisted input). Identical loop.
func (in *Interpreter) Run(ctx context.Context, flowrunID string, g workflowdomain.Graph, input map[string]any) error {
	return in.walk(ctx, flowrunID, g, input)
}
func (in *Interpreter) Resume(ctx context.Context, flowrunID string, g workflowdomain.Graph, input map[string]any) error {
	return in.walk(ctx, flowrunID, g, input)
}

func (in *Interpreter) walk(ctx context.Context, flowrunID string, g workflowdomain.Graph, input map[string]any) error {
	events, err := in.journal.LoadJournal(ctx, flowrunID)
	if err != nil {
		return fmt.Errorf("scheduler.walk load: %w", err)
	}
	completed := completedResults(events)
	branches := branchResults(events)

	node := triggerNode(g)
	if node == nil {
		return fmt.Errorf("scheduler.walk: no trigger node in graph")
	}
	payload := input
	if payload == nil {
		payload = map[string]any{}
	}
	for {
		next, out, stepErr := in.step(ctx, flowrunID, g, *node, payload, completed, branches)
		if stepErr != nil {
			return stepErr
		}
		if next == nil {
			return nil // no successor = terminal path (WP11)
		}
		node, payload = next, out
	}
}

// step runs (or copies) one node and returns its successor + the payload to thread downstream.
func (in *Interpreter) step(ctx context.Context, flowrunID string, g workflowdomain.Graph,
	node workflowdomain.NodeSpec, payload map[string]any,
	completed map[string]map[string]any, branches map[string]map[string]any) (*workflowdomain.NodeSpec, map[string]any, error) {

	switch node.Type {
	case workflowdomain.NodeTypeTrigger:
		return successor(g, node.ID), payload, nil // entry, not an activity
	case workflowdomain.NodeTypeCondition: // 5-node "case": pure control flow
		return in.stepCase(ctx, flowrunID, g, node, payload, branches)
	default:
		return in.stepActivity(ctx, flowrunID, g, node, payload, completed)
	}
}

// stepActivity journals an agent/tool node (node_started → Dispatch → node_completed/node_failed),
// or copies a recorded completion on replay (ADR-019 copy-hit).
func (in *Interpreter) stepActivity(ctx context.Context, flowrunID string, g workflowdomain.Graph,
	node workflowdomain.NodeSpec, payload map[string]any, completed map[string]map[string]any) (*workflowdomain.NodeSpec, map[string]any, error) {

	if cached, ok := completed[node.ID]; ok {
		return successor(g, node.ID), cached, nil // copy-hit: no Dispatch
	}
	if _, err := in.journal.AppendEvent(ctx, &flowrundomain.FlowRunEvent{
		FlowrunID: flowrunID, Type: flowrundomain.EventNodeStarted, NodeID: node.ID,
	}); err != nil {
		return nil, nil, fmt.Errorf("scheduler.step %s started: %w", node.ID, err)
	}
	res := in.dispatch.Dispatch(ctx, DispatchInput{
		Node:   node,
		NodeIn: payload,
		ExecCtx: &ExecutionContext{
			Run:       &flowrundomain.FlowRun{ID: flowrunID},
			Variables: map[string]any{},
			Outputs:   map[string]map[string]any{},
		},
	})
	if res.Error != nil {
		if _, err := in.journal.AppendEvent(ctx, &flowrundomain.FlowRunEvent{
			FlowrunID: flowrunID, Type: flowrundomain.EventNodeFailed, NodeID: node.ID,
			Result: map[string]any{"error": res.Error.Error()},
		}); err != nil {
			return nil, nil, fmt.Errorf("scheduler.step %s failed-journal: %w", node.ID, err)
		}
		return nil, nil, fmt.Errorf("scheduler.step %s: %w", node.ID, res.Error)
	}
	if _, err := in.journal.AppendEvent(ctx, &flowrundomain.FlowRunEvent{
		FlowrunID: flowrunID, Type: flowrundomain.EventNodeCompleted, NodeID: node.ID,
		Result: res.Outputs,
	}); err != nil {
		return nil, nil, fmt.Errorf("scheduler.step %s completed: %w", node.ID, err)
	}
	return successor(g, node.ID), res.Outputs, nil
}

// stepCase evaluates the case node's per-branch CEL guards (first-true-wins, fail-to-false G9),
// journals branch_taken, and routes to the chosen branch's `to` with its emitted payload. On
// replay it copies the recorded branch_taken — the basis for active-branch join (17 §3).
//
// stepCase 求 case 各分支 when(first-true-wins,fail-to-false),记 branch_taken,按选中 to 路由。
func (in *Interpreter) stepCase(ctx context.Context, flowrunID string, g workflowdomain.Graph,
	node workflowdomain.NodeSpec, payload map[string]any, branches map[string]map[string]any) (*workflowdomain.NodeSpec, map[string]any, error) {

	if bt, ok := branches[node.ID]; ok { // copy-hit: decision already journaled
		toID, _ := bt["to"].(string)
		out, _ := bt["payload"].(map[string]any)
		if out == nil {
			out = payload
		}
		return nodeByID(g, toID), out, nil
	}

	specs, _ := node.Config["branches"].([]any)
	for _, b := range specs {
		bm, _ := b.(map[string]any)
		when, _ := bm["when"].(string)
		prg, err := workflowapp.CompileCEL(when)
		if err != nil {
			continue // unparseable guard = skip (author bug; last when:"true" still catches)
		}
		match, evalErr := prg.EvalBool(payload, nil)
		if evalErr != nil {
			match = false // G9 fail-to-false
		}
		if !match {
			continue
		}
		toID, _ := bm["to"].(string)
		out := payload
		if emit, has := bm["emit"].(map[string]any); has {
			out = evalEmit(emit, payload)
		}
		if _, err := in.journal.AppendEvent(ctx, &flowrundomain.FlowRunEvent{
			FlowrunID: flowrunID, Type: flowrundomain.EventBranchTaken, NodeID: node.ID,
			Result: map[string]any{"to": toID, "payload": out},
		}); err != nil {
			return nil, nil, fmt.Errorf("scheduler.case %s branch_taken: %w", node.ID, err)
		}
		return nodeByID(g, toID), out, nil
	}
	return nil, nil, fmt.Errorf("scheduler.case %s: no branch matched (missing final when:\"true\"?)", node.ID)
}

// evalEmit evaluates each emit field as a bare CEL expression producing a typed value.
//
// evalEmit 把 emit 各字段当裸 CEL 求值为 typed 值。
func evalEmit(emit, payload map[string]any) map[string]any {
	out := make(map[string]any, len(emit))
	for k, v := range emit {
		expr, ok := v.(string)
		if !ok {
			out[k] = v
			continue
		}
		prg, err := workflowapp.CompileCEL(expr)
		if err != nil {
			out[k] = nil
			continue
		}
		val, err := prg.Eval(payload, nil)
		if err != nil {
			out[k] = nil
			continue
		}
		out[k] = val
	}
	return out
}

// completedResults maps nodeID → recorded node_completed output (M3: gen0/iteration_key=0).
func completedResults(events []flowrundomain.FlowRunEvent) map[string]map[string]any {
	out := map[string]map[string]any{}
	for i := range events {
		if events[i].Type == flowrundomain.EventNodeCompleted {
			out[events[i].NodeID] = asMap(events[i].Result)
		}
	}
	return out
}

// branchResults maps a case nodeID → its recorded branch_taken result ({to, payload}).
func branchResults(events []flowrundomain.FlowRunEvent) map[string]map[string]any {
	out := map[string]map[string]any{}
	for i := range events {
		if events[i].Type == flowrundomain.EventBranchTaken {
			out[events[i].NodeID] = asMap(events[i].Result)
		}
	}
	return out
}

func triggerNode(g workflowdomain.Graph) *workflowdomain.NodeSpec {
	for i := range g.Nodes {
		if g.Nodes[i].Type == workflowdomain.NodeTypeTrigger {
			return &g.Nodes[i]
		}
	}
	return nil
}

func nodeByID(g workflowdomain.Graph, id string) *workflowdomain.NodeSpec {
	for i := range g.Nodes {
		if g.Nodes[i].ID == id {
			return &g.Nodes[i]
		}
	}
	return nil
}

// successor returns the single downstream node, or nil at a terminal. M3 linear/activity path
// assumes one out-edge; case routes via its branches[].to (nodeByID), and fork-join is next.
func successor(g workflowdomain.Graph, fromID string) *workflowdomain.NodeSpec {
	for _, e := range g.Edges {
		if e.From == fromID {
			return nodeByID(g, e.To)
		}
	}
	return nil
}

func asMap(v any) map[string]any {
	if m, ok := v.(map[string]any); ok {
		return m
	}
	return map[string]any{}
}
