package chat

import (
	"testing"
	"time"
)

// TestSendAfterIdleQueueTeardownRecreatesQueue proves the dormant queue is disposable: after
// the idle policy tears it down, a later Send gets a fresh drain goroutine and still finalizes.
// TestSendAfterIdleQueueTeardownRecreatesQueue 验证休眠队列可安全销毁：空闲策略拆掉后，后续 Send
// 会拿到新的抽取 goroutine，并正常落终态。
func TestSendAfterIdleQueueTeardownRecreatesQueue(t *testing.T) {
	bridge := newRecordBridge()
	svc, _ := newSvc(t, &fakeClient{script: textTurn()}, bridge)
	svc.queueIdleTimeout = 20 * time.Millisecond
	ctx := ctxWS("ws_idle")

	firstID, err := svc.Send(ctx, "cv_idle", SendInput{Content: "first"})
	if err != nil {
		t.Fatalf("first Send: %v", err)
	}
	firstQueueValue, ok := svc.queues.Load("cv_idle")
	if !ok {
		t.Fatal("first Send did not create a queue")
	}
	waitClose(t, bridge, firstID)

	deadline := time.Now().Add(2 * time.Second)
	for {
		if _, ok := svc.queues.Load("cv_idle"); !ok {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("idle queue was not torn down")
		}
		time.Sleep(time.Millisecond)
	}

	secondID, err := svc.Send(ctx, "cv_idle", SendInput{Content: "second"})
	if err != nil {
		t.Fatalf("Send after idle teardown: %v", err)
	}
	secondQueueValue, ok := svc.queues.Load("cv_idle")
	if !ok {
		t.Fatal("second Send did not recreate a queue")
	}
	if firstQueueValue == secondQueueValue {
		t.Fatal("second Send reused the queue that idle teardown retired")
	}
	waitClose(t, bridge, secondID)
}
