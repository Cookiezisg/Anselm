// bash.go — Bash system tool: run a shell command in the user's
// environment. Two modes:
//
//   - Foreground (default): exec the command with the conversation cwd,
//     wait up to `timeout` ms (default 120s, hard max 600s), capture
//     combined stdout+stderr, return the result string with status footer.
//   - Background (`run_in_background: true`): spawn the command, register
//     in ProcessManager, return immediately with the bash_id the LLM
//     uses to poll BashOutput / KillShell. No timeout in background mode.
//
// cwd state machine: when the entire command (after Trim) matches
// `cd <path>`, we update AgentState's cwd and return success without
// invoking a subshell. All other commands run via `sh -c "<command>"`
// with that cwd. Chained `cd && other` is NOT tracked — same limitation
// a real terminal would show ("subshell exited; parent cwd unchanged").
//
// bash.go — Bash 系统工具：在用户环境跑 shell 命令。两模式：
//   - 前台（默认）：用对话 cwd 执行，至多等 timeout 毫秒（默认 120s 硬上限 600s），
//     捕获合并 stdout+stderr，返结果字符串（含状态尾注）。
//   - 后台（`run_in_background: true`）：spawn + 注册进 ProcessManager，
//     立即返 bash_id 让 LLM 用于 BashOutput / KillShell 轮询。后台无超时。
//
// cwd 状态机：整条命令（trim 后）匹配 `cd <path>` 时更新 AgentState cwd 并直接
// 返成功，不下到 subshell。其他命令用 `sh -c "<command>"` + 该 cwd 跑。
// 链式 `cd && other` 不追踪——与真实终端一致（"子 shell 退出后父 cwd 不变"）。
package shell

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// ── Limits & defaults ─────────────────────────────────────────────────────────

const (
	// defaultTimeoutMS is the foreground timeout when LLM doesn't supply.
	// 2 minutes covers typical build / test / install workflows.
	//
	// defaultTimeoutMS 是 LLM 未传 timeout 时的前台超时；2 分钟覆盖典型
	// build / test / install。
	defaultTimeoutMS = 120_000

	// maxTimeoutMS hard cap on a single foreground run. Anything truly
	// long-lived should go background.
	//
	// maxTimeoutMS 单次前台运行硬上限；真长跑应走 background。
	maxTimeoutMS = 600_000

	// outputCapBytes truncates the foreground result body. Same 256 KB
	// budget as bgBufferBytes so the LLM never gets a 10 MB blob.
	//
	// outputCapBytes 截断前台结果正文；与 bgBufferBytes 同 256 KB 预算。
	outputCapBytes = 256 * 1024
)

// ── Validation sentinels ──────────────────────────────────────────────────────

var (
	// ErrEmptyCommand: command missing or empty.
	// ErrEmptyCommand：command 缺失或为空。
	ErrEmptyCommand = errors.New("command is required and must be non-empty")

	// ErrInvalidTimeout: timeout outside [0, maxTimeoutMS]. 0 = use default.
	// ErrInvalidTimeout：timeout 不在 [0, maxTimeoutMS]；0 = 用默认。
	ErrInvalidTimeout = fmt.Errorf("timeout must be between 0 and %d ms", maxTimeoutMS)
)

// ── Description & schema ──────────────────────────────────────────────────────

const bashDescription = `Run a shell command on the user's machine.

Usage:
- ` + "`command`" + ` is the shell command (executed via /bin/sh on Unix). Examples: "ls -la", "git status", "go test ./...".
- ` + "`description`" + ` is a one-line note for the human reader (e.g. "List repo files").
- ` + "`run_in_background: true`" + ` spawns the command without waiting and returns a bash_id; use BashOutput to poll for new output and KillShell to terminate.
- ` + "`timeout`" + ` (milliseconds, foreground only) defaults to 120000 (2 min); hard max 600000 (10 min). For longer-running tasks use background mode.
- The conversation has a tracked working directory: ` + "`cd <path>`" + ` as the entire command updates it; subsequent commands run there. Chained 'cd ... && ...' does not update the tracked cwd (matches normal subshell semantics).
- Combined stdout+stderr is returned, capped at 256 KB. Exit code appears in a status footer.
- This is a local single-user app — there is no banned-command list. Be careful with destructive commands; the user sees what you propose to run.`

