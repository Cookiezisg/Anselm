//go:build unix

package shell

import (
	"os/exec"
	"syscall"
)

// setProcessGroup puts the child in its own process group, so killProcessTree can take out
// grandchildren too (sh -c pipelines / daemons keep running — and keep the stdout pipe open —
// if only sh itself is killed).
//
// setProcessGroup 让子进程自成进程组，使 killProcessTree 能连孙进程一起杀（sh -c 的管道 /
// daemon 在只杀 sh 时会继续跑——还攥着 stdout 管道不放）。
func setProcessGroup(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
}

// killProcessTree SIGKILLs the whole process group (negative pid), falling back to killing
// just the direct child when the group is already gone.
//
// killProcessTree 对整个进程组（负 pid）发 SIGKILL，组已不存在时退化为只杀直接子进程。
func killProcessTree(cmd *exec.Cmd) error {
	if cmd == nil || cmd.Process == nil {
		return nil
	}
	if err := syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL); err == nil {
		return nil
	}
	return cmd.Process.Kill()
}

// groupAlive reports whether pid's process GROUP still has live members (signal 0 to the
// negative pgid). POSIX reserves a pgid while any member lives, so a live group is positively
// the one WE spawned — the leader pid cannot have been recycled meanwhile.
//
// groupAlive 报告 pid 的进程组是否还有存活成员（对负 pgid 发 signal 0）。POSIX 保留有存活成员
// 的 pgid，组活着就必然还是我们 spawn 的那个组——组长 pid 不可能已被复用。
func groupAlive(pid int) bool {
	return syscall.Kill(-pid, 0) == nil
}

// reapStaleGroup kills a recorded background group from a prior run; reports whether anything
// was alive. Same shape as the sandbox boot reaper (probe → group SIGKILL, restore.go
// killIfAlive/killSurvivor) with one extra guard against pid recycling: our children are
// ALWAYS spawned as group leaders (setProcessGroup ⇒ pgid == pid, and leadership can't be
// lost), so a pid that now POSITIVELY belongs to a live non-leader (Getpgid succeeds with
// pgid != pid — the common shape of recycling, most processes are not leaders) was recycled
// by an innocent → spared, never killed. Any other Getpgid outcome proves nothing against us:
// ESRCH covers both a reaped leader whose grandchildren survive (sh -c 'daemon &') AND — on
// macOS — a zombie leader (getpgid refuses zombies while signal 0 still sees them; probed on
// real processes). Both fall through to the single liveness gate, the GROUP probe: POSIX
// reserves a pgid while any member lives, so a live group is provably the one we spawned.
//
// reapStaleGroup 收割上次运行记录的后台进程组；报告是否有活口。与 sandbox boot 回收器同构
// （探活 → 整组 SIGKILL），多一道防 pid 复用的闸：我们的子进程恒为组长（setProcessGroup ⇒
// pgid == pid，组长身份不会丢），故 pid 被**确证**属于存活非组长（Getpgid 成功且 pgid != pid
// ——复用的常见形态,绝大多数进程不是组长）即被无辜者复用 → 放过不杀。Getpgid 其余结果都不能
// 洗脱我们:ESRCH 既是「组长被收尸、孙进程幸存」（sh -c 'daemon &'）也是——macOS 上——「僵尸
// 组长」（getpgid 拒绝僵尸而 signal 0 仍见其在,真进程探针实测）。两者都落到唯一的存活闸:组
// 探针——POSIX 保留有存活成员的 pgid,组活着即可证明是我们 spawn 的那个组。
func reapStaleGroup(pid int) bool {
	if pid <= 0 {
		return false
	}
	if pgid, err := syscall.Getpgid(pid); err == nil && pgid != pid {
		return false // recycled by an innocent non-leader — spare it. 被无辜非组长复用——放过。
	}
	if !groupAlive(pid) {
		return false
	}
	return syscall.Kill(-pid, syscall.SIGKILL) == nil
}
