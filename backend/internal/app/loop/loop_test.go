package loop

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"iter"
	"strings"
	"testing"
	"unicode/utf8"

	"go.uber.org/zap"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

// --- fakes -----------------------------------------------------------------

// fakeClient replays one scripted StreamEvent slice per Stream call (one per ReAct step)
// and captures the messages it was handed, so tests can assert reminder injection.
//
// fakeClient 每次 Stream 调用回放一份脚本（每 ReAct 步一份），并记录收到的 messages，供测试断言
// reminder 注入。
type fakeClient struct {
	scripts  [][]llminfra.StreamEvent
	calls    int
	captured [][]llminfra.LLMMessage
	requests []llminfra.Request
}

func (c *fakeClient) Stream(_ context.Context, req llminfra.Request) iter.Seq[llminfra.StreamEvent] {
	c.captured = append(c.captured, req.Messages)
	c.requests = append(c.requests, req)
	idx := c.calls
	c.calls++
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

type finalizeCapture struct {
	blocks                              []messagesdomain.Block
	status, stopReason, errCode, errMsg string
	in, out                             int
	called                              int
}

// fakeHost implements only Host — the minimal surface. reminderHost / autoActivateHost embed
// it to add the optional capabilities.
//
// fakeHost 只实现 Host——最小面。reminderHost / autoActivateHost 嵌入它以加可选能力。
type fakeHost struct {
	history []llminfra.LLMMessage
	tools   []toolapp.Tool
	fin     finalizeCapture
}

func (h *fakeHost) LoadHistory(context.Context) ([]llminfra.LLMMessage, error) { return h.history, nil }
func (h *fakeHost) Tools(context.Context) []toolapp.Tool                       { return h.tools }
func (h *fakeHost) WriteFinalize(_ context.Context, blocks []messagesdomain.Block, status, stopReason, errCode, errMsg string, in, out int) {
	h.fin.blocks = blocks
	h.fin.status = status
	h.fin.stopReason = stopReason
	h.fin.errCode = errCode
	h.fin.errMsg = errMsg
	h.fin.in = in
	h.fin.out = out
	h.fin.called++
}

type errHistoryHost struct{ fakeHost }

func (errHistoryHost) LoadHistory(context.Context) ([]llminfra.LLMMessage, error) {
	return nil, errors.New("db down")
}

type reminderHost struct {
	*fakeHost
	reminders []string
}

func (h reminderHost) SystemReminders(context.Context) []string { return h.reminders }

type autoActivateHost struct {
	*fakeHost
	lazy []toolapp.Tool // activated when a tool not in the base set is requested
}

type runtimeBudgetHost struct {
	*fakeHost
	budget       int
	observations []ContextObservation
}

func (h *runtimeBudgetHost) RuntimeInputBudget(_ context.Context, route string) int {
	if route != "text" {
		return 0
	}
	return h.budget
}

func (h *runtimeBudgetHost) ObserveContext(_ context.Context, o ContextObservation) {
	h.observations = append(h.observations, o)
}

func (h *autoActivateHost) TryActivateForTool(_ context.Context, name string) []toolapp.Tool {
	for _, t := range h.lazy {
		if t.Name() == name {
			h.tools = append(h.tools, h.lazy...)
			return h.tools
		}
	}
	return nil
}

// fakeTool implements toolapp.Tool. record receives the call's stripped args; err makes
// Execute fail (for the error-storm path).
//
// fakeTool 实现 toolapp.Tool。record 收到调用的剥离后 args；err 让 Execute 失败（错误风暴路径）。
type fakeTool struct {
	name   string
	result string
	err    error
}

func (t fakeTool) Name() string                        { return t.name }
func (t fakeTool) Description() string                 { return "fake tool" }
func (t fakeTool) Parameters() json.RawMessage         { return json.RawMessage(`{"type":"object"}`) }
func (t fakeTool) ValidateInput(json.RawMessage) error { return nil }
func (t fakeTool) Execute(_ context.Context, _ string) (string, error) {
	if t.err != nil {
		return "", t.err
	}
	return t.result, nil
}

var _ toolapp.Tool = fakeTool{}

type countingTool struct {
	name  string
	calls *int
}

func (t countingTool) Name() string                        { return t.name }
func (t countingTool) Description() string                 { return "counting tool" }
func (t countingTool) Parameters() json.RawMessage         { return json.RawMessage(`{"type":"object"}`) }
func (t countingTool) ValidateInput(json.RawMessage) error { return nil }
func (t countingTool) Execute(_ context.Context, _ string) (string, error) {
	*t.calls++
	return "executed", nil
}

// --- event builders --------------------------------------------------------

func textEv(s string) llminfra.StreamEvent {
	return llminfra.StreamEvent{Type: llminfra.EventText, Delta: s}
}
func toolStartEv(idx int, id, name string) llminfra.StreamEvent {
	return llminfra.StreamEvent{Type: llminfra.EventToolStart, ToolIndex: idx, ToolID: id, ToolName: name}
}
func toolDeltaEv(idx int, args string) llminfra.StreamEvent {
	return llminfra.StreamEvent{Type: llminfra.EventToolDelta, ToolIndex: idx, ArgsDelta: args}
}
func finishEv() llminfra.StreamEvent {
	return llminfra.StreamEvent{Type: llminfra.EventFinish, InputTokens: 10, OutputTokens: 5}
}

// errorEv scripts a stream error. A nil err reproduces a silent disconnect (stopReason=error,
// no error text) — the F44 "0 block + null error" face.
func errorEv(err error) llminfra.StreamEvent {
	return llminfra.StreamEvent{Type: llminfra.EventError, Err: err}
}

// --- Run -------------------------------------------------------------------

func TestRun_SingleTextTurn(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{textEv("hello world"), finishEv()}}}
	host := &fakeHost{history: []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: "hi"}}}

	res := Run(context.Background(), host, client, llminfra.Request{}, 5, nil)

	if host.fin.called != 1 {
		t.Fatalf("WriteFinalize called %d times, want 1", host.fin.called)
	}
	if host.fin.status != messagesdomain.StatusCompleted || host.fin.stopReason != messagesdomain.StopReasonEndTurn {
		t.Fatalf("status=%q stopReason=%q, want completed/end_turn", host.fin.status, host.fin.stopReason)
	}
	if res.LastMessage != "hello world" {
		t.Fatalf("LastMessage=%q, want %q", res.LastMessage, "hello world")
	}
	if res.Steps != 1 || res.TokensIn != 10 || res.TokensOut != 5 {
		t.Fatalf("steps=%d in=%d out=%d, want 1/10/5", res.Steps, res.TokensIn, res.TokensOut)
	}
}

