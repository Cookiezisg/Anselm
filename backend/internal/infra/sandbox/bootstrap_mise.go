// bootstrap_mise.go — D2-2 mise bootstrap implementation.
//
// ExtractMiseBinary writes the per-platform embedded mise binary (declared
// in embed_mise_<goos>_<goarch>.go via go:embed) to <dataDir>/sandbox/bin/mise,
// chmods 0755, and on darwin runs ad-hoc codesign so macOS Gatekeeper does
// not SIGKILL the binary. Idempotent via SHA256 hash check at
// <dataDir>/sandbox/.mise.hash — re-extraction only happens when the
// embedded binary changes (mise version bump in cmd/resources fetch).
//
// On unsupported (GOOS, GOARCH) tuples (e.g. freebsd, linux/386), the
// fallback embed_mise_unsupported.go declares an empty miseBinary;
// ExtractMiseBinary detects this and returns ErrRuntimeInstallFailed
// wrapped with platform info, allowing Service.Bootstrap to flip Degraded
// Mode instead of crashing.
//
// Codesign rationale: ad-hoc `codesign --force --sign -` does not require
// an Apple Developer ID and is enough to bypass Gatekeeper's SIGKILL on
// quarantined binaries (issue uv#16726). Once the project obtains an Apple
// Developer ID, the cmd/resources fetcher (or release pipeline) should
// switch to proper notarization and this step becomes unnecessary.
//
// bootstrap_mise.go ——D2-2 mise bootstrap 实现。
//
// ExtractMiseBinary 把 per-platform embed mise 二进制（在
// embed_mise_<goos>_<goarch>.go 通过 go:embed 声明）写到
// <dataDir>/sandbox/bin/mise，chmod 0755，darwin 上 ad-hoc codesign 让
// macOS Gatekeeper 不会 SIGKILL 二进制。靠 <dataDir>/sandbox/.mise.hash
// 的 SHA256 hash 校验幂等——仅当 embed 二进制变（cmd/resources fetch 升版）
// 才重新抽取。
//
// 不支持 (GOOS, GOARCH) 时（如 freebsd、linux/386）embed_mise_unsupported.go
// 声明空 miseBinary；ExtractMiseBinary 检测后返 ErrRuntimeInstallFailed
// 包装平台信息，让 Service.Bootstrap 翻 Degraded Mode 而非 crash。
//
// Codesign 理由：ad-hoc `codesign --force --sign -` 不需 Apple Developer ID，
// 足以绕过 Gatekeeper 对 quarantined 二进制的 SIGKILL（issue uv#16726）。
// 等项目拿到 Apple Developer ID，cmd/resources fetcher（或 release pipeline）
// 切换到正式 notarization，本步骤就不再需要。

package sandbox

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"runtime"

	"go.uber.org/zap"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

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
	// first exec. macCodesign (preflight.go) walks recursively but accepts
	// a single-file root just fine — the WalkDir hits exactly one entry.
	//
	// darwin: ad-hoc codesign 让 Gatekeeper 首次 exec 时不 SIGKILL。
	// macCodesign（preflight.go）虽递归但接受单文件 root 也可——WalkDir
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
