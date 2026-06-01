package scheduler

import (
	"context"
	"testing"

	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
)

// agentSubSteps round-trips ReAct steps through the flowrun journal (ADR-010): steps recorded at a
// prior generation are returned by LoadSteps (ordered by turn) for a replay at a higher generation,
// while the current generation's own steps are excluded (this run's work, not replay input).
func TestAgentSubSteps_RecordThenReplayAcrossGenerations(t *testing.T) {
	journal := newJournal(t)
	ctx := context.Background()

	// Generation 0 — the original run records two completed steps.
	gen0 := &agentSubSteps{journal: journal, flowrunID: "fr1", nodeID: "agent", iter: 0, generation: 0}
	gen0.RecordStep(ctx, 0,
		[]chatdomain.Block{{Type: eventlogdomain.BlockTypeText, Content: "a0"}},
		[]chatdomain.Block{{Type: eventlogdomain.BlockTypeToolResult, Content: "r0"}})
	gen0.RecordStep(ctx, 1,
		[]chatdomain.Block{{Type: eventlogdomain.BlockTypeText, Content: "a1"}}, nil)

	// A replay at generation 1 reconstructs both prior steps, ordered by turn, fields round-tripped.
	gen1 := &agentSubSteps{journal: journal, flowrunID: "fr1", nodeID: "agent", iter: 0, generation: 1}
	steps := gen1.LoadSteps(ctx)
	if len(steps) != 2 {
		t.Fatalf("replay must reconstruct 2 prior steps, got %d", len(steps))
	}
	if len(steps[0].Assistant) != 1 || steps[0].Assistant[0].Content != "a0" {
		t.Fatalf("step0 assistant not round-tripped: %+v", steps[0].Assistant)
	}
	if len(steps[0].ToolResults) != 1 || steps[0].ToolResults[0].Content != "r0" {
		t.Fatalf("step0 tool results not round-tripped: %+v", steps[0].ToolResults)
	}
	if len(steps[1].Assistant) != 1 || steps[1].Assistant[0].Content != "a1" {
		t.Fatalf("step1 not round-tripped: %+v", steps[1].Assistant)
	}

	// The original generation-0 run replays nothing — its own steps are not replay input.
	if got := gen0.LoadSteps(ctx); len(got) != 0 {
		t.Fatalf("a run must not replay its own generation's steps, got %d", len(got))
	}

	// A different node replays nothing (scope is per node + iteration).
	other := &agentSubSteps{journal: journal, flowrunID: "fr1", nodeID: "other", iter: 0, generation: 1}
	if got := other.LoadSteps(ctx); len(got) != 0 {
		t.Fatalf("unrelated node must replay nothing, got %d", len(got))
	}
}

// LoadSteps merges across generations per turn (highest generation wins) so a replay-of-a-replay still
// sees every earlier copy-hit step — turn 0 from gen 0 + turn 1 from gen 1 both surface at gen 2.
func TestAgentSubSteps_MergesAcrossGenerationsByTurn(t *testing.T) {
	journal := newJournal(t)
	ctx := context.Background()

	gen0 := &agentSubSteps{journal: journal, flowrunID: "fr2", nodeID: "ag", iter: 0, generation: 0}
	gen0.RecordStep(ctx, 0, []chatdomain.Block{{Type: eventlogdomain.BlockTypeText, Content: "t0"}}, nil)

	gen1 := &agentSubSteps{journal: journal, flowrunID: "fr2", nodeID: "ag", iter: 0, generation: 1}
	gen1.RecordStep(ctx, 1, []chatdomain.Block{{Type: eventlogdomain.BlockTypeText, Content: "t1"}}, nil)

	gen2 := &agentSubSteps{journal: journal, flowrunID: "fr2", nodeID: "ag", iter: 0, generation: 2}
	steps := gen2.LoadSteps(ctx)
	if len(steps) != 2 {
		t.Fatalf("replay-of-replay must see both turns (gen0 t0 + gen1 t1), got %d", len(steps))
	}
	if steps[0].Assistant[0].Content != "t0" || steps[1].Assistant[0].Content != "t1" {
		t.Fatalf("turns not merged/ordered: %q, %q", steps[0].Assistant[0].Content, steps[1].Assistant[0].Content)
	}
}

// LoadHistory prepends reconstructed replay steps after the prompt so the loop resumes past them.
func TestAgentHost_LoadHistory_PrependsReplaySteps(t *testing.T) {
	h := &agentHost{
		userPrompt: "do it",
		replay: []RecordedStep{
			{Assistant: []chatdomain.Block{{Type: eventlogdomain.BlockTypeText, Content: "step0"}}},
		},
	}
	msgs, err := h.LoadHistory(context.Background())
	if err != nil {
		t.Fatalf("LoadHistory: %v", err)
	}
	if len(msgs) < 2 {
		t.Fatalf("replay history must hold the prompt + at least one reconstructed step, got %d", len(msgs))
	}
	if msgs[0].Content != "do it" {
		t.Fatalf("first message must be the prompt, got %q", msgs[0].Content)
	}
}
