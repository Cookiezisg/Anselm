// installer_mise.go — generic RuntimeInstaller backed by jdx/mise.
//
// One MiseInstaller instance per (kind, defaultVersion). Multiple kinds
// share a single MISE_DATA_DIR rooted at <sandboxRoot>/mise-data/, so
// mise's plugin manifest, version cache, and `mise where` lookups stay
// consistent across all installed runtimes.
//
// Layout per (kind, version) install:
//
//	<sandboxRoot>/mise-data/installs/<kind>/<resolved-version>/bin/<kind>
//
// The "resolved-version" matters when the caller passes a partial version
// like "3.12" — mise expands it to "3.12.5" or whichever patch is current
// at install time, and Install asks `mise where` for the actual path
// before deriving the relPath returned to the service.
//
// installer_mise.go ——基于 jdx/mise 的通用 RuntimeInstaller。
//
// 每个 (kind, defaultVersion) 一个 MiseInstaller 实例。多 kind 共享单个
// MISE_DATA_DIR（位于 <sandboxRoot>/mise-data/），让 mise 的 plugin
// manifest / 版本缓存 / `mise where` 查询在所有装的 runtime 间保持一致。
//
// 每 (kind, version) install 的布局：
//
//	<sandboxRoot>/mise-data/installs/<kind>/<resolved-version>/bin/<kind>
//
// "resolved-version" 在调用方传部分版本（如 "3.12"）时有意义——mise 会展开
// 到 "3.12.5" 或装机时该 minor 的最新 patch；Install 在 mise 装完后调
// `mise where` 拿真实路径再算 relPath 返给 service。

package sandbox

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

// miseDataSubdir is the relative directory under sandboxRoot where mise
// keeps its data (installs, plugins, cache). Shared by all MiseInstaller
// instances so a single mise process state covers the whole sandbox.
//
// miseDataSubdir 是 mise 数据（installs / plugins / cache）相对 sandboxRoot
// 的目录。所有 MiseInstaller 实例共享，让单个 mise 进程状态覆盖整个 sandbox。
const miseDataSubdir = "mise-data"

// MiseInstaller is a generic RuntimeInstaller for any mise-supported tool
// (python / node / rust / java / go / ruby / php / 600+ via mise plugins).
//
// MiseInstaller 是任何 mise 支持工具的通用 RuntimeInstaller
// （python / node / rust / java / go / ruby / php / 通过 mise plugin 600+）。
type MiseInstaller struct {
	miseBin        string // absolute path to extracted mise binary (from ExtractMiseBinary)
	kind           string // mise plugin name + Runtime.Kind
	defaultVersion string // version returned by ResolveDefault when EnvSpec.Runtime.Version is empty
}

// NewMiseInstaller constructs a MiseInstaller. miseBin must be an absolute
// path to an executable mise binary (typically the value returned by
// ExtractMiseBinary). defaultVersion may be a partial spec (e.g. "3.12")
// that mise expands at install time.
//
// NewMiseInstaller 构造 MiseInstaller。miseBin 必须是已可执行 mise 二进制
// 的绝对路径（通常是 ExtractMiseBinary 的返回值）。defaultVersion 可以是
// 部分约束（如 "3.12"），mise 装机时自动展开。
func NewMiseInstaller(miseBin, kind, defaultVersion string) *MiseInstaller {
	return &MiseInstaller{miseBin: miseBin, kind: kind, defaultVersion: defaultVersion}
}

// Kind reports the mise plugin name this installer wraps.
//
// Kind 报告本 installer 包装的 mise plugin 名。
func (m *MiseInstaller) Kind() string { return m.kind }

