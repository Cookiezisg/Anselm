// exec_helper.go — RunWithStderrCapture wraps the install/dep-fetch
// command pattern used across MiseInstaller / Node / Python / Rust / Go /
// Java / Ruby / PHP / .NET / Playwright. It streams each stderr line to
// an optional progress callback AND captures the last 4 KB into a ring
// buffer, so cmd.Wait failures surface the real upstream error rather
// than an opaque sentinel — addresses the §S3 "errors not swallowed"
// invariant that earlier D2 work violated and cost half a debug session.
//
// exec_helper.go — RunWithStderrCapture 封装 MiseInstaller / Node /
// Python / Rust / Go / Java / Ruby / PHP / .NET / Playwright 共用的
// install/dep-fetch 命令模式。每行 stderr 进可选 progress 回调 + 最近
// 4 KB 进环形缓冲；cmd.Wait 失败时把真实上游 error 暴露出来——而不是
// 不透明 sentinel。修补 D2 时违反 §S3"错误不吞"换来的半个 debug session。
package sandbox

import (
	"bufio"
	"fmt"
	"os/exec"
	"strings"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

// stderrTailMax caps the captured stderr ring buffer; larger upstream
// outputs (npm verbose, mise debug) get truncated from the head so we keep
// the trailing context that usually contains the actual error line.
//
// stderrTailMax 限定捕获的 stderr 环形缓冲；上游输出更长（npm verbose、
// mise debug）从头截断，保留尾部——通常含真实错误行。
const stderrTailMax = 4096

// RunWithStderrCapture starts cmd, fans each stderr line into the optional
// progress callback, captures up to stderrTailMax of trailing stderr, and
// waits for completion. On non-zero exit it wraps the original cmd.Wait
// error and the stderr tail behind sentinel; msgPrefix locates the call
// site (e.g. "sandbox.NodeEnvManager.InstallDeps lodash"). cmd.Stderr must
// not be set by the caller — this helper owns it.
//
// RunWithStderrCapture 启动 cmd，每行 stderr 同时进 progress 回调 + 截尾
// 缓冲，等待完成。非零退出时把原 cmd.Wait err + stderr tail 一并裹进
// sentinel；msgPrefix 定位调用点。调用方不能预设 cmd.Stderr——本 helper
// 拥有该字段。
func RunWithStderrCapture(cmd *exec.Cmd, stream sandboxdomain.ProgressFunc, sentinel error, msgPrefix string) error {
	stderrPipe, err := cmd.StderrPipe()
	if err != nil {
		return fmt.Errorf("%s: stderr pipe: %w", msgPrefix, err)
	}
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("%s: start: %w", msgPrefix, err)
	}

	var tail []byte
	scanner := bufio.NewScanner(stderrPipe)
	for scanner.Scan() {
		line := scanner.Text()
		if stream != nil {
			stream("running", line, -1)
		}
		tail = append(tail, line...)
		tail = append(tail, '\n')
		if len(tail) > stderrTailMax {
			tail = tail[len(tail)-stderrTailMax:]
		}
	}
	// scanner.Err() returns the first non-EOF read error (e.g. pipe broken
	// mid-read). Don't gate cmd.Wait on it — we still want the exit status
	// — but the scanner failure is observable here and worth a tail-append
	// so the eventual error message includes context.
	//
	// scanner.Err() 返第一个非 EOF 读错误（如读到一半管道断）。不挡
	// cmd.Wait——仍要 exit status——但 scanner 失败可观，append 到 tail
	// 让最终 error 信息含上下文。
	if scanErr := scanner.Err(); scanErr != nil {
		tail = append(tail, []byte("(stderr scan error: "+scanErr.Error()+")\n")...)
	}

	if err := cmd.Wait(); err != nil {
		snippet := strings.TrimSpace(string(tail))
		if snippet == "" {
			snippet = "(no stderr)"
		}
		// Multi-%w (Go 1.20+) preserves BOTH the install-path sentinel
		// (e.g. ErrRuntimeInstallFailed) AND the wrapped *exec.ExitError.
		// Callers can errors.Is() either; previously %v collapsed
		// ExitError into a string and broke the chain. This single fix
		// flows through mise/Node/Python install paths since they all
		// route through here.
		//
		// 双 %w（Go 1.20+）同时保留 install 路径 sentinel 与
		// *exec.ExitError；之前 %v 折损 ExitError 类型。本处一改通三条
		// install path（mise / Node / Python 都用这条 helper）。
		return fmt.Errorf("%s: %w: %w: %s", msgPrefix, sentinel, err, snippet)
	}
	return nil
}

// Compile-time check that the package's domain sentinels are reachable
// from this file, so a future rename of the import path breaks here
// loudly rather than silently leaving msg lookup in stale state.
//
// 编译期检查 domain sentinel 在本文件可达，import 路径将来改名会在这里
// 直接编译失败而不是悄悄留旧状态。
var _ = sandboxdomain.ErrRuntimeInstallFailed
