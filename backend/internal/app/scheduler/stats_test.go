package scheduler

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
)

// statsSvc builds the thinnest Service the stats read path needs (RunStats only touches s.runs).
func statsSvc(t *testing.T) *Service {
	t.Helper()
	store, _ := newStore(t)
	return &Service{runs: store}
}

// TestRunStats_TooManyIDsLoudReject — the >50 guard fires AFTER dedup (the bound caps query cost,
// which depends on unique ids) and carries the allowed cap in Details.
func TestRunStats_TooManyIDsLoudReject(t *testing.T) {
	svc := statsSvc(t)
	ctx := ctxWS("ws_1")

	ids := make([]string, 0, flowrundomain.StatsMaxWorkflowIDs+1)
	for i := 0; i <= flowrundomain.StatsMaxWorkflowIDs; i++ {
		ids = append(ids, fmt.Sprintf("wf_%d", i))
	}
	if _, err := svc.RunStats(ctx, flowrundomain.StatsQuery{WorkflowIDs: ids}); !errors.Is(err, flowrundomain.ErrStatsTooManyIDs) {
		t.Fatalf("51 unique ids must reject with ErrStatsTooManyIDs, got %v", err)
	}

	// 60 raw ids that dedup to 2 pass — and blanks are dropped, duplicates collapse to one row.
	noisy := make([]string, 0, 60)
	for i := 0; i < 58; i++ {
		noisy = append(noisy, "wf_dup")
	}
	noisy = append(noisy, "", "wf_other")
	got, err := svc.RunStats(ctx, flowrundomain.StatsQuery{WorkflowIDs: noisy})
	if err != nil {
		t.Fatalf("deduped-under-cap must pass: %v", err)
	}
	if len(got.ByWorkflow) != 2 || got.ByWorkflow[0].WorkflowID != "wf_dup" || got.ByWorkflow[1].WorkflowID != "wf_other" {
		t.Fatalf("dedup must keep first-occurrence order and drop blanks: %+v", got.ByWorkflow)
	}
}

// TestRunStats_DefaultsAndClamp — RecentN ≤0 → 10, >20 → 20; a zero Since → the 7d window;
// empty ids → totals only with an empty (non-nil) byWorkflow.
func TestRunStats_DefaultsAndClamp(t *testing.T) {
	svc := statsSvc(t)
	ctx := ctxWS("ws_1")

	// 22 completed runs, newest first by orm's create stamp (each Create gets its own now).
	for i := 0; i < 22; i++ {
		id := fmt.Sprintf("fr_%02d", i)
		mustSeedTerminal(t, svc, ctx, id, "wf_a", flowrundomain.StatusCompleted)
	}

	// default RecentN = 10.
	got, err := svc.RunStats(ctx, flowrundomain.StatsQuery{WorkflowIDs: []string{"wf_a"}})
	if err != nil {
		t.Fatalf("RunStats: %v", err)
	}
	if n := len(got.ByWorkflow[0].Recent); n != flowrundomain.StatsDefaultRecentN {
		t.Fatalf("default RecentN: got %d beads, want %d", n, flowrundomain.StatsDefaultRecentN)
	}
	// oversized RecentN clamps to 20.
	got, err = svc.RunStats(ctx, flowrundomain.StatsQuery{WorkflowIDs: []string{"wf_a"}, RecentN: 99})
	if err != nil {
		t.Fatalf("RunStats: %v", err)
	}
	if n := len(got.ByWorkflow[0].Recent); n != flowrundomain.StatsMaxRecentN {
		t.Fatalf("RecentN clamp: got %d beads, want %d", n, flowrundomain.StatsMaxRecentN)
	}
	// zero Since defaults to the 7d window: everything just seeded lands inside it.
	if got.Totals.CompletedSince != 22 {
		t.Fatalf("default 7d window must cover fresh runs: completedSince = %d", got.Totals.CompletedSince)
	}
	// empty ids: totals only, byWorkflow [] not nil (the wire must emit [], never null).
	got, err = svc.RunStats(ctx, flowrundomain.StatsQuery{})
	if err != nil {
		t.Fatalf("RunStats empty ids: %v", err)
	}
	if got.ByWorkflow == nil || len(got.ByWorkflow) != 0 {
		t.Fatalf("empty ids → byWorkflow must be [] (non-nil), got %#v", got.ByWorkflow)
	}
	if got.Totals.Running != 0 || got.Totals.CompletedSince != 22 {
		t.Fatalf("totals must still aggregate the workspace: %+v", got.Totals)
	}
}

// TestRunStats_ExplicitSinceWindow — a caller-supplied Since bounds the windowed counts without
// touching the streak (store-level windowing is pinned in the store tests; this pins that the
// app passes an explicit Since through untouched).
func TestRunStats_ExplicitSinceWindow(t *testing.T) {
	svc := statsSvc(t)
	ctx := ctxWS("ws_1")
	mustSeedTerminal(t, svc, ctx, "fr_1", "wf_a", flowrundomain.StatusFailed)

	// a window starting in the future sees nothing…
	got, err := svc.RunStats(ctx, flowrundomain.StatsQuery{WorkflowIDs: []string{"wf_a"}, Since: time.Now().UTC().Add(time.Hour)})
	if err != nil {
		t.Fatalf("RunStats: %v", err)
	}
	if got.Totals.FailedSince != 0 || got.ByWorkflow[0].SuccessRate != nil {
		t.Fatalf("future window must be empty: %+v %+v", got.Totals, got.ByWorkflow[0])
	}
	// …the streak is window-independent.
	if got.ByWorkflow[0].ConsecutiveFailures != 1 {
		t.Fatalf("streak must ignore the window: %d", got.ByWorkflow[0].ConsecutiveFailures)
	}
}

// mustSeedTerminal creates a run via the store path and settles it to a terminal status.
func mustSeedTerminal(t *testing.T, svc *Service, ctx context.Context, id, wf, status string) {
	t.Helper()
	run := &flowrundomain.FlowRun{ID: id, WorkflowID: wf, VersionID: "wfv_1"}
	trig := &flowrundomain.FlowRunNode{NodeID: "start", Kind: "trigger"}
	if _, err := svc.runs.CreateRunWithTrigger(ctx, run, trig); err != nil {
		t.Fatalf("seed %s: %v", id, err)
	}
	if status != flowrundomain.StatusRunning {
		if _, err := svc.runs.MarkRunTerminal(ctx, id, status, ""); err != nil {
			t.Fatalf("terminal %s: %v", id, err)
		}
	}
}
