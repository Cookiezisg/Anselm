// mise.go — everything related to the mise universal version manager:
// extracting the embedded mise binary at boot (ExtractMiseBinary) and
// the generic RuntimeInstaller that wraps `mise install` / `mise where`
// (MiseInstaller).
//
// Layout the mise installer establishes per (kind, version):
//
//	<sandboxRoot>/mise-data/installs/<kind>/<resolved-version>/bin/<kind>
//
// All MiseInstaller instances share one MISE_DATA_DIR rooted at
// <sandboxRoot>/mise-data/, so mise's plugin manifest, version cache, and
// `mise where` lookups stay consistent across all installed runtimes.
//
// "resolved-version" matters when callers pass a partial spec like
// "3.12" — mise expands it to whichever patch is current at install
// time, and Install asks `mise where` for the actual path before
// deriving the relPath returned to the service.
//
// mise.go ——所有跟 mise 通用版本管理器相关的代码：启动时抽取 embed mise
// 二进制（ExtractMiseBinary）+ 包装 `mise install` / `mise where` 的通用
// RuntimeInstaller（MiseInstaller）。
//
// mise installer 按 (kind, version) 建立的布局：
//
//	<sandboxRoot>/mise-data/installs/<kind>/<resolved-version>/bin/<kind>
//
// 所有 MiseInstaller 实例共享单个 MISE_DATA_DIR（位于 <sandboxRoot>/mise-data/），
// 让 mise 的 plugin manifest / 版本缓存 / `mise where` 查询在所有装的 runtime
// 间保持一致。
//
// "resolved-version" 在调用方传部分约束（如 "3.12"）时有意义——mise 装机时
// 展开到当时该 minor 的最新 patch；Install 在 mise 装完后调 `mise where` 拿
// 真实路径再算 relPath 返给 service。

package sandbox

import (
	"bufio"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"

	"go.uber.org/zap"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

// ── Embed extraction ─────────────────────────────────────────────────────────

// ExtractMiseBinary writes the embedded mise binary to <dataDir>/sandbox/bin/mise
// (mise.exe on Windows), makes it executable, and on darwin runs ad-hoc
// codesign. Idempotent — subsequent calls with an unchanged embed return
// the existing path without re-writing. Returns the absolute path to the
// extracted mise binary on success.
//
// ExtractMiseBinary 把 embed mise 二进制写到 <dataDir>/sandbox/bin/mise
// （Windows 是 mise.exe），标记可执行，darwin 上 ad-hoc codesign。幂等——
// embed 不变的后续调用直接返已有路径不重写。成功返 mise 二进制绝对路径。
func ExtractMiseBinary(ctx context.Context, dataDir string, log *zap.Logger) (string, error) {
	if len(miseBinary) == 0 {
		return "", fmt.Errorf("sandbox.ExtractMiseBinary: no mise binary embedded for %s/%s: %w",
			runtime.GOOS, runtime.GOARCH, sandboxdomain.ErrRuntimeInstallFailed)
	}

	binDir := filepath.Join(dataDir, "sandbox", "bin")
	if err := os.MkdirAll(binDir, 0o755); err != nil {
		return "", fmt.Errorf("sandbox.ExtractMiseBinary: mkdir bin dir: %w", err)
	}

	binPath := filepath.Join(binDir, miseExeName())
	hashPath := filepath.Join(dataDir, "sandbox", ".mise.hash")

	sum := sha256.Sum256(miseBinary)
	wantHash := hex.EncodeToString(sum[:])

	// Idempotency: skip re-extract if both hash file matches AND binary on
	// disk exists (handles "user wiped sandbox/bin but kept .mise.hash").
	//
	// 幂等：仅当 hash 文件匹配 *且* 二进制存在时才跳过（处理"用户清了
	// sandbox/bin 但留了 .mise.hash"的情况）。
	if existing, err := os.ReadFile(hashPath); err == nil && string(existing) == wantHash {
		if _, statErr := os.Stat(binPath); statErr == nil {
			log.Debug("mise already extracted (hash match)", zap.String("path", binPath))
			return binPath, nil
		}
	}

	// Atomic write: tmp + rename so partial writes never leave a half-built
	// binary that subsequent runs would refuse to overwrite.
	//
	// 原子写：tmp + rename，半写永远不会留下后续运行拒绝覆盖的半成品。
	tmp := binPath + ".tmp"
	if err := os.WriteFile(tmp, miseBinary, 0o755); err != nil {
		return "", fmt.Errorf("sandbox.ExtractMiseBinary: write tmp: %w", err)
	}
	if err := os.Rename(tmp, binPath); err != nil {
		_ = os.Remove(tmp)
		return "", fmt.Errorf("sandbox.ExtractMiseBinary: rename: %w", err)
	}

	// darwin: ad-hoc codesign so Gatekeeper does not SIGKILL the binary on
	// first exec. macCodesign (codesign.go) walks recursively but accepts
	// a single-file root just fine — the WalkDir hits exactly one entry.
	//
	// darwin: ad-hoc codesign 让 Gatekeeper 首次 exec 时不 SIGKILL。
	// macCodesign（codesign.go）虽递归但接受单文件 root 也可——WalkDir
	// 只命中一个 entry。
	if runtime.GOOS == "darwin" {
		if err := macCodesign(ctx, binPath, log); err != nil {
			return "", fmt.Errorf("sandbox.ExtractMiseBinary: codesign: %w", err)
		}
	}

	// Hash file write is best-effort — losing it on a crash just means the
	// next boot re-extracts (cheap, idempotent at the filesystem level).
	//
	// hash 文件写是 best-effort——崩溃丢失只是下次启动重抽（便宜，文件层
	// 仍幂等）。
	if err := os.WriteFile(hashPath, []byte(wantHash), 0o644); err != nil {
		log.Warn("mise hash file write failed (will re-extract next boot)", zap.Error(err))
	}

	log.Info("mise extracted",
		zap.String("path", binPath),
		zap.Int("size_bytes", len(miseBinary)),
		zap.String("sha256", wantHash[:16]+"..."))
	return binPath, nil
}

// miseExeName returns "mise.exe" on Windows, "mise" elsewhere.
//
// miseExeName Windows 上返 "mise.exe"，其他平台返 "mise"。
func miseExeName() string {
	if runtime.GOOS == "windows" {
		return "mise.exe"
	}
	return "mise"
}

// ── Generic RuntimeInstaller ─────────────────────────────────────────────────

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
		"MISE_YES=1",   // skip interactive prompts
		"MISE_QUIET=1", // less chatty stdout (we parse stderr for progress)
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
