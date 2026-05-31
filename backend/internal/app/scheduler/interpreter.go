package scheduler

import (
	"context"
	"fmt"

	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
)

// Interpreter is the durable execution engine (ADR-016): one goroutine walks the pinned graph
// from the trigger node; each agent/tool node is an activity journaled as node_started →
// node_completed/node_failed. Run and Resume share one loop — both consult the journal before
// each activity (copy-hit, ADR-019), so a crash-replay copies recorded results and only re-runs
// the first un-journaled step. M2 scope: linear (single-out-edge) flows; case/fork-join/loop = M3.
//
// Interpreter 是 durable 执行引擎;Run/Resume 同一套 walk,重放命中已记账步抄结果、不重跑。
type Interpreter struct {
	journal  flowrundomain.JournalRepository
	dispatch Dispatcher
}

func New(journal flowrundomain.JournalRepository, dispatch Dispatcher) *Interpreter {
	return &Interpreter{journal: journal, dispatch: dispatch}
}

// Run executes a fresh flowrun. Resume replays an existing one after a crash. They are the same
// loop: Run is Resume on a journal that happens to be empty.
func (in *Interpreter) Run(ctx context.Context, flowrunID string, g workflowdomain.Graph) error {
	return in.walk(ctx, flowrunID, g)
}
func (in *Interpreter) Resume(ctx context.Context, flowrunID string, g workflowdomain.Graph) error {
	return in.walk(ctx, flowrunID, g)
}

func (in *Interpreter) walk(ctx context.Context, flowrunID string, g workflowdomain.Graph) error {
	events, err := in.journal.LoadJournal(ctx, flowrunID)
	if err != nil {
		return fmt.Errorf("scheduler.walk load: %w", err)
	}
	done := completedResults(events)

	node := triggerNode(g)
	if node == nil {
		return fmt.Errorf("scheduler.walk: no trigger node in graph")
	}
	payload := map[string]any{}
	for {
		next, out, stepErr := in.step(ctx, flowrunID, g, *node, payload, done)
		if stepErr != nil {
			return stepErr
		}
		if next == nil {
			return nil // no successor = terminal path (WP11, M2 linear)
		}
		node, payload = next, out
	}
}

// step runs (or copies) one node and returns its successor + the payload to thread downstream.
func (in *Interpreter) step(ctx context.Context, flowrunID string, g workflowdomain.Graph,
	node workflowdomain.NodeSpec, payload map[string]any, done map[string]map[string]any) (*workflowdomain.NodeSpec, map[string]any, error) {

	// trigger is the program entry, not an activity.
	if node.Type == workflowdomain.NodeTypeTrigger {
		return successor(g, node.ID), payload, nil
	}

	// copy-hit (ADR-019): an already-recorded completion is copied — never re-dispatched.
	if cached, ok := done[node.ID]; ok {
		return successor(g, node.ID), cached, nil
	}

	if _, err := in.journal.AppendEvent(ctx, &flowrundomain.FlowRunEvent{
		FlowrunID: flowrunID, Type: flowrundomain.EventNodeStarted, NodeID: node.ID,
	}); err != nil {
		return nil, nil, fmt.Errorf("scheduler.step %s started: %w", node.ID, err)
	}

	// Minimal ExecutionContext satisfies the Dispatcher contract: the M2 linear path
	// (function ignores ExecCtx; handler reads only Run.ID). The deep flow (condition/loop/
	// llm read Outputs/Variables) is wired to journal scope-vars (§5) in M3's node collapse.
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

// completedResults maps nodeID → its recorded output. M2 is gen0/iteration_key=0 only; M3/M6
// generalize to "highest generation" (ADR-019) when replay-reset + loops land.
func completedResults(events []flowrundomain.FlowRunEvent) map[string]map[string]any {
	out := map[string]map[string]any{}
	for i := range events {
		e := events[i]
		if e.Type == flowrundomain.EventNodeCompleted {
			out[e.NodeID] = asMap(e.Result)
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

// successor returns the single downstream node, or nil at a terminal. M2 assumes one out-edge;
// multi-edge fan-out / case-port selection is M3.
func successor(g workflowdomain.Graph, fromID string) *workflowdomain.NodeSpec {
	for _, e := range g.Edges {
		if e.From == fromID {
			for i := range g.Nodes {
				if g.Nodes[i].ID == e.To {
					return &g.Nodes[i]
				}
			}
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
