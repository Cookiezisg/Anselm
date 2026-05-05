// bootstrap_mise_test.go — D2-2 ExtractMiseBinary tests.
//
// Validates: (a) the per-platform go:embed actually loaded a non-trivial
// mise binary (sanity check the build sees the binary asset); (b) the
// happy-path extract writes the binary, persists the hash file, and is
// idempotent on second call; (c) tampering with the on-disk binary
// triggers re-extract on next call (hash mismatch path).
//
// bootstrap_mise_test.go ——D2-2 ExtractMiseBinary 测试。
//
// 验证：(a) per-platform go:embed 实际加载了非平凡的 mise 二进制（sanity
// check 编译期能看到资源）；(b) happy-path 抽取写入二进制 + 持久化 hash 文件
// + 二次调用幂等；(c) 篡改盘上二进制下一次调用触发重抽（hash 不匹配路径）。

package sandbox

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"go.uber.org/zap"
)

// TestEmbed_MiseBinaryIsNonTrivial guards against a silently broken
// embed_mise_<goos>_<goarch>.go (e.g. wrong path in go:embed directive,
// missing fetched binary). mise releases are tens of MB; anything < 1 MB
// is almost certainly an empty placeholder or fragment.
//
// TestEmbed_MiseBinaryIsNonTrivial 防 embed_mise_<goos>_<goarch>.go 隐性
// 损坏（如 go:embed 路径错、漏拉二进制）。mise 发布几十 MB；< 1 MB 几乎
// 一定是空占位或碎片。
func TestEmbed_MiseBinaryIsNonTrivial(t *testing.T) {
	if len(miseBinary) < 1<<20 {
		t.Fatalf("embed mise binary suspiciously small: %d bytes (want >1 MB). Run `make resources` to populate?",
			len(miseBinary))
	}
}

// TestExtractMiseBinary_HappyPath writes the embed to a temp dir, then
// re-runs and asserts the second call short-circuits via the hash file
// (mtime unchanged proves no rewrite).
//
// TestExtractMiseBinary_HappyPath 把 embed 写到临时目录，再跑一次，确认
// 二次调用走 hash 文件短路（mtime 不变证明无重写）。
func TestExtractMiseBinary_HappyPath(t *testing.T) {
	dataDir := t.TempDir()
	log := zap.NewNop()
	ctx := context.Background()

	first, err := ExtractMiseBinary(ctx, dataDir, log)
	if err != nil {
		t.Fatalf("first ExtractMiseBinary: %v", err)
	}
	st1, err := os.Stat(first)
	if err != nil {
		t.Fatalf("stat extracted binary: %v", err)
	}
	// Size sanity: within 10 MB of the embed (darwin codesign --force
	// replaces the upstream signature so disk size differs from embed by
	// up to a few hundred KB; any larger drift is a real bug).
	//
	// Size 容差：跟 embed 相差 10 MB 内（darwin codesign --force 替换上游
	// 签名，盘上 size 与 embed 差几百 KB 是常见；更大偏差就是真 bug）。
	const sizeTolerance = 10 << 20
	embedSize := int64(len(miseBinary))
	if diff := st1.Size() - embedSize; diff > sizeTolerance || diff < -sizeTolerance {
		t.Errorf("extracted binary size %d drifts >10MB from embed %d (diff %d)", st1.Size(), embedSize, diff)
	}
	if st1.Mode().Perm()&0o111 == 0 {
		t.Errorf("extracted binary not executable: mode %v", st1.Mode())
	}

	hashFile := filepath.Join(dataDir, "sandbox", ".mise.hash")
	if _, err := os.Stat(hashFile); err != nil {
		t.Errorf("hash file not written: %v", err)
	}

	// Second call must be a no-op (hash matches + binary present).
	second, err := ExtractMiseBinary(ctx, dataDir, log)
	if err != nil {
		t.Fatalf("second ExtractMiseBinary: %v", err)
	}
	if second != first {
		t.Errorf("path drift between calls: %q vs %q", first, second)
	}
	st2, err := os.Stat(first)
	if err != nil {
		t.Fatalf("re-stat: %v", err)
	}
	if !st1.ModTime().Equal(st2.ModTime()) {
		t.Errorf("idempotency broken: mtime changed (%v -> %v) — re-extract triggered when hash matched",
			st1.ModTime(), st2.ModTime())
	}
}

// TestExtractMiseBinary_RecoversAfterBinaryDeleted exercises the
// "hash matches but binary gone" branch — user wiped sandbox/bin/ but
// .mise.hash survived, e.g. partial GC or crash mid-clean.
//
// TestExtractMiseBinary_RecoversAfterBinaryDeleted 验证"hash 匹配但二进制
// 消失"分支——用户清了 sandbox/bin/ 但 .mise.hash 残留，如部分 GC 或清理
// 过程中 crash。
func TestExtractMiseBinary_RecoversAfterBinaryDeleted(t *testing.T) {
	dataDir := t.TempDir()
	log := zap.NewNop()
	ctx := context.Background()

	first, err := ExtractMiseBinary(ctx, dataDir, log)
	if err != nil {
		t.Fatalf("first ExtractMiseBinary: %v", err)
	}
	if err := os.Remove(first); err != nil {
		t.Fatalf("remove binary mid-test: %v", err)
	}

	second, err := ExtractMiseBinary(ctx, dataDir, log)
	if err != nil {
		t.Fatalf("re-extract after deletion: %v", err)
	}
	if _, err := os.Stat(second); err != nil {
		t.Errorf("binary not re-extracted: %v", err)
	}
}
