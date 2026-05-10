// codesign.go — macOS ad-hoc codesign helper used by ExtractMiseBinary
// (bootstrap_mise.go) and StaticBinaryInstaller (installer_static.go) to
// defang Gatekeeper on quarantined binaries.
//
// Cross-platform shape: macCodesign is a no-op on non-darwin (returns nil
// without invoking the codesign / xattr binaries which don't exist).
// Build-tag splitting would be cleaner but the helper is short enough
// that a runtime guard is simpler — and lets all callers use the same
// signature without per-OS branching.
//
// Strategy on darwin:
//   1. xattr -dr com.apple.provenance <root>  — strips the quarantine
//      attribute so codesign can fully clear Gatekeeper's cache.
//   2. WalkDir root, codesign --force --sign - <each-executable>  —
//      ad-hoc signs every regular file with at least one execute bit.
//      For embedded mise (single binary) this is one entry; for an
//      install_only Python tarball it's hundreds (libpython.dylib,
//      stdlib .so).
//
// Replacing this with proper Apple-Developer-ID notarization is on the
// long-term roadmap — see sandbox.md §3 / §15.1 / §17.
//
// codesign.go ——给 ExtractMiseBinary（bootstrap_mise.go）和
// StaticBinaryInstaller（installer_static.go）用的 macOS ad-hoc codesign
// 辅助；解 quarantined 二进制的 Gatekeeper。
//
// 跨平台形状：macCodesign 在非 darwin 是 no-op（返 nil 不调 codesign /
// xattr，那些在非 darwin 不存在）。按 build tag 拆更干净但 helper 短到
// 用 runtime guard 反而简单——也让调用方都用同签名不分 per-OS 分支。

package sandbox

import (
	"context"
	"fmt"
	"io/fs"
	"os/exec"
	"path/filepath"
	"runtime"

	"go.uber.org/zap"
)

// macCodesign strips com.apple.provenance recursively + ad-hoc codesigns
// every executable file under root. No-op on non-darwin.
//
// macCodesign 递归剥 com.apple.provenance + ad-hoc codesign root 下所有
// 可执行文件。非 darwin no-op。
func macCodesign(ctx context.Context, root string, log *zap.Logger) error {
	if runtime.GOOS != "darwin" {
		return nil
	}

	// 1. Strip com.apple.provenance recursively. Failure is fatal —
	// without it, codesign alone may not clear the Gatekeeper cache for
	// every nested .dylib / .so.
	//
	// 1. 递归剥 com.apple.provenance。失败致命——不剥则 codesign 单步可能
	// 清不掉每个嵌套 .dylib / .so 的 Gatekeeper 缓存。
	cmd := exec.CommandContext(ctx, "xattr", "-dr", "com.apple.provenance", root)
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("sandbox.macCodesign: xattr -dr: %w (output: %s)", err, out)
	}

	// 2. Walk all regular executable files and ad-hoc sign each. We must
	// sign every Mach-O loaded by the interpreter (libpython.dylib + lots
	// of stdlib .so for Python; mostly just the binary itself for mise) —
	// relying on a single sign of the entry binary is not enough because
	// dlopen rechecks each library.
	//
	// 2. 遍历所有正则可执行文件 ad-hoc 签。每个解释器加载的 Mach-O 都要签
	// （Python 是 libpython.dylib + 一堆 stdlib .so；mise 多半就是二进制
	// 本身）——只签入口二进制不够，dlopen 重新校验每个库。
	signed := 0
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		info, err := d.Info()
		if err != nil {
			return err
		}
		if !info.Mode().IsRegular() || info.Mode().Perm()&0o111 == 0 {
			return nil
		}
		signCmd := exec.CommandContext(ctx, "codesign", "--force", "--sign", "-", path)
		if out, signErr := signCmd.CombinedOutput(); signErr != nil {
			return fmt.Errorf("sandbox.macCodesign %s: %w (output: %s)", path, signErr, out)
		}
		signed++
		return nil
	})
	if err != nil {
		return err
	}
	log.Info("mac codesign complete", zap.String("root", root), zap.Int("signed_files", signed))
	return nil
}
