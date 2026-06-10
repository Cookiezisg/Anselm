package chat

import (
	"context"
	"encoding/json"
	"errors"
	"iter"
	"sync"
	"testing"
	"time"

	"go.uber.org/zap"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	conversationdomain "github.com/sunweilin/forgify/backend/internal/domain/conversation"
	messagesdomain "github.com/sunweilin/forgify/backend/internal/domain/messages"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
)

// scriptedClient replays a different script per Stream call (one per ReAct step / turn) — so a
// park turn (step 1) and its continuation turn (a later Stream call) can differ.
//
// scriptedClient 每次 Stream 调用回放不同脚本（每 ReAct 步/回合一份）——使 park 回合（步1）与其续跑回合
// （后续 Stream 调用）可不同。
type scriptedClient struct {
	mu      sync.Mutex
	scripts [][]llminfra.StreamEvent
	call    int
}

func (c *scriptedClient) Stream(_ context.Context, _ llminfra.Request) iter.Seq[llminfra.StreamEvent] {
	c.mu.Lock()
	idx := c.call
	c.call++
	c.mu.Unlock()
	return func(yield func(llminfra.StreamEvent) bool) {
		if idx >= len(c.scripts) {
			return
		}
		for _, ev := range c.scripts[idx] {
			if !yield(ev) {
				return
			}
		}
	}
}

// dangerToolCall scripts one step that calls tool `name` self-reporting danger=dangerous.
//
// dangerToolCall 脚本一步：调用工具 name 且自报 danger=dangerous。
func dangerToolCall(name string) []llminfra.StreamEvent {
	return []llminfra.StreamEvent{
		{Type: llminfra.EventToolStart, ToolIndex: 0, ToolID: "tc1", ToolName: name},
		{Type: llminfra.EventToolDelta, ToolIndex: 0, ArgsDelta: `{"danger":"dangerous","target":"prod"}`},
		{Type: llminfra.EventFinish, FinishReason: "tool_use", InputTokens: 5, OutputTokens: 3},
	}
}

// recordingTool records execution + the args it received, returning a fixed result.
//
// recordingTool 记录执行 + 收到的 args，返回固定结果。
type recordingTool struct {
	name    string
	ran     *bool
	gotArgs *string
}

func (t recordingTool) Name() string                        { return t.name }
func (t recordingTool) Description() string                 { return "deploy to an env" }
func (t recordingTool) Parameters() json.RawMessage         { return json.RawMessage(`{"type":"object"}`) }
func (t recordingTool) ValidateInput(json.RawMessage) error { return nil }
func (t recordingTool) Execute(_ context.Context, args string) (string, error) {
	*t.ran = true
	*t.gotArgs = args
	return "deployed to prod", nil
}

func newDangerSvc(t *testing.T, client llminfra.Client, bridge *recordBridge, tool recordingTool) (*Service, messagesdomain.Repository) {
	t.Helper()
	store := newStore(t)
	return New(store, Deps{
		Conversations: fakeConvs{conv: &conversationdomain.Conversation{SystemPrompt: "be concise"}},
		Resolver:      fakeResolver{client: client},
		Bridge:        bridge,
		Toolset:       toolapp.Toolset{Resident: []toolapp.Tool{tool}},
	}, zap.NewNop()), store
}

// waitContinuation polls for a completed assistant turn other than excludeID — the continuation
// the resolve drove — or fails after a timeout. (The continuation runs async on the queue.)
//
// waitContinuation 轮询除 excludeID 外的已完成 assistant 回合——resolve 驱动的续跑——超时则失败。
func waitContinuation(t *testing.T, store messagesdomain.Repository, ctx context.Context, conv, excludeID string) *messagesdomain.Message {
	t.Helper()
	deadline := time.After(2 * time.Second)
	for {
		msgs, _, err := store.ListMessages(ctx, conv, "", 0)
		if err == nil {
			for _, m := range msgs {
				if m.ID != excludeID && m.Role == messagesdomain.RoleAssistant && m.Status == messagesdomain.StatusCompleted {
					return m
				}
			}
		}
		select {
		case <-deadline:
			t.Fatal("timed out waiting for the continuation turn")
			return nil
		case <-time.After(10 * time.Millisecond):
		}
	}
}