func TestRun_ToolThenText(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{
		{toolStartEv(0, "tc_1", "echo"), toolDeltaEv(0, `{"summary":"echoing","danger":"safe","msg":"x"}`), finishEv()},
		{textEv("done"), finishEv()},
	}}
	host := &fakeHost{
		history: []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: "go"}},
		tools:   []toolapp.Tool{fakeTool{name: "echo", result: "echoed!"}},
	}

	res := Run(context.Background(), host, client, llminfra.Request{}, 5, nil)

	if res.Steps != 2 {
		t.Fatalf("steps=%d, want 2", res.Steps)
	}
	if host.fin.status != messagesdomain.StatusCompleted {
		t.Fatalf("status=%q, want completed", host.fin.status)
	}
	// allBlocks = tool_call + tool_result (step1) + text (step2).
	var sawToolResult, sawText bool
	for _, b := range host.fin.blocks {
		if b.Type == messagesdomain.BlockTypeToolResult && b.Content == "echoed!" {
			sawToolResult = true
		}
		if b.Type == messagesdomain.BlockTypeText && b.Content == "done" {
			sawText = true
		}
	}
	if !sawToolResult || !sawText {
		t.Fatalf("blocks missing pieces: toolResult=%v text=%v (%+v)", sawToolResult, sawText, host.fin.blocks)
	}
}

// A high measured prompt no longer terminates a capable agent. The next step
// gets a chance to edit/checkpoint its prompt and continue.
func TestRun_ContextBudgetContinuesInsteadOfSoftStop(t *testing.T) {
	// Step 1 makes a tool call and reports a high ACTUAL input (1000 tokens); step 2 (if reached) ends.
	highFinish := llminfra.StreamEvent{Type: llminfra.EventFinish, InputTokens: 1000, OutputTokens: 5}
	scripts := func() [][]llminfra.StreamEvent {
		return [][]llminfra.StreamEvent{
			{toolStartEv(0, "tc_1", "echo"), toolDeltaEv(0, `{"summary":"s","danger":"safe","msg":"x"}`), highFinish},
			{textEv("continued"), finishEv()},
		}
	}
	newHost := func() *fakeHost {
		return &fakeHost{history: []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: "go"}}, tools: []toolapp.Tool{fakeTool{name: "echo", result: "ok"}}}
	}

	// Even at the full nominal budget, context governance continues rather than
	// surfacing a proactive soft-stop error to the user.
	host := newHost()
	res := Run(context.Background(), host, &fakeClient{scripts: scripts()}, llminfra.Request{InputBudgetTokens: 1000}, 5, nil)
	if res.Steps != 2 || host.fin.status != messagesdomain.StatusCompleted || res.LastMessage != "continued" {
		t.Fatalf("high context must continue to completion, got steps=%d status=%q last=%q",
			res.Steps, host.fin.status, res.LastMessage)
	}

	// budget 0 (unknown window) → guard disabled → runs both steps to a normal end_turn.
	host2 := newHost()
	res2 := Run(context.Background(), host2, &fakeClient{scripts: scripts()}, llminfra.Request{InputBudgetTokens: 0}, 5, nil)
	if res2.Steps != 2 || host2.fin.stopReason != messagesdomain.StopReasonEndTurn {
		t.Fatalf("disabled guard (budget 0) must run to completion, got steps=%d stop=%q", res2.Steps, host2.fin.stopReason)
	}

	// budget large (1000 < 0.92*100000) → under threshold → no stop, runs to completion.
	host3 := newHost()
	res3 := Run(context.Background(), host3, &fakeClient{scripts: scripts()}, llminfra.Request{InputBudgetTokens: 100000}, 5, nil)
	if res3.Steps != 2 || host3.fin.stopReason != messagesdomain.StopReasonEndTurn {
		t.Fatalf("under-budget step must not stop, got steps=%d stop=%q", res3.Steps, host3.fin.stopReason)
	}
}

func TestRun_RuntimeBudgetOverridesUnknownStaticBudgetAndObservesOutcome(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{textEv("ok"), finishEv()}}}
	host := &runtimeBudgetHost{
		fakeHost: &fakeHost{history: []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: "hi"}}},
		budget:   777_000,
	}
	Run(context.Background(), host, client, llminfra.Request{InputBudgetTokens: 0}, 1, nil)
	if len(host.observations) != 1 {
		t.Fatalf("observations = %d, want 1", len(host.observations))
	}
	o := host.observations[0]
	if o.InputBudget != 777_000 || !o.Succeeded || o.ContextOverflow || o.Route != "text" {
		t.Fatalf("runtime budget observation = %+v", o)
	}
}

