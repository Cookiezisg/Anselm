package bootstrap

// workflow_exec_test.go pins the runnerAdapter's provenance derivation (scheduler 工单①): the
// workflowapp.Trigger throat is shared by the HTTP `:trigger` handler and the chat trigger_workflow
// tool, and the split MUST ride ctx — a conversation id in ctx marks a chat-born run (stamp chat +
// that conversation), its absence marks a human "Run now" (stamp manual).
//
// workflow_exec_test.go 钉 runnerAdapter 的溯源派生（scheduler 工单①）：workflowapp.Trigger 咽喉由
// HTTP `:trigger` 与 chat trigger_workflow 工具共用，两者之分必须走 ctx——ctx 有对话 id 即 chat 出生
// （盖 chat + 该对话），无即人点「Run now」（盖 manual）。

import (
	"context"
	"testing"

	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func TestStartInputFor_ManualWithoutConversation(t *testing.T) {
	in := startInputFor(context.Background(), "wf_1", map[string]any{"k": "v"})
	if in.Origin != flowrundomain.OriginManual {
		t.Fatalf("origin = %q, want manual (no conversation in ctx)", in.Origin)
	}
	if in.ConversationID != "" {
		t.Fatalf("manual run must carry no conversation, got %q", in.ConversationID)
	}
	if in.WorkflowID != "wf_1" || in.Payload["k"] != "v" {
		t.Fatalf("workflow/payload must pass through: %+v", in)
	}
}

func TestStartInputFor_ChatWithConversation(t *testing.T) {
	ctx := reqctxpkg.SetConversationID(context.Background(), "cv_9")
	in := startInputFor(ctx, "wf_1", nil)
	if in.Origin != flowrundomain.OriginChat {
		t.Fatalf("origin = %q, want chat (conversation in ctx)", in.Origin)
	}
	if in.ConversationID != "cv_9" {
		t.Fatalf("conversationId = %q, want cv_9", in.ConversationID)
	}
}
