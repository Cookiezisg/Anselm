package agent

import (
	"context"
	"iter"
	"testing"

	agentdomain "github.com/sunweilin/anselm/backend/internal/domain/agent"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	limitspkg "github.com/sunweilin/anselm/backend/internal/pkg/limits"
)

// blockingLLMClient blocks the stream on ctx until the run's wall-clock deadline cancels it, then
// emits the cancel-shaped EventError the provider layer would on a dead/cut connection — exactly the
// "slow agent" shape R20 guards against (a turn that never finishes on its own).
//
// blockingLLMClient 把流阻塞在 ctx 上、直到运行墙钟 deadline 取消它，再发 provider 层在死/断连接上会发的
// 取消形 EventError——正是 R20 防的「慢 agent」形（永不自行结束的回合）。
type blockingLLMClient struct{}

func (c *blockingLLMClient) Stream(ctx context.Context, _ llminfra.Request) iter.Seq[llminfra.StreamEvent] {
	return func(yield func(llminfra.StreamEvent) bool) {
		<-ctx.Done() // wait for the AgentInvokeSec deadline to fire
		yield(llminfra.StreamEvent{Type: llminfra.EventError, Err: ctx.Err()})
	}
}

// TestService_InvokeWallClockTimeout_R20 — R20: an agent whose loop never finishes on its own (slow
// tools / streaming) is cut off by the AgentInvokeSec wall-clock deadline and recorded as the
// durable, :replay-able ExecutionStatusTimeout — NOT ok, NOT a panic/leak — so one slow agent on the
// single workflow drain goroutine can't starve draining + approval timeouts for all workspaces.
func TestService_InvokeWallClockTimeout_R20(t *testing.T) {
	// Shrink the deadline to 1s (the minimum positive ceiling) so the test cuts off quickly.
	limitspkg.SetProvider(func() limitspkg.Limits {
		l := limitspkg.Default()
		l.Timeout.AgentInvokeSec = 1
		return l
	})
	defer limitspkg.SetProvider(limitspkg.Default)

	svc, ctx := newSvc(t)
	svc.SetInvokeDeps(InvokeDeps{
		Resolver:  fakeResolver{client: &blockingLLMClient{}},
		Knowledge: fakeKnowledge{},
	})

	a, _, err := svc.Create(ctx, CreateInput{Name: "slow", Config: Config{Prompt: "do work"}})
	if err != nil {
		t.Fatalf("create: %v", err)
	}

	res, err := svc.InvokeAgent(ctx, InvokeInput{AgentID: a.ID, TriggeredBy: agentdomain.TriggeredByWorkflow})
	if err != nil {
		t.Fatalf("invoke returned a transport error (should surface as a recorded timeout, not an error): %v", err)
	}
	if res.OK {
		t.Fatalf("a timed-out agent must not be OK: %+v", res)
	}
	if res.Status != agentdomain.ExecutionStatusTimeout {
		t.Fatalf("status = %q, want %q", res.Status, agentdomain.ExecutionStatusTimeout)
	}
	if res.ExecutionID == "" {
		t.Fatalf("a timed-out run must still record a durable execution (for :replay)")
	}

	// The recorded execution row carries the same timeout status (durable, queryable).
	sr, err := svc.SearchExecutions(ctx, agentdomain.ExecutionFilter{AgentID: a.ID})
	if err != nil {
		t.Fatalf("search executions: %v", err)
	}
	if len(sr.Executions) != 1 {
		t.Fatalf("want exactly 1 recorded execution, got %d", len(sr.Executions))
	}
	if got := sr.Executions[0].Status; got != agentdomain.ExecutionStatusTimeout {
		t.Fatalf("recorded execution status = %q, want %q", got, agentdomain.ExecutionStatusTimeout)
	}
}

// TestService_InvokeNoTimeoutUnderDeadline_R20 — the deadline does not alter the normal fast path: an
// agent that completes well within AgentInvokeSec records ok (the guard only fires on a genuine
// overrun), so the timeout is a backstop, not a behavior change for healthy runs.
func TestService_InvokeNoTimeoutUnderDeadline_R20(t *testing.T) {
	limitspkg.SetProvider(func() limitspkg.Limits {
		l := limitspkg.Default()
		l.Timeout.AgentInvokeSec = 60 // generous; the fake finishes instantly
		return l
	})
	defer limitspkg.SetProvider(limitspkg.Default)

	svc, ctx := newSvc(t)
	svc.SetInvokeDeps(InvokeDeps{
		Resolver: fakeResolver{client: &fakeLLMClient{events: []llminfra.StreamEvent{
			{Type: llminfra.EventText, Delta: "done"},
			{Type: llminfra.EventFinish, InputTokens: 3, OutputTokens: 2},
		}}},
		Knowledge: fakeKnowledge{},
	})

	a, _, err := svc.Create(ctx, CreateInput{Name: "fast", Config: Config{Prompt: "answer"}})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	res, err := svc.InvokeAgent(ctx, InvokeInput{AgentID: a.ID, TriggeredBy: agentdomain.TriggeredByWorkflow})
	if err != nil {
		t.Fatalf("invoke: %v", err)
	}
	if !res.OK || res.Status != agentdomain.ExecutionStatusOK {
		t.Fatalf("a healthy fast run must record ok, got %+v", res)
	}
}
