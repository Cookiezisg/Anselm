package handler

import (
	"errors"
	"strings"
	"testing"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// TestCallFailedErr_SurfacesTraceback — round-13 handlerwferr/bigsystem: a handler method's Python
// exception used to ride in the fmt.Errorf wrap, which the LLM error surface (errorspkg.Surface,
// shared by llmErrText/nodeErrText) STRIPS — leaving an opaque "handler.Client: call failed" on every
// agent/flowrun path. The cause + traceback now ride in Details so Surface renders them, while
// .Error() keeps the breadcrumb for the audit record.
func TestCallFailedErr_SurfacesTraceback(t *testing.T) {
	err := pyErr(ErrCallFailed, "ValueError: bad amount", "Traceback (most recent call last):\n  File \"x\", line 2")

	// errors.Is still classifies it (WithDetails/WithCause clones match by Code).
	if !errors.Is(err, ErrCallFailed) {
		t.Fatalf("must remain a HANDLER_CLIENT_CALL_FAILED, got %v", err)
	}
	// The LLM surface must now carry the real Python cause + traceback (was stripped to "call failed").
	surfaced := errorspkg.Surface(err)
	if !strings.Contains(surfaced, "ValueError: bad amount") || !strings.Contains(surfaced, "Traceback") {
		t.Fatalf("Surface must render the Python error + traceback for self-correction, got: %q", surfaced)
	}
	// .Error() keeps the breadcrumb (recordCall persists this).
	if !strings.Contains(err.Error(), "ValueError: bad amount") {
		t.Fatalf(".Error() must keep the cause for the audit record, got: %q", err.Error())
	}

	// The __init__ failure path (broken init body) gets the same treatment — its traceback must surface.
	initErr := pyErr(ErrInitFailed, "KeyError: 'api_key'", "Traceback ...\n  in __init__")
	if !errors.Is(initErr, ErrInitFailed) || !strings.Contains(errorspkg.Surface(initErr), "KeyError") {
		t.Fatalf("init failure must surface its Python cause too, got: %q", errorspkg.Surface(initErr))
	}

	// An empty error/trace degrades gracefully (no panic, no ugly empty key=).
	bare := errorspkg.Surface(pyErr(ErrCallFailed, "", ""))
	if !strings.Contains(bare, "call failed") {
		t.Fatalf("empty error/trace must still surface the base message, got: %q", bare)
	}
}
