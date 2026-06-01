package scheduler

import (
	"context"
	"encoding/json"
	"sort"

	"go.uber.org/zap"

	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
)

// agentSubSteps is the journal-backed AgentSubStepJournal the interpreter hands to an agent dispatch
// (ADR-010). It scopes the flowrun journal to one (node, iteration): RecordStep appends an
// agent_step_completed event per finished ReAct step; LoadSteps returns the prior run's completed steps
// so a :replay reconstructs history and skips re-running them.
//
// agentSubSteps 是 interpreter 交给 agent dispatch 的 journal 实现(ADR-010),按 (node,iteration) 作用域。
type agentSubSteps struct {
	journal    flowrundomain.JournalRepository
	flowrunID  string
	nodeID     string
	iter       int
	generation int
	log        *zap.Logger
}

// RecordStep journals a completed step (assistant turn + tool results) so a future :replay can
// reconstruct it. Best-effort: a journal failure only costs the copy-hit (the step re-runs on replay).
func (a *agentSubSteps) RecordStep(ctx context.Context, step int, assistant, toolResults []chatdomain.Block) {
	if a == nil || a.journal == nil {
		return
	}
	rec := RecordedStep{Assistant: assistant, ToolResults: toolResults}
	if _, err := a.journal.AppendEvent(ctx, &flowrundomain.FlowRunEvent{
		FlowrunID: a.flowrunID, Type: flowrundomain.EventAgentStepCompleted,
		NodeID: a.nodeID, IterationKey: a.iter, Generation: a.generation, Turn: step,
		Result: rec,
	}); err != nil {
		a.logger().Warn("agent sub-step journal failed",
			zap.String("flowrunID", a.flowrunID), zap.String("nodeID", a.nodeID),
			zap.Int("step", step), zap.Error(err))
	}
}

// LoadSteps returns this node/iteration's completed agent steps from PRIOR generations only (a fresh
// run at the current generation replays nothing), one per turn taking the highest generation < current
// (ADR-019 highest-generation), ordered by turn. So a replay-of-a-replay still sees every earlier
// copy-hit step (each turn keeps its best recording across generations).
func (a *agentSubSteps) LoadSteps(ctx context.Context) []RecordedStep {
	if a == nil || a.journal == nil {
		return nil
	}
	evs, err := a.journal.LoadJournal(ctx, a.flowrunID)
	if err != nil {
		a.logger().Warn("agent sub-step load failed", zap.String("flowrunID", a.flowrunID), zap.Error(err))
		return nil
	}
	type pick struct {
		gen int
		rec RecordedStep
	}
	byTurn := map[int]pick{}
	for i := range evs {
		e := evs[i]
		if e.Type != flowrundomain.EventAgentStepCompleted || e.NodeID != a.nodeID || e.IterationKey != a.iter {
			continue
		}
		if e.Generation >= a.generation { // current/future gen = this run's own steps, not replay input
			continue
		}
		if cur, ok := byTurn[e.Turn]; ok && cur.gen >= e.Generation {
			continue
		}
		rec, derr := decodeStep(e.Result)
		if derr != nil {
			a.logger().Warn("agent sub-step decode failed", zap.Int("turn", e.Turn), zap.Error(derr))
			continue
		}
		byTurn[e.Turn] = pick{gen: e.Generation, rec: rec}
	}
	if len(byTurn) == 0 {
		return nil
	}
	turns := make([]int, 0, len(byTurn))
	for t := range byTurn {
		turns = append(turns, t)
	}
	sort.Ints(turns)
	out := make([]RecordedStep, 0, len(turns))
	for _, t := range turns {
		out = append(out, byTurn[t].rec)
	}
	return out
}

func (a *agentSubSteps) logger() *zap.Logger {
	if a.log == nil {
		return zap.NewNop()
	}
	return a.log
}

// decodeStep round-trips the journal's deserialized Result (map[string]any) back into a RecordedStep.
func decodeStep(result any) (RecordedStep, error) {
	raw, err := json.Marshal(result)
	if err != nil {
		return RecordedStep{}, err
	}
	var rec RecordedStep
	if err := json.Unmarshal(raw, &rec); err != nil {
		return RecordedStep{}, err
	}
	return rec, nil
}