func TestRun_ProviderContextOverflowCompactsAndRetriesSameStep(t *testing.T) {
	long := strings.Repeat("tool-output-", 2_000)
	history := []llminfra.LLMMessage{
		{Role: llminfra.RoleUser, Content: "complete the migration; preserve exact ids"},
		{Role: llminfra.RoleAssistant, ReasoningContent: "first complete reasoning", ToolCalls: []llminfra.LLMToolCall{{ID: "old_call", Name: "read_state", Arguments: `{"id":"wf_exact"}`}}},
		{Role: llminfra.RoleTool, ToolCallID: "old_call", Content: long},
		{Role: llminfra.RoleAssistant, ReasoningContent: "second complete reasoning", ToolCalls: []llminfra.LLMToolCall{{ID: "new_call", Name: "check_state", Arguments: `{"id":"wf_exact"}`}}},
		{Role: llminfra.RoleTool, ToolCallID: "new_call", Content: "latest exact result"},
	}
	rejected := &llminfra.RequestRejectedError{Reason: llminfra.RejectionContextLength, Status: 400}
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{
		{errorEv(rejected)},
		{textEv("Goal & constraints: complete the migration.\nExact references: wf_exact.\nOpen work/next action: continue."), finishEv()},
		{textEv("recovered and finished"), finishEv()},
	}}
	host := &fakeHost{history: history}

	res := Run(context.Background(), host, client, llminfra.Request{InputBudgetTokens: 100_000}, 3, nil)

	if client.calls != 3 {
		t.Fatalf("context recovery calls=%d, want rejected attempt + semantic checkpoint + one retry", client.calls)
	}
	if res.Status != messagesdomain.StatusCompleted || res.LastMessage != "recovered and finished" {
		t.Fatalf("recovery should be invisible and complete: %+v", res)
	}
	if host.fin.errCode != "" {
		t.Fatalf("provider context rejection leaked to user: %q %q", host.fin.errCode, host.fin.errMsg)
	}
	if len(client.requests[1].Tools) != 0 || !strings.Contains(client.requests[1].System, "continuation checkpoint") {
		t.Fatalf("middle request must be an isolated checkpoint call: %+v", client.requests[1])
	}
	second := client.captured[2]
	if measureHistory(second) >= measureHistory(client.captured[0]) {
		t.Fatalf("retry prompt did not shrink: first=%d retry=%d", measureHistory(client.captured[0]), measureHistory(second))
	}
	if !strings.Contains(second[0].Content, "context_checkpoint") {
		t.Fatalf("retry lacks a continuation checkpoint: %+v", second)
	}
}

func TestPromptEditsNeverSplitUTF8(t *testing.T) {
	// A byte ceiling can land in the middle of a CJK rune. The prompt view is
	// sent as JSON later, so it must remain valid UTF-8 rather than relying on
	// encoding/json to replace damaged exact references.
	old := strings.Repeat("你", 4_000)
	history := []llminfra.LLMMessage{
		{Role: llminfra.RoleUser, Content: "继续处理中文文件名"},
		{Role: llminfra.RoleAssistant, ToolCalls: []llminfra.LLMToolCall{{ID: "old", Name: "read", Arguments: `{}`}}},
		{Role: llminfra.RoleTool, ToolCallID: "old", Content: old},
		{Role: llminfra.RoleAssistant, ToolCalls: []llminfra.LLMToolCall{{ID: "new", Name: "read", Arguments: `{}`}}},
		{Role: llminfra.RoleTool, ToolCallID: "new", Content: old},
	}
	edited, _ := clearOldToolResults(history, 1, 8_000)
	for i, m := range edited {
		if !utf8.ValidString(m.Content) {
			t.Fatalf("edited message %d is invalid UTF-8", i)
		}
	}
	checkpoint, changed := deterministicCheckpoint(history, 2_000, 1)
	if !changed || !utf8.ValidString(checkpoint[0].Content) {
		t.Fatalf("deterministic checkpoint must be valid UTF-8: changed=%v content=%q", changed, checkpoint[0].Content)
	}
}

func TestRun_MaxStepsReached(t *testing.T) {
	// Every step returns a tool call → the loop never naturally ends.
	loopStep := []llminfra.StreamEvent{toolStartEv(0, "tc_1", "echo"), toolDeltaEv(0, `{"summary":"s","danger":"safe"}`), finishEv()}
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{loopStep, loopStep, loopStep}}
	host := &fakeHost{tools: []toolapp.Tool{fakeTool{name: "echo", result: "ok"}}}

	res := Run(context.Background(), host, client, llminfra.Request{}, 2, nil)

	if host.fin.stopReason != messagesdomain.StopReasonMaxSteps || host.fin.errCode != "MAX_STEPS_REACHED" {
		t.Fatalf("stopReason=%q errCode=%q, want max_steps/MAX_STEPS_REACHED", host.fin.stopReason, host.fin.errCode)
	}
	if host.fin.status != messagesdomain.StatusError || res.Steps != 2 {
		t.Fatalf("status=%q steps=%d, want error/2", host.fin.status, res.Steps)
	}
	// F66: the returned Result must carry the real terminal cause (not just WriteFinalize) so the
	// agent execution record surfaces it instead of a generic "agent loop error".
	if res.ErrCode != "MAX_STEPS_REACHED" || res.ErrMsg == "" {
		t.Fatalf("Result should carry ErrCode/ErrMsg; got code=%q msg=%q", res.ErrCode, res.ErrMsg)
	}
}

func TestRun_ToolErrorStorm(t *testing.T) {
	loopStep := []llminfra.StreamEvent{toolStartEv(0, "tc_1", "boom"), toolDeltaEv(0, `{"summary":"s","danger":"safe"}`), finishEv()}
	scripts := make([][]llminfra.StreamEvent, 5)
	for i := range scripts {
		scripts[i] = loopStep
	}
	client := &fakeClient{scripts: scripts}
	host := &fakeHost{tools: []toolapp.Tool{fakeTool{name: "boom", err: errors.New("kaboom")}}}

	Run(context.Background(), host, client, llminfra.Request{}, 10, nil)

	if host.fin.errCode != "TOOL_ERROR_STORM" {
		t.Fatalf("errCode=%q, want TOOL_ERROR_STORM", host.fin.errCode)
	}
	// 3 consecutive all-fail turns is the cap.
	if !strings.Contains(host.fin.errMsg, "3 consecutive") {
		t.Fatalf("errMsg=%q, want mention of 3 consecutive", host.fin.errMsg)
	}
}

