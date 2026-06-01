package notifications

import (
	"context"
	"testing"

	"go.uber.org/zap"

	notificationsdomain "github.com/sunweilin/forgify/backend/internal/domain/notifications"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// PublishEphemeral delivers to live subscribers but assigns no seq, never buffers, and never blocks —
// the 08 CANON-X4 ephemeral class for flowrun runtime ticks. A reconnecting subscriber must NOT replay
// it (no seq, not buffered) and it must not consume a durable seq.
func TestBridge_PublishEphemeral_LiveOnlyNoSeqNoReplay(t *testing.T) {
	b := NewBridge(zap.NewNop())
	ctx := reqctxpkg.SetUserID(context.Background(), "u1")

	ch, cancel, err := b.Subscribe(ctx, 0)
	if err != nil {
		t.Fatalf("Subscribe: %v", err)
	}
	defer cancel()

	ev := notificationsdomain.Event{Type: "flowrun", ID: "fr1", Data: map[string]any{"action": "tick", "nodeId": "n1", "status": "running"}}
	if err := b.PublishEphemeral(ctx, ev); err != nil {
		t.Fatalf("PublishEphemeral: %v", err)
	}

	select {
	case env := <-ch:
		if env.Seq != 0 {
			t.Fatalf("ephemeral envelope must carry Seq 0, got %d", env.Seq)
		}
		if env.Event.Type != "flowrun" {
			t.Fatalf("wrong event delivered: %+v", env.Event)
		}
	default:
		t.Fatal("ephemeral event not delivered to live subscriber")
	}

	// Not buffered: List (the replay buffer) returns nothing.
	items, _, err := b.List(ctx, 0, 50)
	if err != nil {
		t.Fatalf("List: %v", err)
	}
	if len(items) != 0 {
		t.Fatalf("ephemeral must not enter the replay buffer, List returned %d", len(items))
	}

	// A durable Publish after it must still get seq 1 — the ephemeral consumed no seq.
	env, err := b.Publish(ctx, notificationsdomain.Event{Type: "function", ID: "fn1", Data: map[string]any{}})
	if err != nil {
		t.Fatalf("Publish: %v", err)
	}
	if env.Seq != 1 {
		t.Fatalf("durable event after ephemeral must be seq 1 (ephemeral consumes no seq), got %d", env.Seq)
	}
}

// PublishEphemeral with no subscribers (and a missing user) is a harmless no-op, never an error path
// that could stall the engine.
func TestBridge_PublishEphemeral_NoSubscribers_NoError(t *testing.T) {
	b := NewBridge(zap.NewNop())
	ctx := reqctxpkg.SetUserID(context.Background(), "u_lonely")
	if err := b.PublishEphemeral(ctx, notificationsdomain.Event{Type: "flowrun", ID: "fr9", Data: map[string]any{}}); err != nil {
		t.Fatalf("PublishEphemeral with no subscribers should be a no-op, got %v", err)
	}
}
