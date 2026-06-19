package humanloop

import (
	"context"
	"errors"
	"testing"
	"time"
)

// TestRequestBlocksUntilResolve: Request blocks until Resolve delivers a decision, surfacing the
// pending interaction exactly once.
//
// TestRequestBlocksUntilResolve：Request 阻塞至 Resolve 送来决定，待决交互恰露出一次。
func TestRequestBlocksUntilResolve(t *testing.T) {
	surfaced := 0
	b := New(func(context.Context, Request) { surfaced++ })

	done := make(chan Response, 1)
	go func() {
		resp, _ := b.Request(context.Background(), Request{ToolCallID: "tc1", Kind: KindAsk, Tool: "ask_user", ConversationID: "cv1"})
		done <- resp
	}()

	// it must be pending (blocked), not resolved
	waitFor(t, func() bool { return len(b.Pending("cv1")) == 1 })
	select {
	case <-done:
		t.Fatal("Request returned before Resolve")
	default:
	}

	if !b.Resolve("tc1", Response{Action: DecisionAccept, Answer: "blue"}) {
		t.Fatal("Resolve should find the pending interaction")
	}
	resp := <-done
	if resp.Action != DecisionAccept || resp.Answer != "blue" {
		t.Fatalf("got %+v", resp)
	}
	if surfaced != 1 {
		t.Fatalf("surfaced %d times, want 1", surfaced)
	}
	if len(b.Pending("cv1")) != 0 {
		t.Fatal("interaction should be gone after resolve")
	}
}

// TestRequestCancelled: a cancelled ctx unblocks Request with the ctx error (the run aborted).
//
// TestRequestCancelled：取消的 ctx 用 ctx 错解阻 Request（运行中止）。
func TestRequestCancelled(t *testing.T) {
	b := New(nil)
	ctx, cancel := context.WithCancel(context.Background())
	errc := make(chan error, 1)
	go func() {
		_, err := b.Request(ctx, Request{ToolCallID: "tc1", Kind: KindDanger, Tool: "deploy"})
		errc <- err
	}()
	waitFor(t, func() bool { return len(b.Pending("")) == 1 })
	cancel()
	if err := <-errc; !errors.Is(err, context.Canceled) {
		t.Fatalf("want context.Canceled, got %v", err)
	}
}

// TestApproveAlwaysWhitelists: approve_always on a danger interaction session-whitelists the tool.
//
// TestApproveAlwaysWhitelists：danger 交互上的 approve_always 会话白名单该工具。
func TestApproveAlwaysWhitelists(t *testing.T) {
	b := New(nil)
	if b.IsAllowed("cv1", "deploy") {
		t.Fatal("not allowed yet")
	}
	go b.Request(context.Background(), Request{ToolCallID: "tc1", Kind: KindDanger, Tool: "deploy", ConversationID: "cv1"})
	waitFor(t, func() bool { return len(b.Pending("cv1")) == 1 })
	b.Resolve("tc1", Response{Action: DecisionApproveAlways})
	waitFor(t, func() bool { return b.IsAllowed("cv1", "deploy") })
	// scoped: a different conversation is not whitelisted
	if b.IsAllowed("cv2", "deploy") {
		t.Fatal("always-allow must be per-conversation")
	}
}

// TestResolveUnknownIsNoop: resolving an unknown / already-resolved id returns false (safe double POST).
//
// TestResolveUnknownIsNoop：决议未知 / 已决议 id 返 false（安全的重复 POST）。
func TestResolveUnknownIsNoop(t *testing.T) {
	b := New(nil)
	if b.Resolve("ghost", Response{Action: DecisionApprove}) {
		t.Fatal("resolving an unknown id should return false")
	}
}

// TestForgetDropsConversationGrants: Forget removes every always-allow grant for the named
// conversation and leaves other conversations' grants intact (R16 — grants must not leak past
// conversation deletion on the app-wide broker).
//
// TestForgetDropsConversationGrants：Forget 删指定对话的全部 always-allow 授权、保留其他对话的授权
// （R16——授权不得在 app 级 broker 上越过对话删除泄漏）。
func TestForgetDropsConversationGrants(t *testing.T) {
	b := New(nil)
	b.Allow("cv1", "deploy")
	b.Allow("cv1", "rm")
	b.Allow("cv2", "deploy")

	b.Forget("cv1")

	if b.IsAllowed("cv1", "deploy") || b.IsAllowed("cv1", "rm") {
		t.Fatal("Forget must drop all of cv1's grants")
	}
	if !b.IsAllowed("cv2", "deploy") {
		t.Fatal("Forget(cv1) must not touch cv2's grants")
	}
	// Forgetting a conversation with no grants is a safe no-op.
	b.Forget("cv_unknown")
}

func waitFor(t *testing.T, cond func() bool) {
	t.Helper()
	deadline := time.After(time.Second)
	for !cond() {
		select {
		case <-deadline:
			t.Fatal("condition not met in time")
		case <-time.After(2 * time.Millisecond):
		}
	}
}
