package scheduler

import (
	"context"
	"testing"
	"time"

	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
)

// timerGraph: trigger -> function(a) where a carries the given timer config (at/after).
func timerGraph(cfg map[string]any) workflowdomain.Graph {
	return workflowdomain.Graph{
		Nodes: []workflowdomain.NodeSpec{
			{ID: "t", Type: workflowdomain.NodeTypeTrigger},
			{ID: "a", Type: workflowdomain.NodeTypeFunction, Config: cfg},
		},
		Edges: []workflowdomain.EdgeSpec{{ID: "e1", From: "t", To: "a"}},
	}
}

func hasEvent(evs []flowrundomain.FlowRunEvent, node, typ string) bool {
	for _, e := range evs {
		if e.NodeID == node && e.Type == typ {
			return true
		}
	}
	return false
}

// TestTimerGate_PastAtFiresImmediately: a node with config.at in the past arms a timer_armed +
// writes timer_fired without waiting, then runs the node (durable timer gate, 17 §7).
func TestTimerGate_PastAtFiresImmediately(t *testing.T) {
	journal := newJournal(t)
	router := &countingRouter{calls: map[string]int{}}
	ctx := context.Background()

	g := timerGraph(map[string]any{"at": "2020-01-01T00:00:00Z"})
	if _, err := New(journal, router).Run(ctx, "fr_timer_at", g, nil); err != nil {
		t.Fatalf("run: %v", err)
	}
	evs, _ := journal.LoadJournal(ctx, "fr_timer_at")
	if !hasEvent(evs, "a", flowrundomain.EventTimerArmed) {
		t.Errorf("missing timer_armed for node a; journal=%+v", evs)
	}
	if !hasEvent(evs, "a", flowrundomain.EventTimerFired) {
		t.Errorf("missing timer_fired for node a")
	}
	if !hasEvent(evs, "a", flowrundomain.EventNodeCompleted) {
		t.Errorf("node a did not complete after the timer gate opened")
	}
	if router.calls["a"] != 1 {
		t.Errorf("node a dispatched %d times, want 1", router.calls["a"])
	}
}

// TestTimerGate_AfterWaitsThenFires: config.after waits the (small) duration then fires + runs.
func TestTimerGate_AfterWaitsThenFires(t *testing.T) {
	journal := newJournal(t)
	router := &countingRouter{calls: map[string]int{}}
	ctx := context.Background()

	start := time.Now()
	g := timerGraph(map[string]any{"after": 0.4}) // 0.4s
	if _, err := New(journal, router).Run(ctx, "fr_timer_after", g, nil); err != nil {
		t.Fatalf("run: %v", err)
	}
	if elapsed := time.Since(start); elapsed < 300*time.Millisecond {
		t.Errorf("timer gate did not wait: elapsed %v, want ≥ ~0.4s", elapsed)
	}
	evs, _ := journal.LoadJournal(ctx, "fr_timer_after")
	if !hasEvent(evs, "a", flowrundomain.EventTimerFired) {
		t.Errorf("missing timer_fired for node a")
	}
}

// TestTimerGate_NoConfigNoTimer: a node without at/after arms no timer (no overhead on normal nodes).
func TestTimerGate_NoConfigNoTimer(t *testing.T) {
	journal := newJournal(t)
	router := &countingRouter{calls: map[string]int{}}
	ctx := context.Background()

	if _, err := New(journal, router).Run(ctx, "fr_no_timer", linearGraph(), nil); err != nil {
		t.Fatalf("run: %v", err)
	}
	evs, _ := journal.LoadJournal(ctx, "fr_no_timer")
	if hasEvent(evs, "a", flowrundomain.EventTimerArmed) {
		t.Errorf("node a armed a timer it shouldn't have")
	}
}

// TestTimerGate_ReplayDoesNotReWait: on replay, an already-fired timer is a copy-hit — the node's
// timer_fired exists so waitForTimerGate returns immediately (determinism, no double wait).
func TestTimerGate_ReplayDoesNotReWait(t *testing.T) {
	journal := newJournal(t)
	router := &countingRouter{calls: map[string]int{}}
	ctx := context.Background()
	g := timerGraph(map[string]any{"at": "2020-01-01T00:00:00Z"})

	if _, err := New(journal, router).Run(ctx, "fr_timer_replay", g, nil); err != nil {
		t.Fatalf("run: %v", err)
	}
	j1, _ := journal.LoadJournal(ctx, "fr_timer_replay")

	start := time.Now()
	if _, err := New(journal, router).Resume(ctx, "fr_timer_replay", g, nil); err != nil {
		t.Fatalf("resume: %v", err)
	}
	if elapsed := time.Since(start); elapsed > 200*time.Millisecond {
		t.Errorf("replay re-waited on the timer: %v", elapsed)
	}
	j2, _ := journal.LoadJournal(ctx, "fr_timer_replay")
	if len(j2) != len(j1) {
		t.Errorf("replay changed the journal: %d → %d events", len(j1), len(j2))
	}
}

// TestApprovalTimeout_DurationStringCanon verifies the canon config.timeout duration string (incl.
// the "30d" day form from doc 05) resolves, and the legacy timeoutSec number alias still works.
func TestApprovalTimeout_DurationStringCanon(t *testing.T) {
	cases := []struct {
		cfg  map[string]any
		want time.Duration
		ok   bool
	}{
		{map[string]any{"timeout": "30s"}, 30 * time.Second, true},
		{map[string]any{"timeout": "2h"}, 2 * time.Hour, true},
		{map[string]any{"timeout": "30d"}, 30 * 24 * time.Hour, true}, // doc 05 example
		{map[string]any{"timeoutSec": float64(45)}, 45 * time.Second, true},
		{map[string]any{"timeoutSec": 45}, 45 * time.Second, true},
		{map[string]any{}, 0, false},               // unset → no timeout
		{map[string]any{"timeout": ""}, 0, false},  // empty → no timeout
		{map[string]any{"timeout": "soon"}, 0, false}, // unparseable → no timeout (not a crash)
	}
	for _, c := range cases {
		got, ok := approvalTimeout(c.cfg)
		if ok != c.ok || got != c.want {
			t.Errorf("approvalTimeout(%v) = (%v,%v), want (%v,%v)", c.cfg, got, ok, c.want, c.ok)
		}
	}
}
