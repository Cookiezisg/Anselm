package notification

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"testing"

	"go.uber.org/zap"

	notificationdomain "github.com/sunweilin/anselm/backend/internal/domain/notification"
	streamdomain "github.com/sunweilin/anselm/backend/internal/domain/stream"
)

// fakeRepo is an in-memory notificationdomain.Repository.
//
// fakeRepo 是内存版 notificationdomain.Repository。
type fakeRepo struct {
	saved  []*notificationdomain.Notification
	unread int
}

var _ notificationdomain.Repository = (*fakeRepo)(nil)

func (f *fakeRepo) Save(_ context.Context, n *notificationdomain.Notification) error {
	f.saved = append(f.saved, n)
	return nil
}
func (f *fakeRepo) List(_ context.Context, _ string, _ int) ([]*notificationdomain.Notification, string, error) {
	return f.saved, "", nil
}
func (f *fakeRepo) MarkRead(_ context.Context, id string) error {
	for _, n := range f.saved {
		if n.ID == id {
			return nil
		}
	}
	return notificationdomain.ErrNotFound
}
func (f *fakeRepo) MarkAllRead(_ context.Context) error        { return nil }
func (f *fakeRepo) MarkAllUnread(_ context.Context) error      { return nil }
func (f *fakeRepo) CountUnread(_ context.Context) (int, error) { return f.unread, nil }

// fakeBridge records published events and can force a push error.
//
// fakeBridge 记录推送的事件，可强制推送失败。
type fakeBridge struct {
	published []streamdomain.Event
	err       error
}

var _ streamdomain.Bridge = (*fakeBridge)(nil)

func (f *fakeBridge) Publish(_ context.Context, e streamdomain.Event) (streamdomain.Envelope, error) {
	if f.err != nil {
		return streamdomain.Envelope{}, f.err
	}
	f.published = append(f.published, e)
	return streamdomain.Envelope{Seq: int64(len(f.published)), Event: e}, nil
}
func (f *fakeBridge) Subscribe(_ context.Context, _ int64) (<-chan streamdomain.Envelope, func(), error) {
	return nil, func() {}, nil
}

func TestEmit_PersistsAndPushes(t *testing.T) {
	repo := &fakeRepo{}
	bridge := &fakeBridge{}
	svc := NewService(repo, bridge, zap.NewNop())

	if err := svc.Emit(context.Background(), "memory.updated", map[string]any{"name": "foo"}); err != nil {
		t.Fatalf("emit: %v", err)
	}

	// persisted
	if len(repo.saved) != 1 {
		t.Fatalf("want 1 saved, got %d", len(repo.saved))
	}
	n := repo.saved[0]
	if n.Type != "memory.updated" || n.Payload["name"] != "foo" {
		t.Errorf("saved wrong: %+v", n)
	}
	if !strings.HasPrefix(n.ID, "noti_") {
		t.Errorf("id = %q, want noti_ prefix", n.ID)
	}

	// pushed: scope=notification:<id>, durable signal, node.type=event type
	if len(bridge.published) != 1 {
		t.Fatalf("want 1 pushed, got %d", len(bridge.published))
	}
	e := bridge.published[0]
	if e.Scope.Kind != streamdomain.KindNotification || e.Scope.ID != n.ID {
		t.Errorf("scope = %+v, want notification:%s", e.Scope, n.ID)
	}
	sig, ok := e.Frame.(streamdomain.Signal)
	if !ok {
		t.Fatalf("frame is %T, want Signal", e.Frame)
	}
	if sig.Node.Type != "memory.updated" {
		t.Errorf("node.type = %q, want memory.updated", sig.Node.Type)
	}
	if sig.Ephemeral {
		t.Error("notification signal must be durable (not ephemeral)")
	}
}

func TestBroadcast_PushesButDoesNotPersist(t *testing.T) {
	repo := &fakeRepo{}
	bridge := &fakeBridge{}
	svc := NewService(repo, bridge, zap.NewNop())

	if err := svc.Broadcast(context.Background(), "conversation.created", map[string]any{"conversationId": "cv_1"}); err != nil {
		t.Fatalf("broadcast: %v", err)
	}

	// NO inbox row — the whole point of the frame-only tier.
	if len(repo.saved) != 0 {
		t.Fatalf("broadcast must NOT persist a row, got %d", len(repo.saved))
	}

	// But a durable signal IS pushed, shaped exactly like Emit's: scope=notification:<id>,
	// node.type=event type, durable. The id is transient (noti_ prefix, never a row).
	if len(bridge.published) != 1 {
		t.Fatalf("want 1 pushed, got %d", len(bridge.published))
	}
	e := bridge.published[0]
	if e.Scope.Kind != streamdomain.KindNotification {
		t.Errorf("scope kind = %v, want notification", e.Scope.Kind)
	}
	if !strings.HasPrefix(e.ID, "noti_") || e.Scope.ID != e.ID {
		t.Errorf("wire anchor id = %q / scope.ID = %q, want matching noti_ prefix", e.ID, e.Scope.ID)
	}
	sig, ok := e.Frame.(streamdomain.Signal)
	if !ok {
		t.Fatalf("frame is %T, want Signal", e.Frame)
	}
	if sig.Node.Type != "conversation.created" {
		t.Errorf("node.type = %q, want conversation.created", sig.Node.Type)
	}
	if sig.Ephemeral {
		t.Error("broadcast signal must still be durable (survives reconnect via replay ring)")
	}
}

