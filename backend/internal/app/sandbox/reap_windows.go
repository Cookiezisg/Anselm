//go:build windows

package sandbox

import "os"

// killSurvivor kills the single recorded pid — windows has no POSIX process groups,
// so the boot reaper stays best-effort single-pid (descendants are reaped by the
// per-process Job Object on the live path, not by this cross-boot recovery).
//
// killSurvivor 杀掉记录的单个 pid——windows 无 POSIX 进程组，故 boot 回收器保持 best-effort
// 单 pid（后代由 live 路径的 per-process Job Object 收割，不靠这条跨 boot 恢复）。
func killSurvivor(p *os.Process, _ int) bool {
	return p.Kill() == nil
}
