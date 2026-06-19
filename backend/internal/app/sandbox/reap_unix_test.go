//go:build unix

package sandbox

import (
	"bufio"
	"context"
	"os/exec"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"
)

// TestRestoreOnBoot_KillsGrandchildViaProcessGroup — R6: the boot reaper must SIGKILL
// the whole process GROUP of the recorded survivor pid, not just that one pid. The
// recorded pid is the wrapper the backend spawned (uvx/npx); the real MCP server is a
// grandchild forked into the SAME group. A bare positive-pid kill would orphan it. This
// test starts a `sh` parent in its own process group that forks a `sleep` grandchild and
// asserts killIfAlive(parent) takes the grandchild down with the group.
func TestRestoreOnBoot_KillsGrandchildViaProcessGroup(t *testing.T) {
	svc, _ := newServiceWithEnv(t, "fake-py")
	ctx := context.Background()

	// Parent leads its own process group; it forks a long sleep grandchild and prints the
	// grandchild's pid, then waits — mirroring how uvx/npx wrap the real server in-group.
	// 父进程自成进程组；fork 一个长 sleep 孙进程并打印其 pid，再 wait——模拟 uvx/npx 在组内包裹真服务。
	parent := exec.Command("sh", "-c", "sleep 30 & echo $!; wait")
	parent.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	stdout, err := parent.StdoutPipe()
	if err != nil {
		t.Fatalf("stdout pipe: %v", err)
	}
	if err := parent.Start(); err != nil {
		t.Fatalf("start parent: %v", err)
	}
	t.Cleanup(func() { _ = syscall.Kill(-parent.Process.Pid, syscall.SIGKILL) })

	line, err := bufio.NewReader(stdout).ReadString('\n')
	if err != nil {
		t.Fatalf("read grandchild pid: %v", err)
	}
	grandchild, err := strconv.Atoi(strings.TrimSpace(line))
	if err != nil {
		t.Fatalf("parse grandchild pid %q: %v", line, err)
	}

	if err := svc.repo.SetEnvRunningPID(ctx, "se_test", parent.Process.Pid); err != nil {
		t.Fatalf("set pid: %v", err)
	}

	svc.RestoreOrCleanupOnBoot(ctx)

	// The grandchild must be dead: a SIGKILL to the group reaps it. Poll briefly because
	// SIGKILL delivery + reparenting is asynchronous. Signal(0) on a dead pid → ESRCH.
	// 孙进程必须已死：对整组的 SIGKILL 把它收割。短轮询，因 SIGKILL 投递 + 重新挂载是异步的。
	dead := false
	for range 50 {
		if err := syscall.Kill(grandchild, syscall.Signal(0)); err != nil {
			dead = true
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if !dead {
		_ = syscall.Kill(grandchild, syscall.SIGKILL)
		t.Fatal("grandchild survived boot reaper — process group was not killed (R6)")
	}
}
