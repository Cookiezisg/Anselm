// spawn.go — process spawning helpers used by app/sandbox.Service.Spawn /
// SpawnLongLived. Wraps os/exec with the platform-specific process-tree
// management from proc_linux/darwin/windows.go so the app layer does not
// touch exec.Cmd directly.
//
// Two entry points:
//
//   - SpawnOnce: runs the command to completion, collects stdout/stderr
//     into an ExecutionResult. Honors ctx-cancel via the platform's
//     killProcessGroup callback.
//   - SpawnLongLived: starts the command, wires stdio pipes, returns a
//     LongLivedHandle for the caller to drive (typical use: MCP server
//     stdio JSON-RPC, Bash background processes).
//
// Neither helper knows anything about sandbox business state (owner /
// env / runtime). The caller (app/sandbox.Service) is responsible for
// resolving the binary path, cwd, and env via EnvManager + ToolRegistry
// before constructing SpawnOptions.
//
// spawn.go ——给 app/sandbox.Service.Spawn / SpawnLongLived 用的进程 spawn
// 辅助。把 os/exec 和 proc_linux/darwin/windows.go 的平台特定进程树管理
// 包一层，让 app 层不直接碰 exec.Cmd。
//
// 两个入口：
//
//   - SpawnOnce：跑命令到完成，收 stdout/stderr 进 ExecutionResult。
//     通过平台的 killProcessGroup callback 接 ctx-cancel。
//   - SpawnLongLived：启动命令、布 stdio 管道、返 LongLivedHandle 给调用方
//     驱动（典型用：MCP server stdio JSON-RPC、Bash 后台进程）。
//
// 两个 helper 都不知 sandbox 业务状态（owner / env / runtime）。调用方
// （app/sandbox.Service）负责构 SpawnOptions 前通过 EnvManager + ToolRegistry
// 解析 binary 路径、cwd、env。

package sandbox

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"os/exec"
	"time"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

// SpawnOptions packages the inputs to SpawnOnce / SpawnLongLived. All
// fields are absolute / fully resolved by the caller — this layer does
// not look up anything by name.
//
// SpawnOptions 打包 SpawnOnce / SpawnLongLived 入参。所有字段由调用方解析为
// 绝对值——本层不按名查任何东西。
type SpawnOptions struct {
	Cmd   string   // absolute path to the binary (caller resolved via EnvBin / ToolRegistry)
	Args  []string // command-line arguments (excluding binary itself)
	Cwd   string   // working directory; usually EnvDir(envPath)
	Env   []string // full env list (not overlay) — caller pre-merged base + per-env overrides
	Stdin []byte   // optional one-shot stdin; nil means no stdin
}

// SpawnOnce runs the command to completion. ctx-cancel propagates via
// killProcessGroup (negative-pid SIGKILL on unix, taskkill on Windows).
// Returns ExecutionResult with Ok=true on exit code 0, Ok=false on
// non-zero (the subprocess "ran but failed" — caller often passes this
// to the LLM as a tool_result without further wrapping). Returns a Go
// error only on infrastructure failure (couldn't start, ctx error
// without subprocess having run, etc.).
//
// SpawnOnce 跑命令到完成。ctx-cancel 通过 killProcessGroup 传播
// （unix 负 pid SIGKILL，Windows taskkill）。退出码 0 返 Ok=true，非 0
// 返 Ok=false（子进程"跑了但失败"——调用方常直接当 tool_result 传给 LLM 不
// 再包装）。仅基础设施失败（启不起来、ctx 错且子进程未跑等）才返 Go error。
func SpawnOnce(ctx context.Context, opts SpawnOptions) (*sandboxdomain.ExecutionResult, error) {
	cmd := exec.CommandContext(ctx, opts.Cmd, opts.Args...)
	cmd.Dir = opts.Cwd
	if len(opts.Env) > 0 {
		cmd.Env = opts.Env
	}
	if len(opts.Stdin) > 0 {
		cmd.Stdin = bytes.NewReader(opts.Stdin)
	}

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	setupProcessGroup(cmd)
	cmd.Cancel = func() error { return killProcessGroup(cmd) }

	start := time.Now()
	runErr := cmd.Run()
	elapsed := time.Since(start)

	result := &sandboxdomain.ExecutionResult{
		Stdout:   stdout.Bytes(),
		Stderr:   stderr.Bytes(),
		Duration: elapsed,
	}

	if runErr == nil {
		result.Ok = true
		return result, nil
	}

	// Subprocess ran but exited non-zero — surface as Ok=false, not Go error.
	// 子进程跑了但非零退出——返 Ok=false 而非 Go error。
	var exitErr *exec.ExitError
	if errors.As(runErr, &exitErr) {
		result.Ok = false
		result.ExitCode = exitErr.ExitCode()
		return result, nil
	}

	// Genuine infrastructure failure (start failed, ctx-cancel before
	// process started, etc.) — wrap with sentinel for errmap mapping.
	//
	// 基础设施真失败（启动失败、子进程未启动 ctx-cancel 等）——包 sentinel
	// 给 errmap 映射用。
	if errors.Is(runErr, context.DeadlineExceeded) {
		return result, fmt.Errorf("sandbox.SpawnOnce: %w", sandboxdomain.ErrSpawnTimeout)
	}
	return result, fmt.Errorf("sandbox.SpawnOnce: %w (cause: %w)", sandboxdomain.ErrSpawnFailed, runErr)
}

