//go:build unix

package shell

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"

	"go.uber.org/zap"
)

// These tests cover the CRASH path (T3): the in-memory registry dies with the backend, so the
// pid manifest under pidDir is the only net. A "crash" is simulated the honest way — the first
// manager is simply dropped without Stop(), exactly what SIGKILL/panic/OOM leave behind; a
// second manager (the "next boot") must reap the survivors from the manifest alone. Real
// processes, real kills, no mocks.
//
// 这些测试盯崩溃路径(T3):内存注册表随后端一起死,pidDir 下的 pid 清单是唯一的网。「崩溃」用
// 诚实方式模拟——第一个 manager 不走 Stop() 直接丢弃,恰是 SIGKILL/panic/OOM 留下的现场;第二个
// manager(「下次 boot」)必须只凭清单收割幸存者。真进程、真杀、不 mock。

var bashIDRe = regexp.MustCompile(`bash_id=(bsh_[0-9a-f]+)`)

// spawnBackground runs command through the REAL Bash tool in background mode and returns the
// registered process.
//
// spawnBackground 经真 Bash 工具后台跑 command,返回注册的进程。
func spawnBackground(t *testing.T, mgr *ProcessManager, command string) *BgProcess {
	t.Helper()
	args, err := json.Marshal(map[string]any{"command": command, "run_in_background": true})
	if err != nil {
		t.Fatalf("marshal args: %v", err)
	}
	out, err := (&Bash{mgr: mgr}).Execute(context.Background(), string(args))
	if err != nil {
		t.Fatalf("Bash background execute: %v", err)
	}
	m := bashIDRe.FindStringSubmatch(out)
	if m == nil {
		t.Fatalf("no bash_id in output: %q", out)
	}
	p, err := mgr.Get(m[1])
	if err != nil {
		t.Fatalf("get %s: %v", m[1], err)
	}
	return p
}

// waitPidGone polls until Signal(0) reports pid gone (SIGKILL delivery + reaping are async).
//
// waitPidGone 轮询到 Signal(0) 报告 pid 已消失(SIGKILL 投递 + 收尸是异步的)。
func waitPidGone(t *testing.T, pid int, what string) {
	t.Helper()
	for range 100 {
		if syscall.Kill(pid, syscall.Signal(0)) != nil {
			return
		}
		time.Sleep(50 * time.Millisecond)
	}
	_ = syscall.Kill(-pid, syscall.SIGKILL)
	_ = syscall.Kill(pid, syscall.SIGKILL)
	t.Fatalf("%s (pid %d) survived the boot reaper — T3 net has a hole", what, pid)
}

