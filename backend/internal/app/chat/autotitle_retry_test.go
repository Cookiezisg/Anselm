package chat

import (
	"context"
	"errors"
	"testing"
	"time"

	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	"go.uber.org/zap"
)

type flakyTitler struct {
	calls int
	title chan string
}

func (f *flakyTitler) SetAutoTitle(_ context.Context, _, title string) error {
	f.calls++
	if f.calls == 1 {
		return errors.New("transient title write failure")
	}
	f.title <- title
	return nil
}

// TestAutoTitle_RetriesOneTransientPersistFailure proves a one-turn conversation does not lose a
// generated title forever when the first local write fails transiently; the second attempt reuses
// the same title and does not invoke the model again.
// TestAutoTitle_RetriesOneTransientPersistFailure 验证首轮本地写入瞬时失败后不会永久丢标题；第二次复用
// 同一标题且不再次调用模型。
func TestAutoTitle_RetriesOneTransientPersistFailure(t *testing.T) {
	saved := autoTitlePersistRetryDelay
	autoTitlePersistRetryDelay = time.Millisecond
	t.Cleanup(func() { autoTitlePersistRetryDelay = saved })

	store := newStore(t)
	ctx := ctxWS("ws_title_retry")
	if err := store.CreateMessage(ctx, &messagesdomain.Message{
		ID: "msg_title_retry", ConversationID: "cv_title_retry", Role: messagesdomain.RoleUser,
		Status: messagesdomain.StatusCompleted,
	}, []messagesdomain.Block{{Type: messagesdomain.BlockTypeText, Content: "plan the launch"}}); err != nil {
		t.Fatalf("seed title thread: %v", err)
	}
	titler := &flakyTitler{title: make(chan string, 1)}
	svc := NewService(store, Deps{
		Resolver:      fakeResolver{client: &fakeClient{script: titleTurn()}},
		Titler:        titler,
		Conversations: fakeConvs{conv: &conversationdomain.Conversation{}},
	}, zap.NewNop())

	svc.autoTitle("cv_title_retry", "ws_title_retry")
	select {
	case got := <-titler.title:
		if got != "My Conversation Title" {
			t.Fatalf("retried title = %q", got)
		}
	case <-time.After(time.Second):
		t.Fatal("title was not persisted after transient failure")
	}
	if titler.calls != 2 {
		t.Fatalf("persist attempts = %d, want exactly 2", titler.calls)
	}
}
