package chat

import (
	"context"
	"iter"
	"testing"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	limitspkg "github.com/sunweilin/anselm/backend/internal/pkg/limits"
)

// ctxStallClient's Stream blocks until the turn ctx is cancelled, then surfaces the ctx error — a
// model/stream that stalls past every per-step guard but DOES honor ctx (the case the per-turn wall
// clock recovers; a ctx-ignoring busy-loop is the deeper open item).
type ctxStallClient struct{}

func (ctxStallClient) Stream(ctx context.Context, _ llminfra.Request) iter.Seq[llminfra.StreamEvent] {
	return func(yield func(llminfra.StreamEvent) bool) {
		<-ctx.Done()
		yield(llminfra.StreamEvent{Type: llminfra.EventError, Err: ctx.Err()})
	}
}

// TestProcessTask_TurnWallClockFinalizes — regression for F100 (round-4 memagent lane): a chat turn
// whose stream stalls past the per-step guards used to run forever on its DETACHED ctx — the message
// stayed isGenerating, the runQueue goroutine never returned, and graceful shutdown blocked. The
// per-turn ChatTurnSec wall clock must cancel the turn ctx so the turn FINALIZES (terminal status, not
// stuck streaming). With the old WithCancel (no deadline) this hangs and waitClose times out.
func TestProcessTask_TurnWallClockFinalizes(t *testing.T) {
	defer limitspkg.SetProvider(limitspkg.Default)
	limitspkg.SetProvider(func() limitspkg.Limits {
		l := limitspkg.Default()
		l.Timeout.ChatTurnSec = 1 // tiny turn wall clock so the test is fast
		return l
	})

	bridge := newRecordBridge()
	svc, store := newSvc(t, ctxStallClient{}, bridge)
	ctx := ctxWS("ws_1")

	asstID, err := svc.Send(ctx, "cv_1", SendInput{Content: "stall the stream forever"})
	if err != nil {
		t.Fatalf("Send: %v", err)
	}
	waitClose(t, bridge, asstID) // the turn wall clock must drive it to message_stop within ~1s

	got, err := store.GetMessage(ctx, asstID)
	if err != nil {
		t.Fatalf("GetMessage: %v", err)
	}
	if got.Status == messagesdomain.StatusStreaming || got.Status == messagesdomain.StatusPending {
		t.Fatalf("a stalled turn must finalize via the ChatTurnSec wall clock, got status=%q (stuck)", got.Status)
	}
}
