package handler

import (
	"strings"
	"testing"
)

// TestWriteBody_Dedent — F63: an agent that wrote a handler body already-indented (the natural
// "this is inside a method" style) must not get double-indented into a Python IndentationError that
// surfaces only as an opaque "subprocess crashed". dedent normalises the common indent; flush-left is
// untouched (purely additive); relative nesting is preserved.
func TestWriteBody_Dedent(t *testing.T) {
	cases := []struct{ name, body, want string }{
		{"flush-left unchanged", "x = 1", "        x = 1\n"},
		{"uniform indent dedented", "    self.n = 0\n    self.n += 1", "        self.n = 0\n        self.n += 1\n"},
		{"nested preserves relative", "    if x:\n        y = 1", "        if x:\n            y = 1\n"},
		{"empty body -> pass", "   ", "        pass\n"},
	}
	for _, c := range cases {
		var b strings.Builder
		writeBody(&b, c.body)
		if got := b.String(); got != c.want {
			t.Errorf("%s: writeBody(%q) = %q, want %q", c.name, c.body, got, c.want)
		}
	}
}
