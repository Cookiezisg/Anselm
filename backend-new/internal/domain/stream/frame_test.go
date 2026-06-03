package stream

import "testing"

// testNode is a shared minimal Node for stream-package tests.
//
// testNode 是 stream 包测试共用的最小 Node。
type testNode struct{}

func (testNode) NodeType() string { return "test" }

func TestFrameDurable(t *testing.T) {
	tests := []struct {
		name  string
		frame Frame
		want  bool
	}{
		{"open is durable", Open{Node: testNode{}}, true},
		{"delta is ephemeral", Delta{Chunk: "x"}, false},
		{"close is durable", Close{Status: StatusCompleted}, true},
		{"non-ephemeral signal is durable", Signal{Node: testNode{}}, true},
		{"ephemeral signal is lossy", Signal{Node: testNode{}, Ephemeral: true}, false},
	}
	for _, tt := range tests {
		if got := tt.frame.Durable(); got != tt.want {
			t.Errorf("%s: Durable() = %v, want %v", tt.name, got, tt.want)
		}
	}
}
