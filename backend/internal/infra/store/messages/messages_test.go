package messages

import (
	"context"
	"database/sql"
	"errors"
	"testing"
	"time"

	_ "github.com/glebarez/go-sqlite"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func newStore(t *testing.T) *Store {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1) // in-memory SQLite: single conn so tx + reads hit the same DB. 单连接使事务与读命中同一库。
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	return New(ormpkg.Open(sqlDB))
}

func ctxWS(id string) context.Context {
	return reqctxpkg.SetWorkspaceID(context.Background(), id)
}

// pinTime fixes a message's created_at so List / LoadThread ordering is deterministic
// regardless of clock resolution.
//
// pinTime 把 message 的 created_at 钉死，使 List / LoadThread 排序与时钟精度无关。
func pinTime(t *testing.T, s *Store, ctx context.Context, msgID string, at time.Time) {
	t.Helper()
	if _, err := s.db.Exec(ctx, "UPDATE messages SET created_at = ? WHERE id = ?", at.UTC(), msgID); err != nil {
		t.Fatalf("pin time %s: %v", msgID, err)
	}
}

func userMsg(id, conv string) *messagesdomain.Message {
	return &messagesdomain.Message{ID: id, ConversationID: conv, Role: messagesdomain.RoleUser, Status: messagesdomain.StatusCompleted}
}

func TestCreateMessage_RoundTrip(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")

	m := userMsg("msg_1", "cv_1")
	blocks := []messagesdomain.Block{{Type: messagesdomain.BlockTypeText, Content: "hello"}}
	if err := s.CreateMessage(ctx, m, blocks); err != nil {
		t.Fatalf("CreateMessage: %v", err)
	}

	// insertBlocks mutates the slice in place: id / seq / conv / message must be filled.
	// insertBlocks 原地改切片：id / seq / conv / message 须填好。
	if blocks[0].ID == "" || blocks[0].Seq != 1 || blocks[0].ConversationID != "cv_1" || blocks[0].MessageID != "msg_1" {
		t.Fatalf("block not populated: %+v", blocks[0])
	}

	got, err := s.GetMessage(ctx, "msg_1")
	if err != nil {
		t.Fatalf("GetMessage: %v", err)
	}
	if got.Role != messagesdomain.RoleUser || got.WorkspaceID != "ws_1" {
		t.Fatalf("message fields: role=%q ws=%q", got.Role, got.WorkspaceID)
	}
	if len(got.Blocks) != 1 || got.Blocks[0].Content != "hello" {
		t.Fatalf("blocks not hydrated: %+v", got.Blocks)
	}
	if got.Blocks[0].WorkspaceID != "ws_1" || got.Blocks[0].ContextRole != messagesdomain.ContextRoleHot {
		t.Fatalf("block ws / context_role default wrong: %+v", got.Blocks[0])
	}
}

func TestSeqMonotonicAcrossMessages(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")

	m1 := userMsg("msg_1", "cv_1")
	b1 := []messagesdomain.Block{
		{Type: messagesdomain.BlockTypeText, Content: "a"},
		{Type: messagesdomain.BlockTypeText, Content: "b"},
	}
	if err := s.CreateMessage(ctx, m1, b1); err != nil {
		t.Fatalf("create m1: %v", err)
	}
	m2 := &messagesdomain.Message{ID: "msg_2", ConversationID: "cv_1", Role: messagesdomain.RoleAssistant, Status: messagesdomain.StatusCompleted}
	b2 := []messagesdomain.Block{
		{Type: messagesdomain.BlockTypeText, Content: "c"},
		{Type: messagesdomain.BlockTypeText, Content: "d"},
	}
	if err := s.CreateMessage(ctx, m2, b2); err != nil {
		t.Fatalf("create m2: %v", err)
	}

	if b1[0].Seq != 1 || b1[1].Seq != 2 || b2[0].Seq != 3 || b2[1].Seq != 4 {
		t.Fatalf("seq not monotonic across messages: %d %d %d %d", b1[0].Seq, b1[1].Seq, b2[0].Seq, b2[1].Seq)
	}

	// A second conversation restarts its own seq at 1 (UNIQUE is per conversation).
	// 第二个对话从自己的 seq=1 重起（UNIQUE 按对话）。
	m3 := userMsg("msg_3", "cv_2")
	b3 := []messagesdomain.Block{{Type: messagesdomain.BlockTypeText, Content: "x"}}
	if err := s.CreateMessage(ctx, m3, b3); err != nil {
		t.Fatalf("create m3: %v", err)
	}
	if b3[0].Seq != 1 {
		t.Fatalf("new conversation seq should restart at 1, got %d", b3[0].Seq)
	}
}

