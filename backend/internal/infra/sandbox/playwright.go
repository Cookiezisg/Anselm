// playwright.go — Playwright runtime support: PlaywrightInstaller (browser
// binary download via the playwright CLI) + PlaywrightEnvManager (Node-
// env wrapper that drives the CLI inside an env after pnpm-installing
// the playwright npm package).
//
// Layout per Playwright env:
//
//	<envPath>/package.json                       # NodeEnvManager.CreateEnv writes
//	<envPath>/node_modules/playwright/...        # NodeEnvManager.InstallDeps adds
//	<envPath>/node_modules/.bin/playwright       # CLI shim used by PlaywrightInstaller
//	<sandboxRoot>/playwright-browsers/...        # SHARED across all Playwright envs
//
// The shared browsers cache (PLAYWRIGHT_BROWSERS_PATH) is the key
// optimization: Chromium alone is 300+ MB, so per-env download would
// blow up disk; one cache serves all envs.
//
// playwright.go ——Playwright runtime 支持：PlaywrightInstaller（通过 playwright
// CLI 下浏览器二进制）+ PlaywrightEnvManager（Node-env 包装，pnpm 装好
// playwright npm 包后驱动 env 内 CLI）。
//
// 单 Playwright env 布局见上方英文段。
//
// 共享浏览器缓存（PLAYWRIGHT_BROWSERS_PATH）是关键优化：单 Chromium
// 300+ MB，per-env 下载会爆磁盘；一份缓存服务所有 env。

package sandbox

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

// playwrightBrowsersSubdir is where browser binaries land relative to
// sandboxRoot. Set as PLAYWRIGHT_BROWSERS_PATH so all envs share one
// browser cache (Chromium 300+ MB is too big to per-env duplicate).
//
// playwrightBrowsersSubdir 是浏览器二进制相对 sandboxRoot 的位置。设为
// PLAYWRIGHT_BROWSERS_PATH 让所有 env 共享一份浏览器缓存（Chromium 300+ MB
// 不适合 per-env 复制）。
const playwrightBrowsersSubdir = "playwright-browsers"

// ── PlaywrightInstaller ──────────────────────────────────────────────

// PlaywrightInstaller installs the requested browser via the Playwright
// CLI. The "version" parameter on Install/Locate is the browser channel
// name ("chromium" / "firefox" / "webkit"); we ignore RuntimeSpec.Version
// granularity because Playwright pins browser versions internally per
// playwright npm package version.
//
// PlaywrightInstaller 通过 Playwright CLI 装请求的浏览器。Install/Locate
// 上的 "version" 参数是浏览器频道名（"chromium" / "firefox" / "webkit"）；
// 我们忽略 RuntimeSpec.Version 颗粒度，因 Playwright 内部按 playwright npm 包
// 版本钉死浏览器版本。
type PlaywrightInstaller struct {
	playwrightCLI string // absolute path to playwright CLI shim (typically <env>/node_modules/.bin/playwright)
}

// NewPlaywrightInstaller constructs an installer bound to a specific
// playwright CLI binary. Caller (sandbox service) must ensure the env
// containing playwright npm package has been built first.
//
// NewPlaywrightInstaller 构造绑到指定 playwright CLI 二进制的 installer。
// 调用方（sandbox service）必须先确保含 playwright npm 包的 env 已建。
func NewPlaywrightInstaller(playwrightCLI string) *PlaywrightInstaller {
	return &PlaywrightInstaller{playwrightCLI: playwrightCLI}
}

// Kind reports the dispatch key for browser-style runtimes.
//
// Kind 报告浏览器类 runtime 的派发键。
func (p *PlaywrightInstaller) Kind() string { return "browsers" }

