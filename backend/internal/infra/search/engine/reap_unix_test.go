//go:build unix

package engine

import (
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"testing"
	"time"

	"go.uber.org/zap"
)

// TestReapStalePID_KillsSurvivor — R2: a recorded embedder pid still alive (an orphan from an
// ungraceful exit that bypassed Close) is killed before the next spawn; a dead/garbage/absent record
// is a harmless no-op.
func TestReapStalePID_KillsSurvivor(t *testing.T) {
	dir := t.TempDir()
	pidPath := filepath.Join(dir, "embedder.pid")

	cmd := exec.Command("sleep", "30") // stand-in for an orphaned llama-server
	if err := cmd.Start(); err != nil {
		t.Fatalf("start: %v", err)
	}
	defer func() { _ = cmd.Process.Kill() }() // safety net
	if err := os.WriteFile(pidPath, []byte(strconv.Itoa(cmd.Process.Pid)), 0o644); err != nil {
		t.Fatalf("write pid: %v", err)
	}

	reapStalePID(pidPath, zap.NewNop())

	waitErr := make(chan error, 1)
	go func() { waitErr <- cmd.Wait() }()
	select {
	case err := <-waitErr:
		if err == nil {
			t.Fatal("survivor exited cleanly; expected reapStalePID to KILL it (R2)")
		}
	case <-time.After(3 * time.Second):
		t.Fatal("recorded survivor not killed by reapStalePID (R2)")
	}

	// absent file + garbage content → no panic, no-op
	reapStalePID(filepath.Join(dir, "nope.pid"), zap.NewNop())
	_ = os.WriteFile(pidPath, []byte("not-a-number"), 0o644)
	reapStalePID(pidPath, zap.NewNop())
}
