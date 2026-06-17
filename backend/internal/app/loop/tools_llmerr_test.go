package loop

import (
	stderrors "errors"
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
}
