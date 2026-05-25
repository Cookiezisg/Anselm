package chat

import (
	"context"
	"strings"
	"testing"

	"go.uber.org/zap"

	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	mentiondomain "github.com/sunweilin/forgify/backend/internal/domain/mention"
)

// buildUserLLMMessage reads the snapshot stored in Attrs["mentions"] and renders
// it into the user LLM message — no re-resolution, so history stays a snapshot.
//
// buildUserLLMMessage 读 Attrs["mentions"] 里的快照渲进 user 消息，不重解析。
func TestBuildUserLLMMessage_RendersStoredMentions(t *testing.T) {
	s := &Service{log: zap.NewNop()}
	m := &chatdomain.Message{
		ID:   "msg_1",
		Role: chatdomain.RoleUser,
		Blocks: []chatdomain.Block{
			{Type: eventlogdomain.BlockTypeText, Content: "what is this?"},
		},
		Attrs: map[string]any{
			"mentions": []mentiondomain.Reference{
				{Type: mentiondomain.MentionDocument, ID: "doc_1", Name: "Spec", Content: "ZEBRA-BODY"},
			},
		},
	}
	msg, err := s.buildUserLLMMessage(context.Background(), m)
	if err != nil {
		t.Fatalf("buildUserLLMMessage: %v", err)
	}
	got := msg.Content
	for _, p := range msg.Parts {
		got += p.Text
	}
	if !strings.Contains(got, `<mention type="document" id="doc_1" name="Spec">`) {
		t.Errorf("mention block not in user message: %q", got)
	}
	if !strings.Contains(got, "ZEBRA-BODY") {
		t.Errorf("mention content (snapshot) not in user message: %q", got)
	}
	if !strings.Contains(got, "what is this?") {
		t.Errorf("user prose lost: %q", got)
	}
}

func TestBuildUserLLMMessage_NoMentions_PlainText(t *testing.T) {
	s := &Service{log: zap.NewNop()}
	m := &chatdomain.Message{
		ID:     "msg_2",
		Role:   chatdomain.RoleUser,
		Blocks: []chatdomain.Block{{Type: eventlogdomain.BlockTypeText, Content: "hi"}},
	}
	msg, err := s.buildUserLLMMessage(context.Background(), m)
	if err != nil {
		t.Fatalf("buildUserLLMMessage: %v", err)
	}
	if msg.Content != "hi" {
		t.Errorf("plain message should be single text content; got Content=%q Parts=%v", msg.Content, msg.Parts)
	}
}
