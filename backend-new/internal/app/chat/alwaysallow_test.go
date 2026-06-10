package chat

import (
	"context"
	"errors"
	"testing"
	"time"

	loopapp "github.com/sunweilin/forgify/backend/internal/app/loop"
	messagesdomain "github.com/sunweilin/forgify/backend/internal/domain/messages"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
)

// TestAlwaysAllow_SecondCallSkipsPark: resolving a dangerous call with approve_always session-
// whitelists the tool, so a later dangerous call to the same tool in the same conversation runs
// without parking (D4).
//
// TestAlwaysAllow_SecondCallSkipsPark：以 approve_always 决议危险调用会话白名单该工具，使同对话后续对同一工具的
// 危险调用不 park 直接跑（D4）。
func TestAlwaysAllow_SecondCallSkipsPark(t *testing.T) {
	ran := false
	var gotArgs string
	tool := recordingTool{name: "deploy", ran: &ran, gotArgs: &gotArgs}
	bridge := newRecordBridge()
	client := &scriptedClient{scripts: [][]llminfra.StreamEvent{
		dangerToolCallID("tc1", "deploy"), // turn 1, step 1 → parks
		textTurn(),                        // turn 1 continuation
		dangerToolCallID("tc2", "deploy"), // turn 2, step 1 → should NOT park (whitelisted); distinct id
		textTurn(),                        // turn 2 continuation
	}}
	svc, store := newDangerSvc(t, client, bridge, tool)
	ctx := ctxWS("ws_1")

	// turn 1: parks, resolve approve_always
	asst1, _ := svc.Send(ctx, "cv_1", SendInput{Content: "deploy"})
	waitClose(t, bridge, asst1)
	if _, err := store.GetParkedMessage(ctx, "cv_1"); err != nil {
		t.Fatalf("turn 1 should park, err=%v", err)
	}
	if err := svc.ResolveInteraction(ctx, "cv_1", "tc1", loopapp.ResolveApproveAlways, "", ""); err != nil {
		t.Fatalf("ResolveInteraction approve_always: %v", err)
	}
	cont1 := waitContinuation(t, store, ctx, "cv_1", asst1)

	// turn 2: a fresh dangerous call to the SAME tool must run without parking
	ran = false
	asst2, err := svc.Send(ctx, "cv_1", SendInput{Content: "deploy again"})
	if err != nil {
		t.Fatalf("turn 2 Send: %v", err)
	}
	// poll until turn 2 reaches a terminal state (the continuation runs async on the queue)
	got := waitMessageDone(t, store, ctx, asst2)
	if got.Status != messagesdomain.StatusCompleted {
		t.Fatalf("turn 2 should complete (not park) for a whitelisted tool, got status=%q", got.Status)
	}
	if _, err := store.GetParkedMessage(ctx, "cv_1"); !errors.Is(err, messagesdomain.ErrMessageNotFound) {
		t.Fatal("turn 2 must NOT park — the tool was session-whitelisted by approve_always")
	}
	if !ran {
		t.Fatal("turn 2's whitelisted dangerous tool should run in-loop")
	}
	_ = cont1
}

// waitMessageDone polls a message until it leaves the streaming state, or fails after a timeout.
//
// waitMessageDone 轮询一个 message 直到离开 streaming 态，超时则失败。
func waitMessageDone(t *testing.T, store messagesdomain.Repository, ctx context.Context, msgID string) *messagesdomain.Message {
	t.Helper()
	deadline := time.After(2 * time.Second)
	for {
		m, err := store.GetMessage(ctx, msgID)
		if err == nil && m.Status != messagesdomain.StatusStreaming {
			return m
		}
		select {
		case <-deadline:
			t.Fatalf("timed out waiting for %s to finish (status stuck)", msgID)
			return nil
		case <-time.After(10 * time.Millisecond):
		}
	}
}
