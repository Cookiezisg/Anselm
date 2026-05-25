package handler

import (
	"testing"

	mentiondomain "github.com/sunweilin/forgify/backend/internal/domain/mention"
)

func TestMentionResolver_Type(t *testing.T) {
	if got := (&mentionResolver{}).Type(); got != mentiondomain.MentionHandler {
		t.Errorf("Type() = %q, want handler", got)
	}
}
