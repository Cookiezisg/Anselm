//go:build darwin

package harness

import "golang.org/x/sys/unix"

// cloneTree copy-on-write clones a whole directory hierarchy in ONE syscall.
//
// Handing clonefile(2) the directory itself makes the kernel clone the tree wholesale (~90ms for this
// cache); the per-file route `cp -c` issues one clonefile per entry and spends ~3.4s on the same 6456
// files, because the cost is driven by file count, not bytes. Flags are 0 rather than CLONE_NOFOLLOW
// so that a symlinked cache root resolves exactly the way the cp -R fallback would — the two paths
// must not disagree about what they seeded.
//
// cloneTree 用**一次** syscall 写时复制克隆整棵目录树。
// 把 clonefile(2) 直接喂给目录本身，内核会整树克隆（本缓存 ~90ms）；逐文件路线 `cp -c` 对每个条目发一次
// clonefile，在同样 6456 个文件上要花 ~3.4s——代价由文件**个数**而非字节数决定。flags 取 0 而非
// CLONE_NOFOLLOW，使符号链接形式的缓存根解析得与 cp -R 回落完全一致——两条路径对「预置了什么」不能有分歧。
func cloneTree(src, dst string) error {
	return unix.Clonefile(src, dst, 0)
}
