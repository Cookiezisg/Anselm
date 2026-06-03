package entities

import (
	"testing"

	streamdomain "github.com/sunweilin/forgify/backend/internal/domain/stream"
)

func TestNodeTypes(t *testing.T) {
	cases := []struct {
		node streamdomain.Node
		want string
	}{
		{ForgeNode{Operation: OperationCreate}, "forge"},
		{RunNode{}, "run"},
		{EnvAttemptNode{Attempt: 1}, "env_attempt"},
		{TerminalNode{}, "terminal"},
	}
	for _, c := range cases {
		if got := c.node.NodeType(); got != c.want {
			t.Errorf("NodeType() = %q, want %q", got, c.want)
		}
	}
}