func TestBlockTree_ToolResultParent(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")

	m := &messagesdomain.Message{ID: "msg_1", ConversationID: "cv_1", Role: messagesdomain.RoleAssistant, Status: messagesdomain.StatusCompleted}
	blocks := []messagesdomain.Block{
		{ID: "blk_tc", Type: messagesdomain.BlockTypeToolCall, Content: `{"path":"/x"}`, Attrs: map[string]any{"tool": "Read"}},
		{Type: messagesdomain.BlockTypeToolResult, ParentBlockID: "blk_tc", Content: "file body"},
	}
	if err := s.CreateMessage(ctx, m, blocks); err != nil {
		t.Fatalf("CreateMessage: %v", err)
	}

	got, err := s.GetMessage(ctx, "msg_1")
	if err != nil {
		t.Fatalf("GetMessage: %v", err)
	}
	if len(got.Blocks) != 2 {
		t.Fatalf("want 2 blocks, got %d", len(got.Blocks))
	}
	// seq-ordered: tool_call first, tool_result second; the result points at the call.
	// 按 seq：tool_call 在前、tool_result 在后；result 指向 call。
	if got.Blocks[0].ID != "blk_tc" || got.Blocks[1].ParentBlockID != "blk_tc" {
		t.Fatalf("tool_result parent linkage broken: call=%q result.parent=%q", got.Blocks[0].ID, got.Blocks[1].ParentBlockID)
	}
	if tool, _ := got.Blocks[0].Attrs["tool"].(string); tool != "Read" {
		t.Fatalf("tool_call attrs not round-tripped: %+v", got.Blocks[0].Attrs)
	}
}

func TestFinalizeMessage(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")

	// Open an assistant turn (streaming, no blocks yet) — the host does this before loop.Run.
	// 开 assistant 回合（streaming、暂无 block）——host 在 loop.Run 前做这步。
	m := &messagesdomain.Message{ID: "msg_a", ConversationID: "cv_1", Role: messagesdomain.RoleAssistant, Status: messagesdomain.StatusStreaming}
	if err := s.CreateMessage(ctx, m, nil); err != nil {
		t.Fatalf("open turn: %v", err)
	}

	m.Status = messagesdomain.StatusCompleted
	m.StopReason = messagesdomain.StopReasonEndTurn
	m.InputTokens, m.OutputTokens = 12, 34
	m.Provider, m.ModelID = "anthropic", "claude-x"
	m.Attrs = map[string]any{"contextUsage": map[string]any{"lastPromptInputTokens": 9.0}}
	blocks := []messagesdomain.Block{{Type: messagesdomain.BlockTypeText, Content: "done"}}
	if err := s.FinalizeMessage(ctx, m, blocks); err != nil {
		t.Fatalf("FinalizeMessage: %v", err)
	}

	got, err := s.GetMessage(ctx, "msg_a")
	if err != nil {
		t.Fatalf("GetMessage: %v", err)
	}
	if got.Status != messagesdomain.StatusCompleted || got.StopReason != messagesdomain.StopReasonEndTurn {
		t.Fatalf("terminal status not written: %+v", got)
	}
	if got.InputTokens != 12 || got.OutputTokens != 34 || got.Provider != "anthropic" || got.ModelID != "claude-x" {
		t.Fatalf("token / provenance not written: %+v", got)
	}
	stats, _ := got.Attrs["contextUsage"].(map[string]any)
	if stats["lastPromptInputTokens"] != float64(9) {
		t.Fatalf("finalize attrs not written: %+v", got.Attrs)
	}
	if len(got.Blocks) != 1 || got.Blocks[0].Seq != 1 {
		t.Fatalf("finalized blocks wrong: %+v", got.Blocks)
	}
}

