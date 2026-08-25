package chat

import (
	"context"
	"errors"
	"strings"
	"testing"

	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	"go.uber.org/zap"
)

var errRetryWriteInterrupted = errors.New("injected retry write interruption")

// failMarkStore keeps every real messages-store operation but interrupts exactly the pointer write
// between edit-resend's new user row and the old row's superseded_by update. Embedding the repository
// makes the fault boundary explicit without replacing the durable store with a fake.
//
// failMarkStore 保留真实 messages store 的所有操作，只在编辑重发「新 user 落地」与「旧行写 superseded_by」之间
// 精确打断。嵌入 repository 明确故障边界，同时不以 fake 替换耐久 store。
type failMarkStore struct {
	messagesdomain.Repository
}

func (s failMarkStore) MarkSuperseded(context.Context, string, string) error {
	return errRetryWriteInterrupted
}

// TestRetry_WriteOrderLeavesBothQuestionsVisibleOnInterruption proves the deliberate write order:
// if the process/store dies after the replacement user row is committed but before the old pointer
// is written, both question spellings and the old answer remain readable. A later retry can clean up
// the duplicate; the model must never receive a silently erased exchange.
//
// TestRetry_WriteOrderLeavesBothQuestionsVisibleOnInterruption 证明刻意的写序：如果进程/存储在替代 user 已提交、旧指针
// 尚未写入时中断，两种问句和旧回答仍可读。后续 retry 可以清理重复，模型绝不能收到一次被静默抹掉的交流。
func TestRetry_WriteOrderLeavesBothQuestionsVisibleOnInterruption(t *testing.T) {
	base := newStore(t)
	bridge := newRecordBridge()
	resolver := &recordingResolver{client: &versionedClient{answers: []string{"ORIGINAL ANSWER"}}}
	svc := NewService(&failMarkStore{Repository: base}, Deps{
		Conversations: fakeConvs{conv: &conversationdomain.Conversation{SystemPrompt: "be concise"}},
		Resolver:      resolver,
		Bridge:        bridge,
	}, zap.NewNop())
	t.Cleanup(func() { svc.Shutdown(context.Background()) })
	ctx := ctxWS("ws_1")

	firstAssistant, err := svc.Send(ctx, "cv_write_order", SendInput{Content: "original question"})
	if err != nil {
		t.Fatalf("Send: %v", err)
	}
	waitClose(t, bridge, firstAssistant)

	if _, err := svc.Retry(ctx, "cv_write_order", RetryInput{Content: "edited question"}); !errors.Is(err, errRetryWriteInterrupted) {
		t.Fatalf("Retry interruption = %v, want injected pointer-write failure", err)
	}

	thread, err := base.LoadThread(ctx, "cv_write_order")
	if err != nil {
		t.Fatalf("LoadThread: %v", err)
	}
	if len(thread) != 3 {
		t.Fatalf("interrupted edit-resend must retain original user, answer, and replacement user; got %d rows", len(thread))
	}
	users := retryRoleIDs(t, base, "cv_write_order", messagesdomain.RoleUser)
	if len(users) != 2 {
		t.Fatalf("both question spellings must remain readable, got user ids %v", users)
	}
	if retryRow(t, base, users[0]).SupersededBy != "" {
		t.Fatalf("old question was superseded despite interrupted pointer write: %+v", retryRow(t, base, users[0]))
	}
	if got, _ := blockText(retryRow(t, base, users[1])); got != "edited question" {
		t.Fatalf("replacement question = %q, want edited question", got)
	}
	assembled := llmText(t, base, "cv_write_order")
	for _, want := range []string{"original question", "edited question", "ORIGINAL ANSWER"} {
		if !strings.Contains(assembled, want) {
			t.Fatalf("interrupted retry erased %q from LLM history: %s", want, assembled)
		}
	}
}
