package skill

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"path"
	"strconv"
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
	return "Run one bundled skill script in its sandbox: name is the skill slug (the user's skill name), script is its path relative to that skill; optional args, stdin, and timeoutSec are passed as supplied. cwd is the skill directory, CLAUDE_SKILL_DIR is set, and Python requirements.txt is installed. First run may install a runtime. args must be a string array; an exact JSON array string is also accepted from managed callers. timeoutSec must be an integer; an exact decimal integer string is also accepted. For shell scripts, use the host bash tool."
}

func (t *RunSkillScript) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["name", "script"],
		"properties": {
			"name": {"type": "string", "description": "Skill name (slug)."},
			"script": {"type": "string", "description": "Script path relative to the skill directory, e.g. scripts/fill_form.py."},
			"args": {"type": "array", "items": {"type": "string"}, "description": "Arguments passed to the script. Prefer an array; an exact JSON array string is accepted from managed callers. Other shapes are invalid."},
			"stdin": {"type": "string", "description": "Optional stdin fed to the script."},
			"timeoutSec": {"type": "integer", "description": "Wall-clock cap in seconds (default 60, max 600). Prefer an integer; an exact decimal integer string is accepted from managed callers. Floats, booleans, arrays, and other strings are invalid."}
		}
	}`)
}

type runScriptArgs struct {
	Name       string
	Script     string
	Args       []string
	Stdin      string
	TimeoutSec int
}

// UnmarshalJSON keeps the public schema strongly typed while tolerating the two exact scalar
// encodings emitted by some managed callers. It never turns arbitrary text into script arguments
// or a timeout, so a malformed call still fails before the sandbox or a retry can begin.
//
// UnmarshalJSON 保持公开 schema 的数组/整数类型，同时兼容部分托管调用方发出的两个精确字符串形状。
// 不把任意文本变成脚本参数或超时，故畸形调用仍在进沙箱或重试前失败。
func (a *runScriptArgs) UnmarshalJSON(data []byte) error {
	var raw struct {
		Name       string          `json:"name"`
		Script     string          `json:"script"`
		Args       json.RawMessage `json:"args"`
		Stdin      string          `json:"stdin"`
		TimeoutSec json.RawMessage `json:"timeoutSec"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	args, err := decodeSkillStringArray(raw.Args)
	if err != nil {
		return fmt.Errorf("args: %w", err)
	}
	timeoutSec, err := decodeRunScriptInt(raw.TimeoutSec)
	if err != nil {
		return fmt.Errorf("timeoutSec: %w", err)
	}
	*a = runScriptArgs{
		Name:       raw.Name,
		Script:     raw.Script,
		Args:       args,
		Stdin:      raw.Stdin,
		TimeoutSec: timeoutSec,
	}
	return nil
}

func decodeRunScriptInt(raw json.RawMessage) (int, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return 0, nil
	}
	var value int
	if err := json.Unmarshal(raw, &value); err == nil {
		return value, nil
	}
	var text string
	if err := json.Unmarshal(raw, &text); err != nil {
		return 0, fmt.Errorf("must be an integer or an exact decimal integer string, got %s", string(raw))
	}
	value, err := strconv.Atoi(strings.TrimSpace(text))
	if err != nil {
		return 0, fmt.Errorf("must be an integer or an exact decimal integer string, got %q", text)
	}
	return value, nil
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

// HaltOnRepeat makes a missing script or unsupported extension terminal for this turn. Neither
// condition can be repaired by emitting the same call again; allowing that retry only duplicates
// red cards. A later user turn may create the file or choose the host bash tool.
//
// HaltOnRepeat 将脚本缺失或扩展不支持视为本回合终局。重复发同一调用无法修复任一条件，只会制造重复红卡；
// 后续用户回合仍可先补文件，或改用 host bash。
func (*RunSkillScript) HaltOnRepeat(_ string, errorText string) bool {
	text := strings.ToLower(errorText)
	return strings.Contains(text, "script not found in the skill directory") ||
		strings.Contains(text, "script extension has no sandbox runtime")
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