// SpawnLongLived starts the command and wires stdio pipes, returning a
// handle the caller drives. The caller MUST eventually call handle.Wait()
// or handle.Kill() to release OS resources — Service tracks active
// handles and cleans up at Shutdown (Layer A) but per-call lifecycle
// stays the caller's responsibility while alive.
//
// SpawnLongLived 启动命令布 stdio 管道，返 handle 给调用方驱动。调用方
// 最终**必须**调 handle.Wait() 或 handle.Kill() 释放 OS 资源——Service
// 跟踪 active handle 并在 Shutdown（层 A）清理，但活着时 per-call 生命周期
// 仍是调用方责任。
func SpawnLongLived(ctx context.Context, opts SpawnOptions) (sandboxdomain.LongLivedHandle, error) {
	cmd := exec.CommandContext(ctx, opts.Cmd, opts.Args...)
	cmd.Dir = opts.Cwd
	if len(opts.Env) > 0 {
		cmd.Env = opts.Env
	}

	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, fmt.Errorf("sandbox.SpawnLongLived: stdin pipe: %w (spawn: %w)", err, sandboxdomain.ErrSpawnFailed)
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		_ = stdin.Close()
		return nil, fmt.Errorf("sandbox.SpawnLongLived: stdout pipe: %w (spawn: %w)", err, sandboxdomain.ErrSpawnFailed)
	}
	stderrR, err := cmd.StderrPipe()
	if err != nil {
		_ = stdin.Close()
		_ = stdout.Close()
		return nil, fmt.Errorf("sandbox.SpawnLongLived: stderr pipe: %w (spawn: %w)", err, sandboxdomain.ErrSpawnFailed)
	}

	setupProcessGroup(cmd)
	cmd.Cancel = func() error { return killProcessGroup(cmd) }

	if err := cmd.Start(); err != nil {
		_ = stdin.Close()
		_ = stdout.Close()
		_ = stderrR.Close()
		return nil, fmt.Errorf("sandbox.SpawnLongLived: start: %w (spawn: %w)", err, sandboxdomain.ErrSpawnFailed)
	}

	return &longLivedHandle{
		cmd:    cmd,
		stdin:  stdin,
		stdout: stdout,
		stderr: stderrR,
	}, nil
}

// longLivedHandle implements sandboxdomain.LongLivedHandle by wrapping
// an exec.Cmd. Stdin/Stdout/Stderr expose the pipes set up before Start;
// Wait blocks until the process exits and reaps it; Kill terminates the
// entire process group (or job, on Windows).
//
// longLivedHandle 通过包装 exec.Cmd 实现 sandboxdomain.LongLivedHandle。
// Stdin/Stdout/Stderr 暴露 Start 前布的管道；Wait 阻塞直到进程退出并 reap；
// Kill 终止整个进程组（Windows 上是 job）。
type longLivedHandle struct {
	cmd    *exec.Cmd
	stdin  io.WriteCloser
	stdout io.ReadCloser
	stderr io.ReadCloser
}

func (h *longLivedHandle) Stdin() io.WriteCloser  { return h.stdin }
func (h *longLivedHandle) Stdout() io.ReadCloser  { return h.stdout }
func (h *longLivedHandle) Stderr() io.ReadCloser  { return h.stderr }

// Wait blocks until the subprocess exits and returns its run error.
// Idempotent on the underlying exec.Cmd — once Wait returns, subsequent
// calls return the cached result.
//
// Wait 阻塞直到子进程退出，返其 run 错。底层 exec.Cmd 上幂等——Wait 返后
// 后续调用返缓存结果。
func (h *longLivedHandle) Wait() error { return h.cmd.Wait() }

// Kill sends SIGKILL to the process group (unix) or runs taskkill /T /F
// (Windows). Idempotent — killing an already-dead process is a no-op
// (killProcessGroup checks cmd.Process == nil).
//
// Kill 给进程组发 SIGKILL（unix）或跑 taskkill /T /F（Windows）。幂等——
// 杀已死进程是 no-op（killProcessGroup 检查 cmd.Process == nil）。
func (h *longLivedHandle) Kill() error { return killProcessGroup(h.cmd) }

// PID returns the subprocess PID, or 0 if Start hasn't completed.
//
// PID 返子进程 PID；Start 未完成返 0。
func (h *longLivedHandle) PID() int {
	if h.cmd.Process == nil {
		return 0
	}
	return h.cmd.Process.Pid
}
