// restore.go — Layer B leak prevention: scan the manifest at boot for
// running PIDs left by the previous run (whether it exited gracefully
// without clearing them, or — more importantly — crashed bypassing
// Layer A's Service.Shutdown), kill any survivors, and clear the
// running_pid column so the new run starts from a clean slate.
//
// Why this matters: Layer A handles graceful exits. macOS has no kernel
// equivalent to Linux's PR_SET_PDEATHSIG or Windows' Job Object
// kill-on-close, so a kill -9 of the Forgify process leaves long-lived
// children running. The boot scan is our last-resort cleanup.
//
// On macOS: this is the only safety net for crash-resistant cleanup.
// On Linux: kernel mostly already SIGTERM'd the children via
// PR_SET_PDEATHSIG, but the manifest scan still tidies up by clearing
// stale running_pid columns and explicitly killing anything that escaped.
// On Windows: the OS already strong-killed everything via Job Object;
// the scan just clears the manifest.
//
// restore.go ——层 B leak 防御：启动时扫 manifest 找上次运行留下的 running
// PID（无论是优雅退出未清还是——更重要——绕过层 A Service.Shutdown 的 crash），
// 杀残留 + 清 running_pid 列，让新运行从干净状态开始。
//
// 为啥重要：层 A 管优雅退出。macOS 无 Linux PR_SET_PDEATHSIG 或 Windows
// Job Object kill-on-close 的内核等价物，kill -9 Forgify 进程会留长生命周期
// children。启动扫描是最后兜底。
//
// macOS 上：这是 crash-resistant 清理的唯一安全网。
// Linux 上：内核多半已通过 PR_SET_PDEATHSIG 给 children SIGTERM，但 manifest
// 扫描仍清掉 stale running_pid 列 + 显式 kill 漏网者。
// Windows 上：OS 已通过 Job Object 强 kill 一切；扫描只清 manifest。

package sandbox

import (
	"context"
	"os"
	"runtime"
	"syscall"

	"go.uber.org/zap"
)

// RestoreOrCleanupOnBoot iterates envs with running_pid > 0, sends a
// best-effort kill to each, and clears the manifest column. Idempotent:
// already-dead PIDs and missing manifest entries are no-ops. Errors are
// logged but not returned — boot must proceed even if cleanup partial.
//
// RestoreOrCleanupOnBoot 遍历 running_pid > 0 的 env，best-effort kill 每
// 个，清 manifest 列。幂等：已死 PID 和缺失 manifest 条目都 no-op。错误
// log 不返——清理部分失败 boot 仍要继续。
func (s *Service) RestoreOrCleanupOnBoot(ctx context.Context) {
	envs, err := s.repo.ListEnvsWithRunningPID(ctx)
	if err != nil {
		s.log.Warn("sandbox boot scan: list envs with running pid failed (skipping cleanup)",
			zap.Error(err))
		return
	}
	if len(envs) == 0 {
		return
	}

	killed, alreadyDead := 0, 0
	for _, e := range envs {
		alive := killIfAlive(e.RunningPID)
		if alive {
			killed++
			s.log.Info("sandbox boot scan: killed stale process",
				zap.String("env_id", e.ID),
				zap.String("owner_kind", e.OwnerKind),
				zap.String("owner_id", e.OwnerID),
				zap.Int("pid", e.RunningPID))
		} else {
			alreadyDead++
		}
		if err := s.repo.ClearEnvRunningPID(ctx, e.ID); err != nil {
			s.log.Warn("sandbox boot scan: clear running_pid failed",
				zap.String("env_id", e.ID),
				zap.Error(err))
		}
	}
	s.log.Info("sandbox boot scan complete",
		zap.Int("scanned", len(envs)),
		zap.Int("killed", killed),
		zap.Int("already_dead", alreadyDead))
}

// killIfAlive sends SIGKILL to pid if the process is still alive,
// returning whether a kill was attempted. Cross-platform: on unix we
// probe with signal 0 first to avoid noisy errors; on Windows
// os.FindProcess already validates via OpenProcess.
//
// killIfAlive 进程仍活就给 pid 发 SIGKILL，返是否尝试了 kill。跨平台：
// unix 先用 signal 0 探测避免噪声错；Windows 上 os.FindProcess 已通过
// OpenProcess 验证。
func killIfAlive(pid int) bool {
	if pid <= 0 {
		return false
	}
	p, err := os.FindProcess(pid)
	if err != nil {
		return false
	}
	if runtime.GOOS != "windows" {
		// Signal 0 doesn't deliver anything; just probes existence.
		// Signal 0 不发任何信号；只探测存在性。
		if err := p.Signal(syscall.Signal(0)); err != nil {
			return false
		}
	}
	// Alive — kill. p.Kill is SIGKILL on unix, TerminateProcess on Windows.
	// 活着——kill。p.Kill 在 unix 是 SIGKILL，Windows 是 TerminateProcess。
	if err := p.Kill(); err != nil {
		// Race: process exited between probe and kill. Treat as not-killed.
		// race：探测到 kill 之间进程退出。当未 kill。
		return false
	}
	return true
}
