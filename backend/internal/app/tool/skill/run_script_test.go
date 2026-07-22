package skill

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"testing"

	"go.uber.org/zap"

	skillapp "github.com/sunweilin/anselm/backend/internal/app/skill"
	sandboxdomain "github.com/sunweilin/anselm/backend/internal/domain/sandbox"
	skillfs "github.com/sunweilin/anselm/backend/internal/infra/fs/skill"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// B3 脚本执行（WRK-076）：run_skill_script 的校验面 / requirements 检测 / spawn 指令组装
//（cwd=skill 目录、CLAUDE_SKILL_DIR 导出、owner=OwnerKindSkill）。

type fakeSandbox struct {
	ensuredOwner sandboxdomain.Owner
	ensuredSpec  sandboxdomain.EnvSpec
	spawnOpts    sandboxdomain.SpawnOpts
	result       *sandboxdomain.ExecutionResult
}

func (f *fakeSandbox) EnsureEnv(_ context.Context, owner sandboxdomain.Owner, spec sandboxdomain.EnvSpec, _ sandboxdomain.ProgressFunc) (*sandboxdomain.Env, error) {
	f.ensuredOwner, f.ensuredSpec = owner, spec
	return &sandboxdomain.Env{}, nil
}

func (f *fakeSandbox) Spawn(_ context.Context, _ sandboxdomain.Owner, opts sandboxdomain.SpawnOpts) (*sandboxdomain.ExecutionResult, error) {
	f.spawnOpts = opts
	if f.result != nil {
		return f.result, nil
	}
	return &sandboxdomain.ExecutionResult{Ok: true, Stdout: []byte("done")}, nil
}

func runScriptSetup(t *testing.T) (*RunSkillScript, *fakeSandbox, context.Context, *skillapp.Service) {
	t.Helper()
	svc := skillapp.NewService(skillfs.New(t.TempDir()), nil, nil, zap.NewNop())
	sbx := &fakeSandbox{}
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")
	if _, err := svc.Create(ctx, skillapp.SaveInput{Name: "pdf", Description: "d", Body: "b"}); err != nil {
		t.Fatalf("seed skill: %v", err)
	}
	if err := svc.WriteFile(ctx, "pdf", "scripts/fill.py", []byte("print('hi')")); err != nil {
		t.Fatalf("seed script: %v", err)
	}
	return &RunSkillScript{svc: svc, sbx: sbx}, sbx, ctx, svc
}

func TestRunSkillScript_ValidateInput(t *testing.T) {
	tool := &RunSkillScript{}
	cases := []struct {
		args string
		want error
	}{
		{`{"script":"a.py"}`, ErrNameRequired},
		{`{"name":"pdf"}`, ErrScriptRequired},
		{`{"name":"pdf","script":"run.sh"}`, ErrScriptUnsupported},
		{`{"name":"pdf","script":"scripts/a.py"}`, nil},
		{`{"name":"pdf","script":"scripts/a.mjs"}`, nil},
	}
	for _, c := range cases {
		err := tool.ValidateInput(json.RawMessage(c.args))
		if c.want == nil && err != nil {
			t.Fatalf("ValidateInput(%s) = %v, want nil", c.args, err)
		}
		if c.want != nil && !errors.Is(err, c.want) {
			t.Fatalf("ValidateInput(%s) = %v, want %v", c.args, err, c.want)
		}
	}
}

