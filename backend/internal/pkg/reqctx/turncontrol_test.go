package reqctx

import (
	"context"
	"testing"
)

func TestTurnControl_IsRunLocalAndThreadSafe(t *testing.T) {
	ctx := SetTurnControl(context.Background(), NewTurnControl())
	if ToolsDisabled(ctx) {
		t.Fatal("new turn control must allow tools")
	}
	RequestToolsDisabled(ctx)
	if !ToolsDisabled(ctx) {
		t.Fatal("requested tool shutdown not visible through derived context")
	}

	next := SetTurnControl(context.Background(), NewTurnControl())
	if ToolsDisabled(next) {
		t.Fatal("turn control must not leak into a new run")
	}
}
