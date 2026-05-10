// codesign.go — macOS ad-hoc codesign helper used by ExtractMiseBinary
// (mise.go) to defang Gatekeeper on the quarantined embedded mise binary.
//
// Cross-platform shape: macCodesign is a no-op on non-darwin (returns nil
// without invoking the codesign / xattr binaries which don't exist).
// Build-tag splitting would be cleaner but the helper is short enough
// that a runtime guard is simpler — and lets all callers use the same
// signature without per-OS branching.
//
// Strategy on darwin:
//   1. xattr -dr com.apple.provenance <path>  — strips the quarantine
//      attribute so codesign can fully clear Gatekeeper's cache.
//   2. codesign --force --sign - <path>  — ad-hoc signs the binary.
//      Sole caller passes a single binary path (the embedded mise
//      binary post-extract).
//
// Replacing this with proper Apple-Developer-ID notarization is on the
// long-term roadmap — see sandbox.md §3 / §15.1 / §17.
//
// codesign.go ——给 ExtractMiseBinary（mise.go）用的 macOS ad-hoc codesign
// 辅助；解 quarantined embed mise 二进制的 Gatekeeper。
//
// 跨平台形状：macCodesign 在非 darwin 是 no-op（返 nil 不调 codesign /
// xattr，那些在非 darwin 不存在）。按 build tag 拆更干净但 helper 短到
// 用 runtime guard 反而简单——也让调用方都用同签名不分 per-OS 分支。

package sandbox

import (
	"context"
	"fmt"
	"os/exec"
	"runtime"

	"go.uber.org/zap"
)

// macCodesign strips com.apple.provenance + ad-hoc codesigns the binary
// at path. No-op on non-darwin. Sole caller is ExtractMiseBinary passing
// a single binary path; the helper's signature stays single-file scope
// after the V3 marketplace collapse removed the multi-file installers
// (Python tarball / Playwright) that previously needed recursion.
//
// macCodesign 剥 com.apple.provenance + ad-hoc codesign path 处的二进制。
// 非 darwin no-op。唯一调用方 ExtractMiseBinary 传单二进制路径；helper
// 签名在 V3 marketplace collapse 删除多文件 installer（Python tarball /
// Playwright）后保持单文件作用域。
func macCodesign(ctx context.Context, path string, log *zap.Logger) error {
	if runtime.GOOS != "darwin" {
		return nil
	}

	// 1. Strip com.apple.provenance. Failure is fatal — without it,
	// codesign may not clear the Gatekeeper cache.
	//
	// 1. 剥 com.apple.provenance。失败致命——不剥则 codesign 可能清不掉
	// Gatekeeper 缓存。
	cmd := exec.CommandContext(ctx, "xattr", "-d", "com.apple.provenance", path)
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("sandbox.macCodesign: xattr -d: %w (output: %s)", err, out)
	}

	// 2. Ad-hoc sign the binary.
	//
	// 2. ad-hoc 签二进制。
	signCmd := exec.CommandContext(ctx, "codesign", "--force", "--sign", "-", path)
	if out, signErr := signCmd.CombinedOutput(); signErr != nil {
		return fmt.Errorf("sandbox.macCodesign %s: %w (output: %s)", path, signErr, out)
	}
	log.Info("mac codesign complete", zap.String("path", path))
	return nil
}