func TestFinalizeMessage_NotFound(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	m := &messagesdomain.Message{ID: "msg_missing", ConversationID: "cv_1", Role: messagesdomain.RoleAssistant, Status: messagesdomain.StatusCompleted}
	err := s.FinalizeMessage(ctx, m, nil)
	if !errors.Is(err, messagesdomain.ErrMessageNotFound) {
		t.Fatalf("want ErrMessageNotFound, got %v", err)
	}
}

func TestListMessages_PagingNewestFirst(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	base := time.Date(2026, 6, 9, 10, 0, 0, 0, time.UTC)
	for i, id := range []string{"msg_1", "msg_2", "msg_3"} {
		m := userMsg(id, "cv_1")
		if err := s.CreateMessage(ctx, m, []messagesdomain.Block{{Type: messagesdomain.BlockTypeText, Content: id}}); err != nil {
			t.Fatalf("create %s: %v", id, err)
		}
		pinTime(t, s, ctx, id, base.Add(time.Duration(i)*time.Minute))
	}

	page1, next, err := s.ListMessages(ctx, "cv_1", "", 2)
	if err != nil {
		t.Fatalf("page1: %v", err)
	}
	// newest-first: msg_3 (10:02) then msg_2 (10:01).
	// 最新在前：msg_3 (10:02) 后 msg_2 (10:01)。
	if len(page1) != 2 || page1[0].ID != "msg_3" || page1[1].ID != "msg_2" {
		t.Fatalf("page1 order wrong: %v", idsOf(page1))
	}
	if next == "" {
		t.Fatalf("expected a next cursor")
	}
	page2, next2, err := s.ListMessages(ctx, "cv_1", next, 2)
	if err != nil {
		t.Fatalf("page2: %v", err)
	}
	if len(page2) != 1 || page2[0].ID != "msg_1" || next2 != "" {
		t.Fatalf("page2 wrong: ids=%v next=%q", idsOf(page2), next2)
	}
	if len(page1[0].Blocks) != 1 {
		t.Fatalf("list did not hydrate blocks: %+v", page1[0])
	}
}

func TestLoadThread_OldestFirst(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	base := time.Date(2026, 6, 9, 10, 0, 0, 0, time.UTC)

	u := userMsg("msg_u", "cv_1")
	if err := s.CreateMessage(ctx, u, []messagesdomain.Block{{Type: messagesdomain.BlockTypeText, Content: "q"}}); err != nil {
		t.Fatalf("user: %v", err)
	}
	pinTime(t, s, ctx, "msg_u", base)

	a := &messagesdomain.Message{ID: "msg_a", ConversationID: "cv_1", Role: messagesdomain.RoleAssistant, Status: messagesdomain.StatusCompleted}
	if err := s.CreateMessage(ctx, a, []messagesdomain.Block{
		{Type: messagesdomain.BlockTypeReasoning, Content: "think"},
		{Type: messagesdomain.BlockTypeText, Content: "answer"},
	}); err != nil {
		t.Fatalf("assistant: %v", err)
	}
	pinTime(t, s, ctx, "msg_a", base.Add(time.Minute))

	thread, err := s.LoadThread(ctx, "cv_1")
	if err != nil {
		t.Fatalf("LoadThread: %v", err)
	}
	if len(thread) != 2 || thread[0].ID != "msg_u" || thread[1].ID != "msg_a" {
		t.Fatalf("thread order wrong (want oldest-first): %v", idsOf(thread))
	}
	// assistant turn's blocks are seq-ordered: reasoning (seq 2) before text (seq 3).
	// assistant 回合 block 按 seq：reasoning（seq 2）在 text（seq 3）前。
	if len(thread[1].Blocks) != 2 || thread[1].Blocks[0].Type != messagesdomain.BlockTypeReasoning {
		t.Fatalf("assistant blocks order wrong: %+v", thread[1].Blocks)
	}
}

