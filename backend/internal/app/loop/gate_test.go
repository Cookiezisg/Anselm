package loop

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"testing"

	"go.uber.org/zap"

	humanloopapp "github.com/sunweilin/anselm/backend/internal/app/humanloop"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	agentstatepkg "github.com/sunweilin/anselm/backend/internal/pkg/agentstate"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func dangerTC(name string) messagesdomain.ToolCallData {
	return messagesdomain.ToolCallData{ID: "tc1", Name: name, Danger: string(toolapp.DangerDangerous)}
}

type invalidInputTool struct{}

func (invalidInputTool) Name() string                { return "invalid" }
func (invalidInputTool) Description() string         { return "invalid" }
func (invalidInputTool) Parameters() json.RawMessage { return json.RawMessage(`{"type":"object"}`) }
func (invalidInputTool) ValidateInput(json.RawMessage) error {
	return errors.New("required field is missing")
}
func (invalidInputTool) Execute(context.Context, string) (string, error) {
	panic("invalid tool must not execute")
}

type staticDangerTool struct{ fakeTool }

func (staticDangerTool) MinimumDanger() toolapp.DangerLevel { return toolapp.DangerDangerous }

func TestDispatchWithGate_ValidationHappensBeforeDangerGate(t *testing.T) {
	broker, seen := gateProbe(humanloopapp.DecisionApprove)
	ctx := humanloopapp.WithBroker(context.Background(), broker)

	out, errMsg, ok, executed, approved := dispatchWithGate(
		ctx,
		invalidInputTool{},
		dangerTC("invalid"),
		[]byte(`{}`),
		zap.NewNop(),
	)
	if len(*seen) != 0 {
		t.Fatalf("invalid dangerous input must not open an approval gate: %d requests", len(*seen))
	}
	if ok || executed || approved {
		t.Fatalf("invalid input must fail before execution/approval: out=%q err=%q ok=%v executed=%v approved=%v", out, errMsg, ok, executed, approved)
	}
	if out != "input validation failed: required field is missing" || errMsg != out {
		t.Fatalf("unexpected validation result: out=%q err=%q", out, errMsg)
	}
}

func TestDispatchWithGate_StaticDangerFloorCannotBeSelfReportedSafe(t *testing.T) {
	var broker *humanloopapp.Broker
	seen := 0
	broker = humanloopapp.New(func(_ context.Context, req humanloopapp.Request) {
		seen++
		go broker.Resolve(req.ToolCallID, humanloopapp.Response{Action: humanloopapp.DecisionApprove})
	})
	ctx := humanloopapp.WithBroker(context.Background(), broker)

	tc := messagesdomain.ToolCallData{ID: "tc_delete", Name: "delete_workflow", Danger: string(toolapp.DangerSafe)}
	out, _, ok, executed, approved := dispatchWithGate(
		ctx,
		staticDangerTool{fakeTool{name: "delete_workflow", result: "deleted"}},
		tc,
		[]byte(`{}`),
		zap.NewNop(),
	)
	if seen != 1 {
		t.Fatalf("static irreversible danger floor must surface one gate, got %d", seen)
	}
	if !ok || !executed || !approved || out != "deleted" {
		t.Fatalf("approved static-danger call should execute: out=%q ok=%v executed=%v approved=%v", out, ok, executed, approved)
	}
}

func TestDispatchWithGate_ApprovalUsesResolvedToolAction(t *testing.T) {
	broker, seen := gateProbe(humanloopapp.DecisionDeny)
	ctx := humanloopapp.WithBroker(context.Background(), broker)
	tc := messagesdomain.ToolCallData{
		ID:      "tc_delete",
		Name:    "delete_workflow",
		Summary: "Clean up the old workflow",
		Danger:  string(toolapp.DangerDangerous),
	}

	_, _, _, executed, _ := dispatchWithGate(
		ctx,
		staticDangerTool{fakeTool{name: "delete_workflow", result: "deleted"}},
		tc,
		[]byte(`{}`),
		zap.NewNop(),
	)
	if executed {
		t.Fatal("a denied call must not execute")
	}
	if len(*seen) != 1 {
		t.Fatal("a dangerous delete must surface exactly one gate")
	}
	var prompt map[string]any
	if err := json.Unmarshal((*seen)[0].Prompt, &prompt); err != nil {
		t.Fatalf("gate prompt is not JSON: %v", err)
	}
	if got := prompt["summary"]; got != "Permanently delete this workflow from normal reads. It is not restorable; automation is stopped and history is retained for audit." {
		t.Fatalf("gate must use the resolved delete action, got %v", got)
	}
}