var bashSchema = json.RawMessage(`{
	"type": "object",
	"required": ["command"],
	"properties": {
		"command": {
			"type": "string",
			"description": "Shell command to execute (POSIX sh)."
		},
		"description": {
			"type": "string",
			"description": "One-line human-readable description of what this command does."
		},
		"run_in_background": {
			"type": "boolean",
			"default": false,
			"description": "If true, spawn without waiting and return a bash_id for BashOutput / KillShell."
		},
		"timeout": {
			"type": "number",
			"description": "Foreground timeout in milliseconds (default 120000, hard max 600000). Ignored in background mode."
		}
	}
}`)

// ── Args ──────────────────────────────────────────────────────────────────────

type bashArgs struct {
	Command     string `json:"command"`
	Description string `json:"description"`
	Background  bool   `json:"run_in_background"`
	Timeout     int    `json:"timeout"`
}

// ── Tool struct & 9 methods ───────────────────────────────────────────────────

// Bash implements the Bash system tool. mgr is shared with BashOutput +
// KillShell so all three operate on the same registry.
//
// Bash struct 是 Bash 系统工具。mgr 与 BashOutput + KillShell 共享，三者操作
// 同一注册表。
type Bash struct {
	mgr *ProcessManager
}

// Identity --------------------------------------------------------------------

func (t *Bash) Name() string                { return "Bash" }
func (t *Bash) Description() string         { return bashDescription }
func (t *Bash) Parameters() json.RawMessage { return bashSchema }

// Static metadata -------------------------------------------------------------

func (t *Bash) IsReadOnly() bool        { return false }
func (t *Bash) NeedsReadFirst() bool    { return false }
func (t *Bash) RequiresWorkspace() bool { return false } // PathGuard intentionally NOT applied — see package doc

// Args-dependent hooks --------------------------------------------------------

// ValidateInput rejects empty commands and timeouts outside the allowed
// range.
//
// ValidateInput 拒绝空命令和越界 timeout。
func (t *Bash) ValidateInput(args json.RawMessage) error {
	var a bashArgs
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("Bash.ValidateInput: %w", err)
	}
	if strings.TrimSpace(a.Command) == "" {
		return ErrEmptyCommand
	}
	if a.Timeout < 0 || a.Timeout > maxTimeoutMS {
		return ErrInvalidTimeout
	}
	return nil
}

func (t *Bash) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

// ── Execute ───────────────────────────────────────────────────────────────────

// Execute dispatches:
//   - cd-only command → update AgentState.Cwd, return new cwd.
//   - background → spawn + register, return bash_id immediately.
//   - foreground → run with timeout, return stdout/stderr + exit code.
//
// Filesystem / OS errors are returned as LLM-friendly strings; only truly
// internal failures (post-validation JSON unmarshal) bubble up as Go err.
//
// Execute 分派：cd 单命令 → 更新 cwd 返新值；background → spawn + 注册返
// bash_id；foreground → 超时下跑、返输出 + exit code。
//
// 文件系统 / OS 错误返友好字符串；仅真正内部失败上抛 Go err。
func (t *Bash) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args bashArgs
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("Bash.Execute: %w", err)
	}
	cmdText := strings.TrimSpace(args.Command)

	// cd-only short-circuit: update state and return without subshell.
	// cd-only 短路：更新 state 后直接返，不下 subshell。
	if target, ok := parseCDOnly(cmdText); ok {
		return t.handleCD(ctx, target)
	}

	cwd := resolveCwd(ctx)

	if args.Background {
		return t.runBackground(ctx, cmdText, cwd)
	}

	timeoutMS := args.Timeout
	if timeoutMS == 0 {
		timeoutMS = defaultTimeoutMS
	}
	return t.runForeground(ctx, cmdText, cwd, time.Duration(timeoutMS)*time.Millisecond)
}

// ── cd state machine ──────────────────────────────────────────────────────────

// parseCDOnly returns (target, true) when cmd is exactly `cd` or
// `cd <path>` (no &&, no ;, no |). target may be empty meaning "home".
//
// parseCDOnly 在 cmd 恰为 `cd` 或 `cd <path>`（无 && / ; / |）时返
// (target, true)；target 为空意味着 home。
func parseCDOnly(cmd string) (string, bool) {
	trimmed := strings.TrimSpace(cmd)
	if trimmed == "cd" {
		return "", true
	}
	if !strings.HasPrefix(trimmed, "cd ") && !strings.HasPrefix(trimmed, "cd\t") {
		return "", false
	}
	rest := strings.TrimSpace(strings.TrimPrefix(trimmed, "cd"))
	// Reject anything that contains shell metachars suggesting a chain.
	// 拒绝任何看起来像链式的 shell 元字符。
	if strings.ContainsAny(rest, "&|;<>`$") {
		return "", false
	}
	// Strip a single layer of surrounding quotes for ergonomics.
	// 去一层包裹引号，体验更顺。
	if len(rest) >= 2 && (rest[0] == '"' || rest[0] == '\'') && rest[0] == rest[len(rest)-1] {
		rest = rest[1 : len(rest)-1]
	}
	return rest, true
}

