// envmanager_playwright.go — EnvManager for Playwright MCP / scraping plugins.
//
// PlaywrightEnvManager extends the Node env model: every Playwright env is
// first a normal Node env (package.json + node_modules), then `playwright
// install <browser>` runs to populate the shared browser cache (managed
// by PlaywrightInstaller, NOT a per-env download).
//
// Layout per Playwright env:
//
//	<envPath>/package.json                       # NodeEnvManager.CreateEnv writes
//	<envPath>/node_modules/playwright/...        # NodeEnvManager.InstallDeps adds
//	<envPath>/node_modules/.bin/playwright       # CLI shim used by PlaywrightInstaller
//	<sandboxRoot>/playwright-browsers/...        # SHARED across all Playwright envs
//
// envmanager_playwright.go ——Playwright MCP / scraping plugin 的 EnvManager。
//
// PlaywrightEnvManager 扩展 Node env 模型：每个 Playwright env 先是普通
// Node env（package.json + node_modules），然后跑 `playwright install <browser>`
// 填共享浏览器缓存（由 PlaywrightInstaller 管，**不**是 per-env 下载）。
//
// 单个 Playwright env 布局见上方英文段。

package sandbox

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"os/exec"
	"path/filepath"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

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

		stderrPipe, err := cmd.StderrPipe()
		if err != nil {
			return fmt.Errorf("sandbox.PlaywrightEnvManager.InstallExtras: stderr pipe %s: %w", channel, err)
		}
		if err := cmd.Start(); err != nil {
			return fmt.Errorf("sandbox.PlaywrightEnvManager.InstallExtras: start %s: %w", channel, err)
		}

		if stream != nil {
			scanner := bufio.NewScanner(stderrPipe)
			for scanner.Scan() {
				stream("installing-browser", scanner.Text(), -1)
			}
		} else {
			_, _ = io.Copy(io.Discard, stderrPipe)
		}

		if err := cmd.Wait(); err != nil {
			return fmt.Errorf("sandbox.PlaywrightEnvManager.InstallExtras %s: %w", channel, sandboxdomain.ErrDepInstallFailed)
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