// TestRun_StreamError_EmptyErrFillsActionableMsg pins the F34 fill — the exact F44 "0 block + null
// error" face: a provider can end the stream with stopReason=error yet no error text (silent
// disconnect, zero blocks emitted). The turn must finalize as error/LLM_STREAM_ERROR with a
// NON-EMPTY recovery hint, and the Result must carry the same cause (F66) — never a contentless
// error with a null cause. F44 is judged not-bug because this is already handled; this guards it.
//
// TestRun_StreamError_EmptyErrFillsActionableMsg 锁 F34 填充——正是 F44「0 block + null error」面：
// provider 可能以 stopReason=error 但无错误文本收尾（静默断连、0 块）。回合须 finalize 成
// error/LLM_STREAM_ERROR 带**非空**恢复提示，Result 也带同因（F66）——绝非无因空 error。F44 判
// not-bug 因这已处理；本测守它不回归。
func TestRun_StreamError_EmptyErrFillsActionableMsg(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{errorEv(nil)}}}
	host := &fakeHost{history: []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: "hi"}}}

	res := Run(context.Background(), host, client, llminfra.Request{}, 5, nil)

	if host.fin.status != messagesdomain.StatusError || host.fin.errCode != "LLM_STREAM_ERROR" {
		t.Fatalf("status=%q errCode=%q, want error/LLM_STREAM_ERROR", host.fin.status, host.fin.errCode)
	}
	if host.fin.errMsg == "" {
		t.Fatal("errMsg must be non-empty (F34 fill): a stream error must never finalize with a null cause")
	}
	if res.Status != messagesdomain.StatusError || res.ErrCode != "LLM_STREAM_ERROR" || res.ErrMsg == "" {
		t.Fatalf("Result must carry the terminal cause (F66); got status=%q code=%q msg=%q", res.Status, res.ErrCode, res.ErrMsg)
	}
}

func TestRun_StreamError_PreservesModelNotFoundCode(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{errorEv(fmt.Errorf("%w (404)", llminfra.ErrModelNotFound))}}}
	host := &fakeHost{history: []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: "hi"}}}

	res := Run(context.Background(), host, client, llminfra.Request{}, 5, nil)

	if host.fin.status != messagesdomain.StatusError || host.fin.errCode != "LLM_MODEL_NOT_FOUND" {
		t.Fatalf("status=%q errCode=%q, want error/LLM_MODEL_NOT_FOUND", host.fin.status, host.fin.errCode)
	}
	if !strings.Contains(host.fin.errMsg, "model not found") {
		t.Fatalf("errMsg=%q, want the classified model-not-found cause", host.fin.errMsg)
	}
	if res.ErrCode != "LLM_MODEL_NOT_FOUND" || res.ErrMsg != host.fin.errMsg {
		t.Fatalf("Result must carry the classified terminal cause; got code=%q msg=%q", res.ErrCode, res.ErrMsg)
	}
}

func TestRun_StreamError_PreservesClassifiedProviderCodes(t *testing.T) {
	tests := []struct {
		name string
		err  error
		code string
	}{
		{name: "auth", err: llminfra.ErrAuthFailed, code: "LLM_AUTH_FAILED"},
		{name: "bad request", err: llminfra.ErrBadRequest, code: "LLM_BAD_REQUEST"},
		{name: "model not found", err: llminfra.ErrModelNotFound, code: "LLM_MODEL_NOT_FOUND"},
		{name: "quota exhausted", err: llminfra.ErrQuotaExhausted, code: "LLM_QUOTA_EXHAUSTED"},
		{name: "rate limited", err: llminfra.ErrRateLimited, code: "LLM_RATE_LIMITED"},
		{name: "provider", err: llminfra.ErrProviderError, code: "LLM_PROVIDER_ERROR"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			client := &fakeClient{scripts: [][]llminfra.StreamEvent{{errorEv(fmt.Errorf("classified: %w", tc.err))}}}
			host := &fakeHost{history: []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: "hi"}}}

			res := Run(context.Background(), host, client, llminfra.Request{}, 5, nil)
			if host.fin.status != messagesdomain.StatusError || host.fin.errCode != tc.code {
				t.Fatalf("status=%q errCode=%q, want error/%s", host.fin.status, host.fin.errCode, tc.code)
			}
			if res.ErrCode != tc.code || res.ErrMsg == "" {
				t.Fatalf("result code=%q message=%q, want %s with a cause", res.ErrCode, res.ErrMsg, tc.code)
			}
		})
	}
}

func TestRun_LoadHistoryError(t *testing.T) {
	host := &errHistoryHost{}
	client := &fakeClient{}

	res := Run(context.Background(), host, client, llminfra.Request{}, 5, nil)

	if res.Status != messagesdomain.StatusError || host.fin.errCode != "INTERNAL_ERROR" {
		t.Fatalf("status=%q errCode=%q, want error/INTERNAL_ERROR", res.Status, host.fin.errCode)
	}
	if client.calls != 0 {
		t.Fatalf("client called %d times, want 0 (aborted before stream)", client.calls)
	}
}

func TestRun_RemindersInjectedEachStep(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{textEv("ok"), finishEv()}}}
	base := &fakeHost{history: []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: "hi"}}}
	host := reminderHost{fakeHost: base, reminders: []string{"todo: ship it"}}

	Run(context.Background(), host, client, llminfra.Request{}, 5, nil)

	if len(client.captured) != 1 {
		t.Fatalf("captured %d requests, want 1", len(client.captured))
	}
	msgs := client.captured[0]
	last := msgs[len(msgs)-1]
	if last.Role != llminfra.RoleUser || !strings.Contains(last.Content, "<system-reminder>") || !strings.Contains(last.Content, "ship it") {
		t.Fatalf("last message not the injected reminder: %+v", last)
	}
	// Persisted history (base.history) must stay clean — reminder is transient.
	if len(base.history) != 1 {
		t.Fatalf("base history mutated to len %d, want 1", len(base.history))
	}
}

