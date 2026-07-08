package messages

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
)

// seedTimeline creates n user turns msg_1..msg_n in cv, one text block each, with created_at
// pinned a minute apart so ordering is deterministic.
//
// seedTimeline 在 cv 建 n 个 user 回合 msg_1..msg_n（各一 text block），created_at 按分钟错开钉死。
func seedTimeline(t *testing.T, s *Store, ctx context.Context, cv string, n int) {
	t.Helper()
	base := time.Date(2026, 7, 8, 10, 0, 0, 0, time.UTC)
	for i := 1; i <= n; i++ {
		id := fmt.Sprintf("msg_%d", i)
		m := userMsg(id, cv)
		if err := s.CreateMessage(ctx, m, []messagesdomain.Block{{Type: messagesdomain.BlockTypeText, Content: id}}); err != nil {
			t.Fatalf("create %s: %v", id, err)
		}
		pinTime(t, s, ctx, id, base.Add(time.Duration(i)*time.Minute))
	}
}

// TestListMessagesAround_WindowAndCursors proves the deep-jump window: newest-first assembly
// around the target, limit split before/after, target always included, both continuation
// cursors feeding their respective list reads, blocks hydrated.
//
// TestListMessagesAround_WindowAndCursors 证明深跳窗：围绕 target 的 newest-first 组装、limit
// 前后拆分、target 恒在、双续翻游标各喂各的列表读、blocks 已 hydrate。
func TestListMessagesAround_WindowAndCursors(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	seedTimeline(t, s, ctx, "cv_1", 7)

	window, olderCur, newerCur, hasOlder, hasNewer, err := s.ListMessagesAround(ctx, "cv_1", "msg_4", 4)
	if err != nil {
		t.Fatalf("around: %v", err)
	}
	got := make([]string, len(window))
	for i, m := range window {
		got[i] = m.ID
	}
	want := []string{"msg_6", "msg_5", "msg_4", "msg_3", "msg_2"}
	if len(got) != len(want) {
		t.Fatalf("window = %v, want %v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("window = %v, want %v (newest-first, target centered)", got, want)
		}
	}
	if !hasOlder || !hasNewer {
		t.Fatalf("hasOlder=%v hasNewer=%v, want true/true (msg_1 and msg_7 remain)", hasOlder, hasNewer)
	}
	for _, m := range window {
		if len(m.Blocks) == 0 {
			t.Fatalf("window row %s not hydrated", m.ID)
		}
	}

	// The older cursor continues the plain DESC list: strictly older than the window bottom.
	// 旧游标续普通降序列表：严格旧于窗底。
	older, _, err := s.ListMessages(ctx, "cv_1", olderCur, 10)
	if err != nil {
		t.Fatalf("older continuation: %v", err)
	}
	if len(older) != 1 || older[0].ID != "msg_1" {
		t.Fatalf("older continuation = %v, want [msg_1]", idsOf(older))
	}

	// The newer cursor continues FORWARD: strictly newer than the window top.
	// 新游标向前续：严格新于窗顶。
	newer, _, err := s.ListMessagesNewer(ctx, "cv_1", newerCur, 10)
	if err != nil {
		t.Fatalf("newer continuation: %v", err)
	}
	if len(newer) != 1 || newer[0].ID != "msg_7" {
		t.Fatalf("newer continuation = %v, want [msg_7]", idsOf(newer))
	}
}

// TestListMessagesAround_EdgesAndMissing proves edge honesty: a window at the newest edge reports
// hasNewer=false with no newer cursor; an unknown target — or a target from ANOTHER conversation
// (identity anchoring) — is ErrMessageNotFound.
//
// TestListMessagesAround_EdgesAndMissing 证明边界诚实：贴最新边的窗报 hasNewer=false 且无新游标；
// 未知 target——或**别的对话**的 target（身份锚点派）——即 ErrMessageNotFound。
func TestListMessagesAround_EdgesAndMissing(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	seedTimeline(t, s, ctx, "cv_1", 3)
	other := userMsg("msg_x", "cv_2")
	if err := s.CreateMessage(ctx, other, nil); err != nil {
		t.Fatalf("create other-conv: %v", err)
	}

	window, _, newerCur, _, hasNewer, err := s.ListMessagesAround(ctx, "cv_1", "msg_3", 4)
	if err != nil {
		t.Fatalf("around newest: %v", err)
	}
	if hasNewer || newerCur != "" {
		t.Fatalf("newest edge: hasNewer=%v newerCur=%q, want false/\"\"", hasNewer, newerCur)
	}
	if window[0].ID != "msg_3" {
		t.Fatalf("window top = %s, want the target itself at the newest edge", window[0].ID)
	}

	if _, _, _, _, _, err := s.ListMessagesAround(ctx, "cv_1", "msg_nope", 4); !errors.Is(err, messagesdomain.ErrMessageNotFound) {
		t.Fatalf("missing target: err = %v, want ErrMessageNotFound", err)
	}
	if _, _, _, _, _, err := s.ListMessagesAround(ctx, "cv_1", "msg_x", 4); !errors.Is(err, messagesdomain.ErrMessageNotFound) {
		t.Fatalf("foreign-conversation target: err = %v, want ErrMessageNotFound", err)
	}
}

