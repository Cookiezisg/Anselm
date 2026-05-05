// installer_playwright.go — RuntimeInstaller wrapping Playwright's
// browser-download CLI. PlaywrightInstaller is a thin shim around the
// `playwright install <browser>` command (Chromium / Firefox / Webkit) +
// the path-resolution rules Playwright uses for its browser cache.
//
// Note: this installer does NOT install Node or the playwright npm package —
// those are NodeEnvManager's job. PlaywrightInstaller assumes the Playwright
// CLI is already on PATH inside an env's node_modules/.bin/ (typically
// because PlaywrightEnvManager invoked `pnpm add playwright` first).
//
// Why a separate installer rather than treating browsers as plain Node deps:
// playwright npm package is small (a few MB); the actual browser binaries
// (Chromium ~300 MB, Firefox + Webkit similar) are downloaded out-of-band by
// the playwright CLI. Treating them as deps would mean each conv-env owns
// its own copy. Routing through PlaywrightInstaller lets us respect
// Playwright's PLAYWRIGHT_BROWSERS_PATH env var and share browser binaries
// across all envs.
//
// installer_playwright.go ——包装 Playwright 浏览器下载 CLI 的 RuntimeInstaller。
// 是 `playwright install <browser>` 命令（Chromium / Firefox / Webkit）+
// Playwright 浏览器缓存路径解析规则的薄 shim。
//
// 注意：本 installer **不**装 Node 或 playwright npm 包——那是 NodeEnvManager
// 的活。PlaywrightInstaller 假设 Playwright CLI 已在某 env 的
// node_modules/.bin/ PATH 上（通常因 PlaywrightEnvManager 先跑了
// `pnpm add playwright`）。
//
// 为什么需要独立 installer 而不把 browsers 当普通 Node deps：playwright npm
// 包很小（几 MB）；实际浏览器二进制（Chromium ~300 MB，Firefox + Webkit
// 类似）由 playwright CLI 带外下载。当 deps 处理意味着每个 conv-env 自有
// copy。走 PlaywrightInstaller 让我们尊重 Playwright 的
// PLAYWRIGHT_BROWSERS_PATH env var，跨所有 env 共享浏览器二进制。

package sandbox

import (
	"bufio"
	"context"
	"fmt"
	"io"
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

	stderrPipe, err := cmd.StderrPipe()
	if err != nil {
		return "", fmt.Errorf("sandbox.PlaywrightInstaller.Install: stderr pipe: %w", err)
	}
	if err := cmd.Start(); err != nil {
		return "", fmt.Errorf("sandbox.PlaywrightInstaller.Install: start: %w", err)
	}

	if stream != nil {
		scanner := bufio.NewScanner(stderrPipe)
		for scanner.Scan() {
			stream("installing", scanner.Text(), -1)
		}
	} else {
		_, _ = io.Copy(io.Discard, stderrPipe)
	}

	if err := cmd.Wait(); err != nil {
		return "", fmt.Errorf("sandbox.PlaywrightInstaller.Install %s: %w", version, sandboxdomain.ErrRuntimeInstallFailed)
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
