// envmanager_python.go — uv-backed EnvManager for Python plugin envs.
//
// Builds isolated venvs at <envPath>/.venv via `uv venv`, installs deps via
// `uv pip install`. uv is treated as a support tool: PythonEnvManager
// resolves it via sandboxdomain.ToolRegistry on each operation, which lazily
// installs uv on first use (mise-managed in production; pre-seeded in tests).
//
// Cross-env disk sharing: uv hardlinks wheels from its global cache by
// default. Multiple Forge / MCP / conversation envs that depend on the
// same `pandas==2.2.3` consume only ~one wheel's worth of inodes total.
//
// envmanager_python.go ——基于 uv 的 Python plugin env EnvManager。
//
// 通过 `uv venv` 在 <envPath>/.venv 建隔离 venv，`uv pip install` 装 deps。
// uv 当作支持工具：PythonEnvManager 每次操作经 sandboxdomain.ToolRegistry
// 解析 uv 路径，首次使用时懒装（生产 mise 管，测试预填）。
//
// 跨 env 磁盘共享：uv 默认从全局缓存 hardlink wheel。多个依赖
// `pandas==2.2.3` 的 Forge / MCP / conversation env 总共只占 ~一份 wheel 的
// inode。

package sandbox

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

// PythonEnvManager satisfies sandboxdomain.EnvManager for Python.
//
// PythonEnvManager 满足 sandboxdomain.EnvManager 的 Python 实现。
type PythonEnvManager struct {
	tools sandboxdomain.ToolRegistry // resolves uv binary lazily on first use
}

// NewPythonEnvManager constructs the manager. tools must be a working
// ToolRegistry (typically the sandbox app Service). PythonEnvManager calls
// tools.EnsureTool(ctx, "uv", "") whenever it needs uv — first call triggers
// install, subsequent calls hit the manifest cache.
//
// NewPythonEnvManager 构造 manager。tools 必须是可工作的 ToolRegistry（通常
// sandbox app Service）。PythonEnvManager 需要 uv 时调
// tools.EnsureTool(ctx, "uv", "")——首次调用触发装，后续命中 manifest 缓存。
func NewPythonEnvManager(tools sandboxdomain.ToolRegistry) *PythonEnvManager {
	return &PythonEnvManager{tools: tools}
}

// Kind reports the EnvManager dispatch key — must match the
// MiseInstaller("python") used to install the runtime.
//
// Kind 报告 EnvManager 派发键——必须匹配装 runtime 用的
// MiseInstaller("python")。
func (p *PythonEnvManager) Kind() string { return "python" }

// CreateEnv runs `uv venv --python <runtimePath> <envPath>/.venv`. runtimePath
// is the absolute path to the Python interpreter (e.g. <miseInstallDir>/bin/python).
// Idempotent — already-existing .venv returns nil.
//
// CreateEnv 跑 `uv venv --python <runtimePath> <envPath>/.venv`。runtimePath
// 是 Python 解释器绝对路径（如 <miseInstallDir>/bin/python）。幂等——
// .venv 已存在返 nil。
func (p *PythonEnvManager) CreateEnv(ctx context.Context, runtimePath, envPath string) error {
	venvDir := filepath.Join(envPath, ".venv")
	if _, err := os.Stat(venvDir); err == nil {
		return nil
	}
	if err := os.MkdirAll(envPath, 0o755); err != nil {
		return fmt.Errorf("sandbox.PythonEnvManager.CreateEnv: mkdir env: %w", err)
	}
	uvBin, err := p.tools.EnsureTool(ctx, "uv", "")
	if err != nil {
		return fmt.Errorf("sandbox.PythonEnvManager.CreateEnv: locate uv: %w", err)
	}
	cmd := exec.CommandContext(ctx, uvBin, "venv", "--python", runtimePath, venvDir)
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("sandbox.PythonEnvManager.CreateEnv %s: %w: %v (uv output: %s)",
			venvDir, sandboxdomain.ErrEnvCreateFailed, err, strings.TrimSpace(string(out)))
	}
	return nil
}

