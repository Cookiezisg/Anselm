// envmanager_node.go — pnpm-backed EnvManager for Node plugin envs.
//
// pnpm installs to <envPath>/node_modules/ via `pnpm add <pkgs...>` from
// envPath. pnpm's content-addressable global store at
// ~/.local/share/pnpm/store keeps a single copy of every (package, version)
// tuple on disk; per-env node_modules is symlinks into that store. N envs
// depending on the same `playwright@1.50.0` share one disk-bytes copy.
//
// pnpm is treated as a support tool: NodeEnvManager resolves it via
// sandboxdomain.ToolRegistry on each operation, which lazily installs pnpm
// on first use (mise-managed in production; pre-seeded in tests).
//
// envmanager_node.go ——基于 pnpm 的 Node plugin env EnvManager。
//
// pnpm 用 `pnpm add <pkgs...>` 在 envPath 装到 <envPath>/node_modules/。
// pnpm 的 content-addressable 全局 store（~/.local/share/pnpm/store）每个
// (package, version) 元组只有一份磁盘 copy；per-env node_modules 是指向 store
// 的 symlink。N 个依赖 `playwright@1.50.0` 的 env 共享一份磁盘字节。
//
// pnpm 当作支持工具：NodeEnvManager 每次操作经 sandboxdomain.ToolRegistry
// 解析 pnpm 路径，首次使用时懒装（生产 mise 管，测试预填）。

package sandbox

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

// NodeEnvManager satisfies sandboxdomain.EnvManager for Node.
//
// NodeEnvManager 满足 sandboxdomain.EnvManager 的 Node 实现。
type NodeEnvManager struct {
	tools sandboxdomain.ToolRegistry // resolves pnpm binary lazily on first use
}

// NewNodeEnvManager constructs the manager. tools must be a working
// ToolRegistry (typically the sandbox app Service). NodeEnvManager calls
// tools.EnsureTool(ctx, "pnpm", "") whenever it needs pnpm.
//
// NewNodeEnvManager 构造 manager。tools 必须是可工作的 ToolRegistry（通常
// sandbox app Service）。NodeEnvManager 需要 pnpm 时调
// tools.EnsureTool(ctx, "pnpm", "")。
func NewNodeEnvManager(tools sandboxdomain.ToolRegistry) *NodeEnvManager {
	return &NodeEnvManager{tools: tools}
}

// Kind reports the dispatch key — must match MiseInstaller("node").
//
// Kind 报告派发键——必须匹配 MiseInstaller("node")。
func (n *NodeEnvManager) Kind() string { return "node" }

// CreateEnv writes a minimal package.json to envPath so subsequent
// `pnpm install` / `pnpm add` commands have an anchor. Idempotent — already-
// existing package.json returns nil.
//
// CreateEnv 在 envPath 写最小 package.json，让后续 `pnpm install` /
// `pnpm add` 有锚点。幂等——已存在的 package.json 返 nil。
func (n *NodeEnvManager) CreateEnv(ctx context.Context, runtimePath, envPath string) error {
	pkgJSON := filepath.Join(envPath, "package.json")
	if _, err := os.Stat(pkgJSON); err == nil {
		return nil
	}
	if err := os.MkdirAll(envPath, 0o755); err != nil {
		return fmt.Errorf("sandbox.NodeEnvManager.CreateEnv: mkdir env: %w", err)
	}
	// Minimal package.json — name derived from envPath, private to prevent
	// accidental publish, no scripts/deps so pnpm has nothing to interpret
	// at install time other than what we explicitly add.
	//
	// 最小 package.json——name 从 envPath 派生，private 防误发，无 scripts/deps
	// 让 pnpm 在 install 时只解释我们显式 add 的东西。
	manifest := map[string]any{
		"name":    "forgify-env-" + filepath.Base(envPath),
		"version": "0.0.0",
		"private": true,
	}
	data, err := json.MarshalIndent(manifest, "", "  ")
	if err != nil {
		return fmt.Errorf("sandbox.NodeEnvManager.CreateEnv: marshal pkg: %w", err)
	}
	if err := os.WriteFile(pkgJSON, data, 0o644); err != nil {
		return fmt.Errorf("sandbox.NodeEnvManager.CreateEnv: write pkg: %w (env: %w)", err, sandboxdomain.ErrEnvCreateFailed)
	}
	return nil
}

