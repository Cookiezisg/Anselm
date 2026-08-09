package chat

import (
	"context"
	"errors"
	"testing"

	"go.uber.org/zap"

	humanloopapp "github.com/sunweilin/anselm/backend/internal/app/humanloop"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	asktool "github.com/sunweilin/anselm/backend/internal/app/tool/ask"
	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	streamdomain "github.com/sunweilin/anselm/backend/internal/domain/stream"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

// askCall scripts one step that calls ask_user (self-reported safe — it routes to the ask block,
// not the danger gate).
//
// askCall 脚本一步：调用 ask_user（自报 safe——走 ask 阻塞而非 danger 门）。
func askCall(tcID string) []llminfra.StreamEvent {
	return []llminfra.StreamEvent{
		{Type: llminfra.EventToolStart, ToolIndex: 0, ToolID: tcID, ToolName: "ask_user"},
		{Type: llminfra.EventToolDelta, ToolIndex: 0, ArgsDelta: `{"danger":"safe","message":"Which environment?","options":["staging","prod"]}`},
		{Type: llminfra.EventFinish, FinishReason: "tool_use", InputTokens: 5, OutputTokens: 3},
	}
}

func newAskSvc(t *testing.T, client llminfra.Client, bridge streamdomain.Bridge) (*Service, messagesdomain.Repository) {
	t.Helper()
	store := newStore(t)
	return NewService(store, Deps{
		Conversations: fakeConvs{conv: &conversationdomain.Conversation{SystemPrompt: "be concise", Title: "t"}},
		Resolver:      fakeResolver{client: client},
		Bridge:        bridge,
		Toolset:       toolapp.Toolset{Resident: []toolapp.Tool{asktool.New()}},
	}, zap.NewNop()), store
}

// TestAsk_AcceptReturnsAnswer: ask_user blocks for the human; accepting feeds the answer back as
// the tool_result and the turn completes.
//
// TestAsk_AcceptReturnsAnswer：ask_user 阻塞等人；accept 把答案当 tool_result 反馈、回合完成。
func TestAsk_AcceptReturnsAnswer(t *testing.T) {
	bridge := newRecordBridge()
	client := &scriptedClient{scripts: [][]llminfra.StreamEvent{askCall("tc1"), textTurn()}}
	svc, store := newAskSvc(t, client, bridge)
	ctx := ctxWS("ws_1")

	asstID, err := svc.Send(ctx, "cv_1", SendInput{Content: "deploy somewhere"})
	if err != nil {
		t.Fatalf("Send: %v", err)
	}
	pending := waitPending(t, svc, "cv_1", 1)
	if pending[0].Kind != humanloopapp.KindAsk || pending[0].Tool != "ask_user" {
		t.Fatalf("unexpected pending interaction: %+v", pending[0])
	}
	// The human may open the thread after the live SSE frames have passed. The parked assistant row
	// must already expose its tool_call through REST, otherwise the UI can only show "thinking" and
	// has no node to attach the pending interaction card to.
	parked, err := store.GetMessage(ctx, asstID)
	if err != nil {
		t.Fatalf("get parked turn: %v", err)
	}
	if parked.Status != messagesdomain.StatusStreaming || len(parked.Blocks) != 1 {
		t.Fatalf("parked ask turn should hydrate one tool_call: status=%q blocks=%d", parked.Status, len(parked.Blocks))
	}
	if parked.Blocks[0].ID != pending[0].ToolCallID ||
		parked.Blocks[0].Type != messagesdomain.BlockTypeToolCall ||
		parked.Blocks[0].Attrs["tool"] != "ask_user" {
		t.Fatalf("parked ask tool_call mismatch: %+v", parked.Blocks[0])
	}

	if err := svc.ResolveInteraction(ctx, pending[0].ConversationID, pending[0].ToolCallID, humanloopapp.DecisionAccept, "staging"); err != nil {
		t.Fatalf("ResolveInteraction: %v", err)
	}
	waitClose(t, bridge, asstID)

	got, _ := store.GetMessage(ctx, asstID)
	if got.Status != messagesdomain.StatusCompleted {
		t.Fatalf("turn should complete, got %q", got.Status)
	}
	tr := toolResultUnder(got, pending[0].ToolCallID)
	if tr == nil || tr.Content != "staging" {
		t.Fatalf("ask_user tool_result should hold the answer, got %+v", tr)
	}
	toolCalls := 0
	for _, block := range got.Blocks {
		if block.Type == messagesdomain.BlockTypeToolCall && block.ID == pending[0].ToolCallID {
			toolCalls++
		}
	}
	if toolCalls != 1 {
		t.Fatalf("parked tool_call must not be duplicated at finalize, count=%d blocks=%+v", toolCalls, got.Blocks)
	}
}

// TestAsk_Decline: declining feeds the re-route hint back as the tool_result.
//
// TestAsk_Decline：decline 把改道提示当 tool_result 反馈。
func TestAsk_Decline(t *testing.T) {
	bridge := newRecordBridge()
	client := &scriptedClient{scripts: [][]llminfra.StreamEvent{askCall("tc1"), textTurn()}}
	svc, store := newAskSvc(t, client, bridge)
	ctx := ctxWS("ws_1")

	asstID, _ := svc.Send(ctx, "cv_1", SendInput{Content: "deploy"})
	pending := waitPending(t, svc, "cv_1", 1)
	if err := svc.ResolveInteraction(ctx, pending[0].ConversationID, pending[0].ToolCallID, humanloopapp.DecisionDecline, ""); err != nil {
		t.Fatalf("ResolveInteraction: %v", err)
	}
	waitClose(t, bridge, asstID)

	got, _ := store.GetMessage(ctx, asstID)
	tr := toolResultUnder(got, pending[0].ToolCallID)
	if tr == nil || tr.Content != humanloopapp.DeclineFeedback {
		t.Fatalf("decline should feed the re-route hint, got %+v", tr)
	}
}

// TestResolveInteraction_ConversationScoped prevents a tool-call id from one conversation being
// resolved through another conversation's URL. The broker is app-global, so this binding belongs
// at the chat service boundary rather than in the HTTP handler.
//
// TestResolveInteraction_ConversationScoped 防止一个对话的 tool-call id 通过另一个对话的 URL 被决议。
// broker 是 app-global，因此归属绑定必须在 chat service 边界完成，而不是只靠 HTTP handler。
func TestResolveInteraction_ConversationScoped(t *testing.T) {
	bridge := newRecordBridge()
	client := &scriptedClient{scripts: [][]llminfra.StreamEvent{askCall("tc-scoped"), textTurn()}}
	svc, _ := newAskSvc(t, client, bridge)
	ctx := ctxWS("ws_1")

	asstID, err := svc.Send(ctx, "cv_1", SendInput{Content: "choose"})
	if err != nil {
		t.Fatalf("Send: %v", err)
	}
	pending := waitPending(t, svc, "cv_1", 1)

	if err := svc.ResolveInteraction(ctx, "cv_other", pending[0].ToolCallID, humanloopapp.DecisionAccept, "staging"); !errors.Is(err, ErrNoPendingInteraction) {
		t.Fatalf("cross-conversation resolve = %v, want NO_PENDING_INTERACTION", err)
	}
	if got := len(svc.PendingInteractions(ctx, "cv_1")); got != 1 {
		t.Fatalf("cross-conversation resolve consumed pending interaction: count=%d", got)
	}

	svc.deps.Conversations = fakeConvs{
		conv: &conversationdomain.Conversation{SystemPrompt: "be concise", Title: "t"},
		getErr: func(_ context.Context, id string) error {
			if id == "cv_wrong_workspace" {
				return conversationdomain.ErrNotFound
			}
			return nil
		},
	}
	if err := svc.ResolveInteraction(ctx, "cv_wrong_workspace", pending[0].ToolCallID, humanloopapp.DecisionAccept, "staging"); !errors.Is(err, conversationdomain.ErrNotFound) {
		t.Fatalf("foreign-workspace resolve = %v, want CONVERSATION_NOT_FOUND", err)
	}
	if got := len(svc.PendingInteractions(ctx, "cv_1")); got != 1 {
		t.Fatalf("foreign-workspace resolve consumed pending interaction: count=%d", got)
	}

	if err := svc.ResolveInteraction(ctx, "cv_1", pending[0].ToolCallID, humanloopapp.DecisionAccept, "staging"); err != nil {
		t.Fatalf("same-conversation resolve: %v", err)
	}
	waitClose(t, bridge, asstID)
}

// toolResultUnder finds the tool_result block whose parent is the given tool_call id.
//
// toolResultUnder 找父为给定 tool_call id 的 tool_result 块。
func toolResultUnder(m *messagesdomain.Message, toolCallID string) *messagesdomain.Block {
	for i := range m.Blocks {
		b := &m.Blocks[i]
		if b.ParentBlockID == toolCallID && b.Type == messagesdomain.BlockTypeToolResult {
			return b
		}
	}
	return nil
}
