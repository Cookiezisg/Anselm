package function

import (
	"testing"

	mentiondomain "github.com/sunweilin/forgify/backend/internal/domain/mention"
)

func TestMentionResolver_Type(t *testing.T) {
	if got := (&mentionResolver{}).Type(); got != mentiondomain.MentionFunction {
		t.Errorf("Type() = %q, want function", got)
	}
}
