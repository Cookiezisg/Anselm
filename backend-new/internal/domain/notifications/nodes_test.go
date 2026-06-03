package notifications

import (
	"testing"

	streamdomain "github.com/sunweilin/forgify/backend/internal/domain/stream"
)

func TestNodeTypes(t *testing.T) {
	cases := []struct {
		node streamdomain.Node
		want string
	}{
		{EntityChangedNode{Kind: "function", Action: "created"}, "entity_changed"},
		{FlowrunTickNode{NodeID: "n1", Status: "running"}, "flowrun_tick"},
		{FlowrunLifecycleNode{Status: "completed"}, "flowrun_lifecycle"},
	}
	for _, c := range cases {
		if got := c.node.NodeType(); got != c.want {
			t.Errorf("NodeType() = %q, want %q", got, c.want)
		}
	}
}
