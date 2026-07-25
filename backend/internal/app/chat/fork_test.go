package chat

import (
	"database/sql"
	"errors"
	"testing"

	_ "github.com/glebarez/go-sqlite"
	"go.uber.org/zap"

	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	messagesstore "github.com/sunweilin/anselm/backend/internal/infra/store/messages"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

// forkFixture seeds one conversation whose shape exercises every fork hazard at once, over the REAL
// messages store (seq allocation and parent_block_id are physical facts — a fake repo would let a
// broken remap pass):
//
//	msg_u1  user      text "turn 1"                        seq 1
//	msg_a1  assistant tool_call "spawn" + text "answer 1"   seq 2,3
//	msg_s1  subagent  text "subagent work" parent=<seq 2>   seq 4   ← nesting ACROSS messages
//	msg_u2  user      text "turn 2"                         seq 5
//	msg_a2  assistant text "answer 2"                       seq 6
//
// forkFixture 在**真** messages store 上播一条把所有分叉风险一次性摆齐的对话（seq 分配与
// parent_block_id 是物理事实——fake repo 会让坏掉的 remap 蒙混过关），形状见上。
func forkFixture(t *testing.T) (*Service, messagesdomain.Repository, *forkRec, *conversationdomain.Conversation) {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range messagesstore.Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	store := messagesstore.New(ormpkg.Open(sqlDB))
	src := &conversationdomain.Conversation{ID: "cv_src", Title: "Original", SystemPrompt: "be concise"}
	rec := &forkRec{}
	svc := NewService(store, Deps{Conversations: fakeConvs{conv: src, fork: rec}}, zap.NewNop())
	ctx := ctxWS("ws_1")

	mk := func(id, subagentID, role string, blocks []messagesdomain.Block) []messagesdomain.Block {
		m := &messagesdomain.Message{
			ID: id, ConversationID: "cv_src", SubagentID: subagentID,
			Role: role, Status: messagesdomain.StatusCompleted,
		}
		if err := store.CreateMessage(ctx, m, blocks); err != nil {
			t.Fatalf("seed %s: %v", id, err)
		}
		return blocks // CreateMessage fills each block's assigned id + seq in place
	}
	mk("msg_u1", "", messagesdomain.RoleUser, []messagesdomain.Block{
		{Type: messagesdomain.BlockTypeText, Content: "turn 1"},
	})
	a1 := mk("msg_a1", "", messagesdomain.RoleAssistant, []messagesdomain.Block{
		{Type: messagesdomain.BlockTypeToolCall, Content: "spawn"},
		{Type: messagesdomain.BlockTypeText, Content: "answer 1"},
	})
	mk("msg_s1", "sub_1", messagesdomain.RoleAssistant, []messagesdomain.Block{
		{Type: messagesdomain.BlockTypeText, Content: "subagent work", ParentBlockID: a1[0].ID},
	})
	mk("msg_u2", "", messagesdomain.RoleUser, []messagesdomain.Block{
		{Type: messagesdomain.BlockTypeText, Content: "turn 2"},
	})
	mk("msg_a2", "", messagesdomain.RoleAssistant, []messagesdomain.Block{
		{Type: messagesdomain.BlockTypeText, Content: "answer 2"},
	})
	return svc, store, rec, src
}

// forkThread reads a conversation back oldest-first with all blocks hydrated.
func forkThread(t *testing.T, store messagesdomain.Repository, convID string) []*messagesdomain.Message {
	t.Helper()
	rows, err := store.LoadThread(ctxWS("ws_1"), convID)
	if err != nil {
		t.Fatalf("load %s: %v", convID, err)
	}
	return rows
}

// TestFork_PrefixWindowSeqRenumberAndNestedRemap is the load-bearing fork test: the prefix window is
// INCLUSIVE of the cut message and stops dead there, block seq restarts at 1 with no gaps,
// parent_block_id is remapped into the FORK's own block ids (never left pointing at the source —
// the one outcome that silently corrupts a tree), context_role is reset to hot, and the source is
// byte-for-byte untouched (fork is pure append; messages/message_blocks are D1 Log tables).
//
// TestFork_PrefixWindowSeqRenumberAndNestedRemap 是分叉的承重测试：前缀窗**含**切点消息且到此为止、
// block seq 从 1 重排无空洞、parent_block_id 重映射到**分叉自己**的 block id（绝不留着指向源——那是
// 唯一会静默腐坏树的结果）、context_role 重置为 hot，且源分毫不动（分叉是纯追加；messages /
// message_blocks 是 D1 Log 表）。
func TestFork_PrefixWindowSeqRenumberAndNestedRemap(t *testing.T) {
	svc, store, rec, src := forkFixture(t)
	ctx := ctxWS("ws_1")

	fork, err := svc.Fork(ctx, "cv_src", "msg_s1")
	if err != nil {
		t.Fatalf("fork: %v", err)
	}

	// Prefix window: the first three rows, cut message included, nothing after it.
	got := forkThread(t, store, fork.ID)
	if len(got) != 3 {
		t.Fatalf("prefix window must be 3 rows (u1, a1, s1 inclusive), got %d", len(got))
	}
	wantContents := [][]string{{"turn 1"}, {"spawn", "answer 1"}, {"subagent work"}}
	for i, m := range got {
		if len(m.Blocks) != len(wantContents[i]) {
			t.Fatalf("row %d: %d blocks, want %d", i, len(m.Blocks), len(wantContents[i]))
		}
		for j, b := range m.Blocks {
			if b.Content != wantContents[i][j] {
				t.Errorf("row %d block %d content = %q, want %q", i, j, b.Content, wantContents[i][j])
			}
		}
	}
	// Subagent rows travel (LLM assembly excludes them by subagent_id, so the copy need not).
	if got[2].SubagentID != "sub_1" {
		t.Errorf("subagent row must keep its subagentId, got %q", got[2].SubagentID)
	}

	// seq renumbered from 1, contiguous, in replay order.
	var seqs []int64
	forkBlockIDs := map[string]bool{}
	for _, m := range got {
		if m.ConversationID != fork.ID {
			t.Errorf("copied row %s still points at %q", m.ID, m.ConversationID)
		}
		for _, b := range m.Blocks {
			seqs = append(seqs, b.Seq)
			forkBlockIDs[b.ID] = true
			if b.ContextRole != messagesdomain.ContextRoleHot {
				t.Errorf("block %q contextRole = %q, want reset to hot", b.Content, b.ContextRole)
			}
		}
	}
	for i, s := range seqs {
		if s != int64(i+1) {
			t.Fatalf("seq must renumber 1..N contiguously, got %v", seqs)
		}
	}

	// Nested remap: the subagent block's parent is the FORK's tool_call block, not the source's.
	child := got[2].Blocks[0]
	parent := got[1].Blocks[0]
	if child.ParentBlockID != parent.ID {
		t.Fatalf("parentBlockId = %q, want the fork's tool_call block %q", child.ParentBlockID, parent.ID)
	}
	if !forkBlockIDs[child.ParentBlockID] {
		t.Fatalf("parentBlockId %q escapes the fork's own blocks", child.ParentBlockID)
	}
	srcThread := forkThread(t, store, "cv_src")
	for _, m := range srcThread {
		for _, b := range m.Blocks {
			if b.ID == child.ParentBlockID {
				t.Fatalf("parentBlockId still points into the SOURCE tree (%q)", b.ID)
			}
		}
	}
	// Ids are fresh throughout — no row is shared with the source.
	for _, m := range got {
		for _, s := range srcThread {
			if m.ID == s.ID {
				t.Fatalf("copied row reuses the source message id %q", m.ID)
			}
		}
	}

	// The source is untouched: 5 rows, original seq 1..6, D1 append-only intact.
	if len(srcThread) != 5 {
		t.Fatalf("source must still have 5 rows, got %d", len(srcThread))
	}
	if srcThread[1].Blocks[0].Seq != 2 || srcThread[4].Blocks[0].Seq != 6 {
		t.Errorf("source seq must be untouched, got %d…%d", srcThread[1].Blocks[0].Seq, srcThread[4].Blocks[0].Seq)
	}

	// Lineage reported to the head write is the cut message itself (inclusive).
	if rec.in.AtMessageID != "msg_s1" || rec.in.Source == nil || rec.in.Source.ID != src.ID {
		t.Errorf("fork input lineage = %q / %+v", rec.in.AtMessageID, rec.in.Source)
	}
	if fork.ForkedFromConversationID != "cv_src" || fork.ForkedFromMessageID != "msg_s1" {
		t.Errorf("returned head lineage = %q/%q", fork.ForkedFromConversationID, fork.ForkedFromMessageID)
	}
}

// TestFork_EmptyAtMessageForksAtLatest: the rail's "fork this conversation" has no message id at
// hand, so an omitted atMessageId means "the whole thread".
func TestFork_EmptyAtMessageForksAtLatest(t *testing.T) {
	svc, store, rec, _ := forkFixture(t)
	fork, err := svc.Fork(ctxWS("ws_1"), "cv_src", "")
	if err != nil {
		t.Fatalf("fork: %v", err)
	}
	if got := forkThread(t, store, fork.ID); len(got) != 5 {
		t.Fatalf("empty atMessageId must copy the whole thread (5 rows), got %d", len(got))
	}
	if rec.in.AtMessageID != "msg_a2" {
		t.Errorf("lineage must record the actual latest row, got %q", rec.in.AtMessageID)
	}
}

// TestFork_UnknownAtMessageIs404: a message id is a coordinate, so an id that is not in this thread
// is the same identity-anchor MESSAGE_NOT_FOUND the ?around= deep-jump read returns — and nothing
// is written (no orphan head).
func TestFork_UnknownAtMessageIs404(t *testing.T) {
	svc, store, rec, _ := forkFixture(t)
	_, err := svc.Fork(ctxWS("ws_1"), "cv_src", "msg_from_another_thread")
	if !errors.Is(err, messagesdomain.ErrMessageNotFound) {
		t.Fatalf("want MESSAGE_NOT_FOUND, got %v", err)
	}
	if rec.in.Source != nil {
		t.Error("a rejected fork must not reach the head write")
	}
	if got := forkThread(t, store, "cv_src"); len(got) != 5 {
		t.Errorf("source must be untouched, got %d rows", len(got))
	}
}

// TestFork_SummaryCarriedWhenCutIsAtOrAfterWatermark: the summary folds every source block with
// seq ≤ watermark, so a prefix that REACHES that line inherits it truthfully — with the watermark
// re-based onto the fork's own 1..N numbering, since carrying the source's number would hide the
// wrong rows from the model.
func TestFork_SummaryCarriedWhenCutIsAtOrAfterWatermark(t *testing.T) {
	svc, _, rec, src := forkFixture(t)
	src.Summary = "the older turns, folded"
	src.SummaryCoversUpToSeq = 3 // source seq 1..3 = u1's block + a1's two blocks

	if _, err := svc.Fork(ctxWS("ws_1"), "cv_src", "msg_s1"); err != nil {
		t.Fatalf("fork: %v", err)
	}
	if rec.in.Summary != "the older turns, folded" {
		t.Fatalf("summary must travel when the cut reaches the watermark, got %q", rec.in.Summary)
	}
	// Source seq 1,2,3 became fork seq 1,2,3 (u1 then a1's pair), so the re-based line is 3.
	if rec.in.SummaryCoversUpToSeq != 3 {
		t.Errorf("watermark = %d, want 3 (re-based onto the fork's numbering)", rec.in.SummaryCoversUpToSeq)
	}
}

// TestFork_SummaryDroppedWhenCutIsBeforeWatermark is the branch that keeps the fork honest: a cut
// before the watermark would hand the fork a summary describing turns it does not contain, so
// neither the summary nor the watermark travels — "no compaction yet" is the truth about a short
// fork, and the model must not answer about history that is not there.
func TestFork_SummaryDroppedWhenCutIsBeforeWatermark(t *testing.T) {
	svc, _, rec, src := forkFixture(t)
	src.Summary = "the older turns, folded"
	src.SummaryCoversUpToSeq = 5 // covers through u2's block; we cut at a1 (source seq 3)

	if _, err := svc.Fork(ctxWS("ws_1"), "cv_src", "msg_a1"); err != nil {
		t.Fatalf("fork: %v", err)
	}
	if rec.in.Summary != "" || rec.in.SummaryCoversUpToSeq != 0 {
		t.Fatalf("a cut before the watermark must carry NEITHER half, got %q / %d",
			rec.in.Summary, rec.in.SummaryCoversUpToSeq)
	}
}

// TestFork_MessagelessSourceCopiesHeadOnly: forking a thread nobody has spoken in is a config-only
// copy — no rows, no summary, and no crash on the empty prefix.
func TestFork_MessagelessSourceCopiesHeadOnly(t *testing.T) {
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range messagesstore.Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	store := messagesstore.New(ormpkg.Open(sqlDB))
	rec := &forkRec{}
	svc := NewService(store, Deps{Conversations: fakeConvs{
		conv: &conversationdomain.Conversation{ID: "cv_empty", Title: "Empty"}, fork: rec,
	}}, zap.NewNop())

	fork, err := svc.Fork(ctxWS("ws_1"), "cv_empty", "")
	if err != nil {
		t.Fatalf("fork: %v", err)
	}
	if fork.Title != "Empty (fork)" {
		t.Errorf("title = %q", fork.Title)
	}
	if rec.in.AtMessageID != "" {
		t.Errorf("no rows → no cut point, got %q", rec.in.AtMessageID)
	}
	if got := forkThread(t, store, fork.ID); len(got) != 0 {
		t.Errorf("want zero copied rows, got %d", len(got))
	}
}

// retriedFixture seeds one thread whose last round has been retried once — two assistant rows pointing
// at each other (superseded_by forward, attrs.retryOf back) over the REAL store, because both pointers
// are physical columns/JSON a fake repo would not police.
//
//	msg_u1  user      "one question"
//	msg_a1  assistant "FIRST ANSWER"   superseded_by = msg_a2
//	msg_a2  assistant "SECOND ANSWER"  attrs.retryOf = msg_a1   ← current
//
// retriedFixture 在**真** store 上播一条末回合被重试过一次的线程——两条互指的 assistant 行（superseded_by 向前、
// attrs.retryOf 向后），因为这两个指针都是 fake repo 管不住的物理列 / JSON。形状见上。
func retriedFixture(t *testing.T) (*Service, messagesdomain.Repository) {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range messagesstore.Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	store := messagesstore.New(ormpkg.Open(sqlDB))
	svc := NewService(store, Deps{Conversations: fakeConvs{
		conv: &conversationdomain.Conversation{ID: "cv_src", Title: "Retried"}, fork: &forkRec{},
	}}, zap.NewNop())
	ctx := ctxWS("ws_1")

	seed := func(m *messagesdomain.Message, text string) {
		t.Helper()
		m.ConversationID, m.Status = "cv_src", messagesdomain.StatusCompleted
		if err := store.CreateMessage(ctx, m, []messagesdomain.Block{
			{Type: messagesdomain.BlockTypeText, Content: text},
		}); err != nil {
			t.Fatalf("seed %s: %v", m.ID, err)
		}
	}
	seed(&messagesdomain.Message{ID: "msg_u1", Role: messagesdomain.RoleUser}, "one question")
	seed(&messagesdomain.Message{ID: "msg_a1", Role: messagesdomain.RoleAssistant}, "FIRST ANSWER")
	seed(&messagesdomain.Message{ID: "msg_a2", Role: messagesdomain.RoleAssistant,
		Attrs: map[string]any{messagesdomain.AttrRetryOf: "msg_a1"}}, "SECOND ANSWER")
	if err := store.MarkSuperseded(ctx, "msg_a1", "msg_a2"); err != nil {
		t.Fatalf("supersede: %v", err)
	}
	return svc, store
}

// TestFork_VersionChainRebasedIntoTheFork is the CH-b × CH-c interaction, and the one a naive copy gets
// silently wrong. A copy that kept the SOURCE's message ids would leave the fork's version chain pointing
// into the source thread; worse, dropping superseded_by would reset every copied version to "current" and
// hand the model BOTH answers to the same question. The fork must re-base the two pointers exactly as it
// re-bases parent_block_id.
//
// TestFork_VersionChainRebasedIntoTheFork 是 CH-b × CH-c 的交汇处，也是朴素复制会**静默**做错的那一处。保留**源**
// message id 的复制会让分叉的版本链指进源线程；更糟的是，丢掉 superseded_by 会把每个被复制的版本重置成「现行」，
// 于是模型拿到同一个问题的**两个**回答。分叉必须像它重排 parent_block_id 一样精确地重排这两个指针。
func TestFork_VersionChainRebasedIntoTheFork(t *testing.T) {
	svc, store := retriedFixture(t)
	ctx := ctxWS("ws_1")

	fork, err := svc.Fork(ctx, "cv_src", "")
	if err != nil {
		t.Fatalf("fork: %v", err)
	}
	copied := forkThread(t, store, fork.ID)
	if len(copied) != 3 {
		t.Fatalf("every version travels (the fork copies the durable truth), got %d rows", len(copied))
	}
	byText := map[string]*messagesdomain.Message{}
	for _, m := range copied {
		if len(m.Blocks) > 0 {
			byText[m.Blocks[0].Content] = m
		}
	}
	older, newer := byText["FIRST ANSWER"], byText["SECOND ANSWER"]
	if older == nil || newer == nil {
		t.Fatalf("both versions must be copied, got %+v", byText)
	}
	if older.SupersededBy != newer.ID {
		t.Errorf("copied supersededBy = %q, want the fork's own newer row %q", older.SupersededBy, newer.ID)
	}
	if got := retryOfOf(newer); got != older.ID {
		t.Errorf("copied attrs.retryOf = %q, want the fork's own older row %q", got, older.ID)
	}
	// The consequence that matters: the fork feeds the model ONE answer.
	llm, err := store.LoadThreadForLLM(ctx, fork.ID, 0)
	if err != nil {
		t.Fatalf("LoadThreadForLLM: %v", err)
	}
	if len(llm) != 2 {
		t.Fatalf("the fork's LLM view must be one question + one answer, got %d rows", len(llm))
	}
	for _, m := range llm {
		for _, b := range m.Blocks {
			if b.Content == "FIRST ANSWER" {
				t.Fatal("the fork fed the model a superseded version")
			}
		}
	}
}

// TestFork_CutAtAnOlderVersionLeavesItCurrent: a cut that lands ON the older version leaves the newer one
// outside the prefix window. Inside that fork the older row is the ONLY version of the round, so its
// forward pointer must be EMPTY — not a dangling id, and not a pointer that hides the fork's only answer
// from its own model.
//
// TestFork_CutAtAnOlderVersionLeavesItCurrent：切点落在**旧版**上时，新版落在前缀窗外。在那份分叉里旧行是该回合
// **唯一**的版本，故它的前向指针必须**为空**——不是一个悬空 id，也不是一个把分叉唯一的回答藏起来不给它自己的模型看
// 的指针。
func TestFork_CutAtAnOlderVersionLeavesItCurrent(t *testing.T) {
	svc, store := retriedFixture(t)
	ctx := ctxWS("ws_1")

	fork, err := svc.Fork(ctx, "cv_src", "msg_a1")
	if err != nil {
		t.Fatalf("fork at the older version: %v", err)
	}
	copied := forkThread(t, store, fork.ID)
	if len(copied) != 2 {
		t.Fatalf("the prefix stops at the cut, got %d rows", len(copied))
	}
	for _, m := range copied {
		if m.SupersededBy != "" {
			t.Errorf("a superseding row cut away by the prefix must leave an EMPTY pointer, got %q", m.SupersededBy)
		}
		if got := retryOfOf(m); got != "" {
			t.Errorf("a retryOf whose target is outside the window must be dropped, got %q", got)
		}
	}
	llm, err := store.LoadThreadForLLM(ctx, fork.ID, 0)
	if err != nil {
		t.Fatalf("LoadThreadForLLM: %v", err)
	}
	if len(llm) != 2 {
		t.Fatalf("the fork must feed the model its own only round, got %d rows", len(llm))
	}
}
