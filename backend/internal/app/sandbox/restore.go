package sandbox

import (
	"context"
	"os"
	"runtime"
	"syscall"

	"go.uber.org/zap"
)

// RestoreOrCleanupOnBoot kills survivor PIDs recorded in the manifest from a
// prior run (a long-lived process that outlived a backend crash); best-effort.
//
// RestoreOrCleanupOnBoot 杀掉 manifest 里上次运行记录的残留 PID（熬过后端崩溃的长生命
// 周期进程）；best-effort。
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
		if killIfAlive(e.RunningPID) {
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

// killIfAlive reports whether pid was alive (and kills it). Signal(0) probes
// liveness without killing; on success killSurvivor terminates the survivor.
//
// The recorded pid is the DIRECT child the backend spawned (spawn.go SetEnvRunningPID
// records inner.PID()), which is its process-group LEADER — SpawnOnce/SpawnLongLived
// both setupProcessGroup (Setpgid, so pgid == pid). A bare positive-pid kill would
// only reap that leader and orphan its grandchildren: a python MCP server's recorded
// pid is the `uvx`/`npx` wrapper, which forks the real python/node server into the
// SAME group — kill the leader alone and that server survives reparented to init. So
// the boot reaper must SIGKILL the whole group (negative pgid on unix), mirroring the
// live kill path's killProcessGroup; windows stays best-effort single-pid (no pgroups).
//
// killIfAlive 报告 pid 是否存活（并杀掉）。Signal(0) 探活不杀；存活则 killSurvivor 终结残留。
//
// 记录的 pid 是后端 spawn 的直接子进程（spawn.go SetEnvRunningPID 记 inner.PID()），它是
// 进程组组长——SpawnOnce/SpawnLongLived 都 setupProcessGroup（Setpgid，故 pgid == pid）。裸正
// pid kill 只会收割组长、留下孙进程成孤儿：python MCP server 记录的 pid 是 `uvx`/`npx` 包装器，
// 它把真正的 python/node server fork 进同一组——只杀组长那个 server 会熬过来、被 init 收养。故 boot
// 回收器必须对整组发 SIGKILL（unix 用负 pgid），与 live kill 路径的 killProcessGroup 对齐；windows
// 保持 best-effort 单 pid（无进程组）。
func killIfAlive(pid int) bool {
	if pid <= 0 {
		return false
	}
	p, err := os.FindProcess(pid)
	if err != nil {
		return false
	}
	if runtime.GOOS != "windows" {
		if err := p.Signal(syscall.Signal(0)); err != nil {
			return false
		}
	}
	return killSurvivor(p, pid)
}
