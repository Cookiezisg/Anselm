package cel

import "testing"

// TestCompileFor — F14 (iteration loop): CompileFor restricts an expression to EXACTLY the given
// root variables (no auto-ctx), so author-time validation of a context-restricted entity CEL
// (control/approval read input only; sensor reads payload only) rejects a wrong-namespace ref at
// create/edit instead of letting the permissive package env accept it and fail at runtime.
func TestCompileFor(t *testing.T) {
	ok := []struct {
		roots []string
		expr  string
	}{
		{[]string{"input"}, "input.score >= 0.9"},
		{[]string{"input"}, "has(input.n) ? input.n : 0"},
		{[]string{"payload"}, "payload.value > 0"},
	}
	for _, c := range ok {
		if _, err := CompileFor(c.roots, c.expr); err != nil {
			t.Errorf("CompileFor(%v, %q) should compile, got %v", c.roots, c.expr, err)
		}
	}

	bad := []struct {
		roots []string
		expr  string
	}{
		{[]string{"input"}, "payload.x > 0"}, // wrong root for control/approval
		{[]string{"input"}, "ctx.runId"},     // no auto-ctx
		{[]string{"payload"}, "input.x"},     // wrong root for sensor
	}
	for _, c := range bad {
		if _, err := CompileFor(c.roots, c.expr); err == nil {
			t.Errorf("CompileFor(%v, %q) must fail (out-of-namespace root)", c.roots, c.expr)
		}
	}
}
