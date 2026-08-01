package loop

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"go.uber.org/zap"

	humanloopapp "github.com/sunweilin/anselm/backend/internal/app/humanloop"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	agentstatepkg "github.com/sunweilin/anselm/backend/internal/pkg/agentstate"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// fakeWriteTool is fakeTool plus toolapp.FileWriteTool — a stand-in for Write / Edit that answers with
// whatever `file_path` the call carried, exactly as the real ones do.
//
// fakeWriteTool 是 fakeTool + toolapp.FileWriteTool——Write / Edit 的替身,像它们一样把调用里的
// `file_path` 原样答出。
type fakeWriteTool struct{ fakeTool }

func (t fakeWriteTool) WriteTarget(args json.RawMessage) string {
	var a struct {
		FilePath string `json:"file_path"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return ""
	}
	return a.FilePath
}

var _ toolapp.FileWriteTool = fakeWriteTool{}

// safeTC is a call the LLM self-reported as SAFE — the whole point of the residency gate is that this
// level must not be the last word about a path.
//
// safeTC 是 LLM 自报 **safe** 的调用——驻地闸的全部意义就在于:这个等级不能是关于一个路径的最终判词。
func safeTC(name string) messagesdomain.ToolCallData {
	return messagesdomain.ToolCallData{ID: "tc-wd", Name: name, Danger: string(toolapp.DangerSafe), Summary: "write a file"}
}

// gateProbe wires a broker that records what surfaced and answers with `action`.
//
// gateProbe 接一个记录「浮出了什么」并以 `action` 作答的 broker。
func gateProbe(action string) (*humanloopapp.Broker, *[]humanloopapp.Request) {
	var seen []humanloopapp.Request
	var broker *humanloopapp.Broker
	broker = humanloopapp.New(func(_ context.Context, req humanloopapp.Request) {
		seen = append(seen, req)
		go broker.Resolve(req.ToolCallID, humanloopapp.Response{Action: action})
	})
	return broker, &seen
}

func residencyCtx(t *testing.T, broker *humanloopapp.Broker, root string) context.Context {
	t.Helper()
	ctx := humanloopapp.WithBroker(context.Background(), broker)
	ctx = reqctxpkg.WithAgentState(ctx, agentstatepkg.New())
	return reqctxpkg.SetWorkDir(ctx, root)
}

// TestDispatchWithGate_OutsideWorkDirForcesGate: a `safe` write landing OUTSIDE the residency is gated
// anyway, and the prompt says WHY (`outsideWorkDir`). This is the batch's core safety claim.
//
// TestDispatchWithGate_OutsideWorkDirForcesGate:落在驻地**之外**的 `safe` 写照样设闸,且 prompt 说明
// **为什么**（`outsideWorkDir`）。这是本批核心的安全主张。
func TestDispatchWithGate_OutsideWorkDirForcesGate(t *testing.T) {
	base := t.TempDir()
	root := filepath.Join(base, "root")
	if err := os.MkdirAll(root, 0o755); err != nil {
		t.Fatal(err)
	}
	broker, seen := gateProbe(humanloopapp.DecisionDeny)
	ctx := residencyCtx(t, broker, root)

	args := []byte(`{"file_path":"` + filepath.Join(base, "outside.txt") + `"}`)
	out, _, ok, executed, _ := dispatchWithGate(ctx, fakeWriteTool{fakeTool{name: "Write", result: "wrote"}}, safeTC("Write"), args, zap.NewNop())

	if len(*seen) != 1 {
		t.Fatalf("an out-of-root write must surface for confirmation even at danger=safe (surfaced %d)", len(*seen))
	}
	var prompt map[string]any
	if err := json.Unmarshal((*seen)[0].Prompt, &prompt); err != nil {
		t.Fatalf("prompt is not JSON: %v", err)
	}
	if prompt["outsideWorkDir"] != true {
		t.Fatalf("the prompt must say WHY it is asking; got %v", prompt)
	}
	if executed || out != humanloopapp.DenyFeedback {
		t.Fatalf("a denied out-of-root write must not run: out=%q executed=%v ok=%v", out, executed, ok)
	}
}

// TestDispatchWithGate_InsideWorkDirNoGate: a `safe` write INSIDE the residency runs untouched — the gate
// is about leaving the root, not about writing. Includes the relative-path form, because that is the one
// the residency itself created and it must be judged after resolution, not before.
//
// TestDispatchWithGate_InsideWorkDirNoGate:落在驻地**之内**的 `safe` 写原样执行——闸管的是**离开根**、
// 不是「写」。含相对路径形态,因为那正是驻地自己造出来的形态,且它必须在**解析之后**被判定、不是之前。
func TestDispatchWithGate_InsideWorkDirNoGate(t *testing.T) {
	root := t.TempDir()
	for _, path := range []string{filepath.Join(root, "in.txt"), "in.txt", "sub/deep/new.txt", "./x.txt"} {
		broker, seen := gateProbe(humanloopapp.DecisionDeny)
		ctx := residencyCtx(t, broker, root)
		args := []byte(`{"file_path":` + mustJSON(path) + `}`)
		out, _, _, executed, _ := dispatchWithGate(ctx, fakeWriteTool{fakeTool{name: "Write", result: "wrote"}}, safeTC("Write"), args, zap.NewNop())
		if len(*seen) != 0 {
			t.Errorf("%q is inside the residency and must NOT be gated", path)
		}
		if !executed || out != "wrote" {
			t.Errorf("%q should have run: out=%q executed=%v", path, out, executed)
		}
	}
}

// TestDispatchWithGate_NoResidencyNeverGatesOnPath: with no work dir mounted, a `safe` write anywhere is
// exactly the pre-WD1 behaviour. The default path must gain no confirmations.
//
// TestDispatchWithGate_NoResidencyNeverGatesOnPath:未挂工作目录时,写到**任何地方**的 `safe` 调用与
// WD1 之前完全一致。默认路径绝不该多出任何确认。
func TestDispatchWithGate_NoResidencyNeverGatesOnPath(t *testing.T) {
	broker, seen := gateProbe(humanloopapp.DecisionDeny)
	ctx := humanloopapp.WithBroker(reqctxpkg.WithAgentState(context.Background(), agentstatepkg.New()), broker)
	args := []byte(`{"file_path":"/etc/anything.txt"}`)
	out, _, _, executed, _ := dispatchWithGate(ctx, fakeWriteTool{fakeTool{name: "Write", result: "wrote"}}, safeTC("Write"), args, zap.NewNop())
	if len(*seen) != 0 {
		t.Fatalf("no residency → no path gate (surfaced %d)", len(*seen))
	}
	if !executed || out != "wrote" {
		t.Fatalf("unmounted conversation must behave as before: out=%q executed=%v", out, executed)
	}
}

// TestDispatchWithGate_OutsideWorkDirIgnoresApproveAlways: approve_always is per (conversation, tool), so
// honouring it here would turn one "yes, that file over there" into a standing licence for every later
// Write anywhere. The user answered about a PATH.
//
// TestDispatchWithGate_OutsideWorkDirIgnoresApproveAlways:approve_always 是按 (对话, 工具) 记的,故照顾它
// 会把一次「行，那边那个文件」变成此后**任何**位置每次 Write 的长期许可。用户回答的是一个**路径**。
func TestDispatchWithGate_OutsideWorkDirIgnoresApproveAlways(t *testing.T) {
	base := t.TempDir()
	root := filepath.Join(base, "root")
	if err := os.MkdirAll(root, 0o755); err != nil {
		t.Fatal(err)
	}
	broker, seen := gateProbe(humanloopapp.DecisionApproveAlways)
	ctx := reqctxpkg.SetConversationID(residencyCtx(t, broker, root), "cv_1")
	args := []byte(`{"file_path":` + mustJSON(filepath.Join(base, "outside.txt")) + `}`)

	for i := range 2 {
		out, _, _, executed, _ := dispatchWithGate(ctx, fakeWriteTool{fakeTool{name: "Write", result: "wrote"}}, safeTC("Write"), args, zap.NewNop())
		if !executed || out != "wrote" {
			t.Fatalf("call %d: approved write should run: out=%q executed=%v", i, out, executed)
		}
	}
	if len(*seen) != 2 {
		t.Fatalf("every out-of-root write must ask again — approve_always is about a tool, not a path (surfaced %d, want 2)", len(*seen))
	}
}

// TestDispatchWithGate_OutsideWorkDirIgnoresSkillPreApproval: a skill's allowed-tools is a promise made
// before anyone knew WHERE the tool would write, so it cannot authorize leaving the residency either.
//
// TestDispatchWithGate_OutsideWorkDirIgnoresSkillPreApproval:skill 的 allowed-tools 是在谁都还不知道
// 工具要写到**哪里**之前作出的承诺,故它同样无法授权「离开驻地」。
func TestDispatchWithGate_OutsideWorkDirIgnoresSkillPreApproval(t *testing.T) {
	base := t.TempDir()
	root := filepath.Join(base, "root")
	if err := os.MkdirAll(root, 0o755); err != nil {
		t.Fatal(err)
	}
	broker, seen := gateProbe(humanloopapp.DecisionDeny)
	state := agentstatepkg.New()
	state.SetActiveSkill("scaffolder", []string{"Write"})
	ctx := humanloopapp.WithBroker(reqctxpkg.WithAgentState(context.Background(), state), broker)
	ctx = reqctxpkg.SetWorkDir(ctx, root)

	args := []byte(`{"file_path":` + mustJSON(filepath.Join(base, "outside.txt")) + `}`)
	_, _, _, executed, _ := dispatchWithGate(ctx, fakeWriteTool{fakeTool{name: "Write", result: "wrote"}}, safeTC("Write"), args, zap.NewNop())
	if len(*seen) != 1 {
		t.Fatalf("skill pre-approval must not bypass the residency gate (surfaced %d)", len(*seen))
	}
	if executed {
		t.Fatal("denied out-of-root write must not execute")
	}
}

// TestDispatchWithGate_NonWriterToolNeverPathGated: reads are never gated on the residency. LS / Grep /
// Read do not implement FileWriteTool, so a mounted work dir changes nothing for them — "if I want to
// look outside, I can" is the user's own requirement.
//
// TestDispatchWithGate_NonWriterToolNeverPathGated:**读**永不被驻地设闸。LS / Grep / Read 不实现
// FileWriteTool,故挂了工作目录对它们毫无改变——「想看外面什么的,都可以」是用户自己的要求。
func TestDispatchWithGate_NonWriterToolNeverPathGated(t *testing.T) {
	root := t.TempDir()
	broker, seen := gateProbe(humanloopapp.DecisionDeny)
	ctx := residencyCtx(t, broker, root)
	args := []byte(`{"file_path":"/etc/passwd"}`)
	out, _, _, executed, _ := dispatchWithGate(ctx, fakeTool{name: "Read", result: "contents"}, safeTC("Read"), args, zap.NewNop())
	if len(*seen) != 0 {
		t.Fatalf("a non-writing tool must never be path-gated (surfaced %d)", len(*seen))
	}
	if !executed || out != "contents" {
		t.Fatalf("read outside the residency must just work: out=%q executed=%v", out, executed)
	}
}

// TestDispatchWithGate_UndeterminableTargetFallsThrough: unparseable args / no path means the gate cannot
// name a file, and a confirmation that cannot say what it is about teaches users to click through. Execute
// refuses such a call on its own.
//
// TestDispatchWithGate_UndeterminableTargetFallsThrough:args 解不开 / 没有路径,意味着闸说不出是哪个文件,
// 而一个说不清自己在问什么的确认框只会训练用户闭眼点掉。这种调用 Execute 自己会拒。
func TestDispatchWithGate_UndeterminableTargetFallsThrough(t *testing.T) {
	root := t.TempDir()
	for _, args := range []string{`{}`, `{"file_path":""}`, `{"file_path":"   "}`, `not json at all`} {
		broker, seen := gateProbe(humanloopapp.DecisionDeny)
		ctx := residencyCtx(t, broker, root)
		_, _, _, executed, _ := dispatchWithGate(ctx, fakeWriteTool{fakeTool{name: "Write", result: "wrote"}}, safeTC("Write"), []byte(args), zap.NewNop())
		if len(*seen) != 0 {
			t.Errorf("args %q: no determinable target must not manufacture a confirmation", args)
		}
		if !executed {
			t.Errorf("args %q: the call should reach Execute, which reports the real reason", args)
		}
	}
}

// TestDispatchWithGate_DangerousStillGatedInsideResidency: the residency ADDS a reason to gate, it does
// not replace the danger self-report. A dangerous call inside the root still asks.
//
// TestDispatchWithGate_DangerousStillGatedInsideResidency:驻地是**多**一条设闸理由、不是取代 danger
// 自报。根**内**的 dangerous 调用照样要问。
func TestDispatchWithGate_DangerousStillGatedInsideResidency(t *testing.T) {
	root := t.TempDir()
	broker, seen := gateProbe(humanloopapp.DecisionApprove)
	ctx := residencyCtx(t, broker, root)
	tc := messagesdomain.ToolCallData{ID: "tc-d", Name: "Write", Danger: string(toolapp.DangerDangerous)}
	args := []byte(`{"file_path":"in.txt"}`)
	out, _, _, executed, _ := dispatchWithGate(ctx, fakeWriteTool{fakeTool{name: "Write", result: "wrote"}}, tc, args, zap.NewNop())
	if len(*seen) != 1 {
		t.Fatalf("a self-reported dangerous call inside the root must still gate (surfaced %d)", len(*seen))
	}
	var prompt map[string]any
	_ = json.Unmarshal((*seen)[0].Prompt, &prompt)
	if _, present := prompt["outsideWorkDir"]; present {
		t.Fatalf("an ordinary danger prompt must stay byte-identical (no outsideWorkDir key); got %v", prompt)
	}
	if !executed || out != "wrote" {
		t.Fatalf("approved call should run: out=%q executed=%v", out, executed)
	}
}

func mustJSON(s string) string {
	b, err := json.Marshal(s)
	if err != nil {
		panic(err)
	}
	return string(b)
}