func TestRun_AutoActivateLazyTool(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{
		{toolStartEv(0, "tc_1", "lazy_tool"), toolDeltaEv(0, `{"summary":"s","danger":"safe"}`), finishEv()},
		{textEv("activated and ran"), finishEv()},
	}}
	base := &fakeHost{} // base tool set is EMPTY — lazy_tool only reachable via activation
	host := &autoActivateHost{fakeHost: base, lazy: []toolapp.Tool{fakeTool{name: "lazy_tool", result: "lazy ran"}}}

	Run(context.Background(), host, client, llminfra.Request{}, 5, nil)

	var ran bool
	for _, b := range host.fin.blocks {
		if b.Type == messagesdomain.BlockTypeToolResult && b.Content == "lazy ran" {
			ran = true
		}
	}
	if !ran {
		t.Fatalf("lazy tool was not auto-activated + executed: %+v", host.fin.blocks)
	}
}

// --- tool dispatch ---------------------------------------------------------

func TestPartitionByExecutionGroup(t *testing.T) {
	calls := []messagesdomain.ToolCallData{
		{ID: "a", ExecutionGroup: 1},
		{ID: "b", ExecutionGroup: 1},
		{ID: "c", ExecutionGroup: 0}, // auto-grouped, sorts after explicit
		{ID: "d", ExecutionGroup: 2},
	}
	batches := partitionByExecutionGroup(calls)
	// groups: 1 -> [a,b], 2 -> [d], auto(1000) -> [c]. Order: 1, 2, 1000.
	if len(batches) != 3 {
		t.Fatalf("got %d batches, want 3", len(batches))
	}
	if len(batches[0].items) != 2 || batches[0].items[0].tc.ID != "a" {
		t.Fatalf("batch0 wrong: %+v", batches[0].items)
	}
	if len(batches[1].items) != 1 || batches[1].items[0].tc.ID != "d" {
		t.Fatalf("batch1 wrong: %+v", batches[1].items)
	}
	if len(batches[2].items) != 1 || batches[2].items[0].tc.ID != "c" {
		t.Fatalf("batch2 (auto) wrong: %+v", batches[2].items)
	}
}

func TestRunTools_ResultsIndexAligned(t *testing.T) {
	// Two calls in the same execution group run concurrently; results must map back to input order.
	calls := []messagesdomain.ToolCallData{
		{ID: "tc_a", Name: "a", ExecutionGroup: 1},
		{ID: "tc_b", Name: "b", ExecutionGroup: 1},
	}
	byName := map[string]toolapp.Tool{
		"a": fakeTool{name: "a", result: "result-a"},
		"b": fakeTool{name: "b", result: "result-b"},
	}
	blocks := runTools(context.Background(), calls, byName, zap.NewNop())
	if len(blocks) != 2 {
		t.Fatalf("got %d blocks, want 2", len(blocks))
	}
	if blocks[0].Content != "result-a" || blocks[0].ParentBlockID != "tc_a" {
		t.Fatalf("block0 misaligned: %+v", blocks[0])
	}
	if blocks[1].Content != "result-b" || blocks[1].ParentBlockID != "tc_b" {
		t.Fatalf("block1 misaligned: %+v", blocks[1])
	}
}

func TestRunTools_SuppressesIdenticalCallsInOneBatch(t *testing.T) {
	runCount := 0
	calls := []messagesdomain.ToolCallData{
		{ID: "tc_a", Name: "create_control", Arguments: map[string]any{"name": "router"}, ExecutionGroup: 1},
		{ID: "tc_b", Name: "create_control", Arguments: map[string]any{"name": "router"}, ExecutionGroup: 1},
	}
	blocks := runTools(context.Background(), calls, map[string]toolapp.Tool{
		"create_control": countingTool{name: "create_control", calls: &runCount},
	}, zap.NewNop())
	if runCount != 1 {
		t.Fatalf("identical calls executed %d times, want once", runCount)
	}
	if len(blocks) != 2 || blocks[1].Error != "" || !strings.Contains(blocks[1].Content, "Duplicate tool call suppressed") {
		t.Fatalf("duplicate result = %+v, want completed suppression", blocks)
	}
	if blocks[1].Attrs["duplicateSuppressed"] != true {
		t.Fatalf("duplicate result attrs = %#v, want duplicateSuppressed=true", blocks[1].Attrs)
	}
}

func TestExecuteTool_NotFound(t *testing.T) {
	out, errMsg, ok := executeTool(context.Background(), nil, "ghost", []byte(`{}`), zap.NewNop())
	if ok || !strings.Contains(out, "not found") || errMsg == "" {
		t.Fatalf("nil tool: out=%q errMsg=%q ok=%v", out, errMsg, ok)
	}
}

// TestParseToolArgs_RepairsDirtyJSON — F-toolargs-opacity: dirty LLM JSON (trailing comma) is repaired
// so the tool gets its REAL fields, not the rawArgsKey sentinel that would trigger a misleading
// "field X required". Genuinely-unparseable args fall through to the sentinel.
func TestParseToolArgs_RepairsDirtyJSON(t *testing.T) {
	// A literal control char (unescaped newline) inside a string — invalid JSON, the most common LLM
	// failure mode; jsonrepair escapes it so the real fields decode.
	_, args := parseToolArgs("{\"code\":\"line1\nline2\"}")
	if _, isRaw := args[rawArgsKey]; isRaw {
		t.Fatalf("dirty-but-repairable JSON must decode to real fields, got sentinel: %v", args)
	}
	if _, ok := args["code"]; !ok {
		t.Fatalf("repaired args must carry the real 'code' field, got %v", args)
	}
	// Genuinely-unparseable garbage falls through to the sentinel.
	_, garbage := parseToolArgs(`}{not json at all`)
	if _, isRaw := garbage[rawArgsKey]; !isRaw {
		t.Fatalf("unparseable args must leave the rawArgsKey sentinel, got %v", garbage)
	}
	// F165: a REAL one-field tool call whose only field happens to be named "raw" (valid JSON) must NOT
	// be mistaken for the unparseable sentinel — the old sentinel key was literally "raw", which made
	// any tool declaring a `raw` string param permanently un-callable.
	if _, ok := unparsedRaw([]byte(`{"raw":"a legitimate string value"}`)); ok {
		t.Fatal("a valid {\"raw\":...} call must not be detected as the unparseable-args sentinel (F165 collision)")
	}
}

