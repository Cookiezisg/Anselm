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
