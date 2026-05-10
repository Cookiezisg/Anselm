//go:build windows

// proc_windows.go: process tree management for Windows via Job Objects.
//
// Strategy: at first sandbox spawn, create a single master Job Object,
// set JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE on it, and assign Forgify itself
// to the job. Windows 10 1607+ supports nested jobs, so this works even
// if Forgify is wrapped in another job (Windows Service, container, etc.).
// All future Forgify-spawned children inherit the master job from their
// parent (Forgify) automatically, so no per-spawn Job assignment is
// needed.
//
// When Forgify exits — gracefully OR via kill -9 / Task Manager —
// the OS closes Forgify's handle to the job, the job's last ref drops,
// and JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE strong-kills every member.
// This is the **strongest** leak-prevention mechanism on any platform
// in our v1 set; macOS and Linux can only approximate it (see
// proc_darwin.go / proc_linux.go).
//
// taskkill is kept as the per-process kill mechanism (cmd.Cancel
// callback for ctx-cancel propagation) since Windows lacks the unix
// "negative pid kills the group" trick. Job Object handles app-level
// catastrophic cleanup; taskkill handles per-call cleanup.
//
// proc_windows.go：Windows 通过 Job Object 管理进程树。
//
// 策略：sandbox 首次 spawn 时创建一个 master Job Object，设
// JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE，把 Forgify 自身 assign 到 job。
// Windows 10 1607+ 支持 nested job，即便 Forgify 被另一 job 包着
// （Windows Service / 容器等）也工作。之后 Forgify spawn 的所有 child
// 自动从父进程（Forgify）继承 master job，无需 per-spawn assign。
//
// Forgify 退出时——优雅 OR kill -9 / Task Manager——OS 关闭 Forgify 的
// job handle，job 最后一个 ref 释放，JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
// 强 kill 所有成员。这是 v1 平台集中**最强**的 leak 防御；macOS 和 Linux
// 只能近似（见 proc_darwin.go / proc_linux.go）。
//
// taskkill 保留作 per-process kill 机制（cmd.Cancel callback 传播 ctx 取消）
// ——Windows 没 unix "负 pid 杀进程组" 技巧。Job Object 管 app-level
// 灾难性清理；taskkill 管 per-call 清理。

package sandbox

import (
	"fmt"
	"os/exec"
	"strconv"
	"sync"
	"unsafe"

	"golang.org/x/sys/windows"
)

var (
	masterJobOnce sync.Once
	masterJobErr  error
	// masterJob is held for Forgify's lifetime — closing it would trigger
	// the kill-on-close protection prematurely. The OS releases it when
	// the process exits.
	//
	// masterJob 持 Forgify 整个生命周期——提前关会触发 kill-on-close
	// 保护。进程退出时 OS 释放。
	masterJob windows.Handle
)

// EnsureMasterJob creates the per-process Job Object on first call,
// assigning Forgify itself to it so all subsequent child processes
// inherit. Idempotent — subsequent calls return cached error or nil.
//
// main.go calls this once during boot to fail-fast if the OS denies the
// job (rare; usually only happens in restrictive container/sandbox
// environments). Spawn paths also call it lazily as a safety net.
//
// EnsureMasterJob 首次调用创建 per-process Job Object 并把 Forgify 自身
// assign 进去，后续所有 child 自动继承。幂等——后续调用返缓存的错或 nil。
//
// main.go 启动时调一次让 OS 拒绝 job 时立即失败（罕见，通常只在受限
// container/sandbox 环境）。Spawn 路径也懒调作 safety net。
func EnsureMasterJob() error {
	masterJobOnce.Do(initMasterJob)
	return masterJobErr
}

func initMasterJob() {
	h, err := windows.CreateJobObject(nil, nil)
	if err != nil {
		masterJobErr = fmt.Errorf("sandbox.initMasterJob: CreateJobObject: %w", err)
		return
	}
	info := windows.JOBOBJECT_EXTENDED_LIMIT_INFORMATION{
		BasicLimitInformation: windows.JOBOBJECT_BASIC_LIMIT_INFORMATION{
			LimitFlags: windows.JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE,
		},
	}
	_, err = windows.SetInformationJobObject(
		h,
		windows.JobObjectExtendedLimitInformation,
		uintptr(unsafe.Pointer(&info)),
		uint32(unsafe.Sizeof(info)),
	)
	if err != nil {
		_ = windows.CloseHandle(h)
		masterJobErr = fmt.Errorf("sandbox.initMasterJob: SetInformationJobObject: %w", err)
		return
	}
	if err := windows.AssignProcessToJobObject(h, windows.CurrentProcess()); err != nil {
		_ = windows.CloseHandle(h)
		masterJobErr = fmt.Errorf("sandbox.initMasterJob: AssignProcessToJobObject(self): %w", err)
		return
	}
	masterJob = h
}

// setupProcessGroup ensures the master Job Object is initialized so that
// children spawned after this call inherit it. Must be called before
// cmd.Start().
//
// setupProcessGroup 确保 master Job Object 已初始化，让此后 spawn 的 child
// 继承。必须在 cmd.Start() 前调。
func setupProcessGroup(cmd *exec.Cmd) {
	// Best-effort. If the job init failed (e.g. OS denial in restricted
	// environments), we still proceed — the spawn just won't get the
	// catastrophic-cleanup safety net. Service.Shutdown() (Layer A) and
	// boot-time PID scan (Layer B) still work.
	//
	// Best-effort。job init 失败时（如受限环境 OS 拒绝）仍继续——这次
	// spawn 不获灾难性清理 safety net。Service.Shutdown()（层 A）和
	// 启动 PID 扫描（层 B）仍工作。
	_ = EnsureMasterJob()
}

// killProcessGroup runs `taskkill /T /F /PID <pid>` to terminate cmd's
// entire process tree. /T = tree (includes all descendants); /F = force
// (no graceful shutdown chance). Used as cmd.Cancel callback. Returns
// nil if the process never started.
//
// killProcessGroup 跑 `taskkill /T /F /PID <pid>` 终止 cmd 整个进程树。
// /T = 树（含所有后代）；/F = 强制（不给优雅关闭机会）。作 cmd.Cancel
// callback。进程未启动返 nil。
func killProcessGroup(cmd *exec.Cmd) error {
	if cmd.Process == nil {
		return nil
	}
	pid := strconv.Itoa(cmd.Process.Pid)
	out, err := exec.Command("taskkill", "/T", "/F", "/PID", pid).CombinedOutput()
	if err != nil {
		return fmt.Errorf("sandbox.killProcessGroup: taskkill: %w (output: %s)", err, out)
	}
	return nil
}
