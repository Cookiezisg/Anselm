//go:build unix

package sandbox

import (
	"context"
	"testing"
	"time"

	sandboxdomain "github.com/sunweilin/anselm/backend/internal/domain/sandbox"
)

// TestShutdown_ReapsInFlightOneShot — R13: a one-shot Spawn (the python function-runner)
// in flight at backend exit must be killed by sandbox.Shutdown. One-shots are NOT in
// activeHandles (only SpawnLongLived is), and their ctx may never cancel on shutdown
// (a drained workflow Advance runs on a Detached ctx) — so before the fix an in-flight
// one-shot leaked detached. Here Spawn runs on context.Background() (never cancellable),
// so the ONLY thing that can stop the `sleep 30` is Shutdown's explicit group-kill.
func TestShutdown_ReapsInFlightOneShot(t *testing.T) {
	svc, owner := newServiceWithEnv(t, "fake-py")

	done := make(chan error, 1)
	go func() {
		_, err := svc.Spawn(context.Background(), owner, sandboxdomain.SpawnOpts{
			Cmd: "sleep", Args: []string{"30"},
		})
		done <- err
	}()

	// Wait until the one-shot has registered (its process exists). Poll oneShots.
	// 等到一次性进程登记完成（其 process 已存在），轮询 oneShots。
	registered := false
	for range 100 {
		count := 0
		svc.oneShots.Range(func(_, _ any) bool { count++; return true })
		if count == 1 {
			registered = true
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	if !registered {
		t.Fatal("one-shot never registered in oneShots")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := svc.Shutdown(ctx); err != nil {
		t.Fatalf("Shutdown: %v", err)
	}

	// Spawn must return promptly because Shutdown SIGKILL'd the `sleep` — had it not been
	// reaped, Spawn would block ~30s on a context that never cancels.
	// Spawn 必须立即返回，因 Shutdown 已 SIGKILL 掉 sleep——若未被收割，Spawn 会在永不取消的 ctx 上阻塞约 30s。
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		t.Fatal("one-shot survived Shutdown — R13 not reaped")
	}
}
