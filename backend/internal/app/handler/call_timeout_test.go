package handler

import (
	"testing"
	"time"

	limitspkg "github.com/sunweilin/anselm/backend/internal/pkg/limits"
)

// TestMethodCallTimeout: every handler method call is wall-clock bounded. Round-2 hasync lane found a
// method that slept 120s ran UNBOUNDED (elapsedMs 120003, no timeout) because handler calls had no
// global default — asymmetric with FunctionRunSec (F83). A method with no per-method timeout now falls
// back to the global HandlerCallSec; an explicit per-method timeout (ms) still overrides it.
func TestMethodCallTimeout(t *testing.T) {
	// No per-method timeout → the global default (seconds), so the call is bounded (was unbounded).
	if got := methodCallTimeout(0, 300); got != 300*time.Second {
		t.Errorf("spec=0 should fall back to the global 300s default, got %v", got)
	}
	// An explicit per-method timeout (ms) overrides — tighter than the default.
	if got := methodCallTimeout(5000, 300); got != 5*time.Second {
		t.Errorf("spec=5000ms should override to 5s, got %v", got)
	}
	// ...and can be looser than the default when a method legitimately needs longer.
	if got := methodCallTimeout(600000, 300); got != 600*time.Second {
		t.Errorf("spec=600000ms should be 600s, got %v", got)
	}
	// The default must actually be wired (> 0) — a zero default would re-open the unbounded-call hole.
	if limitspkg.Default().Timeout.HandlerCallSec <= 0 {
		t.Error("HandlerCallSec default must be > 0 so handler calls are bounded by default")
	}
}
