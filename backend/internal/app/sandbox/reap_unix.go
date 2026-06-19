//go:build unix

package sandbox

import (
	"os"
	"syscall"
)

// killSurvivor SIGKILLs the recorded pid's whole process group (negative pgid; the
// recorded pid is the group leader so pgid == pid), falling back to a single-pid kill
// if the group is already gone — so uvx/npx grandchildren die with their wrapper.
//
// killSurvivor 对记录 pid 的整个进程组（负 pgid；记录 pid 即组长，故 pgid == pid）发 SIGKILL，
// 组已不存在时退化为单 pid kill——使 uvx/npx 孙进程随包装器一同死掉。
func killSurvivor(p *os.Process, pid int) bool {
	if err := syscall.Kill(-pid, syscall.SIGKILL); err == nil {
		return true
	}
	return p.Kill() == nil
}
