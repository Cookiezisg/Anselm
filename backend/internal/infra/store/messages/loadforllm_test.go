package messages

import (
	"testing"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
)

// TestLoadThreadForLLM_FiltersSubagentAndWatermark_R10 — R10: the LLM-history read path must NOT pull
// from disk (a) subagent sub-messages or (b) compaction-folded blocks (seq ≤ watermark), while the
// shared LoadThread still returns the full set. This is the read-amplification cut: a long single
// conversation stops re-reading the whole folded-inclusive block table every turn.
func TestLoadThreadForLLM_FiltersSubagentAndWatermark_R10(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")

	// Turn 1 (user): seq 1.
	u1 := userMsg("msg_1", "cv_1")
	if err := s.CreateMessage(ctx, u1, []messagesdomain.Block{
		{Type: messagesdomain.BlockTypeText, Content: "old user paste"},
	}); err != nil {
		t.Fatalf("create u1: %v", err)
	}
	// Turn 2 (assistant): seq 2 (text) + seq 3 (tool_result). These are the OLD turn folded under
	// the watermark after compaction.
	a1 := &messagesdomain.Message{ID: "msg_2", ConversationID: "cv_1", Role: messagesdomain.RoleAssistant, Status: messagesdomain.StatusCompleted}
	if err := s.CreateMessage(ctx, a1, []messagesdomain.Block{
		{Type: messagesdomain.BlockTypeText, Content: "old answer"},
		{Type: messagesdomain.BlockTypeToolResult, Content: "old tool output", ContextRole: messagesdomain.ContextRoleArchived},
	}); err != nil {
		t.Fatalf("create a1: %v", err)
	}
	// Subagent sub-message (seq 4): persisted for the reload tree, NEVER part of the parent's LLM
	// history.
	sub := &messagesdomain.Message{ID: "msg_sub", ConversationID: "cv_1", SubagentID: "subagt_1", Role: messagesdomain.RoleAssistant, Status: messagesdomain.StatusCompleted}
	if err := s.CreateMessage(ctx, sub, []messagesdomain.Block{
		{Type: messagesdomain.BlockTypeText, Content: "subagent internal step"},
	}); err != nil {
		t.Fatalf("create sub: %v", err)
	}
	// Turn 3 (user, fresh): seq 5 — above the watermark, must survive.
	u2 := userMsg("msg_3", "cv_1")
	if err := s.CreateMessage(ctx, u2, []messagesdomain.Block{
		{Type: messagesdomain.BlockTypeText, Content: "fresh question"},
	}); err != nil {
		t.Fatalf("create u2: %v", err)
	}

	// Compaction folded turns 1+2 (seq 1..3) into the summary → watermark = 3.
	const watermark = int64(3)

	// LoadThread (shared full path) returns EVERYTHING — all 4 messages, all blocks, unfiltered.
	full, err := s.LoadThread(ctx, "cv_1")
	if err != nil {
		t.Fatalf("LoadThread: %v", err)
	}
	if len(full) != 4 {
		t.Fatalf("LoadThread must return all 4 messages (incl subagent), got %d", len(full))
	}
	var totalFullBlocks int
	for _, m := range full {
		totalFullBlocks += len(m.Blocks)
	}
	if totalFullBlocks != 5 {
		t.Fatalf("LoadThread must hydrate all 5 blocks, got %d", totalFullBlocks)
	}

	// LoadThreadForLLM drops the subagent message AND every block at seq ≤ watermark.
	llm, err := s.LoadThreadForLLM(ctx, "cv_1", watermark)
	if err != nil {
		t.Fatalf("LoadThreadForLLM: %v", err)
	}
	for _, m := range llm {
		if m.SubagentID != "" {
			t.Fatalf("subagent sub-message must NOT be read for LLM history: %+v", m)
		}
		for _, b := range m.Blocks {
			if b.Seq <= watermark {
				t.Fatalf("folded block (seq %d ≤ watermark %d) must NOT be read for LLM history: %+v", b.Seq, watermark, b)
			}
		}
	}
	// Only turn 3's fresh user block (seq 5) survives.
	var survivors []messagesdomain.Block
	for _, m := range llm {
		survivors = append(survivors, m.Blocks...)
	}
	if len(survivors) != 1 || survivors[0].Content != "fresh question" || survivors[0].Seq != 5 {
		t.Fatalf("only the post-watermark fresh user block should survive, got %+v", survivors)
	}
}

// TestLoadThreadForLLM_NoWatermark_ReadsAll_R10 — with no compaction (minSeq ≤ 0) the block filter is
// off: every non-subagent block is read (the common early-conversation path), so the optimization
// never silently drops content before compaction has folded anything.
func TestLoadThreadForLLM_NoWatermark_ReadsAll_R10(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")

	a := &messagesdomain.Message{ID: "msg_1", ConversationID: "cv_1", Role: messagesdomain.RoleAssistant, Status: messagesdomain.StatusCompleted}
	if err := s.CreateMessage(ctx, a, []messagesdomain.Block{
		{Type: messagesdomain.BlockTypeText, Content: "answer"},
		{Type: messagesdomain.BlockTypeToolResult, Content: "tool output"},
	}); err != nil {
		t.Fatalf("create: %v", err)
	}

	llm, err := s.LoadThreadForLLM(ctx, "cv_1", 0)
	if err != nil {
		t.Fatalf("LoadThreadForLLM: %v", err)
	}
	if len(llm) != 1 || len(llm[0].Blocks) != 2 {
		t.Fatalf("with no watermark every block must be read, got %d msgs / blocks %+v", len(llm), llm)
	}
}
