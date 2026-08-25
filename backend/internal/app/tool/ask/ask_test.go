package ask

import (
	"context"
	"errors"
	"testing"
)

// TestExecuteWithoutInteractiveUserFailsLoudly proves workflow/agent-style contexts cannot leave
// an ask_user call parked forever: no broker returns the stable unavailable sentinel immediately.
//
// TestExecuteWithoutInteractiveUserFailsLoudly 证明 workflow/agent 等非交互 context 不会让 ask_user
// 永久挂起：没有 broker 时立即返回稳定的 unavailable sentinel。
func TestExecuteWithoutInteractiveUserFailsLoudly(t *testing.T) {
	out, err := New().Execute(context.Background(), `{"message":"Which environment?"}`)
	if out != "" {
		t.Fatalf("non-interactive ask must not fabricate an answer, got %q", out)
	}
	if !errors.Is(err, ErrNoInteractiveUser) {
		t.Fatalf("want ErrNoInteractiveUser, got %v", err)
	}
}