// readPidFile polls for a helper-written pid file and parses it.
//
// readPidFile 轮询 helper 写出的 pid 文件并解析。
func readPidFile(t *testing.T, path string) int {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		raw, err := os.ReadFile(path)
		if err == nil && strings.TrimSpace(string(raw)) != "" {
			pid, err := strconv.Atoi(strings.TrimSpace(string(raw)))
			if err != nil {
				t.Fatalf("parse %s: %v", path, err)
			}
			return pid
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("pid file %s never appeared", path)
	return 0
}

// TestReapStaleOnBoot_CrashPath_KillsWorkerGroup — the ledger's measured B-form
// (`sleep & ×3 + wait` = the `npm run dev` shape, "1 crash = 4 survivors"): after a simulated
// crash the next boot must take out the LEADER and every worker via one negative-pgid kill.
func TestReapStaleOnBoot_CrashPath_KillsWorkerGroup(t *testing.T) {
	pidDir := t.TempDir()
	scratch := t.TempDir()

	mgr1 := NewProcessManager(pidDir)
	cmd := fmt.Sprintf(
		"sleep 30 & echo $! > %[1]s/w1; sleep 30 & echo $! > %[1]s/w2; sleep 30 & echo $! > %[1]s/w3; wait",
		scratch)
	proc := spawnBackground(t, mgr1, cmd)
	leader := proc.Cmd.Process.Pid
	t.Cleanup(func() { _ = syscall.Kill(-leader, syscall.SIGKILL) })

	workers := []int{
		readPidFile(t, filepath.Join(scratch, "w1")),
		readPidFile(t, filepath.Join(scratch, "w2")),
		readPidFile(t, filepath.Join(scratch, "w3")),
	}
	if _, err := os.Stat(filepath.Join(pidDir, proc.ID+".pid")); err != nil {
		t.Fatalf("pid manifest record missing while group runs: %v", err)
	}

	// CRASH: mgr1 dropped hot — no Stop(), registry gone. 崩溃:mgr1 直接丢弃,不走 Stop()。
	mgr2 := NewProcessManager(pidDir)
	mgr2.ReapStaleOnBoot(zap.NewNop())

	waitPidGone(t, leader, "group leader")
	for i, w := range workers {
		waitPidGone(t, w, fmt.Sprintf("worker %d", i+1))
	}
	if _, err := os.Stat(filepath.Join(pidDir, proc.ID+".pid")); !os.IsNotExist(err) {
		t.Fatalf("manifest record not removed after boot reap (err=%v)", err)
	}
}

// TestNoteExited_ClearsRecordOnceGroupFullyDead — a short job's record must vanish the moment
// the group is fully dead, closing the pid-reuse window (the manifest never outlives what it
// describes on the happy path).
func TestNoteExited_ClearsRecordOnceGroupFullyDead(t *testing.T) {
	pidDir := t.TempDir()
	mgr := NewProcessManager(pidDir)
	proc := spawnBackground(t, mgr, "true")

	path := filepath.Join(pidDir, proc.ID+".pid")
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(path); os.IsNotExist(err) {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("record %s still present after the job's group fully died", path)
}

// TestNoteExited_KeepsRecordWhileGrandchildSurvives — the daemon form (sh -c 'x & ' with fds
// detached, as real daemons do): the leader exits and IS reaped, but a grandchild keeps the
// GROUP alive, so noteExited must keep the record (POSIX reserves the pgid — it is provably
// still ours), and the next boot must reap the grandchild through the leaderless group.
func TestNoteExited_KeepsRecordWhileGrandchildSurvives(t *testing.T) {
	pidDir := t.TempDir()
	scratch := t.TempDir()

	mgr1 := NewProcessManager(pidDir)
	// The daemon detaches its fds; the pipes close with sh, so cmd.Wait reaps the leader and
	// noteExited actually runs. 守护进程摘掉自己的 fd;管道随 sh 关闭,cmd.Wait 收尸、noteExited 真跑。
	proc := spawnBackground(t, mgr1,
		fmt.Sprintf("sleep 30 > /dev/null 2>&1 & echo $! > %s/gw", scratch))
	leader := proc.Cmd.Process.Pid
	t.Cleanup(func() { _ = syscall.Kill(-leader, syscall.SIGKILL) })
	grandchild := readPidFile(t, filepath.Join(scratch, "gw"))

	// Wait for the leader to be reaped (status leaves running) — noteExited has then made its
	// keep/clear decision. 等组长被收尸(status 离开 running)——noteExited 已做完留/删裁决。
	deadline := time.Now().Add(5 * time.Second)
	reaped := false
	for time.Now().Before(deadline) {
		if _, _, status, _ := proc.drainNew(); status != StatusRunning {
			reaped = true
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if !reaped {
		t.Fatal("leader never left running — daemon fd redirect did not release the pipes")
	}
	path := filepath.Join(pidDir, proc.ID+".pid")
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("record dropped while grandchild %d still holds the group: %v", grandchild, err)
	}

	// CRASH → next boot reaps the survivor group even though its leader is long dead.
	// 崩溃 → 下次 boot 收割幸存组,哪怕组长早已死透。
	mgr2 := NewProcessManager(pidDir)
	mgr2.ReapStaleOnBoot(zap.NewNop())
	waitPidGone(t, grandchild, "daemon grandchild")
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatalf("manifest record not removed after boot reap (err=%v)", err)
	}
}

// TestReapStaleOnBoot_ZombieLeaderGroupStillReaped — regression for a hole caught by a real
// probe: a grandchild that inherits the pipes keeps cmd.Wait blocked, so the exited leader
// stays a ZOMBIE in the spawning process — and macOS getpgid refuses zombies (ESRCH) while
// signal 0 still sees them. The reaper must not read "unqueryable leader" as "recycled pid"
// and spare the live group. (A real boot never faces a prior backend's zombies — init reaps
// them — but the innocence guard must only trust a POSITIVE non-leader answer.)
func TestReapStaleOnBoot_ZombieLeaderGroupStillReaped(t *testing.T) {
	pidDir := t.TempDir()
	scratch := t.TempDir()

	mgr1 := NewProcessManager(pidDir)
	// No fd redirect: the grandchild holds the pipes → pumps never EOF → leader stays zombie.
	// 不重定向 fd:孙进程攥着管道 → pump 永不 EOF → 组长滞留僵尸态。
	proc := spawnBackground(t, mgr1, fmt.Sprintf("sleep 30 & echo $! > %s/gw", scratch))
	leader := proc.Cmd.Process.Pid
	t.Cleanup(func() { _ = syscall.Kill(-leader, syscall.SIGKILL) })
	grandchild := readPidFile(t, filepath.Join(scratch, "gw"))

	mgr2 := NewProcessManager(pidDir)
	mgr2.ReapStaleOnBoot(zap.NewNop())
	waitPidGone(t, grandchild, "grandchild behind a zombie leader")
}

// TestReapStaleOnBoot_SparesRecycledNonLeaderPid — the don't-kill-innocents guard: a record
// whose pid now belongs to a live process that is NOT a group leader (the common shape of pid
// recycling — our children are ALWAYS leaders) must be spared and the stale record dropped.
func TestReapStaleOnBoot_SparesRecycledNonLeaderPid(t *testing.T) {
	pidDir := t.TempDir()
	scratch := t.TempDir()

	// A live innocent: worker inside someone else's group (pgid != pid).
	// 一个活着的无辜进程:别人组里的 worker(pgid != pid)。
	innocentParent := exec.Command("sh", "-c", fmt.Sprintf("sleep 30 & echo $! > %s/ip; wait", scratch))
	innocentParent.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	if err := innocentParent.Start(); err != nil {
		t.Fatalf("start innocent parent: %v", err)
	}
	t.Cleanup(func() {
		_ = syscall.Kill(-innocentParent.Process.Pid, syscall.SIGKILL)
		_ = innocentParent.Wait()
	})
	innocent := readPidFile(t, filepath.Join(scratch, "ip"))

	// A stale record claiming that pid — as if OUR dead child's pid got recycled.
	// 一条声称该 pid 的陈旧记录——仿佛我们已死子进程的 pid 被复用了。
	if err := os.WriteFile(filepath.Join(pidDir, "bsh_deadbeef00000000.pid"),
		[]byte(strconv.Itoa(innocent)), 0o644); err != nil {
		t.Fatalf("write fake record: %v", err)
	}

	NewProcessManager(pidDir).ReapStaleOnBoot(zap.NewNop())

	if err := syscall.Kill(innocent, syscall.Signal(0)); err != nil {
		t.Fatalf("boot reaper killed an innocent non-leader that merely reused a recorded pid")
	}
	if _, err := os.Stat(filepath.Join(pidDir, "bsh_deadbeef00000000.pid")); !os.IsNotExist(err) {
		t.Fatalf("stale record should be dropped even when spared (err=%v)", err)
	}
}