func TestCanonicalGateSummary_CoversIrreversibleDeleteFamily(t *testing.T) {
	cases := []struct {
		name string
		want []string
	}{
		{name: "delete_function", want: []string{"not restorable", "version history", "sandbox"}},
		{name: "delete_handler", want: []string{"resident instance", "not restorable", "relation edges"}},
		{name: "delete_agent", want: []string{"active configuration", "not restorable", "execution history"}},
		{name: "delete_control", want: []string{"not reversible", "restore operation", "capability checks"}},
		{name: "delete_approval", want: []string{"primary row", "not restorable", "versions", "capability checks"}},
		{name: "delete_skill", want: []string{"Permanently delete", "cannot be undone", "equipped"}},
		{name: "delete_trigger", want: []string{"stop its listener", "primary row", "not restorable", "activation and firing history", "relation edges"}},
		{name: "delete_workflow", want: []string{"not restorable", "automation is stopped", "history"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := canonicalGateSummary(fakeTool{name: tc.name}, dangerTC(tc.name), false)
			for _, want := range tc.want {
				if !strings.Contains(got, want) {
					t.Fatalf("summary %q missing %q", got, want)
				}
			}
			if strings.HasPrefix(got, "Run the `") {
				t.Fatalf("irreversible delete must not use generic gate copy: %q", got)
			}
		})
	}
}

func TestToolIntentConflictRejectsDestructiveWrongTool(t *testing.T) {
	var ran bool
	tracked := trackingTool{fakeTool: fakeTool{name: "delete_workflow", result: "deleted"}, ran: &ran}
	tc := messagesdomain.ToolCallData{
		ID:      "tc_delete",
		Name:    "delete_workflow",
		Summary: "Deactivate this workflow gracefully and let in-flight runs finish",
		Danger:  string(toolapp.DangerDangerous),
	}
	out, errMsg, ok, executed, approved := dispatchWithGate(
		context.Background(), tracked, tc, []byte(`{}`), zap.NewNop(),
	)
	if ok || executed || approved || ran {
		t.Fatalf("conflicting destructive call must not run: out=%q err=%q ok=%v executed=%v approved=%v ran=%v", out, errMsg, ok, executed, approved, ran)
	}
	if !strings.Contains(out, "deactivate_workflow") {
		t.Fatalf("conflict feedback must identify the intended tool: %q", out)
	}
}

type trackingTool struct {
	fakeTool
	ran *bool
}

func (t trackingTool) Execute(context.Context, string) (string, error) {
	*t.ran = true
	return t.result, nil
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

	out, _, ok, executed, _ := dispatchWithGate(ctx, fakeTool{name: "deploy", result: "deployed"}, dangerTC("deploy"), []byte(`{}`), zap.NewNop())
	if surfaced != 0 {
		t.Fatalf("a skill-pre-approved tool must not surface for approval (surfaced %d)", surfaced)
	}
	if !ok || !executed || out != "deployed" {
		t.Fatalf("pre-approved dangerous tool should run: out=%q ok=%v executed=%v", out, ok, executed)
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

	out, _, ok, executed, _ := dispatchWithGate(ctx, fakeTool{name: "deploy", result: "deployed"}, dangerTC("deploy"), []byte(`{}`), zap.NewNop())
	if surfaced != 1 {
		t.Fatalf("a non-pre-approved dangerous tool must be gated (surfaced %d)", surfaced)
	}
	if !ok || out != humanloopapp.DenyFeedback {
		t.Fatalf("denied tool should not run: out=%q", out)
	}
	if executed {
		t.Fatal("a denied call must report executed=false — the ledger must not book a phantom touch")
	}
}

func TestRunOneTool_ApprovedGateFactReachesModelOnly(t *testing.T) {
	var broker *humanloopapp.Broker
	broker = humanloopapp.New(func(_ context.Context, req humanloopapp.Request) {
		go broker.Resolve(req.ToolCallID, humanloopapp.Response{Action: humanloopapp.DecisionApprove})
	})
	ctx := humanloopapp.WithBroker(context.Background(), broker)
	tc := dangerTC("deploy")
	blocks := runOneTool(ctx, fakeTool{name: "deploy", result: "deployed"}, tc, zap.NewNop())
	if len(blocks) != 1 || blocks[0].Attrs[messagesdomain.AttrHumanApproval] != true {
		t.Fatalf("approved tool result attrs = %#v, want humanApproval=true", blocks)
	}
	if strings.Contains(blocks[0].Content, "Human approval granted") {
		t.Fatal("the approval fact must not pollute the visible tool result")
	}
	llm := BlocksToAssistantLLM(blocks)
	if len(llm) != 2 || !strings.Contains(llm[1].Content, "Human approval granted before this tool executed") {
		t.Fatalf("LLM tool result = %#v, want explicit approval fact", llm)
	}
}