// The inbox marker (WRK-062 S-8): Emit frames carry inbox:true, Broadcast frames must NOT — the
// client's "all" level keys off it, and the two tiers are otherwise identically shaped.
// inbox 标(S-8):Emit 帧带 inbox:true、Broadcast 绝不带——「全部」档据此分流,两档其余帧形全同。
func TestPush_InboxMarkerSplitsTheTiers(t *testing.T) {
	repo := &fakeRepo{}
	bridge := &fakeBridge{}
	svc := NewService(repo, bridge, zap.NewNop())

	payload := map[string]any{"name": "foo"}
	if err := svc.Emit(context.Background(), "memory.updated", payload); err != nil {
		t.Fatalf("emit: %v", err)
	}
	if err := svc.Broadcast(context.Background(), "conversation.updated", payload); err != nil {
		t.Fatalf("broadcast: %v", err)
	}

	var emitContent, bcastContent map[string]any
	if err := json.Unmarshal(bridge.published[0].Frame.(streamdomain.Signal).Node.Content, &emitContent); err != nil {
		t.Fatalf("emit content: %v", err)
	}
	if err := json.Unmarshal(bridge.published[1].Frame.(streamdomain.Signal).Node.Content, &bcastContent); err != nil {
		t.Fatalf("broadcast content: %v", err)
	}
	if emitContent["inbox"] != true {
		t.Errorf("Emit frame must carry inbox:true, got %v", emitContent)
	}
	if _, has := bcastContent["inbox"]; has {
		t.Errorf("Broadcast frame must NOT carry inbox, got %v", bcastContent)
	}
	// The caller's map is never mutated (push copies before marking). 调用方 map 不被原地改。
	if _, has := payload["inbox"]; has {
		t.Error("push must copy the payload, not mutate the caller's map")
	}
	// The persisted row's payload stays unmarked (inbox is a WIRE marker only). 落行 payload 不带标。
	if _, has := repo.saved[0].Payload["inbox"]; has {
		t.Error("the persisted payload must not carry the wire-only inbox marker")
	}
}

func TestBroadcast_EmptyTypeRejected(t *testing.T) {
	svc := NewService(&fakeRepo{}, &fakeBridge{}, zap.NewNop())
	if err := svc.Broadcast(context.Background(), "", nil); !errors.Is(err, notificationdomain.ErrInvalidType) {
		t.Errorf("want ErrInvalidType, got %v", err)
	}
}

func TestBroadcast_NilBridge_NoOp(t *testing.T) {
	repo := &fakeRepo{}
	svc := NewService(repo, nil, zap.NewNop()) // nil bridge → nothing to push, no row either
	if err := svc.Broadcast(context.Background(), "conversation.created", nil); err != nil {
		t.Fatalf("broadcast with nil bridge: %v", err)
	}
	if len(repo.saved) != 0 {
		t.Errorf("broadcast never persists, got %d saved", len(repo.saved))
	}
}

func TestEmit_EmptyTypeRejected(t *testing.T) {
	svc := NewService(&fakeRepo{}, &fakeBridge{}, zap.NewNop())
	if err := svc.Emit(context.Background(), "", nil); !errors.Is(err, notificationdomain.ErrInvalidType) {
		t.Errorf("want ErrInvalidType, got %v", err)
	}
}

func TestEmit_NilBridge_StillPersists(t *testing.T) {
	repo := &fakeRepo{}
	svc := NewService(repo, nil, zap.NewNop()) // nil bridge → persist only
	if err := svc.Emit(context.Background(), "memory.updated", nil); err != nil {
		t.Fatalf("emit with nil bridge: %v", err)
	}
	if len(repo.saved) != 1 {
		t.Errorf("want 1 saved even without bridge, got %d", len(repo.saved))
	}
}

func TestEmit_PushFailure_StillSucceeds(t *testing.T) {
	repo := &fakeRepo{}
	bridge := &fakeBridge{err: errors.New("bus down")}
	svc := NewService(repo, bridge, zap.NewNop())
	// SSE push fails but the notification is persisted → Emit succeeds (best-effort push).
	if err := svc.Emit(context.Background(), "memory.updated", nil); err != nil {
		t.Fatalf("emit should succeed despite push failure: %v", err)
	}
	if len(repo.saved) != 1 {
		t.Errorf("want 1 saved, got %d", len(repo.saved))
	}
}

func TestMarkRead_NotFound(t *testing.T) {
	svc := NewService(&fakeRepo{}, nil, zap.NewNop())
	if err := svc.MarkRead(context.Background(), "noti_missing"); !errors.Is(err, notificationdomain.ErrNotFound) {
		t.Errorf("want ErrNotFound, got %v", err)
	}
}

// Mark-all-read / mark-all-unread are collection-level ops that delegate straight to the repo and
// push NO frame (symmetric — the unread badge reconciles by REST refetch, never off a stream frame).
// 集合级全标已读/未读纯委派 repo、不推任何帧(对称——未读徽标靠 REST 重取对账、绝不据帧)。
func TestMarkAll_DelegatesWithoutFrame(t *testing.T) {
	bridge := &fakeBridge{}
	svc := NewService(&fakeRepo{}, bridge, zap.NewNop())
	if err := svc.MarkAllRead(context.Background()); err != nil {
		t.Fatalf("mark-all-read: %v", err)
	}
	if err := svc.MarkAllUnread(context.Background()); err != nil {
		t.Fatalf("mark-all-unread: %v", err)
	}
	if len(bridge.published) != 0 {
		t.Errorf("mark-all-read/unread must push NO frame, got %d", len(bridge.published))
	}
}