// Install runs `mise install <kind>@<version>` against the shared
// MISE_DATA_DIR (<sandboxRoot>/mise-data/). After mise reports success,
// `mise where` resolves the actual install directory (handles partial
// version spec → concrete patch resolution); the returned relPath is the
// install dir relative to sandboxRoot — service layer stores it in
// Runtime.Path.
//
// Install 在共享 MISE_DATA_DIR（<sandboxRoot>/mise-data/）跑
// `mise install <kind>@<version>`。mise 报告成功后，`mise where` 解析实际
// install 目录（处理部分版本约束 → 具体 patch 的解析）；返回的 relPath
// 是 install dir 相对 sandboxRoot 的路径——service 层存入 Runtime.Path。
func (m *MiseInstaller) Install(ctx context.Context, version, sandboxRoot string, stream sandboxdomain.ProgressFunc) (string, error) {
	dataDir := filepath.Join(sandboxRoot, miseDataSubdir)
	if err := os.MkdirAll(dataDir, 0o755); err != nil {
		return "", fmt.Errorf("sandbox.MiseInstaller.Install: mkdir mise data: %w", err)
	}

	cmd := exec.CommandContext(ctx, m.miseBin, "install", "-y", m.kind+"@"+version)
	cmd.Env = append(os.Environ(),
		"MISE_DATA_DIR="+dataDir,
		"MISE_YES=1",       // skip interactive prompts
		"MISE_QUIET=1",     // less chatty stdout (we parse stderr for progress)
	)

	stderrPipe, err := cmd.StderrPipe()
	if err != nil {
		return "", fmt.Errorf("sandbox.MiseInstaller.Install: stderr pipe: %w", err)
	}
	if err := cmd.Start(); err != nil {
		return "", fmt.Errorf("sandbox.MiseInstaller.Install: start: %w", err)
	}

	// Stream parse: each stderr line surfaces as one progress event so the
	// frontend SSE bridge can show "downloading python-3.12.5 ..." etc.
	// percent stays -1 since mise doesn't reliably emit a percent figure.
	//
	// 流式解析：每行 stderr 当一个 progress 事件，前端 SSE 显示
	// "downloading python-3.12.5 ..." 之类。percent=-1，mise 不稳定输出百分比。
	if stream != nil {
		scanner := bufio.NewScanner(stderrPipe)
		for scanner.Scan() {
			stream("installing", scanner.Text(), -1)
		}
	} else {
		_, _ = io.Copy(io.Discard, stderrPipe)
	}

	if err := cmd.Wait(); err != nil {
		return "", fmt.Errorf("sandbox.MiseInstaller.Install %s@%s: %w", m.kind, version, sandboxdomain.ErrRuntimeInstallFailed)
	}

	// Resolve actual install dir — mise may have expanded a partial spec
	// (e.g. "3.12" → "3.12.5"). Use absolute path then derive relPath.
	//
	// 解析实际 install 目录——mise 可能展开了部分约束（如 "3.12" → "3.12.5"）。
	// 用绝对路径再算 relPath。
	actual, err := m.where(ctx, dataDir, version)
	if err != nil {
		return "", fmt.Errorf("sandbox.MiseInstaller.Install: locate after install: %w", err)
	}
	rel, err := filepath.Rel(sandboxRoot, actual)
	if err != nil {
		return "", fmt.Errorf("sandbox.MiseInstaller.Install: rel path %q from %q: %w", actual, sandboxRoot, err)
	}
	return rel, nil
}

// Locate returns the absolute path to the runtime's primary binary inside
// the install directory resolved via `mise where`. Binary name is
// kind-derived (python, node, ...); on Windows we tack on ".exe".
//
// Locate 通过 `mise where` 解析 install 目录后返主 binary 绝对路径。
// Binary 名按 kind 推（python、node 等）；Windows 加 ".exe"。
func (m *MiseInstaller) Locate(version, sandboxRoot string) (string, error) {
	dataDir := filepath.Join(sandboxRoot, miseDataSubdir)
	installDir, err := m.where(context.Background(), dataDir, version)
	if err != nil {
		return "", fmt.Errorf("sandbox.MiseInstaller.Locate: %w", err)
	}
	binName := m.kind
	if runtime.GOOS == "windows" {
		binName += ".exe"
	}
	return filepath.Join(installDir, "bin", binName), nil
}

// where invokes `mise where <kind>@<version>` against the given dataDir
// and returns the install path. Returns an error if the tool isn't
// installed at that version (caller chains it as install-failure context).
//
// where 在指定 dataDir 调 `mise where <kind>@<version>` 返 install 路径。
// 工具未装该版本返错（调用方串成 install-failure 上下文）。
func (m *MiseInstaller) where(ctx context.Context, dataDir, version string) (string, error) {
	cmd := exec.CommandContext(ctx, m.miseBin, "where", m.kind+"@"+version)
	cmd.Env = append(os.Environ(), "MISE_DATA_DIR="+dataDir)
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("mise where %s@%s: %w", m.kind, version, err)
	}
	return strings.TrimSpace(string(out)), nil
}

// ListAvailable returns the list of versions mise can install for this
// kind. Output is the raw `mise ls-remote <kind>` text split on newlines —
// callers (UI) typically reverse + filter to show recent releases.
//
// ListAvailable 返 mise 可装的版本列表。输出是 `mise ls-remote <kind>` 原始
// 文本按行拆——调用方（UI）通常 reverse + filter 展示近期版本。
func (m *MiseInstaller) ListAvailable(ctx context.Context) ([]string, error) {
	cmd := exec.CommandContext(ctx, m.miseBin, "ls-remote", m.kind)
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("sandbox.MiseInstaller.ListAvailable %s: %w", m.kind, err)
	}
	trimmed := strings.TrimSpace(string(out))
	if trimmed == "" {
		return nil, nil
	}
	return strings.Split(trimmed, "\n"), nil
}

// ResolveDefault returns the default version baked at construction time.
// May be a partial spec (e.g. "3.12"); mise resolves to the latest patch
// at install time.
//
// ResolveDefault 返构造时固化的默认版本。可以是部分约束（如 "3.12"）；
// mise 装机时解析到该 minor 最新 patch。
func (m *MiseInstaller) ResolveDefault(ctx context.Context) (string, error) {
	return m.defaultVersion, nil
}