// TestExecuteTool_UnparseableArgsClearError — the rawArgsKey sentinel must yield a clear "not valid
// JSON" message, NOT the tool's downstream validation error, must NOT execute the tool, AND must echo
// back the agent's own malformed text so its retry isn't blind (F168-M9).
func TestExecuteTool_UnparseableArgsClearError(t *testing.T) {
	tool := fakeTool{name: "writer", result: "SHOULD-NOT-RUN"}
	// Build the sentinel via the constant (not a hardcoded "raw" key, which F165 changed). Use a
	// recognizable marker as the malformed text so we can assert it gets echoed back.
	const garbage = "}{MARKER-garbage"
	sentinel := []byte(fmt.Sprintf(`{%q:%q}`, rawArgsKey, garbage))
	out, errMsg, ok := executeTool(context.Background(), tool, "writer", sentinel, zap.NewNop())
	if ok {
		t.Fatalf("unparseable args must fail, got ok=true out=%q", out)
	}
	if !strings.Contains(out, "not valid JSON") || errMsg == "" {
		t.Fatalf("unparseable args must surface a clear JSON error, got out=%q errMsg=%q", out, errMsg)
	}
	if !strings.Contains(out, "MARKER") {
		t.Fatalf("the error must echo the agent's malformed text so retry isn't blind (F168-M9), got out=%q", out)
	}
	if strings.Contains(out, "SHOULD-NOT-RUN") {
		t.Fatal("the tool must NOT execute on unparseable args")
	}
}

// TestExecuteTool_UnparseableArgsEchoTruncated — an oversized malformed blob is truncated in the
// echo so it can't bloat the tool_result (F168-M9).
func TestExecuteTool_UnparseableArgsEchoTruncated(t *testing.T) {
	tool := fakeTool{name: "writer", result: "SHOULD-NOT-RUN"}
	big := "}{" + strings.Repeat("X", 4000)
	sentinel := []byte(fmt.Sprintf(`{%q:%q}`, rawArgsKey, big))
	out, _, ok := executeTool(context.Background(), tool, "writer", sentinel, zap.NewNop())
	if ok {
		t.Fatal("unparseable args must fail")
	}
	if !strings.Contains(out, "truncated") || len(out) > 1200 {
		t.Fatalf("oversized malformed echo must be truncated, got len=%d out=%.120q…", len(out), out)
	}
}

// --- stream assembly + danger ---------------------------------------------

func TestStreamLLM_AssemblesBlocksAndDanger(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		llminfra.StreamEvent{Type: llminfra.EventReasoning, Delta: "thinking"},
		textEv("answer"),
		llminfra.StreamEvent{Type: llminfra.EventToolStart, ToolIndex: 0, ToolID: "tc_1", ToolName: "writer", Signature: "sig-call"},
		toolDeltaEv(0, `{"summary":"writing","danger":"dangerous","path":"/x"}`),
		finishEv(),
	}}}

	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	blocks, calls, stop, _, in, out := streamLLM(context.Background(), client, llminfra.Request{}, noBuild, nil)

	if stop != messagesdomain.StopReasonEndTurn || in != 10 || out != 5 {
		t.Fatalf("stop=%q in=%d out=%d", stop, in, out)
	}
	if len(calls) != 1 || calls[0].Danger != "dangerous" || calls[0].Summary != "writing" {
		t.Fatalf("tool call danger/summary not parsed: %+v", calls)
	}
	// Business args must have the standard fields stripped.
	if _, hasDanger := calls[0].Arguments["danger"]; hasDanger {
		t.Fatalf("danger leaked into business args: %+v", calls[0].Arguments)
	}
	if calls[0].Arguments["path"] != "/x" {
		t.Fatalf("business arg missing: %+v", calls[0].Arguments)
	}
	// reasoning + text + tool_call blocks; tool_call carries danger in attrs.
	var toolCallBlk *messagesdomain.Block
	for i := range blocks {
		if blocks[i].Type == messagesdomain.BlockTypeToolCall {
			toolCallBlk = &blocks[i]
		}
	}
	if toolCallBlk == nil || toolCallBlk.Attrs["danger"] != "dangerous" || toolCallBlk.Attrs["signature"] != "sig-call" {
		t.Fatalf("tool_call block missing danger attr: %+v", blocks)
	}
}

// --- history transform -----------------------------------------------------

func TestBlocksToAssistantLLM(t *testing.T) {
	blocks := []messagesdomain.Block{
		{Type: messagesdomain.BlockTypeReasoning, Content: "hmm", Attrs: map[string]any{"signature": "sig1"}},
		{Type: messagesdomain.BlockTypeText, Content: "hi"},
		{ID: "tc_1", Type: messagesdomain.BlockTypeToolCall, Content: `{"x":1}`, Attrs: map[string]any{"tool": "echo", "signature": "sig-call"}},
		{Type: messagesdomain.BlockTypeToolResult, Content: "out", ParentBlockID: "tc_1"},
		{Type: messagesdomain.BlockTypeCompaction, Content: "dropme"},
	}
	msgs := BlocksToAssistantLLM(blocks)
	if len(msgs) != 2 {
		t.Fatalf("got %d msgs, want 2 (assistant + tool)", len(msgs))
	}
	a := msgs[0]
	if a.Role != llminfra.RoleAssistant || a.Content != "hi" || a.ReasoningContent != "hmm" || a.ReasoningSignature != "sig1" {
		t.Fatalf("assistant msg wrong: %+v", a)
	}
	if len(a.ToolCalls) != 1 || a.ToolCalls[0].Name != "echo" || a.ToolCalls[0].ID != "tc_1" || a.ToolCalls[0].Signature != "sig-call" {
		t.Fatalf("assistant tool calls wrong: %+v", a.ToolCalls)
	}
	if msgs[1].Role != llminfra.RoleTool || msgs[1].Content != "out" || msgs[1].ToolCallID != "tc_1" {
		t.Fatalf("tool msg wrong: %+v", msgs[1])
	}
}