func TestRunSkillScript_SpawnOrderShape(t *testing.T) {
	tool, sbx, ctx, svc := runScriptSetup(t)
	out, err := tool.Execute(ctx, `{"name":"pdf","script":"scripts/fill.py","args":["--fast"],"stdin":"in"}`)
	if err != nil {
		t.Fatalf("execute: %v", err)
	}
	if !strings.Contains(out, "exit: 0") || !strings.Contains(out, "done") {
		t.Fatalf("result shape: %q", out)
	}
	// owner = skill 归属（OwnerKindSkill env 轴被真正消费）。
	if sbx.ensuredOwner.Kind != sandboxdomain.OwnerKindSkill || sbx.ensuredOwner.ID != "pdf" {
		t.Fatalf("owner mismatch: %+v", sbx.ensuredOwner)
	}
	if sbx.ensuredSpec.Runtime.Kind != "python" || len(sbx.ensuredSpec.Deps) != 0 {
		t.Fatalf("spec mismatch: %+v", sbx.ensuredSpec)
	}
	// spawn 指令：cwd=skill 目录、脚本绝对路径、CLAUDE_SKILL_DIR 导出、stdin 透传。
	dir, _ := svc.Dir(ctx, "pdf")
	if sbx.spawnOpts.Cwd != dir {
		t.Fatalf("cwd must be the skill dir: %q vs %q", sbx.spawnOpts.Cwd, dir)
	}
	if sbx.spawnOpts.Cmd != "python" || len(sbx.spawnOpts.Args) != 2 ||
		sbx.spawnOpts.Args[0] != dir+"/scripts/fill.py" || sbx.spawnOpts.Args[1] != "--fast" {
		t.Fatalf("spawn cmd/args mismatch: %q %+v", sbx.spawnOpts.Cmd, sbx.spawnOpts.Args)
	}
	if sbx.spawnOpts.Env["CLAUDE_SKILL_DIR"] != dir || string(sbx.spawnOpts.Stdin) != "in" {
		t.Fatalf("env/stdin mismatch: %+v %q", sbx.spawnOpts.Env, sbx.spawnOpts.Stdin)
	}
}

func TestRunSkillScript_RequirementsBecomeDeps(t *testing.T) {
	tool, sbx, ctx, svc := runScriptSetup(t)
	if err := svc.WriteFile(ctx, "pdf", "requirements.txt", []byte("pypdf>=4\n# comment\n\nreportlab\n")); err != nil {
		t.Fatalf("seed requirements: %v", err)
	}
	if _, err := tool.Execute(ctx, `{"name":"pdf","script":"scripts/fill.py"}`); err != nil {
		t.Fatalf("execute: %v", err)
	}
	if len(sbx.ensuredSpec.Deps) != 2 || sbx.ensuredSpec.Deps[0] != "pypdf>=4" || sbx.ensuredSpec.Deps[1] != "reportlab" {
		t.Fatalf("requirements must become deps (comments/blank dropped): %+v", sbx.ensuredSpec.Deps)
	}
}

func TestRunSkillScript_MissingAndEscapingScriptsRefused(t *testing.T) {
	tool, _, ctx, _ := runScriptSetup(t)
	if _, err := tool.Execute(ctx, `{"name":"pdf","script":"scripts/ghost.py"}`); !errors.Is(err, ErrScriptNotFound) {
		t.Fatalf("missing script should be ScriptNotFound, got %v", err)
	}
	// 越界路径不在文件列表 → 同码拒（列表器天然不出目录）。
	if _, err := tool.Execute(ctx, `{"name":"pdf","script":"../other/steal.py"}`); !errors.Is(err, ErrScriptNotFound) {
		t.Fatalf("escaping script should be ScriptNotFound, got %v", err)
	}
}

func TestRunSkillScript_FailedExitIsHonest(t *testing.T) {
	tool, sbx, ctx, _ := runScriptSetup(t)
	sbx.result = &sandboxdomain.ExecutionResult{Ok: false, ExitCode: 3, Stderr: []byte("boom")}
	out, err := tool.Execute(ctx, `{"name":"pdf","script":"scripts/fill.py"}`)
	if err != nil {
		t.Fatalf("non-zero exit is a RESULT, not a Go error: %v", err)
	}
	if !strings.Contains(out, "exit: 3") || !strings.Contains(out, "boom") {
		t.Fatalf("failed result must carry exit code + stderr: %q", out)
	}
}