// InstallDeps runs `pnpm add <deps...>` from envPath. pnpm hardlinks /
// symlinks into the global content-addressable store, so installing the
// same dep tree across N envs costs roughly one tree's worth of bytes.
// stream callbacks fire per stderr line.
//
// InstallDeps 在 envPath 跑 `pnpm add <deps...>`。pnpm 从全局
// content-addressable store hardlink/symlink，N 个 env 装相同 dep 树总共
// 约一份字节。stream 在每行 stderr 触发。
func (n *NodeEnvManager) InstallDeps(ctx context.Context, runtimePath, envPath string, deps []string, stream sandboxdomain.ProgressFunc) error {
	if len(deps) == 0 {
		return nil
	}
	pnpmBin, err := n.tools.EnsureTool(ctx, "pnpm", "")
	if err != nil {
		return fmt.Errorf("sandbox.NodeEnvManager.InstallDeps: locate pnpm: %w", err)
	}
	args := append([]string{"add"}, deps...)
	cmd := exec.CommandContext(ctx, pnpmBin, args...)
	cmd.Dir = envPath

	stderrPipe, err := cmd.StderrPipe()
	if err != nil {
		return fmt.Errorf("sandbox.NodeEnvManager.InstallDeps: stderr pipe: %w", err)
	}
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("sandbox.NodeEnvManager.InstallDeps: start: %w", err)
	}

	if stream != nil {
		scanner := bufio.NewScanner(stderrPipe)
		for scanner.Scan() {
			stream("installing-deps", scanner.Text(), -1)
		}
	} else {
		_, _ = io.Copy(io.Discard, stderrPipe)
	}

	if err := cmd.Wait(); err != nil {
		return fmt.Errorf("sandbox.NodeEnvManager.InstallDeps %v: %w", deps, sandboxdomain.ErrDepInstallFailed)
	}
	return nil
}

// InstallExtras is a no-op for Node — Node plugins declare runtime deps
// only. Browser binary downloads (Playwright's chromium) live in the
// dedicated PlaywrightEnvManager which orchestrates `playwright install`
// after the npm package itself is in node_modules.
//
// InstallExtras Node 上是 no-op——Node plugin 只声明 runtime deps。浏览器
// 二进制下载（Playwright 的 chromium）在专用的 PlaywrightEnvManager 里编排，
// 在 npm 包本身已进 node_modules 之后跑 `playwright install`。
func (n *NodeEnvManager) InstallExtras(ctx context.Context, runtimePath, envPath string, extras []string, stream sandboxdomain.ProgressFunc) error {
	return nil
}

// EnvBin returns the absolute path to a binary inside the env's
// node_modules/.bin/ shim directory (npm/pnpm convention). On Windows
// pnpm generates *.cmd / *.ps1 wrappers; we tack on .cmd if the caller
// did not provide an extension.
//
// EnvBin 返 env 的 node_modules/.bin/ shim 目录中某 binary 绝对路径
// （npm/pnpm 约定）。Windows 上 pnpm 生成 *.cmd / *.ps1 包装；调用方
// 未传扩展名时加 .cmd。
func (n *NodeEnvManager) EnvBin(envPath, binName string) string {
	if runtime.GOOS == "windows" && filepath.Ext(binName) == "" {
		binName += ".cmd"
	}
	return filepath.Join(envPath, "node_modules", ".bin", binName)
}

// EnvDir returns the env root.
//
// EnvDir 返 env 根目录。
func (n *NodeEnvManager) EnvDir(envPath string) string { return envPath }