// Install runs `playwright install <browser>` with PLAYWRIGHT_BROWSERS_PATH
// pointed at <sandboxRoot>/playwright-browsers/. version is the browser
// channel name. Returns the relative path under sandboxRoot where the
// browser was installed (the shared cache root, identical for all
// browsers — Playwright sub-dirs each browser).
//
// Install 跑 `playwright install <browser>` + PLAYWRIGHT_BROWSERS_PATH 指
// <sandboxRoot>/playwright-browsers/。version 是浏览器频道名。返浏览器装到
// sandboxRoot 下的相对路径（共享缓存根，所有浏览器一致——Playwright 自己
// 子目录化每个浏览器）。
func (p *PlaywrightInstaller) Install(ctx context.Context, version, sandboxRoot string, stream sandboxdomain.ProgressFunc) (string, error) {
	browsersDir := filepath.Join(sandboxRoot, playwrightBrowsersSubdir)
	if err := os.MkdirAll(browsersDir, 0o755); err != nil {
		return "", fmt.Errorf("sandbox.PlaywrightInstaller.Install: mkdir browsers dir: %w", err)
	}

	cmd := exec.CommandContext(ctx, p.playwrightCLI, "install", version)
	cmd.Env = append(os.Environ(), "PLAYWRIGHT_BROWSERS_PATH="+browsersDir)

	if err := RunWithStderrCapture(cmd, stream,
		sandboxdomain.ErrRuntimeInstallFailed,
		fmt.Sprintf("sandbox.PlaywrightInstaller.Install %s", version)); err != nil {
		return "", err
	}
	return playwrightBrowsersSubdir, nil
}

// Locate returns the absolute path to the browsers cache root for the
// given sandboxRoot. Caller (typically Playwright server inside an env)
// uses PLAYWRIGHT_BROWSERS_PATH to point at this dir; the actual binary
// path under it depends on browser + version which Playwright resolves
// internally.
//
// Locate 返浏览器缓存根的绝对路径（给定 sandboxRoot）。调用方（通常是
// env 内的 Playwright server）用 PLAYWRIGHT_BROWSERS_PATH 指此目录；
// 该目录下实际 binary 路径依浏览器 + 版本由 Playwright 内部解析。
func (p *PlaywrightInstaller) Locate(version, sandboxRoot string) (string, error) {
	return filepath.Join(sandboxRoot, playwrightBrowsersSubdir), nil
}

// ListAvailable returns the fixed set of browser channels Playwright
// supports. Not a network query — these are baked into the Playwright
// release process.
//
// ListAvailable 返 Playwright 支持的固定浏览器频道集。非网络查询——这些
// 在 Playwright release 流程中固化。
func (p *PlaywrightInstaller) ListAvailable(ctx context.Context) ([]string, error) {
	return []string{"chromium", "firefox", "webkit"}, nil
}

// ResolveDefault returns "chromium" — the most-used Playwright browser
// for MCP / scraping workloads.
//
// ResolveDefault 返 "chromium"——MCP / scraping workload 最常用的 Playwright
// 浏览器。
func (p *PlaywrightInstaller) ResolveDefault(ctx context.Context) (string, error) {
	return "chromium", nil
}

// ── PlaywrightEnvManager ─────────────────────────────────────────────

// PlaywrightEnvManager satisfies sandboxdomain.EnvManager for the
// "browsers" kind. CreateEnv + InstallDeps delegate to a wrapped Node
// EnvManager (Playwright is a Node tool); InstallExtras handles the
// `playwright install chromium`-style browser binary download.
//
// PlaywrightEnvManager 满足 sandboxdomain.EnvManager 的 "browsers" kind。
// CreateEnv + InstallDeps 委托给包装的 Node EnvManager（Playwright 是 Node
// 工具）；InstallExtras 处理 `playwright install chromium` 类浏览器二进制
// 下载。
type PlaywrightEnvManager struct {
	node        *NodeEnvManager
	sandboxRoot string // absolute path to <dataDir>/sandbox/, used to set PLAYWRIGHT_BROWSERS_PATH
}

