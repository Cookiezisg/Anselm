package chat

import (
	"context"
	"errors"
	"testing"
	"time"

	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	"go.uber.org/zap"
)

type archiveRecordingConvs struct {
	fakeConvs
	calls chan string
	err   error
}

func (c *archiveRecordingConvs) Unarchive(_ context.Context, id string) error {
	c.calls <- id
	return c.err
}

// TestSendArchivedConversationUnarchivesAndContinues proves sending to an archived thread wakes
// it first, while a transient unarchive failure remains soft and cannot block the message itself.
// TestSendArchivedConversationUnarchivesAndContinues 验证归档线程发消息先唤回；即便解档瞬时失败，
// 该失败仍是软失败，不阻塞消息本身。
func TestSendArchivedConversationUnarchivesAndContinues(t *testing.T) {
	for _, tc := range []struct {
		name string
		err  error
	}{
		{name: "unarchive succeeds"},
		{name: "unarchive soft failure", err: errors.New("archive flag write unavailable")},
	} {
		t.Run(tc.name, func(t *testing.T) {
			bridge := newRecordBridge()
			convs := &archiveRecordingConvs{
				fakeConvs: fakeConvs{conv: &conversationdomain.Conversation{Archived: true}},
				calls:     make(chan string, 1),
				err:       tc.err,
			}
			svc := NewService(newStore(t), Deps{
				Conversations: convs,
				Resolver:      fakeResolver{client: &fakeClient{script: textTurn()}},
				Bridge:        bridge,
			}, zap.NewNop())
			ctx := ctxWS("ws_archived")

			asstID, err := svc.Send(ctx, "cv_archived", SendInput{Content: "continue this thread"})
			if err != nil {
				t.Fatalf("Send: %v", err)
			}
			select {
			case got := <-convs.calls:
				if got != "cv_archived" {
					t.Fatalf("Unarchive conversation = %q", got)
				}
			case <-time.After(2 * time.Second):
				t.Fatal("archived Send did not attempt Unarchive")
			}
			waitClose(t, bridge, asstID)
		})
	}
}