func TestProjectToolResultContent_ContextRole(t *testing.T) {
	long := strings.Repeat("x", 500)
	cases := []struct {
		role string
		want string // substring expected
	}{
		{messagesdomain.ContextRoleHot, long},
		{messagesdomain.ContextRoleWarm, "truncated, 500 total bytes"},
		{messagesdomain.ContextRoleCold, "output omitted to save context"},
	}
	for _, c := range cases {
		b := messagesdomain.Block{
			Type: messagesdomain.BlockTypeToolResult, Content: long,
			ContextRole: c.role, Attrs: map[string]any{"tool": "reader"},
		}
		got := projectToolResultContent(b)
		if !strings.Contains(got, c.want) {
			t.Fatalf("role %q: got %q, want substring %q", c.role, truncate(got), c.want)
		}
	}
}

func TestInjectReminders_NoProviderUnchanged(t *testing.T) {
	host := &fakeHost{}
	history := []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: "hi"}}
	got := injectReminders(context.Background(), host, history)
	if len(got) != 1 {
		t.Fatalf("non-provider host should pass history through, got len %d", len(got))
	}
}

// --- helpers ---------------------------------------------------------------

func truncate(s string) string {
	if len(s) > 60 {
		return s[:60] + "..."
	}
	return s
}

// --- WRK-082 批B' consumption chokepoint, tool_result half ------------------

// mediaHost adds the optional MediaExpander capability to fakeHost, recording which ids the
// loop asked to expand and returning one image part.
//
// mediaHost 给 fakeHost 加可选 MediaExpander 能力,记录 loop 请求展开的 id 并返回一个图 part。
type mediaHost struct {
	fakeHost
	got     [][]string
	gotCall []string // the tool_call id each expansion was asked under 每次展开被问及的 tool_call id
}

func (h *mediaHost) ExpandToolMedia(_ context.Context, toolCallID string, ids []string) []llminfra.ContentPart {
	h.got = append(h.got, ids)
	h.gotCall = append(h.gotCall, toolCallID)
	return []llminfra.ContentPart{{Type: llminfra.PartImageURL, ImageURL: "data:image/png;base64,xx"}}
}

// TestRun_SelfAuthoredMediaIsFedBack: an artifact the model ORDERED comes back to it as input.
// This test asserted the OPPOSITE until 2026-07-28, guarding a producer veto (ADR 0017) whose
// premise — "it wrote the prompt, so the pixels add nothing" — a paired live experiment falsified:
// handed a pictureless receipt, `qwen3-vl-plus` treated the generation as failed and re-drew until
// MAX_STEPS (4 generation calls veto-on vs 1 veto-off, twice each, zero disagreement). Knowing what
// you asked for is not knowing what you got. Whether the model can RECEIVE the artifact is decided
// downstream by the capability/envelope gate; the loop's job is to hand the reference over
// (ADR 0020). The 3.2MB-clip 400 that once justified the veto was an unchecked envelope, fixed
// separately in fitsMediaEnvelope.
//
// TestRun_SelfAuthoredMediaIsFedBack:模型**自己点的**产物会作为输入回到它那里。本测试在 2026-07-28
// 之前断言**相反**的事,守着一道产地否决(ADR 0017),而其前提——「prompt 是它写的,像素毫无增益」——被
// 成对真钱实验证伪:拿到没有图的 receipt,`qwen3-vl-plus` 把生成当失败、重画到 MAX_STEPS(否决开 4 次
// vs 否决关 1 次,各跑两遍零分歧)。**知道自己要什么 ≠ 知道做出来是什么。** 模型收不收得下由下游能力+
// 信封闸裁决;loop 的职责是把引用递过去(ADR 0020)。当年为否决背书的那次 3.2MB 400,真因是信封没查,
// 已在 fitsMediaEnvelope 单独修掉。
func TestRun_SelfAuthoredMediaIsFedBack(t *testing.T) {
	receipt := `{"attachmentId":"att_00aa00aa00aa00aa","mime":"image/png","source":"generate_image"}`
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{
		{toolStartEv(0, "tc_1", "paint"), toolDeltaEv(0, `{"summary":"s","danger":"safe"}`), finishEv()},
		{textEv("done"), finishEv()},
	}}
	host := &mediaHost{fakeHost: fakeHost{tools: []toolapp.Tool{fakeTool{name: "paint", result: receipt}}}}

	Run(context.Background(), host, client, llminfra.Request{}, 5, nil)

	if host.fin.status != messagesdomain.StatusCompleted {
		t.Fatalf("status=%q, want completed", host.fin.status)
	}
	if len(host.got) != 1 || len(host.got[0]) != 1 || host.got[0][0] != "att_00aa00aa00aa00aa" {
		t.Fatalf("expander asked for %v, want exactly the generated artifact once", host.got)
	}
	if len(client.captured) != 2 {
		t.Fatalf("requests=%d, want 2", len(client.captured))
	}
	for _, m := range client.captured[0] {
		for _, p := range m.Parts {
			if p.Type == llminfra.PartImageURL {
				t.Fatalf("first request already carries the media part — expansion must ride the follow-up only")
			}
		}
	}
	// The follow-up request must carry the pixels — the confirmation signal whose absence caused
	// the re-draw loop.
	// 后续请求必须带上像素——正是这份确认信号的缺席造成了重画循环。
	found := false
	for _, m := range client.captured[1] {
		for _, p := range m.Parts {
			if p.Type == llminfra.PartImageURL {
				found = true
			}
		}
	}
	if !found {
		t.Fatalf("the follow-up request never carries the generated image: %+v", client.captured[1])
	}
}

