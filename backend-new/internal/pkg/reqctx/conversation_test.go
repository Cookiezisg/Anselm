package reqctx

import (
	"context"
	"errors"
	"testing"
)

func TestConversationID_SetGetRequire(t *testing.T) {
	ctx := context.Background()
	if _, ok := GetConversationID(ctx); ok {
		t.Error("empty ctx must not yield a conversation id")
	}
	if _, err := RequireConversationID(ctx); !errors.Is(err, ErrMissingConversationID) {
		t.Errorf("Require on empty ctx: err = %v, want ErrMissingConversationID", err)
	}
	ctx = SetConversationID(ctx, "conv_1")
	if id, ok := GetConversationID(ctx); !ok || id != "conv_1" {
		t.Errorf("Get after Set: %q %v", id, ok)
	}
	if id, err := RequireConversationID(ctx); err != nil || id != "conv_1" {
		t.Errorf("Require after Set: %q %v", id, err)
	}
}

func TestConversationID_EmptyStringIsAbsent(t *testing.T) {
	ctx := SetConversationID(context.Background(), "")
	if _, ok := GetConversationID(ctx); ok {
		t.Error("empty-string conversation id must read as absent")
	}
}

func TestSubagentID_OptionalAndCoexistsWithConversation(t *testing.T) {
	ctx := SetConversationID(context.Background(), "conv_1")
	if _, ok := GetSubagentID(ctx); ok {
		t.Error("a main-conversation turn must not carry a subagent id")
	}
	ctx = SetSubagentID(ctx, "subagent_1")
	if id, ok := GetSubagentID(ctx); !ok || id != "subagent_1" {
		t.Errorf("Get after Set subagent: %q %v", id, ok)
	}
	if id, ok := GetConversationID(ctx); !ok || id != "conv_1" {
		t.Errorf("conversation id must survive subagent set: %q %v", id, ok)
	}
}