// TestDanger_ParksThenApproveRunsAndContinues: a dangerous tool call parks the turn (tool NOT run);
// approving runs the tool at resolve time, fills the tool_result, and drives a continuation turn.
//
// TestDanger_ParksThenApproveRunsAndContinues：危险工具调用 park 回合（工具不跑）；批准在 resolve 时跑工具、
// 填 tool_result、驱动续跑回合。
func TestDanger_ParksThenApproveRunsAndContinues(t *testing.T) {
	ran := false
	var gotArgs string
	tool := recordingTool{name: "deploy", ran: &ran, gotArgs: &gotArgs}
	bridge := newRecordBridge()
	client := &scriptedClient{scripts: [][]llminfra.StreamEvent{
		dangerToolCall("deploy"), // turn 1 → parks
		textTurn(),               // continuation → final text
	}}
	svc, store := newDangerSvc(t, client, bridge, tool)
	ctx := ctxWS("ws_1")

	asstID, err := svc.Send(ctx, "cv_1", SendInput{Content: "deploy prod"})
	if err != nil {
		t.Fatalf("Send: %v", err)
	}
	waitClose(t, bridge, asstID)

	parked, err := store.GetMessage(ctx, asstID)
	if err != nil || parked.Status != messagesdomain.StatusParked {
		t.Fatalf("turn should be parked, got status=%q err=%v", parked.Status, err)
	}
	if ran {
		t.Fatal("dangerous tool ran before approval")
	}

	// approve → executes the tool now + continues
	if err := svc.ResolveInteraction(ctx, "cv_1", "tc1", ResolveApprove, "", ""); err != nil {
		t.Fatalf("ResolveInteraction: %v", err)
	}
	if !ran {
		t.Fatal("approve must execute the tool at resolve time")
	}
	if gotArgs != `{"target":"prod"}` { // standard fields (danger) stripped before persistence
		t.Fatalf("tool got wrong args: %q", gotArgs)
	}
	// the parked turn is no longer parked
	if _, err := store.GetParkedMessage(ctx, "cv_1"); !errors.Is(err, messagesdomain.ErrMessageNotFound) {
		t.Fatalf("turn should no longer be parked, err=%v", err)
	}
	// a continuation turn ran to completion
	waitContinuation(t, store, ctx, "cv_1", asstID)
}

// TestDanger_Deny: denying does NOT run the tool; the tool_result carries the denial so the model
// can re-route, and a continuation turn runs.
//
// TestDanger_Deny：拒绝不跑工具；tool_result 带拒绝信息供模型改道，且续跑回合运行。
func TestDanger_Deny(t *testing.T) {
	ran := false
	var gotArgs string
	tool := recordingTool{name: "deploy", ran: &ran, gotArgs: &gotArgs}
	bridge := newRecordBridge()
	client := &scriptedClient{scripts: [][]llminfra.StreamEvent{dangerToolCall("deploy"), textTurn()}}
	svc, store := newDangerSvc(t, client, bridge, tool)
	ctx := ctxWS("ws_1")

	asstID, _ := svc.Send(ctx, "cv_1", SendInput{Content: "deploy prod"})
	waitClose(t, bridge, asstID)

	if err := svc.ResolveInteraction(ctx, "cv_1", "tc1", ResolveDeny, "", ""); err != nil {
		t.Fatalf("ResolveInteraction deny: %v", err)
	}
	if ran {
		t.Fatal("deny must NOT run the tool")
	}
	waitContinuation(t, store, ctx, "cv_1", asstID) // continuation runs to completion
}

// TestSend_RejectedWhileParked: a new Send is refused while an interaction is pending.
//
// TestSend_RejectedWhileParked：有待决交互时新 Send 被拒。
func TestSend_RejectedWhileParked(t *testing.T) {
	ran := false
	var gotArgs string
	tool := recordingTool{name: "deploy", ran: &ran, gotArgs: &gotArgs}
	bridge := newRecordBridge()
	client := &scriptedClient{scripts: [][]llminfra.StreamEvent{dangerToolCall("deploy"), textTurn()}}
	svc, _ := newDangerSvc(t, client, bridge, tool)
	ctx := ctxWS("ws_1")

	asstID, _ := svc.Send(ctx, "cv_1", SendInput{Content: "deploy prod"})
	waitClose(t, bridge, asstID)

	if _, err := svc.Send(ctx, "cv_1", SendInput{Content: "wait, also do this"}); !errors.Is(err, ErrInteractionPending) {
		t.Fatalf("Send while parked should be ErrInteractionPending, got %v", err)
	}
}
