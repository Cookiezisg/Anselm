package agent

import (
	"context"
	"strings"
	"testing"

	loopapp "github.com/sunweilin/foryx/backend/internal/app/loop"
	agentdomain "github.com/sunweilin/foryx/backend/internal/domain/agent"
	streamdomain "github.com/sunweilin/foryx/backend/internal/domain/stream"
	llminfra "github.com/sunweilin/foryx/backend/internal/infra/llm"
	reqctxpkg "github.com/sunweilin/foryx/backend/internal/pkg/reqctx"
)

type recBridge struct{ events []streamdomain.Event }

func (b *recBridge) Publish(_ context.Context, e streamdomain.Event) (streamdomain.Envelope, error) {
	b.events = append(b.events, e)
	return streamdomain.Envelope{}, nil
}
func (b *recBridge) Subscribe(_ context.Context, _ int64) (<-chan streamdomain.Envelope, func(), error) {
	return nil, func() {}, nil
}

// TestService_InvokeStreamsNestedAndPersistsTranscript: invoked as a tool in a chat turn, the agent
// streams its blocks nested under the invoke_agent tool_call (E3, "中间内容挂 tool 中间过程"), while
// the run's durable record is the Execution transcript (self-contained — NOT message_blocks),
// correlatable to the tool_call via ToolCallID.
//
// TestService_InvokeStreamsNestedAndPersistsTranscript：在 chat turn 内作为 tool 调起，agent 把 block
// 嵌在 invoke_agent tool_call 下流式（E3，「中间内容挂 tool 中间过程」），而本次运行的耐久记录是 Execution
// transcript（自包含——**非** message_blocks），经 ToolCallID 关联回 tool_call。
func TestService_InvokeStreamsNestedAndPersistsTranscript(t *testing.T) {
	svc, baseCtx := newSvc(t)
	svc.SetInvokeDeps(InvokeDeps{
		Resolver: fakeResolver{client: &fakeLLMClient{events: []llminfra.StreamEvent{
			{Type: llminfra.EventText, Delta: "hello from agent"},
			{Type: llminfra.EventFinish, InputTokens: 1, OutputTokens: 1},
		}}},
		Knowledge: fakeKnowledge{},
	})
	a, _, err := svc.Create(baseCtx, CreateInput{Name: "streamer", Config: Config{Prompt: "do it"}})
	if err != nil {
		t.Fatalf("create: %v", err)
	}

	// A streamed chat tool context: messages Bridge + conversation anchor + the invoke_agent tool_call id.
	bridge := &recBridge{}
	ctx := reqctxpkg.SetToolCallID(reqctxpkg.SetConversationID(loopapp.WithBridge(baseCtx, bridge), "c1"), "tc_agent")
	res, err := svc.InvokeAgent(ctx, InvokeInput{AgentID: a.ID, TriggeredBy: agentdomain.TriggeredByChat})
	if err != nil {
		t.Fatalf("invoke: %v", err)
	}

	// The agent's blocks streamed nested under the invoke_agent tool_call.
	var nested bool
	for _, e := range bridge.events {
		if o, ok := e.Frame.(streamdomain.Open); ok && o.ParentID == "tc_agent" {
			nested = true
		}
	}
	if !nested {
		t.Fatalf("agent blocks not streamed nested under tool_call tc_agent: %+v", bridge.events)
	}

	// The full transcript is the run's durable record in the Execution, linked to the tool_call.
	exec, err := svc.GetExecutionDetail(baseCtx, res.ExecutionID)
	if err != nil {
		t.Fatalf("get execution: %v", err)
	}
	if exec.ToolCallID != "tc_agent" {
		t.Fatalf("execution not linked to the tool_call: %q", exec.ToolCallID)
	}
	if !strings.Contains(string(exec.Transcript), "hello from agent") {
		t.Fatalf("execution transcript missing the agent's output: %s", exec.Transcript)
	}
}

// TestService_InvokeOffChatStillPersistsTranscript: a workflow/REST invocation (no tool_call) skips
// chat surfacing but still records the full transcript — the durable home is the Execution.
//
// TestService_InvokeOffChatStillPersistsTranscript：workflow/REST 调用（无 tool_call）跳过 chat 呈现，
// 但仍记录完整 transcript——耐久家是 Execution。
func TestService_InvokeOffChatStillPersistsTranscript(t *testing.T) {
	svc, baseCtx := newSvc(t)
	svc.SetInvokeDeps(InvokeDeps{
		Resolver: fakeResolver{client: &fakeLLMClient{events: []llminfra.StreamEvent{
			{Type: llminfra.EventText, Delta: "batch output"},
			{Type: llminfra.EventFinish, InputTokens: 1, OutputTokens: 1},
		}}},
		Knowledge: fakeKnowledge{},
	})
	a, _, err := svc.Create(baseCtx, CreateInput{Name: "batch", Config: Config{Prompt: "run"}})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	res, err := svc.InvokeAgent(baseCtx, InvokeInput{AgentID: a.ID, TriggeredBy: agentdomain.TriggeredByWorkflow})
	if err != nil {
		t.Fatalf("invoke: %v", err)
	}
	exec, err := svc.GetExecutionDetail(baseCtx, res.ExecutionID)
	if err != nil {
		t.Fatalf("get execution: %v", err)
	}
	if exec.ToolCallID != "" {
		t.Fatalf("off-chat run should have no tool_call link: %q", exec.ToolCallID)
	}
	if !strings.Contains(string(exec.Transcript), "batch output") {
		t.Fatalf("transcript missing output off-chat: %s", exec.Transcript)
	}
}
