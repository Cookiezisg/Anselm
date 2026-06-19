package chat

import (
	"context"
	"testing"

	loopapp "github.com/sunweilin/anselm/backend/internal/app/loop"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

// buildR10Thread seeds a conversation with: a folded old user turn + a folded old assistant turn
// (under the watermark, content now in the summary), a subagent sub-message (never in the parent's
// LLM history), and a fresh user + fresh assistant turn above the watermark. Returns the store-backed
// chat service. Block seqs are conversation-wide MAX+1, so after these inserts the watermark lands on
// a turn boundary (seq 3 = end of the old assistant turn).
func buildR10Thread(t *testing.T, store messagesdomain.Repository) {
	t.Helper()
	ctx := ctxWS("ws_1")

	// Old user turn (seq 1) — folded.
	if err := store.CreateMessage(ctx, &messagesdomain.Message{ID: "m_u1", ConversationID: "cv_1", Role: messagesdomain.RoleUser, Status: messagesdomain.StatusCompleted},
		[]messagesdomain.Block{{Type: messagesdomain.BlockTypeText, Content: "old paste"}}); err != nil {
		t.Fatalf("u1: %v", err)
	}
	// Old assistant turn (seq 2 text, seq 3 tool_result) — folded + flagged archived.
	if err := store.CreateMessage(ctx, &messagesdomain.Message{ID: "m_a1", ConversationID: "cv_1", Role: messagesdomain.RoleAssistant, Status: messagesdomain.StatusCompleted},
		[]messagesdomain.Block{
			{Type: messagesdomain.BlockTypeText, Content: "old answer", ContextRole: messagesdomain.ContextRoleArchived},
			{Type: messagesdomain.BlockTypeToolResult, Content: "old tool output", ContextRole: messagesdomain.ContextRoleArchived},
		}); err != nil {
		t.Fatalf("a1: %v", err)
	}
	// Subagent sub-message (seq 4) — excluded from parent LLM history.
	if err := store.CreateMessage(ctx, &messagesdomain.Message{ID: "m_sub", ConversationID: "cv_1", SubagentID: "subagt_1", Role: messagesdomain.RoleAssistant, Status: messagesdomain.StatusCompleted},
		[]messagesdomain.Block{{Type: messagesdomain.BlockTypeText, Content: "subagent step"}}); err != nil {
		t.Fatalf("sub: %v", err)
	}
	// Fresh user turn (seq 5) — survives.
	if err := store.CreateMessage(ctx, &messagesdomain.Message{ID: "m_u2", ConversationID: "cv_1", Role: messagesdomain.RoleUser, Status: messagesdomain.StatusCompleted},
		[]messagesdomain.Block{{Type: messagesdomain.BlockTypeText, Content: "fresh question"}}); err != nil {
		t.Fatalf("u2: %v", err)
	}
	// Fresh assistant turn (seq 6) — survives.
	if err := store.CreateMessage(ctx, &messagesdomain.Message{ID: "m_a2", ConversationID: "cv_1", Role: messagesdomain.RoleAssistant, Status: messagesdomain.StatusCompleted},
		[]messagesdomain.Block{{Type: messagesdomain.BlockTypeText, Content: "fresh answer"}}); err != nil {
		t.Fatalf("a2: %v", err)
	}
}

// loadHistoryFull is the PRE-R10 assembly: read the WHOLE thread (all blocks, all messages) via
// LoadThread, then apply the post-read Go filters (subagent skip + unfolded watermark drop +
// BlocksToAssistantLLM). It is the reference the new SQL-filtered LoadHistory must match byte-for-byte
// — it duplicates the old history.go body verbatim except the load call, so a divergence means the SQL
// filter changed what the LLM sees.
func (h *chatHost) loadHistoryFull(ctx context.Context) ([]llminfra.LLMMessage, error) {
	thread, err := h.svc.messages.LoadThread(ctx, h.conversationID)
	if err != nil {
		return nil, err
	}
	var out []llminfra.LLMMessage
	if h.summary != "" {
		out = append(out, llminfra.LLMMessage{Role: llminfra.RoleUser, Content: "<conversation_summary>\n" + h.summary + "\n</conversation_summary>"})
	}
	for _, m := range thread {
		if m.SubagentID != "" {
			continue
		}
		switch m.Role {
		case messagesdomain.RoleUser:
			if len(m.Blocks) > 0 && len(h.unfolded(m.Blocks)) == 0 {
				continue
			}
			out = append(out, h.userMessage(ctx, m))
		case messagesdomain.RoleAssistant:
			if m.ID == h.assistantMsgID {
				continue
			}
			msgs := loopapp.BlocksToAssistantLLM(h.unfolded(m.Blocks))
			if isEmptyAssistant(msgs) {
				continue
			}
			out = append(out, msgs...)
		}
	}
	return out, nil
}

// TestLoadHistory_ByteIdenticalAfterR10 — the LLM-visible history (block list, order, content) the
// new SQL-filtered LoadThreadForLLM path assembles is byte-identical to the pre-R10 full-LoadThread +
// post-read Go-filter path. Only the disk read shrank; the model sees exactly the same messages.
func TestLoadHistory_ByteIdenticalAfterR10(t *testing.T) {
	svc, store := newSvc(t, &fakeClient{}, nil)
	buildR10Thread(t, store)
	ctx := ctxWS("ws_1")

	h := &chatHost{
		svc:                  svc,
		conversationID:       "cv_1",
		summary:              "the older turns, summarized",
		summaryCoversUpToSeq: 3, // folds seqs 1..3 (the old user + old assistant turn)
	}

	got, err := h.LoadHistory(ctx) // new path: LoadThreadForLLM + Go filters (no-ops on pre-filtered set)
	if err != nil {
		t.Fatalf("LoadHistory: %v", err)
	}
	want, err := h.loadHistoryFull(ctx) // reference: full LoadThread + the old Go filters
	if err != nil {
		t.Fatalf("loadHistoryFull: %v", err)
	}

	if len(got) != len(want) {
		t.Fatalf("LLM history length diverged: got %d, want %d\ngot=%+v\nwant=%+v", len(got), len(want), got, want)
	}
	for i := range want {
		if got[i].Role != want[i].Role || got[i].Content != want[i].Content {
			t.Fatalf("LLM message %d diverged:\n got=%+v\nwant=%+v", i, got[i], want[i])
		}
	}

	// Sanity on the expected shape: summary block, then ONLY the two fresh turns — the folded turns
	// and the subagent message are absent.
	if len(got) != 3 {
		t.Fatalf("want [summary, fresh user, fresh assistant], got %d messages: %+v", len(got), got)
	}
	if got[0].Role != llminfra.RoleUser || got[0].Content != "<conversation_summary>\nthe older turns, summarized\n</conversation_summary>" {
		t.Fatalf("first message must be the summary, got %+v", got[0])
	}
	if got[1].Role != llminfra.RoleUser || got[1].Content != "fresh question" {
		t.Fatalf("second must be the fresh user turn, got %+v", got[1])
	}
	if got[2].Role != llminfra.RoleAssistant || got[2].Content != "fresh answer" {
		t.Fatalf("third must be the fresh assistant turn, got %+v", got[2])
	}
}
