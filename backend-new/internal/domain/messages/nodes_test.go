package messages

import (
	"testing"

	streamdomain "github.com/sunweilin/forgify/backend/internal/domain/stream"
)

// TestNodeTypes pins each node's wire discriminant and (by the []stream.Node slice)
// proves every node satisfies stream.Node at compile time.
//
// TestNodeTypes 固定每个 node 的线缆判别值，并（经 []stream.Node 切片）编译期证明
// 每个 node 都满足 stream.Node。
func TestNodeTypes(t *testing.T) {
	cases := []struct {
		node streamdomain.Node
		want string
	}{
		{MessageNode{Role: RoleUser}, "message"},
		{TextNode{}, "text"},
		{ReasoningNode{}, "reasoning"},
		{ToolCallNode{Name: "x"}, "tool_call"},
		{ToolResultNode{}, "tool_result"},
		{ProgressNode{}, "progress"},
		{CompactionNode{}, "compaction"},
	}
	for _, c := range cases {
		if got := c.node.NodeType(); got != c.want {
			t.Errorf("NodeType() = %q, want %q", got, c.want)
		}
	}
}
