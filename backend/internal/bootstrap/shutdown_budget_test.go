package bootstrap

import (
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"testing"
	"time"

	shelltool "github.com/sunweilin/anselm/backend/internal/app/tool/shell"
)

// TestShutdownBudget_NestsInsideAppGrace is the T8 (WRK-070) cross-repo golden test. The app gives
// the backend a SIGTERM grace (frontend backend_controller.dart) and then escalates to SIGKILL,
// which orphans every child and skips the WAL checkpoint. The two constants used to live in two
// repos with nothing comparing them — and they WERE inverted (backend 10s > app 8s), so a single
// pipe-holding grandchild turned every normal quit into a SIGKILL. This test reads the app-side
// constant from source and pins the whole budget lattice:
//
//	shell.WaitDelay < drain floors < shutdownGrace < app grace
//	drainShutdownGrace + 2×WaitDelay < app grace   (worst-case ctx-free SERIAL floor:
//	    WaitPoolDrained grace → StopPool waits a cancelled Bash's pipe floor →
//	    chat.Shutdown's wg.Wait waits another)
//
// It FAILS (not skips) when the dart file is missing: a guard that skips on layout drift is no
// guard — relocate the constant, update the path here in the same commit.
//
// TestShutdownBudget_NestsInsideAppGrace 是 T8（WRK-070）跨仓 golden 测试。app 侧给后端一段
// SIGTERM 宽限（前端 backend_controller.dart），超过即升级 SIGKILL——子进程全部成孤儿、WAL
// checkpoint 被跳过。这两个常量曾分居两仓、没有任何东西把它们放在一起比——且它们**曾经就是反的**
// （后端 10s > app 8s），一个攥管道的孙进程就把每次正常退出变成 SIGKILL。本测试从源码读 app 侧
// 常量，钉死整个预算格：
//
//	shell.WaitDelay < 各层宽限 < shutdownGrace < app 宽限
//	drainShutdownGrace + 2×WaitDelay < app 宽限（不认 ctx 的最坏**串行**地板：
//	    WaitPoolDrained 宽限 → StopPool 等一个被取消 Bash 的管道地板 → chat.Shutdown 的 wg.Wait 再等一个）
//
// dart 文件缺失时**红灯而非跳过**：布局漂移就跳过的守卫不是守卫——挪常量必须同提交改这里的路径。
func TestShutdownBudget_NestsInsideAppGrace(t *testing.T) {
	dartPath := filepath.Join("..", "..", "..", "frontend", "lib", "core", "process", "backend_controller.dart")
	src, err := os.ReadFile(dartPath)
	if err != nil {
		t.Fatalf("cannot read app-side grace source %s: %v — if the constant moved, update this path in the same commit", dartPath, err)
	}
	m := regexp.MustCompile(`shutdownGrace = const Duration\(seconds: (\d+)\)`).FindSubmatch(src)
	if m == nil {
		t.Fatalf("app-side `shutdownGrace = const Duration(seconds: N)` not found in %s — if it was renamed or reshaped, update this regexp in the same commit", dartPath)
	}
	secs, err := strconv.Atoi(string(m[1]))
	if err != nil {
		t.Fatalf("parse app grace: %v", err)
	}
	appGrace := time.Duration(secs) * time.Second

	// Backend total budget strictly under the app grace, with at least 1s margin for the
	// ctx-free tail (WAL checkpoint, log flush, process teardown).
	// 后端总预算严格小于 app 宽限，且为不认 ctx 的尾步（WAL checkpoint、日志 flush、进程收尾）
	// 留至少 1s 余量。
	if shutdownGrace >= appGrace-time.Second {
		t.Errorf("backend shutdownGrace %v must stay ≥1s under the app SIGTERM grace %v — exceeding it means SIGKILL escalation on every slow quit", shutdownGrace, appGrace)
	}
	// Layer nesting: each ctx-free floor must leave the rest of the ordered shutdown budget.
	// 分层嵌套：每个不认 ctx 的地板必须给关停其余步骤留出预算。
	if shelltool.WaitDelay >= shutdownGrace {
		t.Errorf("shell.WaitDelay %v must nest under shutdownGrace %v", shelltool.WaitDelay, shutdownGrace)
	}
	if drainShutdownGrace >= shutdownGrace {
		t.Errorf("drainShutdownGrace %v must nest under shutdownGrace %v", drainShutdownGrace, shutdownGrace)
	}
	// Worst-case ctx-free serial floor of App.Shutdown: pool-drain grace, then StopPool and
	// chat.Shutdown each wait out one cancelled Bash pipe floor, one after the other.
	// App.Shutdown 不认 ctx 的最坏串行地板：池排空宽限之后，StopPool 与 chat.Shutdown 先后各等
	// 满一个被取消 Bash 的管道地板。
	if worst := drainShutdownGrace + 2*shelltool.WaitDelay; worst >= appGrace {
		t.Errorf("worst-case serial shutdown floor %v (drainShutdownGrace + 2×WaitDelay) must stay under the app SIGTERM grace %v", worst, appGrace)
	}
}
