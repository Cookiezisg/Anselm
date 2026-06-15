package loop

import (
	"context"
	"testing"

	"go.uber.org/zap"

	humanloopapp "github.com/sunweilin/foryx/backend/internal/app/humanloop"
	toolapp "github.com/sunweilin/foryx/backend/internal/app/tool"
	messagesdomain "github.com/sunweilin/foryx/backend/internal/domain/messages"
	agentstatepkg "github.com/sunweilin/foryx/backend/internal/pkg/agentstate"
	reqctxpkg "github.com/sunweilin/foryx/backend/internal/pkg/reqctx"
)

func dangerTC(name string) messagesdomain.ToolCallData {
	return messagesdomain.ToolCallData{ID: "tc1", Name: name, Danger: string(toolapp.DangerDangerous)}
}

// TestDispatchWithGate_SkillPreApproved: a dangerous tool the active skill declared in its
// allowed-tools runs WITHOUT surfacing for confirmation — allowed-tools are a pre-authorization
// wiring the skill consumer into the danger gate.
func TestDispatchWithGate_SkillPreApproved(t *testing.T) {
	surfaced := 0
	broker := humanloopapp.New(func(context.Context, humanloopapp.Request) { surfaced++ })
	state := agentstatepkg.New()
	state.SetActiveSkill("deployer", []string{"deploy"}) // pre-approves "deploy"
	ctx := humanloopapp.WithBroker(reqctxpkg.WithAgentState(context.Background(), state), broker)

	out, _, ok := dispatchWithGate(ctx, fakeTool{name: "deploy", result: "deployed"}, dangerTC("deploy"), []byte(`{}`), zap.NewNop())
	if surfaced != 0 {
		t.Fatalf("a skill-pre-approved tool must not surface for approval (surfaced %d)", surfaced)
	}
	if !ok || out != "deployed" {
		t.Fatalf("pre-approved dangerous tool should run: out=%q ok=%v", out, ok)
	}
}

// TestDispatchWithGate_NotPreApprovedGated: a dangerous tool the active skill does NOT cover is still
// gated — it surfaces (here denied) and does not run. Proves the pre-approval is tool-specific, not a
// blanket bypass.
func TestDispatchWithGate_NotPreApprovedGated(t *testing.T) {
	surfaced := 0
	var broker *humanloopapp.Broker
	broker = humanloopapp.New(func(_ context.Context, req humanloopapp.Request) {
		surfaced++
		go broker.Resolve(req.ToolCallID, humanloopapp.Response{Action: humanloopapp.DecisionDeny})
	})
	state := agentstatepkg.New()
	state.SetActiveSkill("reader", []string{"read_file"}) // does NOT cover "deploy"
	ctx := humanloopapp.WithBroker(reqctxpkg.WithAgentState(context.Background(), state), broker)

	out, _, ok := dispatchWithGate(ctx, fakeTool{name: "deploy", result: "deployed"}, dangerTC("deploy"), []byte(`{}`), zap.NewNop())
	if surfaced != 1 {
		t.Fatalf("a non-pre-approved dangerous tool must be gated (surfaced %d)", surfaced)
	}
	if !ok || out != humanloopapp.DenyFeedback {
		t.Fatalf("denied tool should not run: out=%q", out)
	}
}
