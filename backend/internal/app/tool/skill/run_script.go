package skill

import (
	"context"
	"encoding/json"
	"fmt"
	"path"
	"strings"
	"time"

	loopapp "github.com/sunweilin/anselm/backend/internal/app/loop"
	skillapp "github.com/sunweilin/anselm/backend/internal/app/skill"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	sandboxdomain "github.com/sunweilin/anselm/backend/internal/domain/sandbox"
)

// ScriptSandbox is the slice of sandboxapp.Service that skill-script execution needs:
// idempotently materialize the skill's own env (OwnerKindSkill — first run installs the
// interpreter via directInstaller) and run the one-shot. Mirrors mcp's SandboxPort precedent.
//
// ScriptSandbox 是 skill 脚本执行所需的 sandboxapp.Service 切片：幂等物化 skill 自己的 env
// （OwnerKindSkill——首跑经 directInstaller 装解释器）+ 一次性执行。镜像 mcp 的 SandboxPort 先例。
type ScriptSandbox interface {
	EnsureEnv(ctx context.Context, owner sandboxdomain.Owner, spec sandboxdomain.EnvSpec, stream sandboxdomain.ProgressFunc) (*sandboxdomain.Env, error)
	Spawn(ctx context.Context, owner sandboxdomain.Owner, opts sandboxdomain.SpawnOpts) (*sandboxdomain.ExecutionResult, error)
}

// scriptRuntimes maps a script extension to the sandbox runtime kind that executes it.
// Only sandboxed kinds are listed — anything else (e.g. .sh) has no sandbox runtime and the
// error points the LLM at the host bash tool (which walks the danger-confirmation flow).
//
// scriptRuntimes 把脚本扩展名映射到执行它的沙箱运行时 kind。只列沙箱化 kind——其余（如 .sh）
// 无沙箱运行时，错误信息把 LLM 指向 host bash 工具（走危险确认流）。
var scriptRuntimes = map[string]struct {
	kind string
	cmd  string
}{
	".py":  {kind: "python", cmd: "python"},
	".js":  {kind: "node", cmd: "node"},
	".mjs": {kind: "node", cmd: "node"},
	".cjs": {kind: "node", cmd: "node"},
}

const (
	runScriptDefaultTimeout = 60 * time.Second
	runScriptMaxTimeout     = 600 * time.Second
	runScriptOutputCap      = 64 * 1024 // 与 logtail 的执行日志预算同级
)

// RunSkillScript executes one bundled script inside the skill's OWN sandbox env (WRK-076 B3):
// cwd = the skill directory (relative references/ resolve), CLAUDE_SKILL_DIR exported, and for
// python a bundled requirements.txt becomes the env's deps. The sandbox is the default — the
// host bash tool remains for everything else, behind the usual danger confirmation.
//
// RunSkillScript 在 skill **自己的**沙箱 env 里执行单个捆绑脚本（WRK-076 B3）：cwd = skill 目录
// （相对 references/ 可解析）、导出 CLAUDE_SKILL_DIR、python 时捆绑的 requirements.txt 即 env
// deps。沙箱是默认——其余情形留给 host bash 工具、照走危险确认。
type RunSkillScript struct {
	svc *skillapp.Service
	sbx ScriptSandbox
}

func (t *RunSkillScript) Name() string { return "run_skill_script" }

func (t *RunSkillScript) Description() string {
	return "Run one of a skill's bundled scripts (scripts/*.py, *.js) inside the skill's OWN sandboxed runtime — the default, safest way to execute skill scripts. cwd is the skill directory (relative references resolve), CLAUDE_SKILL_DIR is set, and a bundled requirements.txt is installed for python. First run may take a while (runtime install). For shell scripts or anything else, use the bash tool (host, confirmed per call)."
}

