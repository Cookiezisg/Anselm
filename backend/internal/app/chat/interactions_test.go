package chat

import (
	"context"
	"errors"
	"testing"

	"go.uber.org/zap"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// TestResolveInteractionRejectsUnknownActionLoudly locks the transport-facing contract for a
// typo such as "aprove": it fails before looking up a conversation or pending call and exposes
// the closed valid action set instead of silently denying the intended approval.
//
// TestResolveInteractionRejectsUnknownActionLoudly 锁住拼错 action（如 "aprove"）的 transport 契约：
// 在查对话或 pending call 前失败，并暴露封闭合法动作集，而不是静默拒绝用户本想批准的调用。
func TestResolveInteractionRejectsUnknownActionLoudly(t *testing.T) {
	svc := NewService(newStore(t), Deps{}, zap.NewNop())
	err := svc.ResolveInteraction(context.Background(), "missing", "tc_missing", "aprove", "")

	if !errors.Is(err, ErrInvalidInteractionAction) {
		t.Fatalf("want ErrInvalidInteractionAction, got %v", err)
	}
	var structured *errorspkg.Error
	if !errors.As(err, &structured) {
		t.Fatalf("invalid interaction error lost structured details: %v", err)
	}
	valid, ok := structured.Details["validActions"].([]string)
	if !ok || len(valid) != 5 {
		t.Fatalf("validActions details missing or incomplete: %#v", structured.Details)
	}
	for _, want := range []string{"approve", "approve_always", "deny", "accept", "decline"} {
		found := false
		for _, got := range valid {
			if got == want {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("validActions missing %q: %v", want, valid)
		}
	}
}
