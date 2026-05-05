// restore_test.go — Layer B leak prevention end-to-end. Spawns a real
// long-lived sleep process to seed running_pid, then verifies
// RestoreOrCleanupOnBoot kills it + clears the manifest column.
//
// restore_test.go ——层 B leak 防御端到端。spawn 真长生命周期 sleep 进程
// 填 running_pid，验证 RestoreOrCleanupOnBoot 杀它 + 清 manifest 列。

package sandbox

import (
	"context"
	"os/exec"
	"runtime"
	"syscall"
	"testing"
	"time"
)

func TestRestoreOrCleanupOnBoot_KillsStaleProcessAndClearsPID(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("uses sleep + posix signal probe")
	}
	svc, owner := newServiceWithEnv(t, "fake-py")
	ctx := context.Background()

	// Start a real long-lived sleep we control directly (NOT via Service —
	// we want to simulate "previous run" state where a process is alive
	// but the Service has no live handle for it).
	//
	// 起一个真长生命周期 sleep 自己控制（**不**走 Service——模拟"上次
	// 运行"状态：进程活着但 Service 无 live handle）。
	sleepBin, err := exec.LookPath("sleep")
	if err != nil {
		t.Fatalf("look up sleep: %v", err)
	}
	cmd := exec.Command(sleepBin, "30")
	if err := cmd.Start(); err != nil {
		t.Fatalf("start sleep: %v", err)
	}
	stalePID := cmd.Process.Pid

	// Seed env's running_pid so the boot scan thinks this is a stale
	// previous-run process.
	// 填 env 的 running_pid 让启动扫描认为这是上次运行残留。
	envRow, err := svc.repo.FindEnvByOwner(ctx, owner.Kind, owner.ID)
	if err != nil {
		t.Fatalf("find env: %v", err)
	}
	if err := svc.repo.SetEnvRunningPID(ctx, envRow.ID, stalePID); err != nil {
		t.Fatalf("seed running PID: %v", err)
	}

	// Confirm the process is actually alive before the scan.
	// 扫描前确认进程真活。
	if err := cmd.Process.Signal(syscall.Signal(0)); err != nil {
		t.Fatalf("seeded process not alive before scan: %v", err)
	}

	// Run the boot scan.
	// 跑启动扫描。
	svc.RestoreOrCleanupOnBoot(ctx)

	// Verify the kill landed by waiting on cmd. If the boot scan failed
	// to kill, sleep 30 would block until the test deadline; if it
	// succeeded, Wait returns within milliseconds with a signal-killed
	// status (we don't assert exact error text — presence of completion
	// is the signal).
	//
	// 验证 kill 成功：等 cmd 退出。boot scan 失败则 sleep 30 阻塞到测试
	// 超时；成功则 Wait 在毫秒内返带 signal-killed status（不 assert 具体
	// 错文本——完成的事实就是信号）。
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	select {
	case <-done:
		// good — sleep was killed and reaped within the budget
	case <-time.After(2 * time.Second):
		t.Errorf("stale process %d not reapable 2s after boot scan (kill failed)", stalePID)
		_ = cmd.Process.Kill() // last-ditch cleanup so the test process doesn't leak
		<-done
	}

	// Manifest column must be cleared.
	// Manifest 列必须清。
	envRow, err = svc.repo.FindEnvByOwner(ctx, owner.Kind, owner.ID)
	if err != nil {
		t.Fatalf("re-find env: %v", err)
	}
	if envRow.RunningPID != 0 {
		t.Errorf("running_pid not cleared: got %d, want 0", envRow.RunningPID)
	}
}

func TestRestoreOrCleanupOnBoot_NoOpWhenNoStalePIDs(t *testing.T) {
	svc, _ := newServiceWithEnv(t, "fake-py")
	// No SetEnvRunningPID call — manifest is clean. Scan should be silent
	// no-op (no panic, no spurious log spam).
	//
	// 不调 SetEnvRunningPID——manifest 干净。扫描该静默 no-op
	// （不 panic，不噪声 log）。
	svc.RestoreOrCleanupOnBoot(context.Background())
}

func TestRestoreOrCleanupOnBoot_HandlesAlreadyDeadPID(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("uses /bin/true + posix signal probe")
	}
	svc, owner := newServiceWithEnv(t, "fake-py")
	ctx := context.Background()

	// Start + immediately reap a process so its PID exists in manifest
	// but the OS has already cleaned it up.
	// 起+立即 reap 进程，让 PID 在 manifest 里但 OS 已清理。
	trueBin, err := exec.LookPath("true")
	if err != nil {
		t.Fatalf("look up true: %v", err)
	}
	cmd := exec.Command(trueBin)
	if err := cmd.Run(); err != nil {
		t.Fatalf("run true: %v", err)
	}
	deadPID := cmd.Process.Pid

	envRow, err := svc.repo.FindEnvByOwner(ctx, owner.Kind, owner.ID)
	if err != nil {
		t.Fatalf("find env: %v", err)
	}
	if err := svc.repo.SetEnvRunningPID(ctx, envRow.ID, deadPID); err != nil {
		t.Fatalf("seed dead PID: %v", err)
	}

	// Scan must complete without error and clear the column.
	// 扫描必须无错完成 + 清列。
	svc.RestoreOrCleanupOnBoot(ctx)
	envRow, _ = svc.repo.FindEnvByOwner(ctx, owner.Kind, owner.ID)
	if envRow.RunningPID != 0 {
		t.Errorf("dead PID column not cleared: got %d, want 0", envRow.RunningPID)
	}
}
