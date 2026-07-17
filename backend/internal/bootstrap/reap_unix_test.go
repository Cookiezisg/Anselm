//go:build unix

package bootstrap

import (
	"context"
	"os/exec"
	"syscall"
	"testing"
	"time"

	shelltool "github.com/sunweilin/anselm/backend/internal/app/tool/shell"
)

// TestApp_ShutdownReapsBackgroundShellProcs — R1: a run_in_background shell child (and its whole
// process group) must be killed by App.Shutdown via the shell ProcessManager, not orphaned. Before
// the fix the manager handle was discarded at assembly (build_services.go kept only .Tools), so
// Shutdown could never reach Stop() and backgrounded jobs leaked on every backend exit.
func TestApp_ShutdownReapsBackgroundShellProcs(t *testing.T) {
	app, err := Build(Config{DataDir: t.TempDir()})
	if err != nil {
		t.Fatalf("Build: %v", err)
	}
	app.Boot(context.Background())

	// A long sleep in its own process group — how run_in_background spawns — registered the way the
	// Bash tool does.
	cmd := exec.Command("sleep", "30")
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	if err := cmd.Start(); err != nil {
		t.Fatalf("start sleep: %v", err)
	}
	app.svc.shellMgr.Register(&shelltool.BgProcess{Cmd: cmd})

	waitErr := make(chan error, 1)
	go func() { waitErr <- cmd.Wait() }()

	app.Shutdown(context.Background())

	select {
	case err := <-waitErr:
		if err == nil {
			t.Fatal("background process exited cleanly; expected Shutdown to KILL it (R1)")
		}
	case <-time.After(3 * time.Second):
		_ = cmd.Process.Kill()
		t.Fatal("background shell process survived Shutdown — R1 not reaped")
	}
}

// TestBoot_ReapsBackgroundShellSurvivorsAcrossCrash — T3, the crash half R1 left open: the
// in-memory manager dies with the backend, so only the pid manifest under DataDir can save the
// next boot. App #1 registers a run_in_background child, then "crashes" (dropped hot, no
// Shutdown — exactly what SIGKILL/panic/OOM leave behind). App #2 booting from the SAME
// DataDir must kill the survivor via ReapStaleOnBoot. Real process, real kill.
func TestBoot_ReapsBackgroundShellSurvivorsAcrossCrash(t *testing.T) {
	dataDir := t.TempDir()

	app1, err := Build(Config{DataDir: dataDir})
	if err != nil {
		t.Fatalf("Build app1: %v", err)
	}
	t.Cleanup(func() { app1.Shutdown(context.Background()) })
	app1.Boot(context.Background())

	cmd := exec.Command("sleep", "30") // the ledger's measured A-form. 台账实测的 A 形。
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	if err := cmd.Start(); err != nil {
		t.Fatalf("start sleep: %v", err)
	}
	app1.svc.shellMgr.Register(&shelltool.BgProcess{Cmd: cmd})

	waitErr := make(chan error, 1)
	go func() { waitErr <- cmd.Wait() }()

	// CRASH: app1 is never Shutdown before the next boot — its registry is unreachable, the
	// manifest row on disk is all that survives.
	// 崩溃:下次 boot 前 app1 绝不 Shutdown——它的注册表已不可达,盘上的清单行是唯一遗物。
	app2, err := Build(Config{DataDir: dataDir})
	if err != nil {
		t.Fatalf("Build app2: %v", err)
	}
	t.Cleanup(func() { app2.Shutdown(context.Background()) })
	app2.Boot(context.Background())

	select {
	case err := <-waitErr:
		if err == nil {
			t.Fatal("survivor exited cleanly; expected the next Boot to KILL it (T3)")
		}
	case <-time.After(5 * time.Second):
		_ = cmd.Process.Kill()
		t.Fatal("background shell survivor outlived the next boot — T3 net has a hole")
	}
}
