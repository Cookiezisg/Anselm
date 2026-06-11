package agent

import (
	"testing"

	agentdomain "github.com/sunweilin/forgify/backend/internal/domain/agent"
	streamdomain "github.com/sunweilin/forgify/backend/internal/domain/stream"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
)

// TestService_InvokeMirrorsRunToEntities: with an EntitiesBridge wired, an agent run mirrors its
// ReAct trace (the loop's blocks) onto the entities stream scoped to the agent — so the agent panel
// shows the run live, even off-chat (manual invoke, no conversation).
//
// TestService_InvokeMirrorsRunToEntities：装了 EntitiesBridge 后，agent run 把 ReAct 轨迹（loop 的 block）
// 镜像到 agent scope 的 entities 流——使 agent 面板实时显示运行，即使不在 chat（manual 调起、无对话）。
func TestService_InvokeMirrorsRunToEntities(t *testing.T) {
	svc, baseCtx := newSvc(t)
	ent := &recBridge{}
	svc.SetInvokeDeps(InvokeDeps{
		Resolver: fakeResolver{client: &fakeLLMClient{events: []llminfra.StreamEvent{
			{Type: llminfra.EventText, Delta: "thinking out loud"},
			{Type: llminfra.EventFinish, InputTokens: 1, OutputTokens: 1},
		}}},
		Knowledge:      fakeKnowledge{},
		EntitiesBridge: ent,
	})
	a, _, err := svc.Create(baseCtx, CreateInput{Name: "mirror", Config: Config{Prompt: "do"}})
	if err != nil {
		t.Fatalf("create: %v", err)
	}

	// Manual invoke: no chat, no tool_call — the mirror is the ONLY emit destination.
	if _, err := svc.InvokeAgent(baseCtx, InvokeInput{AgentID: a.ID, TriggeredBy: agentdomain.TriggeredByManual}); err != nil {
		t.Fatalf("invoke: %v", err)
	}

	if len(ent.events) == 0 {
		t.Fatal("agent run not mirrored to the entities stream at all")
	}
	for _, e := range ent.events {
		if e.Scope.Kind != streamdomain.KindAgent || e.Scope.ID != a.ID {
			t.Fatalf("mirrored frame not scoped to agent:%s: %+v", a.ID, e.Scope)
		}
	}
}
