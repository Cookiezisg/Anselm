// disk.go — filesystem helpers used by Service for size accounting + safe
// directory removal. Kept tiny and deliberately conservative: failures are
// logged inside Service rather than returned, since these are best-effort
// adjuncts to manifest persistence (we never want a stat hiccup to abort
// an EnsureEnv that succeeded everywhere else).
//
// disk.go ——Service 用的文件系统辅助：尺寸统计 + 安全目录删除。刻意保持
// 极小且保守：失败由 Service 内部 log 而非上抛，因为它们是 manifest 持久化
// 的 best-effort 配套（绝不让一次 stat 抖动中止其他都成功的 EnsureEnv）。

package sandbox

import (
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

// computeDirSize sums file sizes under root recursively. Returns 0 on
// any error (caller stores the value in SizeBytes for UI; misreporting
// disk to "0" is acceptable, propagating the error and aborting the
// install is not).
//
// computeDirSize 递归求 root 下文件 size 总和。任何错返 0（调用方把值存
// SizeBytes 给 UI；磁盘误报 "0" 可接受，传播错并中止 install 不可）。
func computeDirSize(root string) int64 {
	var total int64
	_ = filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil // skip broken entries
		}
		if d.IsDir() {
			return nil
		}
		info, err := d.Info()
		if err != nil {
			return nil
		}
		total += info.Size()
		return nil
	})
	return total
}

// removeAll wraps os.RemoveAll with a guard against catastrophic paths
// (root, "/", "C:\", relative paths). Sandbox env paths always live under
// <sandboxRoot>/envs/ so this catches programming errors that could
// otherwise wipe the filesystem.
//
// removeAll 包 os.RemoveAll，防灾难性路径（root、"/"、"C:\"、相对路径）。
// Sandbox env 路径总在 <sandboxRoot>/envs/ 下，捕获否则可能清空文件系统的
// 编程错。
func removeAll(path string) error {
	if !filepath.IsAbs(path) {
		return os.ErrInvalid
	}
	clean := filepath.Clean(path)
	if isFilesystemRoot(clean) {
		return os.ErrInvalid
	}
	return os.RemoveAll(clean)
}

// isFilesystemRoot detects "/", "C:\", "C:" and similar — paths whose
// removal would be catastrophic. Conservative: any path of length <= 3
// after Clean is treated as suspect.
//
// isFilesystemRoot 检测 "/"、"C:\"、"C:" 等——删了灾难的路径。保守：Clean
// 后长度 <= 3 的路径视为可疑。
func isFilesystemRoot(path string) bool {
	if path == "/" || path == "\\" {
		return true
	}
	// Windows drive roots: "C:", "C:\", "C:/"
	// Windows drive root：上述形式。
	if len(path) <= 3 && len(path) >= 2 && path[1] == ':' {
		return true
	}
	// Edge case: Clean turned everything into ".".
	// Clean 把一切变成 "."。
	if strings.TrimSpace(path) == "." {
		return true
	}
	return false
}
