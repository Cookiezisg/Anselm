package idgen

import (
	"regexp"
	"testing"
)

var idPattern = regexp.MustCompile(`^wf_[0-9a-f]{16}$`)

func TestNewFormat(t *testing.T) {
	if id := New("wf"); !idPattern.MatchString(id) {
		t.Fatalf("New(\"wf\") = %q, want wf_<16hex>", id)
	}
}

func TestNewUnique(t *testing.T) {
	const n = 1000
	seen := make(map[string]bool, n)
	for i := range n {
		id := New("x")
		if seen[id] {
			t.Fatalf("collision after %d ids: %q", i, id)
		}
		seen[id] = true
	}
}
