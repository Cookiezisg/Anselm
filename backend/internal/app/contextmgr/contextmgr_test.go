package contextmgr

import (
	"context"
	"fmt"
	"iter"
	"slices"
	"strings"
	"testing"

	"go.uber.org/zap"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

// --- fakes -----------------------------------------------------------------

type roleUpdate struct {
	ids  []string
	role string
}

type fakeMessages struct {
	thread       []*messagesdomain.Message
	roleUpdates  []roleUpdate
	created      []*messagesdomain.Message
	createdBlock []messagesdomain.Block
}

func (f *fakeMessages) LoadThread(context.Context, string) ([]*messagesdomain.Message, error) {
	return f.thread, nil
}

// contextmgr only uses LoadThread (full content); LoadThreadForLLM is here for interface conformance.
func (f *fakeMessages) LoadThreadForLLM(context.Context, string, int64) ([]*messagesdomain.Message, error) {
	return f.thread, nil
}

func (f *fakeMessages) UpdateBlocksContextRole(_ context.Context, ids []string, role string) error {
	if len(ids) > 0 {
		f.roleUpdates = append(f.roleUpdates, roleUpdate{ids: ids, role: role})
	}
	return nil
}

func (f *fakeMessages) CreateMessage(_ context.Context, m *messagesdomain.Message, blocks []messagesdomain.Block) error {
	f.created = append(f.created, m)
	f.createdBlock = append(f.createdBlock, blocks...)
	return nil
}
func (f *fakeMessages) FinalizeMessage(context.Context, *messagesdomain.Message, []messagesdomain.Block) error {
	return nil
}
func (f *fakeMessages) GetMessage(context.Context, string) (*messagesdomain.Message, error) {
	return nil, nil
}
func (f *fakeMessages) MarkSuperseded(context.Context, string, string) error { return nil }
func (f *fakeMessages) ListMessages(context.Context, string, string, int) ([]*messagesdomain.Message, string, error) {
	return nil, "", nil
}
func (f *fakeMessages) ListMessagesNewer(context.Context, string, string, int) ([]*messagesdomain.Message, string, error) {
	return nil, "", nil
}
func (f *fakeMessages) ListMessagesAround(context.Context, string, string, int) ([]*messagesdomain.Message, string, string, bool, bool, error) {
	return nil, "", "", false, false, nil
}
func (f *fakeMessages) ListAnchorSource(context.Context, string) ([]*messagesdomain.Message, []*messagesdomain.Block, error) {
	return nil, nil, nil
}
func (f *fakeMessages) SumTokens(context.Context, string) (int, int, error) { return 0, 0, nil }

func (f *fakeMessages) idsForRole(role string) []string {
	var out []string
	for _, u := range f.roleUpdates {
		if u.role == role {
			out = append(out, u.ids...)
		}
	}
	return out
}

type fakeConv struct {
	summary         string
	watermark       int64
	setCalls        int
	panicAfterWrite bool
}

func (f *fakeConv) GetSummary(context.Context, string) (string, int64, error) {
	return f.summary, f.watermark, nil
}
func (f *fakeConv) SetSummary(_ context.Context, _, summary string, coversUpToSeq int64) error {
	f.summary, f.watermark = summary, coversUpToSeq
	f.setCalls++
	if f.panicAfterWrite {
		panic("simulated crash after durable summary write")
	}
	return nil
}

type fakeClient struct {
	out     string
	lastReq llminfra.Request
}

func (c *fakeClient) Stream(_ context.Context, req llminfra.Request) iter.Seq[llminfra.StreamEvent] {
	c.lastReq = req
	return func(yield func(llminfra.StreamEvent) bool) {
		_ = yield(llminfra.StreamEvent{Type: llminfra.EventText, Delta: c.out}) &&
			yield(llminfra.StreamEvent{Type: llminfra.EventFinish, FinishReason: "stop"})
	}
}

type fakeResolver struct{ client *fakeClient }

func (r fakeResolver) ResolveUtility(context.Context) (Bundle, error) {
	return Bundle{Client: r.client, Request: llminfra.Request{ModelID: "utility"}}, nil
}

type fakeWindow struct{ window, maxOutput int }

func (w fakeWindow) ContextBudget(context.Context, string, string) (int, int) {
	return w.window, w.maxOutput
}

// --- builders --------------------------------------------------------------

func trTurn(id string, seq int64, tokens int, content string) *messagesdomain.Message {
	return &messagesdomain.Message{
		ID: id, ConversationID: "cv", Role: messagesdomain.RoleAssistant,
		InputTokens: tokens, Provider: "p", ModelID: "m",
		Attrs: map[string]any{"contextUsage": map[string]any{
			"lastPromptInputTokens": tokens,
		}},
		Blocks: []messagesdomain.Block{{
			ID: id + "_tr", Seq: seq, Type: messagesdomain.BlockTypeToolResult,
			Content: content, ContextRole: messagesdomain.ContextRoleHot,
			Attrs: map[string]any{"tool": "Read"},
		}},
	}
}

func newSvc(msgs *fakeMessages, conv *fakeConv, win fakeWindow, client *fakeClient) *Service {
	return NewService(Deps{
		Messages:      msgs,
		Conversations: conv,
		Resolver:      fakeResolver{client: client},
		Windows:       win,
	}, zap.NewNop())
}

// --- tests -----------------------------------------------------------------

func TestMaybeCompact_UnderThreshold(t *testing.T) {
	msgs := &fakeMessages{thread: []*messagesdomain.Message{trTurn("m1", 1, 1000, "small")}}
	conv := &fakeConv{}
	svc := newSvc(msgs, conv, fakeWindow{window: 200000, maxOutput: 8000}, &fakeClient{out: "X"})

	if err := svc.MaybeCompact(context.Background(), "cv"); err != nil {
		t.Fatalf("MaybeCompact: %v", err)
	}
	if conv.setCalls != 0 || len(msgs.roleUpdates) != 0 || len(msgs.created) != 0 {
		t.Fatalf("under threshold must be a no-op: setCalls=%d updates=%d created=%d", conv.setCalls, len(msgs.roleUpdates), len(msgs.created))
	}
}

func TestMaybeCompact_IgnoresAggregateRunTokens(t *testing.T) {
	turn := trTurn("m1", 1, 1_000, "small")
	turn.InputTokens = 900_000 // aggregate cost across many ReAct requests
	turn.Attrs["contextUsage"].(map[string]any)["lastPromptInputTokens"] = 1_000
	msgs := &fakeMessages{thread: []*messagesdomain.Message{turn}}
	conv := &fakeConv{}
	svc := newSvc(msgs, conv, fakeWindow{window: 100_000}, &fakeClient{out: "X"})

	if err := svc.MaybeCompact(context.Background(), "cv"); err != nil {
		t.Fatal(err)
	}
	if conv.setCalls != 0 || len(msgs.roleUpdates) != 0 {
		t.Fatalf("aggregate run cost triggered compaction: sets=%d roles=%v", conv.setCalls, msgs.roleUpdates)
	}
}

func TestMaybeCompact_UnknownWindow(t *testing.T) {
	msgs := &fakeMessages{thread: []*messagesdomain.Message{trTurn("m1", 1, 999999, "huge")}}
	conv := &fakeConv{}
	svc := newSvc(msgs, conv, fakeWindow{window: 0, maxOutput: 0}, &fakeClient{out: "X"})

	if err := svc.MaybeCompact(context.Background(), "cv"); err != nil {
		t.Fatalf("MaybeCompact: %v", err)
	}
	if conv.setCalls != 0 || len(msgs.roleUpdates) != 0 {
		t.Fatal("unknown window must skip compaction (don't compact blind)")
	}
}

// TestMaybeCompact_TwoLongMessagesHonorDurableRecentFloor proves persistent compaction never crosses
// the two-message verbatim floor, even when both messages are far above the trigger estimate. The
// loop-level prompt checkpoint remains a separate, in-memory projection escape hatch.
//
// TestMaybeCompact_TwoLongMessagesHonorDurableRecentFloor 证明持久化压缩即使两条 message 都远超触发估算，也绝不
// 越过最近两条逐字底线。loop 层的 prompt checkpoint 仍是独立的内存投影出口。
func TestMaybeCompact_TwoLongMessagesHonorDurableRecentFloor(t *testing.T) {
	thread := []*messagesdomain.Message{
		trTurn("only-a", 1, 100, strings.Repeat("old durable A ", 500)),
		trTurn("only-b", 2, 100, strings.Repeat("old durable B ", 500)),
	}
	msgs := &fakeMessages{thread: thread}
	conv := &fakeConv{}
	client := &fakeClient{out: "must not be called"}
	svc := newSvc(msgs, conv, fakeWindow{window: 100}, client)

	if err := svc.MaybeCompact(context.Background(), "cv"); err != nil {
		t.Fatalf("MaybeCompact: %v", err)
	}
	if conv.setCalls != 0 || len(msgs.roleUpdates) != 0 || len(msgs.created) != 0 {
		t.Fatalf("two-message durable floor must block persistent compaction: set=%d updates=%d anchors=%d",
			conv.setCalls, len(msgs.roleUpdates), len(msgs.created))
	}
	for _, m := range thread {
		if m.Blocks[0].ContextRole != messagesdomain.ContextRoleHot {
			t.Fatalf("durable recent message %s was demoted: %q", m.ID, m.Blocks[0].ContextRole)
		}
	}
}

func TestDemote_Tiering(t *testing.T) {
	// Newest-first over all 20 tool results: ranks 1-4 hot, 5-12 warm,
	// 13-20 cold. Recency protects complete tool activity even when it all lives
	// inside one newest assistant turn.
	var thread []*messagesdomain.Message
	for i := range 20 {
		thread = append(thread, trTurn("m"+string(rune('a'+i)), int64(i+1), 100, "tool output"))
	}
	msgs := &fakeMessages{thread: thread}
	svc := newSvc(msgs, &fakeConv{}, fakeWindow{}, &fakeClient{})

	svc.demote(context.Background(), thread, len(thread)-recentTurns)

	warm := msgs.idsForRole(messagesdomain.ContextRoleWarm)
	cold := msgs.idsForRole(messagesdomain.ContextRoleCold)
	if len(warm) != warmZone {
		t.Fatalf("want %d warm, got %d", warmZone, len(warm))
	}
	if len(cold) != 20-recentTRHot-warmZone {
		t.Fatalf("want %d cold, got %d", 20-recentTRHot-warmZone, len(cold))
	}
	// The 4 most-recent tool results remain hot.
	for _, m := range thread[len(thread)-recentTRHot:] {
		if m.Blocks[0].ContextRole != messagesdomain.ContextRoleHot {
			t.Fatalf("protected recent turn demoted: %s = %s", m.ID, m.Blocks[0].ContextRole)
		}
	}
	// The very oldest block is cold.
	if thread[0].Blocks[0].ContextRole != messagesdomain.ContextRoleCold {
		t.Fatalf("oldest block should be cold, got %s", thread[0].Blocks[0].ContextRole)
	}
}

// TestDemote_OnlyAgesToolResultsInsideLongMixedTurns proves the first compaction step is scoped
// to tool_result blocks even when one assistant message contains a long tool chain. User prose,
// a large paste, and assistant explanation text must remain verbatim and hot.
//
// TestDemote_OnlyAgesToolResultsInsideLongMixedTurns 证明第一步压缩即使面对单个 assistant 的长工具链，也只处理
// tool_result block。用户原话、大粘贴和 assistant 解释正文必须逐字保留且仍为 hot。
func TestDemote_OnlyAgesToolResultsInsideLongMixedTurns(t *testing.T) {
	largePaste := strings.Repeat("USER PASTE ", 500)
	user := &messagesdomain.Message{
		ID: "user_paste", ConversationID: "cv", Role: messagesdomain.RoleUser,
		Blocks: []messagesdomain.Block{{
			ID: "user_paste_block", Seq: 1, Type: messagesdomain.BlockTypeText,
			Content: largePaste, ContextRole: messagesdomain.ContextRoleHot,
		}},
	}
	assistant := &messagesdomain.Message{
		ID: "assistant_chain", ConversationID: "cv", Role: messagesdomain.RoleAssistant,
		Blocks: []messagesdomain.Block{{
			ID: "assistant_explanation", Seq: 2, Type: messagesdomain.BlockTypeText,
			Content: "assistant explanation", ContextRole: messagesdomain.ContextRoleHot,
		}},
	}
	for i := 0; i < 16; i++ {
		assistant.Blocks = append(assistant.Blocks, messagesdomain.Block{
			ID: fmt.Sprintf("tool_result_%02d", i), Seq: int64(3 + i),
			Type: messagesdomain.BlockTypeToolResult, Content: fmt.Sprintf("tool output %02d", i),
			ContextRole: messagesdomain.ContextRoleHot,
		})
	}
	recent := &messagesdomain.Message{
		ID: "recent", ConversationID: "cv", Role: messagesdomain.RoleUser,
		Blocks: []messagesdomain.Block{{ID: "recent_block", Seq: 30, Type: messagesdomain.BlockTypeText, Content: "recent"}},
	}
	thread := []*messagesdomain.Message{user, assistant, recent}
	msgs := &fakeMessages{thread: thread}
	svc := newSvc(msgs, &fakeConv{}, fakeWindow{}, &fakeClient{})
	svc.demote(context.Background(), thread, len(thread)-1)

	if user.Blocks[0].ContextRole != messagesdomain.ContextRoleHot || user.Blocks[0].Content != largePaste {
		t.Fatal("user original/paste was changed by demote")
	}
	if assistant.Blocks[0].ContextRole != messagesdomain.ContextRoleHot || assistant.Blocks[0].Content != "assistant explanation" {
		t.Fatal("assistant explanation text was changed by demote")
	}
	for i, b := range assistant.Blocks[1:] {
		want := messagesdomain.ContextRoleCold
		switch {
		case i >= 12:
			want = messagesdomain.ContextRoleHot
		case i >= 4:
			want = messagesdomain.ContextRoleWarm
		}
		if b.ContextRole != want {
			t.Errorf("tool result %d role=%q, want %q", i, b.ContextRole, want)
		}
	}
	for _, update := range msgs.roleUpdates {
		for _, id := range update.ids {
			if id == user.Blocks[0].ID || id == assistant.Blocks[0].ID {
				t.Fatalf("non-tool block %q entered context-role update", id)
			}
		}
	}
}

func TestSummarize_FoldsAndArchives(t *testing.T) {
	// A tool_call + tool_result pair in one old turn (atomic archive), past the watermark.
	old := &messagesdomain.Message{
		ID: "m1", ConversationID: "cv", Role: messagesdomain.RoleAssistant,
		Blocks: []messagesdomain.Block{
			{ID: "b1", Seq: 1, Type: messagesdomain.BlockTypeToolCall, Content: `{"path":"x"}`, ContextRole: messagesdomain.ContextRoleHot, Attrs: map[string]any{"tool": "Read"}},
			{ID: "b2", Seq: 2, Type: messagesdomain.BlockTypeToolResult, Content: "file contents here", ContextRole: messagesdomain.ContextRoleHot},
		},
	}
	// Recent protected turns (won't be summarized).
	var thread []*messagesdomain.Message
	thread = append(thread, old)
	for i := range recentTurns {
		thread = append(thread, trTurn("r"+string(rune('a'+i)), int64(10+i), 100, "recent"))
	}
	msgs := &fakeMessages{thread: thread}
	conv := &fakeConv{summary: "OLD SUMMARY", watermark: 0}
	client := &fakeClient{out: "NEW SUMMARY"}
	svc := newSvc(msgs, conv, fakeWindow{}, client)

	if err := svc.summarize(context.Background(), "cv", thread, len(thread)-recentTurns, conv.summary, conv.watermark); err != nil {
		t.Fatalf("summarize: %v", err)
	}

	if conv.summary != "NEW SUMMARY" || conv.watermark != 2 {
		t.Fatalf("summary/watermark wrong: %q / %d", conv.summary, conv.watermark)
	}
	// Both blocks of the old turn archived together (atomic tool_call+tool_result).
	archived := msgs.idsForRole(messagesdomain.ContextRoleArchived)
	if len(archived) != 2 || !contains(archived, "b1") || !contains(archived, "b2") {
		t.Fatalf("both old blocks must archive atomically, got %v", archived)
	}
	// Prompt fed the old summary + the new content.
	prompt := client.lastReq.Messages[0].Content
	if !strings.Contains(prompt, "OLD SUMMARY") || !strings.Contains(prompt, "file contents here") {
		t.Fatalf("summary prompt missing prior summary or new content: %q", prompt)
	}
	// A compaction anchor was dropped.
	if len(msgs.created) != 1 || len(msgs.createdBlock) != 1 || msgs.createdBlock[0].Type != messagesdomain.BlockTypeCompaction {
		t.Fatalf("expected one compaction anchor block, got %d msgs / %d blocks", len(msgs.created), len(msgs.createdBlock))
	}
}

func TestMaybeCompact_OldAttachmentForcesTraceableSummary(t *testing.T) {
	// Native media is not a byte-for-token input. Even with a tiny text estimate, the old turn
	// must cross the watermark so a future agent gets a durable attachment reference instead of
	// silently replaying unbounded media forever.
	//
	// 原生媒体不是字节/token 输入。即使文本估算很小，旧回合也必须跨过水位线，使后续 agent 得到可追溯
	// 的附件引用，而非永远静默重放无界媒体。
	old := &messagesdomain.Message{
		ID: "u_old", ConversationID: "cv", Role: messagesdomain.RoleUser,
		Attrs: map[string]any{attachmentsAttr: []any{"att_video_1"}},
		Blocks: []messagesdomain.Block{{
			ID: "u_old_text", Seq: 1, Type: messagesdomain.BlockTypeText,
			ContextRole: messagesdomain.ContextRoleHot,
		}},
	}
	thread := []*messagesdomain.Message{old}
	for i := range recentTurns {
		thread = append(thread, trTurn("recent"+string(rune('a'+i)), int64(10+i), 80, "recent"))
	}
	msgs := &fakeMessages{thread: thread}
	conv := &fakeConv{}
	client := &fakeClient{out: "summary with attachment reference"}
	svc := newSvc(msgs, conv, fakeWindow{window: 100}, client)

	if err := svc.MaybeCompact(context.Background(), "cv"); err != nil {
		t.Fatalf("MaybeCompact: %v", err)
	}
	if conv.setCalls != 1 || conv.watermark != 1 {
		t.Fatalf("attachment turn must be summarized once through seq 1, calls=%d watermark=%d", conv.setCalls, conv.watermark)
	}
	if !strings.Contains(client.lastReq.Messages[0].Content, "att_video_1") {
		t.Fatalf("summary prompt lost durable attachment reference: %q", client.lastReq.Messages[0].Content)
	}
	if archived := msgs.idsForRole(messagesdomain.ContextRoleArchived); !slices.Contains(archived, "u_old_text") {
		t.Fatalf("attachment turn block must be archived after summary, got %v", archived)
	}
}

func TestSummarize_NothingPastWatermark(t *testing.T) {
	// Old turn already covered by the watermark → nothing to summarize.
	old := trTurn("m1", 1, 100, "already covered")
	var thread []*messagesdomain.Message
	thread = append(thread, old)
	for i := range recentTurns {
		thread = append(thread, trTurn("r"+string(rune('a'+i)), int64(10+i), 100, "recent"))
	}
	msgs := &fakeMessages{thread: thread}
	conv := &fakeConv{summary: "S", watermark: 5} // watermark already past seq 1
	svc := newSvc(msgs, conv, fakeWindow{}, &fakeClient{out: "X"})

	if err := svc.summarize(context.Background(), "cv", thread, len(thread)-recentTurns, conv.summary, conv.watermark); err != nil {
		t.Fatalf("summarize: %v", err)
	}
	if conv.setCalls != 0 || len(msgs.created) != 0 {
		t.Fatal("nothing past the watermark → no summary write, no anchor")
	}
}

// TestSummarize_WatermarkMakesCrashBetweenWritesIdempotent simulates a process dying immediately
// after SetSummary commits but before the archive flag and anchor are written. A fresh service run
// must treat the new watermark as truth, skip the already-covered blocks, and avoid a second summary
// write even though the old blocks still look hot in the in-memory fixture.
//
// TestSummarize_WatermarkMakesCrashBetweenWritesIdempotent 模拟 SetSummary 提交后、archive 标记与锚写入前进程
// 崩溃。新 service 重跑必须把新水位当真相，跳过已覆盖 block；即使 fixture 里的旧 block 还显示 hot，也不得
// 第二次写 summary。
func TestSummarize_WatermarkMakesCrashBetweenWritesIdempotent(t *testing.T) {
	old := &messagesdomain.Message{
		ID: "m_crash", ConversationID: "cv", Role: messagesdomain.RoleAssistant,
		Blocks: []messagesdomain.Block{{
			ID: "b_crash", Seq: 1, Type: messagesdomain.BlockTypeText,
			Content: "old content", ContextRole: messagesdomain.ContextRoleHot,
		}},
	}
	thread := []*messagesdomain.Message{old, trTurn("recent-a", 10, 100, "recent a"), trTurn("recent-b", 11, 100, "recent b")}
	msgs := &fakeMessages{thread: thread}
	conv := &fakeConv{panicAfterWrite: true}
	client := &fakeClient{out: "summary once"}
	first := newSvc(msgs, conv, fakeWindow{}, client)

	func() {
		defer func() {
			if recover() == nil {
				t.Fatal("expected the simulated crash after SetSummary")
			}
		}()
		if err := first.summarize(context.Background(), "cv", thread, len(thread)-recentTurns, conv.summary, conv.watermark); err != nil {
			t.Fatalf("first summarize: %v", err)
		}
	}()
	if conv.setCalls != 1 || conv.watermark != 1 || conv.summary != "summary once" {
		t.Fatalf("durable summary write was not the crash boundary: calls=%d watermark=%d summary=%q",
			conv.setCalls, conv.watermark, conv.summary)
	}
	if len(msgs.roleUpdates) != 0 || len(msgs.created) != 0 {
		t.Fatalf("crash must precede archive/anchor writes: updates=%d anchors=%d", len(msgs.roleUpdates), len(msgs.created))
	}

	conv.panicAfterWrite = false
	second := newSvc(msgs, conv, fakeWindow{}, client)
	if err := second.summarize(context.Background(), "cv", thread, len(thread)-recentTurns, conv.summary, conv.watermark); err != nil {
		t.Fatalf("recovery summarize: %v", err)
	}
	if conv.setCalls != 1 || conv.watermark != 1 || conv.summary != "summary once" {
		t.Fatalf("watermark must prevent a second fold: calls=%d watermark=%d summary=%q",
			conv.setCalls, conv.watermark, conv.summary)
	}
	if len(msgs.roleUpdates) != 0 || len(msgs.created) != 0 {
		t.Fatalf("recovery must not duplicate archive/anchor work: updates=%d anchors=%d", len(msgs.roleUpdates), len(msgs.created))
	}
}

// TestMaybeCompact_DropsSupersededVersionsBeforeSummary proves the compaction read uses the same
// current-version projection as the LLM. If the old answer entered the summary prompt, it would be
// re-injected into every later request because a summary cannot filter prose back out.
//
// TestMaybeCompact_DropsSupersededVersionsBeforeSummary 证明压缩读与 LLM 使用同一现行版本投影。若旧回答进入摘要
// prompt，它会回流到此后每次请求，因为摘要无法再把那段文字过滤出去。
func TestMaybeCompact_DropsSupersededVersionsBeforeSummary(t *testing.T) {
	old := &messagesdomain.Message{
		ID: "m_old_answer", ConversationID: "cv", Role: messagesdomain.RoleAssistant,
		SupersededBy: "m_current_answer",
		Blocks: []messagesdomain.Block{{
			ID: "b_old_answer", Seq: 1, Type: messagesdomain.BlockTypeText,
			Content: "OLD ANSWER MUST NEVER RETURN",
		}},
	}
	current := &messagesdomain.Message{
		ID: "m_current_answer", ConversationID: "cv", Role: messagesdomain.RoleAssistant,
		Attrs: map[string]any{"contextUsage": map[string]any{
			"lastPromptInputTokens": 100,
		}},
		Blocks: []messagesdomain.Block{{
			ID: "b_current_answer", Seq: 2, Type: messagesdomain.BlockTypeText,
			Content: strings.Repeat("CURRENT ANSWER ", 100),
		}},
	}
	thread := []*messagesdomain.Message{old, current,
		trTurn("recent-a", 10, 100, "recent a"),
		trTurn("recent-b", 11, 100, "recent b"),
	}
	msgs := &fakeMessages{thread: thread}
	conv := &fakeConv{}
	client := &fakeClient{out: "summary without superseded prose"}
	svc := newSvc(msgs, conv, fakeWindow{window: 100}, client)

	if err := svc.MaybeCompact(context.Background(), "cv"); err != nil {
		t.Fatalf("MaybeCompact: %v", err)
	}
	if conv.setCalls != 1 || conv.watermark != 2 {
		t.Fatalf("current answer should be compacted once through seq 2, calls=%d watermark=%d", conv.setCalls, conv.watermark)
	}
	prompt := client.lastReq.Messages[0].Content
	if strings.Contains(prompt, "OLD ANSWER MUST NEVER RETURN") {
		t.Fatalf("superseded answer leaked into compaction prompt: %q", prompt)
	}
	if !strings.Contains(prompt, "CURRENT ANSWER") {
		t.Fatalf("current answer missing from compaction prompt: %q", prompt)
	}
}

func TestCompactPrompt_StructuredCheckpointKeepsRecentProtocol(t *testing.T) {
	history := []llminfra.LLMMessage{
		{Role: llminfra.RoleUser, Content: "fix /exact/path and preserve wf_123"},
	}
	for i := 0; i < 4; i++ {
		id := "call_" + string(rune('a'+i))
		history = append(history,
			llminfra.LLMMessage{
				Role: llminfra.RoleAssistant, ReasoningContent: "complete reasoning " + id,
				ToolCalls: []llminfra.LLMToolCall{{ID: id, Name: "inspect", Arguments: `{"id":"wf_123"}`}},
			},
			llminfra.LLMMessage{Role: llminfra.RoleTool, ToolCallID: id, Content: "result " + id},
		)
	}
	client := &fakeClient{out: "Goal & constraints: fix /exact/path.\nExact references: wf_123.\nOpen work/next action: continue."}
	svc := newSvc(&fakeMessages{}, &fakeConv{}, fakeWindow{}, client)

	got, err := svc.CompactPrompt(context.Background(), history, 10_000)
	if err != nil {
		t.Fatal(err)
	}
	if len(got) >= len(history) || got[0].Role != llminfra.RoleUser ||
		!strings.Contains(got[0].Content, "/exact/path") || !strings.Contains(got[0].Content, "wf_123") {
		t.Fatalf("bad checkpoint: %+v", got)
	}
	if got[1].Role != llminfra.RoleAssistant || got[1].ReasoningContent == "" || len(got[1].ToolCalls) == 0 {
		t.Fatalf("recent complete reasoning/tool group was not retained: %+v", got[1])
	}
	if !strings.Contains(client.lastReq.Messages[0].Content, "/exact/path") ||
		!strings.Contains(client.lastReq.Messages[0].Content, "wf_123") {
		t.Fatalf("summarizer input lost exact references: %q", client.lastReq.Messages[0].Content)
	}
}

func contains(ss []string, s string) bool { return slices.Contains(ss, s) }

func (f *fakeMessages) SweepNonTerminal(context.Context) (int, error) { return 0, nil }
