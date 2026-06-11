package contextmgr

import (
	"context"
	"iter"
	"slices"
	"strings"
	"testing"

	"go.uber.org/zap"

	messagesdomain "github.com/sunweilin/forgify/backend/internal/domain/messages"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
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
func (f *fakeMessages) ListMessages(context.Context, string, string, int) ([]*messagesdomain.Message, string, error) {
	return nil, "", nil
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
	summary   string
	watermark int64
	setCalls  int
}

func (f *fakeConv) GetSummary(context.Context, string) (string, int64, error) {
	return f.summary, f.watermark, nil
}
func (f *fakeConv) SetSummary(_ context.Context, _, summary string, coversUpToSeq int64) error {
	f.summary, f.watermark = summary, coversUpToSeq
	f.setCalls++
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
		Blocks: []messagesdomain.Block{{
			ID: id + "_tr", Seq: seq, Type: messagesdomain.BlockTypeToolResult,
			Content: content, ContextRole: messagesdomain.ContextRoleHot,
			Attrs: map[string]any{"tool": "Read"},
		}},
	}
}

func newSvc(msgs *fakeMessages, conv *fakeConv, win fakeWindow, client *fakeClient) *Service {
	return New(Deps{
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

func TestDemote_Tiering(t *testing.T) {
	// 16 old tool_result turns + 4 recent (protected). Newest-first over the 16: ranks 1-4 hot,
	// 5-12 warm, 13-16 cold. Protected recent 4 stay hot (untouched).
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
	if len(cold) != 16-recentTRHot-warmZone {
		t.Fatalf("want %d cold, got %d", 16-recentTRHot-warmZone, len(cold))
	}
	// The 4 most-recent turns are protected: their blocks must remain hot.
	for _, m := range thread[len(thread)-recentTurns:] {
		if m.Blocks[0].ContextRole != messagesdomain.ContextRoleHot {
			t.Fatalf("protected recent turn demoted: %s = %s", m.ID, m.Blocks[0].ContextRole)
		}
	}
	// The very oldest block is cold.
	if thread[0].Blocks[0].ContextRole != messagesdomain.ContextRoleCold {
		t.Fatalf("oldest block should be cold, got %s", thread[0].Blocks[0].ContextRole)
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

func contains(ss []string, s string) bool { return slices.Contains(ss, s) }
