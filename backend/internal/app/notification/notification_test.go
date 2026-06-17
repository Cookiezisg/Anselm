package notification

import (
	"context"
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