// InstallDeps invokes `uv pip install --python <venv>/bin/python <deps...>`.
// uv hardlinks shared wheels from its global cache, so installing the same
// deps in N envs costs roughly one wheel's worth of disk total. stream
// callbacks fire for each stderr line (uv prints "Downloading numpy..."
// "Installed 14 packages" etc.); pass nil to suppress progress.
//
// InstallDeps 调 `uv pip install --python <venv>/bin/python <deps...>`。
// uv 从全局缓存 hardlink 共享 wheel，N 个 env 装相同 deps 总共只费 ~一份
// wheel。stream 在每行 stderr 触发（uv 打印 "Downloading numpy..."、
// "Installed 14 packages" 等）；传 nil 跳过进度。
func (p *PythonEnvManager) InstallDeps(ctx context.Context, runtimePath, envPath string, deps []string, stream sandboxdomain.ProgressFunc) error {
	if len(deps) == 0 {
		return nil
	}
	uvBin, err := p.tools.EnsureTool(ctx, "uv", "")
	if err != nil {
		return fmt.Errorf("sandbox.PythonEnvManager.InstallDeps: locate uv: %w", err)
	}
	venvPython := filepath.Join(envPath, ".venv", venvBinSubdir(), pythonExe())
	args := append([]string{"pip", "install", "--python", venvPython}, deps...)
	cmd := exec.CommandContext(ctx, uvBin, args...)

	return RunWithStderrCapture(cmd, stream,
		sandboxdomain.ErrDepInstallFailed,
		fmt.Sprintf("sandbox.PythonEnvManager.InstallDeps %v", deps))
}

// InstallExtras is a no-op for Python — the extras concept (e.g.
// "browsers/chromium" for Playwright) lives on the Node side. Python plugins
// declare runtime deps only.
//
// InstallExtras Python 上是 no-op——extras 概念（如 Playwright 的
// "browsers/chromium"）在 Node 那侧。Python plugin 只声明 runtime deps。
func (p *PythonEnvManager) InstallExtras(ctx context.Context, runtimePath, envPath string, extras []string, stream sandboxdomain.ProgressFunc) error {
	return nil
}

// EnvBin returns the absolute path to a binary inside the env's venv
// (e.g. EnvBin(envPath, "python") → "<envPath>/.venv/bin/python" on unix
// or "<envPath>/.venv/Scripts/python.exe" on Windows).
//
// EnvBin 返 env 的 venv 内某 binary 绝对路径
// （unix 上 "<envPath>/.venv/bin/python"；
//
//	Windows 上 "<envPath>/.venv/Scripts/python.exe"）。
func (p *PythonEnvManager) EnvBin(envPath, binName string) string {
	if runtime.GOOS == "windows" && filepath.Ext(binName) == "" {
		binName += ".exe"
	}
	return filepath.Join(envPath, ".venv", venvBinSubdir(), binName)
}

// EnvDir returns the env root — used by Spawn as cwd candidate.
//
// EnvDir 返 env 根目录——Spawn 用作 cwd 候选。
func (p *PythonEnvManager) EnvDir(envPath string) string { return envPath }

// venvBinSubdir returns the per-OS subdirectory inside .venv where binaries
// live: "Scripts" on Windows, "bin" elsewhere. Standard Python venv layout.
//
// venvBinSubdir 返 .venv 内 per-OS binary 子目录：Windows 是 "Scripts"，
// 其他是 "bin"。标准 Python venv 布局。
func venvBinSubdir() string {
	if runtime.GOOS == "windows" {
		return "Scripts"
	}
	return "bin"
}

// pythonExe returns the Python interpreter file name for the current OS.
//
// pythonExe 返当前 OS 的 Python 解释器文件名。
func pythonExe() string {
	if runtime.GOOS == "windows" {
		return "python.exe"
	}
	return "python"
}
