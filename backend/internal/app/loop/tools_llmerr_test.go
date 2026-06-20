package loop

import (
	stderrors "errors"
	"fmt"
	"strings"
	"testing"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// TestLLMErrText: a tool error surfaced to the LLM must carry the structured Details a tool/domain
// attached (e.g. a workflow validation's "reason" naming the offending node + the real CEL error),
// not just the bare Message — Error() drops Details. Regression for F7 (iteration loop): an opaque
// "workflow graph is invalid" with no detail had the agent guessing CEL syntax blindly.
func TestLLMErrText(t *testing.T) {
	e := errorspkg.New(errorspkg.KindInvalid, "WORKFLOW_GRAPH_INVALID", "workflow graph is invalid").
		WithDetails(map[string]any{"reason": "cel scope: undeclared reference to 'payload'", "node": "convert"})
	got := llmErrText(e)
	if !strings.Contains(got, "workflow graph is invalid") ||
		!strings.Contains(got, "undeclared reference to 'payload'") ||
		!strings.Contains(got, "node=convert") {
		t.Fatalf("llmErrText must surface Details to the LLM, got: %s", got)
	}

	if got := llmErrText(stderrors.New("plain boom")); got != "plain boom" {
		t.Errorf("plain error must pass through unchanged: %q", got)
	}

	if got := llmErrText(errorspkg.New(errorspkg.KindInvalid, "X", "nope")); got != "nope" {
		t.Errorf("no-details error must be just the message: %q", got)
	}

	// A sentinel wrapped by an app layer (fmt.Errorf("pkg.Method: %w", …)) must surface the clean
	// Message — never the Go call-path the wrap chain leaks. Regression for the tooload-lane finding:
	// run_function errors reached the LLM as "functionapp.RunFunction: function not found" (S20 violated).
	sentinel := errorspkg.New(errorspkg.KindNotFound, "FUNCTION_NOT_FOUND", "function not found")
	wrapped := fmt.Errorf("functionapp.RunFunction: %w", sentinel)
	if got := llmErrText(wrapped); got != "function not found" {
		t.Errorf("wrapped sentinel must surface clean Message without Go call-path, got: %q", got)
	}
}
