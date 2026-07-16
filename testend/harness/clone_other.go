//go:build !darwin

package harness

import "errors"

// cloneTree has no portable equivalent, so non-Darwin hosts take the cp -R fallback: clonefile(2) is
// Darwin-only, and Linux's reflink is filesystem-dependent (btrfs/XFS yes, ext4 no) — a `cp
// --reflink=auto` here would silently degrade to a full copy on the most common CI filesystem anyway,
// buying nothing for the portability cost. This suite's home is macOS.
//
// cloneTree 无可移植等价物，故非 Darwin 主机走 cp -R 回落：clonefile(2) 是 Darwin 独有，而 Linux 的
// reflink 取决于文件系统（btrfs/XFS 有、ext4 无）——在此写 `cp --reflink=auto` 在最常见的 CI 文件系统上
// 也只会静默退化成全量拷贝，付了移植代价却什么都没买到。本套件的主场是 macOS。
func cloneTree(_, _ string) error {
	return errors.ErrUnsupported
}
