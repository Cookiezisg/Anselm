package scheduler

import (
	"context"
	"errors"
	"testing"
	"time"

	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
)

// :replay bumps the generation and re-drives the interpreter for a failed run (ADR-019).
func TestReplayRun_BumpsGenerationAndReDrives(t *testing.T) {
	repo := newFakeRepo()
	s := newSvc(t, repo, &fakeWorkflowReader{wf: mkEnabledWorkflow(), ver: mkVersion()})
	s.SetJournal(newJournal(t))
	ctx := ctxWith("u1")
	_ = repo.Create(ctx, &flowrundomain.FlowRun{
		ID: "fr1", UserID: "u1", WorkflowID: "wf1",
		Status: flowrundomain.StatusFailed, StartedAt: time.Now().UTC(), Generation: 0,
	})
	executed := make(chan struct{})
	s.ExecuteFn = func(context.Context, *flowrundomain.FlowRun, *workflowdomain.Graph) { close(executed) }

	if err := s.ReplayRun(ctx, "fr1"); err != nil {
		t.Fatalf("ReplayRun: %v", err)
	}
	got, _ := repo.Get(ctx, "fr1")
	if got.Generation != 1 {
		t.Fatalf("generation after replay = %d, want 1", got.Generation)
	}
	select {
	case <-executed:
	case <-time.After(time.Second):
		t.Fatal("ReplayRun must re-drive executeRun")
	}
}

// Only a terminal-failed run is replayable; a completed/running one is rejected.
func TestReplayRun_NonFailedRejected(t *testing.T) {
	repo := newFakeRepo()
	s := newSvc(t, repo, &fakeWorkflowReader{wf: mkEnabledWorkflow(), ver: mkVersion()})
	ctx := ctxWith("u1")
	_ = repo.Create(ctx, &flowrundomain.FlowRun{
		ID: "fr1", UserID: "u1", WorkflowID: "wf1",
		Status: flowrundomain.StatusCompleted, StartedAt: time.Now().UTC(),
	})
	if err := s.ReplayRun(ctx, "fr1"); !errors.Is(err, ErrNotReplayable) {
		t.Fatalf("replaying a completed run must be ErrNotReplayable, got %v", err)
	}
}