func (t *RunSkillScript) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["name", "script"],
		"properties": {
			"name": {"type": "string", "description": "Skill name (slug)."},
			"script": {"type": "string", "description": "Script path relative to the skill directory, e.g. scripts/fill_form.py."},
			"args": {"type": "array", "items": {"type": "string"}, "description": "Arguments passed to the script."},
			"stdin": {"type": "string", "description": "Optional stdin fed to the script."},
			"timeoutSec": {"type": "integer", "description": "Wall-clock cap in seconds (default 60, max 600)."}
		}
	}`)
}

type runScriptArgs struct {
	Name       string   `json:"name"`
	Script     string   `json:"script"`
	Args       []string `json:"args"`
	Stdin      string   `json:"stdin"`
	TimeoutSec int      `json:"timeoutSec"`
}

func (t *RunSkillScript) ValidateInput(args json.RawMessage) error {
	var a runScriptArgs
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("run_skill_script: bad args: %w", err)
	}
	if strings.TrimSpace(a.Name) == "" {
		return ErrNameRequired
	}
	if strings.TrimSpace(a.Script) == "" {
		return ErrScriptRequired
	}
	if _, ok := scriptRuntimes[strings.ToLower(path.Ext(a.Script))]; !ok {
		return ErrScriptUnsupported
	}
	return nil
}

func (t *RunSkillScript) Execute(ctx context.Context, argsJSON string) (string, error) {
	var a runScriptArgs
	if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
		return "", fmt.Errorf("run_skill_script: bad args: %w", err)
	}
	rt := scriptRuntimes[strings.ToLower(path.Ext(a.Script))]

	// The script must appear in the skill's file listing — one check buys existence,
	// containment (the lister never leaves the directory) and regular-file-ness (symlinks
	// are filtered out) at once.
	// 脚本必须出现在 skill 文件列表里——一次检查同时买到存在性、不越界（列表器不出目录）与
	// 普通文件性（symlink 被滤）。
	files, err := t.svc.ListFiles(ctx, a.Name)
	if err != nil {
		return "", fmt.Errorf("run_skill_script: %w", err)
	}
	want := path.Clean(a.Script)
	found, hasRequirements := false, false
	for _, f := range files {
		if f.Path == want {
			found = true
		}
		if f.Path == "requirements.txt" {
			hasRequirements = true
		}
	}
	if !found {
		return "", ErrScriptNotFound.WithDetails(map[string]any{"skill": a.Name, "script": want})
	}

	dir, err := t.svc.Dir(ctx, a.Name)
	if err != nil {
		return "", fmt.Errorf("run_skill_script: %w", err)
	}

	// A python skill that bundles requirements.txt gets those deps in its env (pip format,
	// one per line); node deps (package.json install) are a recorded backlog — bare node
	// covers the stdlib-only scripts the ecosystem mostly ships.
	// 捆绑 requirements.txt 的 python skill 把依赖装进自己的 env（pip 格式逐行）；node 依赖
	//（package.json 安装）记 backlog——裸 node 已覆盖生态里多数纯标准库脚本。
	var deps []string
	if rt.kind == "python" && hasRequirements {
		if raw, rErr := t.svc.ReadFile(ctx, a.Name, "requirements.txt"); rErr == nil {
			for _, line := range strings.Split(string(raw), "\n") {
				line = strings.TrimSpace(line)
				if line != "" && !strings.HasPrefix(line, "#") {
					deps = append(deps, line)
				}
			}
		}
	}

	owner := sandboxdomain.Owner{Kind: sandboxdomain.OwnerKindSkill, ID: a.Name, Name: a.Name}
	prog := loopapp.ToolProgress(ctx)
	defer prog.Close()
	if _, err := t.sbx.EnsureEnv(ctx, owner,
		sandboxdomain.EnvSpec{Runtime: sandboxdomain.RuntimeSpec{Kind: rt.kind}, Deps: deps},
		func(stage, message string, percent int) {
			if percent > 0 {
				prog.Print(fmt.Sprintf("[%s] %s (%d%%)\n", stage, message, percent))
				return
			}
			prog.Print(fmt.Sprintf("[%s] %s\n", stage, message))
		}); err != nil {
		return "", fmt.Errorf("run_skill_script: provision env: %w", err)
	}

	timeout := runScriptDefaultTimeout
	if a.TimeoutSec > 0 {
		timeout = min(time.Duration(a.TimeoutSec)*time.Second, runScriptMaxTimeout)
	}
	res, err := t.sbx.Spawn(ctx, owner, sandboxdomain.SpawnOpts{
		Cmd:     rt.cmd,
		Args:    append([]string{dir + "/" + want}, a.Args...),
		Cwd:     dir,
		Env:     map[string]string{"CLAUDE_SKILL_DIR": dir},
		Stdin:   []byte(a.Stdin),
		Timeout: timeout,
	})
	if err != nil {
		return "", fmt.Errorf("run_skill_script: %w", err)
	}
	return formatScriptResult(res), nil
}

// formatScriptResult renders the execution outcome as the tool_result text — honest exit
// status + capped stdout/stderr (one unbounded print loop must not blow the turn).
//
// formatScriptResult 把执行结果渲染为 tool_result 文本——诚实的退出态 + 截断的 stdout/stderr
// （一个无界 print 循环不能炸掉回合）。
func formatScriptResult(res *sandboxdomain.ExecutionResult) string {
	var b strings.Builder
	if res.Ok {
		b.WriteString("exit: 0 (ok)\n")
	} else {
		fmt.Fprintf(&b, "exit: %d (failed)\n", res.ExitCode)
	}
	writeCapped := func(label string, data []byte) {
		if len(data) == 0 {
			return
		}
		b.WriteString(label + ":\n")
		if len(data) > runScriptOutputCap {
			b.Write(data[:runScriptOutputCap])
			fmt.Fprintf(&b, "\n… (%d bytes truncated)", len(data)-runScriptOutputCap)
		} else {
			b.Write(data)
		}
		b.WriteString("\n")
	}
	writeCapped("stdout", res.Stdout)
	writeCapped("stderr", res.Stderr)
	return b.String()
}

var _ toolapp.Tool = (*RunSkillScript)(nil)
