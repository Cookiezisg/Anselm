package forge

import (
	"context"
	"errors"
	"testing"
	"time"

	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	forgedomain "github.com/sunweilin/forgify/backend/internal/domain/forge"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

func ctxFor(uid string) context.Context {
	return reqctxpkg.SetUserID(context.Background(), uid)
}

func started(scopeID string) forgedomain.ForgeStarted {
	return forgedomain.ForgeStarted{
		Scope:     eventlogdomain.Scope{Kind: eventlogdomain.KindFunction, ID: scopeID},
		Operation: forgedomain.OperationCreate,
	}
}

func TestPublish_AssignsMonotonicSeq(t *testing.T) {
	b := NewBridge(nil)
	ctx := ctxFor("u1")
	for i := 1; i <= 3; i++ {
		env, err := b.Publish(ctx, started("fn_x"))
		if err != nil {
			t.Fatalf("publish #%d: %v", i, err)
		}
		if env.Seq != int64(i) {
			t.Errorf("seq #%d: want %d, got %d", i, i, env.Seq)
		}
	}
}

func TestPublish_PerUserSeq(t *testing.T) {
	b := NewBridge(nil)
	ctxA := ctxFor("user_a")
	ctxB := ctxFor("user_b")
	envA1, _ := b.Publish(ctxA, started("fn_a"))
	envB1, _ := b.Publish(ctxB, started("fn_b"))
	envA2, _ := b.Publish(ctxA, started("fn_a"))
	if envA1.Seq != 1 || envA2.Seq != 2 || envB1.Seq != 1 {
		t.Errorf("per-user seq: got A=%d,%d B=%d want 1,2 / 1", envA1.Seq, envA2.Seq, envB1.Seq)
	}
}

func TestPublish_RejectsMissingUserID(t *testing.T) {
	b := NewBridge(nil)
	_, err := b.Publish(context.Background(), started("fn_x"))
	if !errors.Is(err, reqctxpkg.ErrMissingUserID) {
		t.Errorf("want ErrMissingUserID, got %v", err)
	}
}

func TestPublish_RejectsInvalidScopeKind(t *testing.T) {
	b := NewBridge(nil)
	_, err := b.Publish(ctxFor("u1"), forgedomain.ForgeStarted{
		Scope:     eventlogdomain.Scope{Kind: eventlogdomain.KindConversation, ID: "cv_x"},
		Operation: forgedomain.OperationCreate,
	})
	if !errors.Is(err, forgedomain.ErrInvalidEvent) {
		t.Errorf("want ErrInvalidEvent (conversation not forge-able), got %v", err)
	}
}

func TestPublish_RejectsUnknownOperation(t *testing.T) {
	b := NewBridge(nil)
	_, err := b.Publish(ctxFor("u1"), forgedomain.ForgeStarted{
		Scope:     eventlogdomain.Scope{Kind: eventlogdomain.KindFunction, ID: "fn_x"},
		Operation: "frobnicate",
	})
	if !errors.Is(err, forgedomain.ErrInvalidEvent) {
		t.Errorf("want ErrInvalidEvent, got %v", err)
	}
}

func TestSubscribe_LiveDelivery(t *testing.T) {
	b := NewBridge(nil)
	ctx, cancel := context.WithCancel(ctxFor("u1"))
	defer cancel()

	ch, cancelSub, err := b.Subscribe(ctx, 0)
	if err != nil {
		t.Fatalf("subscribe: %v", err)
	}
	defer cancelSub()

	b.Publish(ctx, started("fn_x"))

	select {
	case env := <-ch:
		if env.Seq != 1 {
			t.Errorf("seq: got %d, want 1", env.Seq)
		}
		if _, ok := env.Event.(forgedomain.ForgeStarted); !ok {
			t.Errorf("event type: got %T, want ForgeStarted", env.Event)
		}
	case <-time.After(time.Second):
		t.Fatal("timeout waiting for event")
	}
}

func TestSubscribe_ReplayFromSeq(t *testing.T) {
	b := NewBridge(nil)
	ctx := ctxFor("u1")

	for i := 0; i < 4; i++ {
		b.Publish(ctx, started("fn_x"))
	}

	ch, cancelSub, err := b.Subscribe(ctx, 2)
	if err != nil {
		t.Fatalf("subscribe: %v", err)
	}
	defer cancelSub()

	for want := int64(3); want <= 4; want++ {
		select {
		case env := <-ch:
			if env.Seq != want {
				t.Errorf("replay: want seq %d, got %d", want, env.Seq)
			}
		case <-time.After(time.Second):
			t.Fatalf("timeout at seq %d", want)
		}
	}
}

func TestSubscribe_TooOldReturnsErrSeqTooOld(t *testing.T) {
	b := NewBridge(nil)
	ctx := ctxFor("u1")

	for i := 0; i < replayBufferSize+50; i++ {
		b.Publish(ctx, started("fn_x"))
	}

	_, _, err := b.Subscribe(ctx, 5)
	if !errors.Is(err, forgedomain.ErrSeqTooOld) {
		t.Errorf("want ErrSeqTooOld, got %v", err)
	}
}

func TestPublish_AllFourEventTypes(t *testing.T) {
	b := NewBridge(nil)
	ctx := ctxFor("u1")
	scope := eventlogdomain.Scope{Kind: eventlogdomain.KindHandler, ID: "hd_x"}

	if _, err := b.Publish(ctx, forgedomain.ForgeStarted{
		Scope: scope, Operation: forgedomain.OperationEdit, ConversationID: "cv_a",
	}); err != nil {
		t.Errorf("forge_started: %v", err)
	}
	if _, err := b.Publish(ctx, forgedomain.ForgeOpApplied{
		Scope: scope, Index: 0, Op: "set_meta",
	}); err != nil {
		t.Errorf("forge_op_applied: %v", err)
	}
	if _, err := b.Publish(ctx, forgedomain.ForgeEnvAttempt{
		Scope: scope, Attempt: 1, Status: forgedomain.EnvAttemptOK,
	}); err != nil {
		t.Errorf("forge_env_attempt: %v", err)
	}
	if _, err := b.Publish(ctx, forgedomain.ForgeCompleted{
		Scope: scope, Status: forgedomain.CompletedOK, VersionID: "hdv_y", AttemptsUsed: 1,
	}); err != nil {
		t.Errorf("forge_completed: %v", err)
	}
}
