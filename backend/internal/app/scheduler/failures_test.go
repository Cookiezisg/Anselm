package scheduler

import (
	"context"
	"testing"

	"go.uber.org/zap"

	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
	notificationspkg "github.com/sunweilin/forgify/backend/internal/pkg/notifications"
)

// ListFailures returns node_failed events, but a node re-run to success at an equal-or-higher
// generation (a `:replay`) is no longer reported — highest-generation state (ADR-019).
func TestListFailures_HigherGenerationSuccessSupersedes(t *testing.T) {
	journal := newJournal(t)
	ctx := context.Background()
	mustAppend(t, journal, &flowrundomain.FlowRunEvent{FlowrunID: "fr1", Type: flowrundomain.EventNodeFailed, NodeID: "a", Result: map[string]any{"error": "boom"}})
	mustAppend(t, journal, &flowrundomain.FlowRunEvent{FlowrunID: "fr1", Type: flowrundomain.EventNodeFailed, NodeID: "b", Generation: 0, Result: map[string]any{"error": "x"}})
	// b was re-run at generation 1 and succeeded → it should drop out of the failures list.
	mustAppend(t, journal, &flowrundomain.FlowRunEvent{FlowrunID: "fr1", Type: flowrundomain.EventNodeCompleted, NodeID: "b", Generation: 1, Result: map[string]any{}})

	s := NewService(newFakeRepo(), &fakeWorkflowReader{}, notificationspkg.New(nil, zap.NewNop()), zap.NewNop())
	s.SetJournal(journal)

	failures, err := s.ListFailures(ctx, "fr1")
	if err != nil {
		t.Fatalf("ListFailures: %v", err)
	}
	if len(failures) != 1 || failures[0].NodeID != "a" || failures[0].Error != "boom" {
		t.Fatalf("only a's failure should remain (b superseded by a gen-1 success): %+v", failures)
	}
}

func mustAppend(t *testing.T, j interface {
	AppendEvent(context.Context, *flowrundomain.FlowRunEvent) (*flowrundomain.FlowRunEvent, error)
}, e *flowrundomain.FlowRunEvent) {
	t.Helper()
	if _, err := j.AppendEvent(context.Background(), e); err != nil {
		t.Fatalf("append %s: %v", e.Type, err)
	}
}