// handleCD validates the target dir, updates AgentState, and returns a
// confirmation. AgentState absent (chat layer didn't wire it) is reported
// as a soft error so the LLM can recover rather than being told nothing.
//
// handleCD 校验目标目录、更新 AgentState、返确认。AgentState 缺失（chat
// 层未接线）报软错让 LLM 可恢复。
func (t *Bash) handleCD(ctx context.Context, target string) (string, error) {
	if target == "" {
		if h, err := os.UserHomeDir(); err == nil {
			target = h
		} else {
			return "Cannot resolve home directory: " + err.Error(), nil
		}
	}
	// Resolve relative to current cwd.
	// 对 current cwd 解析相对路径。
	current := resolveCwd(ctx)
	if !filepath.IsAbs(target) {
		target = filepath.Join(current, target)
	}
	target = filepath.Clean(target)

	info, err := os.Stat(target)
	if err != nil {
		return fmt.Sprintf("cd: %s: %v", target, err), nil
	}
	if !info.IsDir() {
		return fmt.Sprintf("cd: not a directory: %s", target), nil
	}

	state, ok := reqctxpkg.GetAgentState(ctx)
	if !ok {
		return "cd: agent state missing — cwd not persisted across calls. Subsequent commands will use the process default cwd.", nil
	}
	state.SetCwd(target)
	return "Changed working directory to " + target, nil
}

// resolveCwd returns the conversation's tracked cwd, falling back to the
// process cwd when AgentState is missing or empty.
//
// resolveCwd 返对话级 cwd；AgentState 缺失或空时回落到进程 cwd。
func resolveCwd(ctx context.Context) string {
	if state, ok := reqctxpkg.GetAgentState(ctx); ok {
		if c := state.Cwd(); c != "" {
			return c
		}
	}
	if c, err := os.Getwd(); err == nil {
		return c
	}
	return "/"
}

// ── Foreground run ────────────────────────────────────────────────────────────

// runForeground execs command with a hard wall-clock timeout, captures
// combined stdout+stderr (capped), and returns a formatted result.
//
// runForeground 带硬墙钟超时执行 command，捕获合并 stdout+stderr（截断），
// 返格式化结果。
func (t *Bash) runForeground(ctx context.Context, command, cwd string, timeout time.Duration) (string, error) {
	runCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	cmd := buildShellCmd(runCtx, command, cwd)
	var buf bytes.Buffer
	cmd.Stdout = &buf
	cmd.Stderr = &buf

	err := cmd.Run()
	output := capOutput(buf.Bytes())

	switch {
	case errors.Is(runCtx.Err(), context.DeadlineExceeded):
		return formatForegroundResult(output, -1, fmt.Sprintf("command timed out after %s", timeout)), nil
	case err != nil:
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			return formatForegroundResult(output, exitErr.ExitCode(), ""), nil
		}
		return formatForegroundResult(output, -1, "exec failed: "+err.Error()), nil
	}
	return formatForegroundResult(output, 0, ""), nil
}

// formatForegroundResult assembles the body + status footer the LLM sees.
// Output-empty case still includes the footer so the LLM never has to
// guess "did anything happen?".
//
// formatForegroundResult 拼正文 + 状态尾注；输出为空也带尾注，让 LLM 不必
// 猜"有没有跑成功"。
func formatForegroundResult(output string, exitCode int, note string) string {
	var sb strings.Builder
	sb.WriteString(output)
	if !strings.HasSuffix(output, "\n") {
		sb.WriteString("\n")
	}
	sb.WriteString("\n")
	if note != "" {
		fmt.Fprintf(&sb, "[%s]\n", note)
	}
	fmt.Fprintf(&sb, "[exit code: %d]", exitCode)
	return sb.String()
}

// capOutput trims output to outputCapBytes, indicating truncation when
// it had to cut.
//
// capOutput 截到 outputCapBytes，截断时附标注。
func capOutput(b []byte) string {
	if len(b) <= outputCapBytes {
		return string(b)
	}
	dropped := len(b) - outputCapBytes
	return fmt.Sprintf("...[truncated %d bytes from start]\n", dropped) + string(b[len(b)-outputCapBytes:])
}