// TestRun_EvidenceMediaStillExpands is the OTHER half of the rule, and the reason it is keyed on the
// producer rather than on "media in a tool_result". A chart a function computed is something the
// model has NEVER seen — that is the whole point of having asked — so it must still arrive as a
// real media part. Losing this would quietly turn the computation↔perception loop into a text
// pipeline that only pretends to look.
//
// TestRun_EvidenceMediaStillExpands 是这条规则的**另一半**,也是它按**产地**而非按「tool_result 里有
// 媒体」判定的理由。function 算出来的图表是模型**从未见过**的东西——那正是它开口要的理由——故它必须
// 仍然以真媒体 part 到达。丢了这条,「计算↔感知闭环」会静默退化成一条**假装在看**的文本流水线。
func TestRun_EvidenceMediaStillExpands(t *testing.T) {
	receipt := `{"attachmentId":"att_00bb00bb00bb00bb","mime":"image/png","source":"function_artifact"}`
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{
		{toolStartEv(0, "tc_1", "chart"), toolDeltaEv(0, `{"summary":"s","danger":"safe"}`), finishEv()},
		{textEv("done"), finishEv()},
	}}
	host := &mediaHost{fakeHost: fakeHost{tools: []toolapp.Tool{fakeTool{name: "chart", result: receipt}}}}

	Run(context.Background(), host, client, llminfra.Request{}, 5, nil)

	if len(host.got) != 1 || len(host.got[0]) != 1 || host.got[0][0] != "att_00bb00bb00bb00bb" {
		t.Fatalf("expander asked for %v, want exactly the function artifact once", host.got)
	}
	// The expansion must be asked under the tool_call that produced it. Reading that id off ctx
	// instead is what silently disabled this whole branch in the real loop: the id is only seeded
	// inside the tool's own execution scope, and the expansion runs one level out.
	// 展开必须**在产出它的那个 tool_call 名下**被问。改成从 ctx 读那个 id,正是这条分支在真 loop 里被
	// 静默关掉的方式:那个 id 只在**工具自己的执行作用域内**被种下,而展开发生在外面一层。
	// The id is the loop's OWN tool_call block id — the very value SetToolCallID plants for the
	// tool's execution, hence the value the artifact's origin_tool_call_id was stamped with. What
	// matters is that it is present: an empty id makes the expansion chokepoint refuse, which is
	// exactly how this branch died in production while every mocked test stayed green.
	// 这个 id 是 loop **自己**的 tool_call 块 id——正是 SetToolCallID 为工具执行种下的那个值,也因此正是
	// 产物的 origin_tool_call_id 被打上的那个值。要紧的是**它在**:空 id 会让展开咽喉拒绝,而那正是这条
	// 分支在生产里死掉的方式,同时每个 mock 测试都还绿着。
	if len(host.gotCall) != 1 || host.gotCall[0] == "" {
		t.Fatalf("expander asked under %v, want a non-empty producing tool_call id", host.gotCall)
	}
	found := false
	for _, m := range client.captured[1] {
		if m.Role != llminfra.RoleUser {
			continue
		}
		for _, p := range m.Parts {
			if p.Type == llminfra.PartImageURL && p.ImageURL == "data:image/png;base64,xx" {
				found = true
			}
		}
	}
	if !found {
		t.Fatalf("second request lacks the evidence media part: %+v", client.captured[1])
	}
}

// TestRun_ToolResultWithoutMediaExpandsNothing: plain tool results must not summon the expander,
// and a host WITHOUT the capability runs identically (no extra messages either way).
//
// TestRun_ToolResultWithoutMediaExpandsNothing:普通 tool result 不得召唤展开器;无能力 host 行为
// 完全一致(两边都不多长消息)。
func TestRun_ToolResultWithoutMediaExpandsNothing(t *testing.T) {
	script := func() [][]llminfra.StreamEvent {
		return [][]llminfra.StreamEvent{
			{toolStartEv(0, "tc_1", "echo"), toolDeltaEv(0, `{"summary":"s","danger":"safe"}`), finishEv()},
			{textEv("done"), finishEv()},
		}
	}
	// Capability present, no MediaRef in the result → expander never called. 有能力无引用→零调用。
	c1 := &fakeClient{scripts: script()}
	h1 := &mediaHost{fakeHost: fakeHost{tools: []toolapp.Tool{fakeTool{name: "echo", result: "plain text"}}}}
	Run(context.Background(), h1, c1, llminfra.Request{}, 5, nil)
	if len(h1.got) != 0 {
		t.Fatalf("expander called for a media-free result: %v", h1.got)
	}
	// No capability, receipt present → same message count as capability-present media-free run.
	// 无能力有 receipt→消息数与上面一致(不长消息、不炸)。
	receipt := `{"attachmentId":"att_00aa00aa00aa00aa","source":"generate_image"}`
	c2 := &fakeClient{scripts: script()}
	h2 := &fakeHost{tools: []toolapp.Tool{fakeTool{name: "echo", result: receipt}}}
	Run(context.Background(), h2, c2, llminfra.Request{}, 5, nil)
	if h2.fin.status != messagesdomain.StatusCompleted {
		t.Fatalf("capability-less host must complete, got %q", h2.fin.status)
	}
	if len(c1.captured[1]) != len(c2.captured[1]) {
		t.Fatalf("message counts diverge: with-cap %d vs without-cap %d", len(c1.captured[1]), len(c2.captured[1]))
	}
}
