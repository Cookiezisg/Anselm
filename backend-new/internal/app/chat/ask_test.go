package chat

import (
	"testing"

	"go.uber.org/zap"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	asktool "github.com/sunweilin/forgify/backend/internal/app/tool/ask"
	conversationdomain "github.com/sunweilin/forgify/backend/internal/domain/conversation"
	messagesdomain "github.com/sunweilin/forgify/backend/internal/domain/messages"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
)

// askToolCall scripts one step that calls ask_user with a question.
//
// askToolCall 脚本一步：调用 ask_user 提问。
func askToolCall() []llminfra.StreamEvent {
	return []llminfra.StreamEvent{
		{Type: llminfra.EventToolStart, ToolIndex: 0, ToolID: "tc1", ToolName: "ask_user"},
		{Type: llminfra.EventToolDelta, ToolIndex: 0, ArgsDelta: `{"message":"Which environment?","options":["staging","prod"]}`},
		{Type: llminfra.EventFinish, FinishReason: "tool_use", InputTokens: 5, OutputTokens: 3},
	}
}

func newAskSvc(t *testing.T, client llminfra.Client, bridge *recordBridge) (*Service, messagesdomain.Repository) {
	t.Helper()
	store := newStore(t)
	return New(store, Deps{
		Conversations: fakeConvs{conv: &conversationdomain.Conversation{SystemPrompt: "be concise"}},
		Resolver:      fakeResolver{client: client},
		Bridge:        bridge,
		Toolset:       toolapp.Toolset{Resident: []toolapp.Tool{asktool.New()}},
	}, zap.NewNop()), store
}

// toolResultUnder returns the tool_result block parented to toolCallID in a turn, or nil.
//
// toolResultUnder 返回回合里挂在 toolCallID 下的 tool_result 块，或 nil。
func toolResultUnder(m *messagesdomain.Message, toolCallID string) *messagesdomain.Block {
	for i := range m.Blocks {
		b := &m.Blocks[i]
		if b.ParentBlockID == toolCallID && b.Type == messagesdomain.BlockTypeToolResult {
			return b
		}
	}
	return nil
}

// TestAsk_ParksThenAcceptFillsAnswer: an ask_user call parks the turn (NOT executed); accepting
// fills the answer as the tool_result and drives a continuation.
//
// TestAsk_ParksThenAcceptFillsAnswer：ask_user 调用 park 回合（不执行）；accept 把答案填为 tool_result 并续跑。
func TestAsk_ParksThenAcceptFillsAnswer(t *testing.T) {
	bridge := newRecordBridge()
	client := &scriptedClient{scripts: [][]llminfra.StreamEvent{askToolCall(), textTurn()}}
	svc, store := newAskSvc(t, client, bridge)
	ctx := ctxWS("ws_1")

	asstID, err := svc.Send(ctx, "cv_1", SendInput{Content: "deploy"})
	if err != nil {
		t.Fatalf("Send: %v", err)
	}
	waitClose(t, bridge, asstID)

	parked, err := store.GetMessage(ctx, asstID)
	if err != nil || parked.Status != messagesdomain.StatusParked {
		t.Fatalf("turn should be parked, got status=%q err=%v", parked.Status, err)
	}
	if tr := toolResultUnder(parked, "tc1"); tr == nil || tr.Status != messagesdomain.StatusPending {
		t.Fatalf("ask should leave a pending tool_result, got %+v", tr)
	}

	if err := svc.ResolveInteraction(ctx, "cv_1", "tc1", ResolveAccept, "staging"); err != nil {
		t.Fatalf("ResolveInteraction accept: %v", err)
	}
	// the answer is now the tool_result content
	done, err := store.GetMessage(ctx, asstID)
	if err != nil {
		t.Fatalf("GetMessage: %v", err)
	}
	tr := toolResultUnder(done, "tc1")
	if tr == nil || tr.Status != messagesdomain.StatusCompleted || tr.Content != "staging" {
		t.Fatalf("accepted answer not recorded as tool_result: %+v", tr)
	}
	waitContinuation(t, store, ctx, "cv_1", asstID)
}

// TestAsk_Decline: declining records a "declined" tool_result (the model re-routes) and continues.
//
// TestAsk_Decline：decline 记一条「拒答」tool_result（模型改道）并续跑。
func TestAsk_Decline(t *testing.T) {
	bridge := newRecordBridge()
	client := &scriptedClient{scripts: [][]llminfra.StreamEvent{askToolCall(), textTurn()}}
	svc, store := newAskSvc(t, client, bridge)
	ctx := ctxWS("ws_1")

	asstID, _ := svc.Send(ctx, "cv_1", SendInput{Content: "deploy"})
	waitClose(t, bridge, asstID)

	if err := svc.ResolveInteraction(ctx, "cv_1", "tc1", ResolveDecline, ""); err != nil {
		t.Fatalf("ResolveInteraction decline: %v", err)
	}
	done, _ := store.GetMessage(ctx, asstID)
	tr := toolResultUnder(done, "tc1")
	if tr == nil || tr.Status != messagesdomain.StatusCompleted || tr.Content == "" {
		t.Fatalf("decline should record a non-empty tool_result, got %+v", tr)
	}
	waitContinuation(t, store, ctx, "cv_1", asstID)
}