func TestWorkspaceIsolation(t *testing.T) {
	s := newStore(t)
	if err := s.CreateMessage(ctxWS("ws_a"), userMsg("msg_1", "cv_1"),
		[]messagesdomain.Block{{Type: messagesdomain.BlockTypeText, Content: "secret"}}); err != nil {
		t.Fatalf("create in ws_a: %v", err)
	}

	// Workspace B sees neither the thread nor the message.
	// 工作区 B 既看不到线程也看不到消息。
	thread, err := s.LoadThread(ctxWS("ws_b"), "cv_1")
	if err != nil {
		t.Fatalf("LoadThread ws_b: %v", err)
	}
	if len(thread) != 0 {
		t.Fatalf("ws_b leaked %d messages", len(thread))
	}
	if _, err := s.GetMessage(ctxWS("ws_b"), "msg_1"); !errors.Is(err, messagesdomain.ErrMessageNotFound) {
		t.Fatalf("ws_b should not find msg_1, got %v", err)
	}
}

func TestGetMessage_NotFound(t *testing.T) {
	s := newStore(t)
	if _, err := s.GetMessage(ctxWS("ws_1"), "msg_nope"); !errors.Is(err, messagesdomain.ErrMessageNotFound) {
		t.Fatalf("want ErrMessageNotFound, got %v", err)
	}
}

func idsOf(rows []*messagesdomain.Message) []string {
	out := make([]string, len(rows))
	for i, m := range rows {
		out[i] = m.ID
	}
	return out
}

func TestUpdateBlocksContextRole(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")

	m := &messagesdomain.Message{ID: "msg_1", ConversationID: "cv_1", Role: messagesdomain.RoleAssistant, Status: messagesdomain.StatusCompleted}
	blocks := []messagesdomain.Block{
		{Type: messagesdomain.BlockTypeToolResult, Content: "big output"},
		{Type: messagesdomain.BlockTypeText, Content: "answer"},
	}
	if err := s.CreateMessage(ctx, m, blocks); err != nil {
		t.Fatalf("CreateMessage: %v", err)
	}
	if blocks[0].ContextRole != messagesdomain.ContextRoleHot {
		t.Fatalf("default role should be hot, got %q", blocks[0].ContextRole)
	}

	// Demote the tool_result block to cold; the text block stays hot.
	if err := s.UpdateBlocksContextRole(ctx, []string{blocks[0].ID}, messagesdomain.ContextRoleCold); err != nil {
		t.Fatalf("UpdateBlocksContextRole: %v", err)
	}
	// Empty ids is a no-op (not an error).
	if err := s.UpdateBlocksContextRole(ctx, nil, messagesdomain.ContextRoleArchived); err != nil {
		t.Fatalf("empty ids should be a no-op: %v", err)
	}

	got, err := s.GetMessage(ctx, "msg_1")
	if err != nil {
		t.Fatalf("GetMessage: %v", err)
	}
	roles := map[string]string{}
	for _, b := range got.Blocks {
		roles[b.Type] = b.ContextRole
	}
	if roles[messagesdomain.BlockTypeToolResult] != messagesdomain.ContextRoleCold {
		t.Fatalf("tool_result should be cold, got %q", roles[messagesdomain.BlockTypeToolResult])
	}
	if roles[messagesdomain.BlockTypeText] != messagesdomain.ContextRoleHot {
		t.Fatalf("text should stay hot, got %q", roles[messagesdomain.BlockTypeText])
	}
}