// NewPlaywrightEnvManager constructs the manager. Callers pass a fully
// configured NodeEnvManager (so we re-use its pnpm path + behaviour) plus
// the sandbox root so we can route browser downloads to the shared
// PLAYWRIGHT_BROWSERS_PATH directory.
//
// NewPlaywrightEnvManager 构造 manager。调用方传完全配好的 NodeEnvManager
// （复用其 pnpm 路径 + 行为）+ sandbox 根目录，让浏览器下载路由到共享
// PLAYWRIGHT_BROWSERS_PATH 目录。
func NewPlaywrightEnvManager(node *NodeEnvManager, sandboxRoot string) *PlaywrightEnvManager {
	return &PlaywrightEnvManager{node: node, sandboxRoot: sandboxRoot}
}

// Kind reports the dispatch key — paired with PlaywrightInstaller.Kind().
//
// Kind 报告派发键——与 PlaywrightInstaller.Kind() 配对。
func (p *PlaywrightEnvManager) Kind() string { return "browsers" }

// CreateEnv delegates to NodeEnvManager — Playwright env is a Node env.
//
// CreateEnv 委托给 NodeEnvManager——Playwright env 是 Node env。
func (p *PlaywrightEnvManager) CreateEnv(ctx context.Context, runtimePath, envPath string) error {
	return p.node.CreateEnv(ctx, runtimePath, envPath)
}

// InstallDeps delegates to NodeEnvManager — same `pnpm add <pkg...>` shape.
// Caller passes deps including "playwright" itself + any project deps.
//
// InstallDeps 委托给 NodeEnvManager——同样的 `pnpm add <pkg...>` 形态。
// 调用方传含 "playwright" 自身 + 项目 deps 的 deps 列表。
func (p *PlaywrightEnvManager) InstallDeps(ctx context.Context, runtimePath, envPath string, deps []string, stream sandboxdomain.ProgressFunc) error {
	return p.node.InstallDeps(ctx, runtimePath, envPath, deps, stream)
}

// InstallExtras runs `playwright install <browser>` for each entry in
// extras. Each extra is a browser channel name ("chromium" / "firefox" /
// "webkit"). PLAYWRIGHT_BROWSERS_PATH points at the shared
// <sandboxRoot>/playwright-browsers/ dir so all envs share one cache.
//
// InstallExtras 对 extras 里每项跑 `playwright install <browser>`。每项是
// 浏览器频道名（"chromium" / "firefox" / "webkit"）。
// PLAYWRIGHT_BROWSERS_PATH 指共享 <sandboxRoot>/playwright-browsers/ 让所有
// env 共享缓存。
func (p *PlaywrightEnvManager) InstallExtras(ctx context.Context, runtimePath, envPath string, extras []string, stream sandboxdomain.ProgressFunc) error {
	if len(extras) == 0 {
		return nil
	}
	playwrightCLI := p.node.EnvBin(envPath, "playwright")
	browsersDir := filepath.Join(p.sandboxRoot, playwrightBrowsersSubdir)

	for _, browser := range extras {
		// extras may be "browsers/chromium"-style; strip prefix to get
		// the channel name.
		// extras 可能是 "browsers/chromium" 形式；剥前缀拿频道名。
		channel := browser
		if idx := len(channel) - 1; idx >= 0 {
			if base := filepath.Base(channel); base != "" {
				channel = base
			}
		}

		cmd := exec.CommandContext(ctx, playwrightCLI, "install", channel)
		cmd.Env = append(cmd.Environ(), "PLAYWRIGHT_BROWSERS_PATH="+browsersDir)
		cmd.Dir = envPath

		if err := RunWithStderrCapture(cmd, stream,
			sandboxdomain.ErrDepInstallFailed,
			fmt.Sprintf("sandbox.PlaywrightEnvManager.InstallExtras %s", channel)); err != nil {
			return err
		}
	}
	return nil
}

// EnvBin / EnvDir delegate to NodeEnvManager — env layout is identical.
//
// EnvBin / EnvDir 委托给 NodeEnvManager——env 布局一致。
func (p *PlaywrightEnvManager) EnvBin(envPath, binName string) string {
	return p.node.EnvBin(envPath, binName)
}

func (p *PlaywrightEnvManager) EnvDir(envPath string) string {
	return p.node.EnvDir(envPath)
}