// TestListMessagesNewer_WalksForward proves the ascending continuation pages forward without
// duplicates and terminates with an empty cursor at the newest edge.
//
// TestListMessagesNewer_WalksForward 证明升序续翻向前分页、零重复、到最新边以空游标终止。
func TestListMessagesNewer_WalksForward(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	seedTimeline(t, s, ctx, "cv_1", 5)

	// Open a pivot at msg_2 via an around read (limit 2 → 1 older + 1 newer).
	// 经 around 读在 msg_2 开支点（limit 2 → 旧 1 + 新 1）。
	_, _, newerCur, _, _, err := s.ListMessagesAround(ctx, "cv_1", "msg_2", 2)
	if err != nil {
		t.Fatalf("around: %v", err)
	}
	var walked []string
	cursor := newerCur // continues past msg_3 (the window's newer half)
	for cursor != "" {
		rows, next, err := s.ListMessagesNewer(ctx, "cv_1", cursor, 1)
		if err != nil {
			t.Fatalf("newer page: %v", err)
		}
		for _, m := range rows {
			walked = append(walked, m.ID)
		}
		cursor = next
	}
	want := []string{"msg_4", "msg_5"}
	if len(walked) != len(want) {
		t.Fatalf("walked = %v, want %v", walked, want)
	}
	for i := range want {
		if walked[i] != want[i] {
			t.Fatalf("walked = %v, want %v (oldest-first)", walked, want)
		}
	}
}

// TestListAnchorSource_LeanProjections proves the anchors scan reads ONLY what the builder needs:
// turn rows without hydrate, machine blocks (tool_call + compaction), user-turn text — and never
// tool_result / progress / assistant prose.
//
// TestListAnchorSource_LeanProjections 证明锚点扫描只读构建器所需：不 hydrate 的回合行、机器块
// （tool_call + compaction）、user 回合 text——绝不读 tool_result / progress / assistant 散文。
func TestListAnchorSource_LeanProjections(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")

	u := userMsg("msg_u", "cv_1")
	if err := s.CreateMessage(ctx, u, []messagesdomain.Block{{Type: messagesdomain.BlockTypeText, Content: "帮我删掉旧函数\n顺便清理"}}); err != nil {
		t.Fatalf("user: %v", err)
	}
	a := &messagesdomain.Message{ID: "msg_a", ConversationID: "cv_1", Role: messagesdomain.RoleAssistant, Status: messagesdomain.StatusCompleted}
	if err := s.CreateMessage(ctx, a, []messagesdomain.Block{
		{Type: messagesdomain.BlockTypeText, Content: "好的，我来处理。"},
		{Type: messagesdomain.BlockTypeToolCall, Attrs: map[string]any{"tool": "delete_function", "danger": "dangerous"}, Content: `{"functionId":"fn_1"}`},
		{Type: messagesdomain.BlockTypeToolResult, Content: "deleted"},
		{Type: messagesdomain.BlockTypeProgress, Content: "tick"},
		{Type: messagesdomain.BlockTypeCompaction, Content: "↯ 12 turns folded"},
	}); err != nil {
		t.Fatalf("assistant: %v", err)
	}

	msgs, blocks, err := s.ListAnchorSource(ctx, "cv_1")
	if err != nil {
		t.Fatalf("ListAnchorSource: %v", err)
	}
	if len(msgs) != 2 {
		t.Fatalf("msgs = %d, want 2", len(msgs))
	}
	for _, m := range msgs {
		if m.Blocks != nil {
			t.Fatalf("msg %s was hydrated — the scan must stay lean", m.ID)
		}
	}
	var types []string
	var lastSeq int64
	for _, b := range blocks {
		types = append(types, b.Type)
		if b.Seq < lastSeq {
			t.Fatalf("blocks not seq-ascending: %v", types)
		}
		lastSeq = b.Seq
	}
	want := []string{
		messagesdomain.BlockTypeText,       // the user turn's excerpt source
		messagesdomain.BlockTypeToolCall,   // machine anchor
		messagesdomain.BlockTypeCompaction, // machine anchor
	}
	if len(types) != len(want) {
		t.Fatalf("block types = %v, want %v (tool_result/progress/assistant prose excluded)", types, want)
	}
	for i := range want {
		if types[i] != want[i] {
			t.Fatalf("block types = %v, want %v", types, want)
		}
	}
}