// ── Background spawn ──────────────────────────────────────────────────────────

// runBackground starts the command without waiting, registers a BgProcess
// in the manager, and returns the assigned bash_id. The Wait+output pump
// run in a child goroutine that updates the BgProcess on completion.
//
// runBackground 不等待启动 command，注册 BgProcess 并返 bash_id；Wait + 输出
// pump 在子 goroutine 跑，结束时更新 BgProcess。
func (t *Bash) runBackground(ctx context.Context, command, cwd string) (string, error) {
	convID, _ := reqctxpkg.GetConversationID(ctx)
	cmd := buildShellCmd(context.Background(), command, cwd)

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return fmt.Sprintf("Failed to open stdout pipe: %v", err), nil
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return fmt.Sprintf("Failed to open stderr pipe: %v", err), nil
	}

	if err := cmd.Start(); err != nil {
		return fmt.Sprintf("Failed to start background command: %v", err), nil
	}

	proc := &BgProcess{
		ConvID:    convID,
		Command:   command,
		Cmd:       cmd,
		StartedAt: time.Now(),
		status:    StatusRunning,
	}
	t.mgr.Register(proc)

	// Pump stdout + stderr into the ring buffer concurrently so a noisy
	// process doesn't deadlock by filling one pipe.
	// 并发把 stdout + stderr 灌进环形缓冲，防一根管满死锁。
	var pumpWG sync.WaitGroup
	pumpWG.Add(2)
	go pumpReader(&pumpWG, proc, stdout)
	go pumpReader(&pumpWG, proc, stderr)

	// Reaper goroutine: wait for pumps to drain, then Wait the child to
	// reap zombies + capture exit code.
	// reaper goroutine：等 pump 排空再 Wait 子进程，reap 僵尸 + 抓 exit code。
	go func() {
		pumpWG.Wait()
		err := cmd.Wait()
		switch {
		case err == nil:
			proc.markFinished(StatusExited, 0)
		default:
			var exitErr *exec.ExitError
			if errors.As(err, &exitErr) {
				if exitErr.ProcessState != nil && exitErr.ProcessState.Exited() {
					proc.markFinished(StatusExited, exitErr.ExitCode())
				} else {
					// Killed by signal — exit code is -1 in Go's model.
					// 被信号杀——Go 模型中 exit code 是 -1。
					proc.markFinished(StatusKilled, -1)
				}
			} else {
				proc.markErrored(err)
			}
		}
	}()

	return fmt.Sprintf(
		"Started background command (bash_id=%s): %s\nUse BashOutput with this bash_id to poll new output, or KillShell to terminate.",
		proc.ID, command,
	), nil
}

// pumpReader copies r into proc.appendOutput until EOF.
//
// pumpReader 把 r 拷贝到 proc.appendOutput 直至 EOF。
func pumpReader(wg *sync.WaitGroup, proc *BgProcess, r io.Reader) {
	defer wg.Done()
	buf := make([]byte, 4096)
	for {
		n, err := r.Read(buf)
		if n > 0 {
			proc.appendOutput(buf[:n])
		}
		if err != nil {
			return
		}
	}
}

// ── Shell command builder ─────────────────────────────────────────────────────

// buildShellCmd creates the *exec.Cmd to run the user's command. We use
// `sh -c "<cmd>"` on Unix (Forgify is Wails desktop targeting macOS/Linux
// primarily; Windows would need cmd.exe / PowerShell — out of scope).
//
// buildShellCmd 构造 *exec.Cmd。Unix 用 `sh -c "<cmd>"`（Forgify 目标
// macOS/Linux；Windows 走 cmd.exe / PowerShell——超出本期范围）。
func buildShellCmd(ctx context.Context, command, cwd string) *exec.Cmd {
	shell := "/bin/sh"
	if runtime.GOOS == "windows" {
		// Best-effort Windows support; not officially in scope.
		// Windows 尽力支持；非本期目标。
		shell = "cmd"
	}
	var cmd *exec.Cmd
	if runtime.GOOS == "windows" {
		cmd = exec.CommandContext(ctx, shell, "/c", command)
	} else {
		cmd = exec.CommandContext(ctx, shell, "-c", command)
	}
	cmd.Dir = cwd
	cmd.Env = os.Environ()
	return cmd
}

// ── Compile-time checks ───────────────────────────────────────────────────────

var _ toolapp.Tool = (*Bash)(nil)
