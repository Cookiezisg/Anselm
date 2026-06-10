package chat

import (
	"context"
	"encoding/json"
	"testing"

	"go.uber.org/zap"

	loopapp "github.com/sunweilin/forgify/backend/internal/app/loop"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	conversationdomain "github.com/sunweilin/forgify/backend/internal/domain/conversation"
	messagesdomain "github.com/sunweilin/forgify/backend/internal/domain/messages"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
)

// parkingInvokeAgent is a fake invoke_agent tool whose sub-run "parks": its Execute returns a
// ParkSignal, so the chat loop parks the turn (nested HITL propagation, R0064).
//
// parkingInvokeAgent 是 fake invoke_agent 工具，其子运行「park」：Execute 返 ParkSignal，使 chat loop park 回合
// （嵌套人在环传播，R0064）。
type parkingInvokeAgent struct{}

func (parkingInvokeAgent) Name() string                        { return "invoke_agent" }
func (parkingInvokeAgent) Description() string                 { return "run an agent" }
func (parkingInvokeAgent) Parameters() json.RawMessage         { return json.RawMessage(`{"type":"object"}`) }
func (parkingInvokeAgent) ValidateInput(json.RawMessage) error { return nil }
func (parkingInvokeAgent) Execute(context.Context, string) (string, error) {
	return "", loopapp.NewParkSignal("agx_1", []loopapp.ParkRequest{
		{ToolCallID: "leaf1", Kind: loopapp.ParkKindDanger, ToolName: "delete"},
	})
}

// fakeResumer is a chat.AgentResumer that records the resume + returns a scripted outcome.
//
// fakeResumer 是记录恢复 + 返回脚本结果的 chat.AgentResumer。
type fakeResumer struct {
	called  *bool
	gotLeaf *string
	parked  bool
	output  string
}

func (r fakeResumer) ResumeExecution(_ context.Context, _, leafToolCallID, _, _ string) (bool, string, error) {
	*r.called = true
	*r.gotLeaf = leafToolCallID
	return r.parked, r.output, nil
}

func invokeAgentCall() []llminfra.StreamEvent {
	return []llminfra.StreamEvent{
		{Type: llminfra.EventToolStart, ToolIndex: 0, ToolID: "tc_agent", ToolName: "invoke_agent"},
		{Type: llminfra.EventToolDelta, ToolIndex: 0, ArgsDelta: `{"agentId":"ag_x"}`},
		{Type: llminfra.EventFinish, FinishReason: "tool_use", InputTokens: 5, OutputTokens: 3},
	}
}

func newNestedSvc(t *testing.T, client llminfra.Client, bridge *recordBridge, resumer AgentResumer) (*Service, messagesdomain.Repository) {
	t.Helper()
	store := newStore(t)
	return New(store, Deps{
		Conversations: fakeConvs{conv: &conversationdomain.Conversation{SystemPrompt: "be concise"}},
		Resolver:      fakeResolver{client: client},
		Bridge:        bridge,
		Toolset:       toolapp.Toolset{Resident: []toolapp.Tool{parkingInvokeAgent{}}},
		AgentResumer:  resumer,
	}, zap.NewNop()), store
}

// TestNested_InvokeAgentParksThenResolves: a chat LLM delegating to a sub-agent that parks makes
// the chat turn park (the invoke_agent pending references the sub-execution); resolving threads
// down to the sub-agent, and on its completion the invoke_agent tool_result is filled with the
// sub-agent's output and the chat continues.
//
// TestNested_InvokeAgentParksThenResolves：chat LLM 委托的子 agent park 使 chat 回合 park（invoke_agent pending
// 引用子 execution）；决议向下穿到子 agent，其完成时 invoke_agent tool_result 填子 agent 输出、chat 续跑。
func TestNested_InvokeAgentParksThenResolves(t *testing.T) {
	bridge := newRecordBridge()
	called := false
	var gotLeaf string
	client := &scriptedClient{scripts: [][]llminfra.StreamEvent{invokeAgentCall(), textTurn()}}
	svc, store := newNestedSvc(t, client, bridge, fakeResumer{
		called: &called, gotLeaf: &gotLeaf, parked: false, output: "sub-agent shipped it",
	})
	ctx := ctxWS("ws_1")

	asstID, err := svc.Send(ctx, "cv_1", SendInput{Content: "delegate the deploy"})
	if err != nil {
		t.Fatalf("Send: %v", err)
	}
	waitClose(t, bridge, asstID)

	parked, err := store.GetMessage(ctx, asstID)
	if err != nil || parked.Status != messagesdomain.StatusParked {
		t.Fatalf("chat turn should park on the sub-agent park, got status=%q err=%v", parked.Status, err)
	}
	tr := toolResultUnder(parked, "tc_agent")
	if tr == nil || tr.Status != messagesdomain.StatusPending {
		t.Fatalf("expected a pending invoke_agent tool_result, got %+v", tr)
	}
	if tr.Attrs["park"] != loopapp.ParkKindAgent || tr.Attrs["agentExecutionId"] != "agx_1" {
		t.Fatalf("pending should reference the parked sub-execution, attrs=%+v", tr.Attrs)
	}

	// resolve (approve) → threads down to the sub-agent, which completes
	if err := svc.ResolveInteraction(ctx, "cv_1", "tc_agent", ResolveApprove, "", "leaf1"); err != nil {
		t.Fatalf("ResolveInteraction: %v", err)
	}
	if !called || gotLeaf != "leaf1" {
		t.Fatalf("the sub-agent resumer must be called with the leaf id, called=%v leaf=%q", called, gotLeaf)
	}
	done, _ := store.GetMessage(ctx, asstID)
	tr2 := toolResultUnder(done, "tc_agent")
	if tr2 == nil || tr2.Status != messagesdomain.StatusCompleted || tr2.Content != "sub-agent shipped it" {
		t.Fatalf("invoke_agent tool_result should hold the sub-agent's output, got %+v", tr2)
	}
	waitContinuation(t, store, ctx, "cv_1", asstID)
}

// TestNested_SubAgentReParksStaysParked: if the resumed sub-agent parks again (a later
// interaction), the chat turn STAYS parked — the invoke_agent tool_result is not filled.
//
// TestNested_SubAgentReParksStaysParked：恢复的子 agent 再次 park（更后的交互），chat 回合**保持** parked
// ——invoke_agent tool_result 不填。
func TestNested_SubAgentReParksStaysParked(t *testing.T) {
	bridge := newRecordBridge()
	called := false
	var gotLeaf string
	client := &scriptedClient{scripts: [][]llminfra.StreamEvent{invokeAgentCall(), textTurn()}}
	svc, store := newNestedSvc(t, client, bridge, fakeResumer{
		called: &called, gotLeaf: &gotLeaf, parked: true, // sub-agent re-parks
	})
	ctx := ctxWS("ws_1")

	asstID, _ := svc.Send(ctx, "cv_1", SendInput{Content: "delegate"})
	waitClose(t, bridge, asstID)

	if err := svc.ResolveInteraction(ctx, "cv_1", "tc_agent", ResolveApprove, "", "leaf1"); err != nil {
		t.Fatalf("ResolveInteraction: %v", err)
	}
	// the chat turn is still parked (sub-agent re-parked)
	if _, err := store.GetParkedMessage(ctx, "cv_1"); err != nil {
		t.Fatalf("chat should stay parked after a sub-agent re-park, err=%v", err)
	}
}
