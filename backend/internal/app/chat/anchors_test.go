package chat

import (
	"database/sql"
	"testing"
	"time"

	"go.uber.org/zap"

	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	messagesstore "github.com/sunweilin/anselm/backend/internal/infra/store/messages"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

// at returns a deterministic timestamp i minutes past a fixed base. 定基准 + i 分钟。
func at(i int) time.Time {
	return time.Date(2026, 7, 8, 10, 0, 0, 0, time.UTC).Add(time.Duration(i) * time.Minute)
}

// TestBuildAnchors_Classification proves the anchor taxonomy on one hand-built timeline: user
// turns anchor with a first-line excerpt; consecutive non-dangerous tool calls fold into ONE
// counted cluster that flushes at every real anchor (human content is the hard boundary);
// dangerous calls, compaction marks and abnormal terminals surface individually; a trailing
// cluster still flushes.
//
// TestBuildAnchors_Classification 在一条手搭时间线上证明锚点分类学：user 回合带首行节选成锚；
// 连续非危险工具折叠为**一条**带计数的簇、在每个真锚处 flush（人类内容是硬边界）；危险调用、
// 压缩标记、异常终态逐条露出；尾部残簇仍 flush。
func TestBuildAnchors_Classification(t *testing.T) {
	msgs := []*messagesdomain.Message{
		{ID: "m_u1", Role: messagesdomain.RoleUser, Status: messagesdomain.StatusCompleted, CreatedAt: at(1)},
		{ID: "m_a1", Role: messagesdomain.RoleAssistant, Status: messagesdomain.StatusCompleted, CreatedAt: at(2)},
		{ID: "m_u2", Role: messagesdomain.RoleUser, Status: messagesdomain.StatusCompleted, CreatedAt: at(3)},
		{ID: "m_a2", Role: messagesdomain.RoleAssistant, Status: messagesdomain.StatusError, StopReason: "max_tokens", CreatedAt: at(4)},
		{ID: "m_a3", Role: messagesdomain.RoleAssistant, Status: messagesdomain.StatusCompleted, CreatedAt: at(5)},
	}
	blocks := []*messagesdomain.Block{
		{ID: "b_t1", MessageID: "m_u1", Seq: 1, Type: messagesdomain.BlockTypeText, Content: "\n  帮我修一下时区 bug\n附:日志", CreatedAt: at(1)},
		{ID: "b_c1", MessageID: "m_a1", Seq: 2, Type: messagesdomain.BlockTypeToolCall, Attrs: map[string]any{"tool": "get_function", "danger": "safe"}, CreatedAt: at(2)},
		{ID: "b_c2", MessageID: "m_a1", Seq: 3, Type: messagesdomain.BlockTypeToolCall, Attrs: map[string]any{"tool": "edit_function"}, CreatedAt: at(2)},
		{ID: "b_t2", MessageID: "m_u2", Seq: 4, Type: messagesdomain.BlockTypeText, Content: "顺手把旧的删了", CreatedAt: at(3)},
		{ID: "b_d1", MessageID: "m_a2", Seq: 5, Type: messagesdomain.BlockTypeToolCall, Attrs: map[string]any{"tool": "delete_function", "danger": "dangerous", "entityName": "sync_v1"}, CreatedAt: at(4)},
		{ID: "b_k1", MessageID: "m_a3", Seq: 6, Type: messagesdomain.BlockTypeCompaction, Content: "↯ 12 turns folded", CreatedAt: at(5)},
		{ID: "b_c3", MessageID: "m_a3", Seq: 7, Type: messagesdomain.BlockTypeToolCall, Attrs: map[string]any{"tool": "run_function"}, CreatedAt: at(5)},
	}

	got := buildAnchors(msgs, blocks)
	want := []struct {
		kind, title string
		count       int
	}{
		{AnchorKindUser, "帮我修一下时区 bug", 0}, // excerpt skips the leading blank line 节选跳过首空行
		{AnchorKindTools, "", 2},           // b_c1 + b_c2 folded 折叠
		{AnchorKindUser, "顺手把旧的删了", 0},     // the human boundary flushed the cluster 人类边界触发 flush
		{AnchorKindDanger, "delete_function · sync_v1", 0},
		{AnchorKindAbnormal, "max_tokens", 0}, // status=error surfaces its stopReason 异常终态报止因
		{AnchorKindCompaction, "↯ 12 turns folded", 0},
		{AnchorKindTools, "", 1}, // the trailing cluster still flushes 尾簇仍 flush
	}
	if len(got) != len(want) {
		kinds := make([]string, len(got))
		for i, a := range got {
			kinds[i] = a.Kind
		}
		t.Fatalf("anchors = %v (%d), want %d", kinds, len(got), len(want))
	}
	for i, w := range want {
		if got[i].Kind != w.kind || got[i].Title != w.title || got[i].Count != w.count {
			t.Fatalf("anchor[%d] = {%s %q %d}, want {%s %q %d}", i, got[i].Kind, got[i].Title, got[i].Count, w.kind, w.title, w.count)
		}
	}
	// The cluster anchors pin their FIRST call's block (the jump target). 簇锚钉首个调用块。
	if got[1].BlockID != "b_c1" || got[1].MessageID != "m_a1" {
		t.Errorf("cluster anchor pins %s/%s, want m_a1/b_c1", got[1].MessageID, got[1].BlockID)
	}
}

// TestExcerptFirstLine covers the excerpt edges: blank lines skipped, rune-capped with an
// ellipsis (multi-byte safe), empty input → empty.
//
// TestExcerptFirstLine 覆盖节选边界：跳空行、按 rune 截断加省略号（多字节安全）、空入 → 空。
func TestExcerptFirstLine(t *testing.T) {
	if got := excerptFirstLine("\n\n  第一行  \n第二行", 120); got != "第一行" {
		t.Errorf("blank-skip = %q", got)
	}
	long := ""
	for i := 0; i < 50; i++ {
		long += "测试"
	}
	if got := excerptFirstLine(long, 10); got != "测试测试测试测试测试…" {
		t.Errorf("rune cap = %q", got)
	}
	if got := excerptFirstLine("   \n\t\n", 10); got != "" {
		t.Errorf("empty = %q", got)
	}
}

// TestListAnchors_PagingNewestFirst proves the service pages the built anchors newest-first with
// a stable keyset cursor (no duplicates, no gaps) and honors the ownership pre-check.
//
// TestListAnchors_PagingNewestFirst 证明 service 按最新在前分页锚点、keyset 游标稳定（零重复零漏）
// 且守归属前置校验。
func TestListAnchors_PagingNewestFirst(t *testing.T) {
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
	svc := NewService(store, Deps{Conversations: fakeConvs{conv: &conversationdomain.Conversation{}}}, zap.NewNop())
	ctx := ctxWS("ws_1")

	for i := 1; i <= 5; i++ {
		id := []string{"", "msg_1", "msg_2", "msg_3", "msg_4", "msg_5"}[i]
		m := &messagesdomain.Message{ID: id, ConversationID: "cv_1", Role: messagesdomain.RoleUser, Status: messagesdomain.StatusCompleted}
		if err := store.CreateMessage(ctx, m, []messagesdomain.Block{{Type: messagesdomain.BlockTypeText, Content: id}}); err != nil {
			t.Fatalf("create %s: %v", id, err)
		}
		if _, err := sqlDB.Exec("UPDATE messages SET created_at = ? WHERE id = ?", at(i), id); err != nil {
			t.Fatalf("pin: %v", err)
		}
	}

	var walked []string
	cursor := ""
	pages := 0
	for {
		page, next, err := svc.ListAnchors(ctx, "cv_1", cursor, 2)
		if err != nil {
			t.Fatalf("ListAnchors: %v", err)
		}
		if len(page) > 2 {
			t.Fatalf("page of %d, limit 2", len(page))
		}
		for _, a := range page {
			walked = append(walked, a.MessageID)
		}
		pages++
		if pages > 10 {
			t.Fatal("did not terminate")
		}
		if next == "" {
			break
		}
		cursor = next
	}
	want := []string{"msg_5", "msg_4", "msg_3", "msg_2", "msg_1"}
	if len(walked) != len(want) {
		t.Fatalf("walked %v, want %v", walked, want)
	}
	for i := range want {
		if walked[i] != want[i] {
			t.Fatalf("walked %v, want %v (newest-first)", walked, want)
		}
	}
	if pages != 3 {
		t.Errorf("5 anchors / page 2 → want 3 pages, got %d", pages)
	}
}
