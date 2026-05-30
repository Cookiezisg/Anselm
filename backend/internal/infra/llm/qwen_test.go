package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// ──────────────────────────────────────────────────────────────────────────────
// L1: BuildRequest shape (Qwen golden wire format per 03 §6)
// ──────────────────────────────────────────────────────────────────────────────

// TestQwen_BuildRequest_GoldenShape verifies the Qwen BuildRequest wire shape:
// model, messages, tools in OpenAI shape, stream:true, stream_options, no
// thinking fields. Matches 03-implementation-reference §6 golden request.
//
// 验证 Qwen BuildRequest wire shape：model/messages/tools/stream/stream_options，
// 无 thinking 字段；对照 03 §6 黄金请求体。
func TestQwen_BuildRequest_GoldenShape(t *testing.T) {
	p := newQwenProvider()
	req := Request{
		ModelID: "qwen-plus",
		BaseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
		Key:     "sk-test",
		Messages: []LLMMessage{
			{Role: RoleUser, Content: "Weather in Shanghai?"},
		},
		Tools: []ToolDef{
			{
				Name:        "get_weather",
				Description: "",
				Parameters:  json.RawMessage(`{"type":"object","properties":{"location":{"type":"string"}},"required":["location"]}`),
			},
		},
	}
	httpReq, err := p.BuildRequest(context.Background(), req)
	if err != nil {
		t.Fatalf("BuildRequest: %v", err)
	}

	var body qwenRequest
	if err := json.NewDecoder(httpReq.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}

	if body.Model != "qwen-plus" {
		t.Errorf("model = %q, want qwen-plus", body.Model)
	}
	if !body.Stream {
		t.Error("stream must be true")
	}
	if body.StreamOptions == nil || !body.StreamOptions.IncludeUsage {
		t.Error("stream_options.include_usage must be true")
	}
	if len(body.Tools) != 1 || body.Tools[0].Function.Name != "get_weather" {
		t.Errorf("tools = %+v, want 1 tool named get_weather", body.Tools)
	}
	if body.EnableThinking != nil {
		t.Errorf("nil Thinking → enable_thinking must be absent; got %v", *body.EnableThinking)
	}
}

// TestQwen_BuildRequest_ThinkingOn_EnableThinkingTrue verifies Mode="on" emits
// enable_thinking:true (and stream:true since DisableStream is false).
// Matches 03 §6 golden: enable_thinking=true requires stream:true.
//
// 验证 Qwen Mode="on" emit enable_thinking:true（DisableStream=false → stream:true）。
// 对照 03 §6：enable_thinking=true 必须 stream:true。
func TestQwen_BuildRequest_ThinkingOn_EnableThinkingTrue(t *testing.T) {
	body := buildProviderBody(t, "qwen", "https://dashscope.aliyuncs.com/compatible-mode/v1",
		func() Request {
			r := minimalReq("qwen-plus")
			r.Thinking = &ThinkingSpec{Mode: "on"}
			return r
		}())

	var parsed map[string]json.RawMessage
	if err := json.Unmarshal(body, &parsed); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if _, ok := parsed["enable_thinking"]; !ok {
		t.Fatalf("body missing enable_thinking; body: %s", body)
	}
	var et bool
	json.Unmarshal(parsed["enable_thinking"], &et)
	if !et {
		t.Errorf("enable_thinking = %v, want true", et)
	}
	// stream must be true when enable_thinking=true (Qwen hard requirement).
	// stream 必须为 true（Qwen 硬要求）。
	var stream bool
	json.Unmarshal(parsed["stream"], &stream)
	if !stream {
		t.Errorf("stream must be true when enable_thinking=true")
	}
}

// TestQwen_BuildRequest_ThinkingOn_WithBudget verifies Mode="on"+Budget emits
// thinking_budget.
//
// 验证 Qwen Mode="on"+Budget emit thinking_budget。
func TestQwen_BuildRequest_ThinkingOn_WithBudget(t *testing.T) {
	r := minimalReq("qwen-plus")
	r.Thinking = &ThinkingSpec{Mode: "on", Budget: 512}
	body := buildProviderBody(t, "qwen", "https://dashscope.aliyuncs.com/compatible-mode/v1", r)

	var parsed map[string]json.RawMessage
	json.Unmarshal(body, &parsed)
	if _, ok := parsed["thinking_budget"]; !ok {
		t.Fatalf("body missing thinking_budget; body: %s", body)
	}
	var budget int
	json.Unmarshal(parsed["thinking_budget"], &budget)
	if budget != 512 {
		t.Errorf("thinking_budget = %d, want 512", budget)
	}
}

// TestQwen_BuildRequest_ThinkingOff_EnableThinkingFalse verifies Mode="off"
// emits enable_thinking:false.
//
// 验证 Qwen Mode="off" emit enable_thinking:false。
func TestQwen_BuildRequest_ThinkingOff_EnableThinkingFalse(t *testing.T) {
	r := minimalReq("qwen-plus")
	r.Thinking = &ThinkingSpec{Mode: "off"}
	body := buildProviderBody(t, "qwen", "https://dashscope.aliyuncs.com/compatible-mode/v1", r)

	var parsed map[string]json.RawMessage
	json.Unmarshal(body, &parsed)
	if _, ok := parsed["enable_thinking"]; !ok {
		t.Fatalf("body missing enable_thinking; body: %s", body)
	}
	var et bool
	json.Unmarshal(parsed["enable_thinking"], &et)
	if et {
		t.Errorf("enable_thinking = %v, want false", et)
	}
}

// TestQwen_BuildRequest_StreamGuard_DisableStreamPlusOn_NoEnableThinking verifies
// that DisableStream=true + Mode="on" does NOT emit enable_thinking (stream guard).
// Qwen 400s with "enable_thinking must be set to false for non-streaming calls".
//
// 验证 DisableStream=true+Mode="on" 时不 emit enable_thinking（流式守卫）。
// Qwen 非流式+on → 400。
func TestQwen_BuildRequest_StreamGuard_DisableStreamPlusOn_NoEnableThinking(t *testing.T) {
	r := minimalReq("qwen-plus")
	r.DisableStream = true
	r.Thinking = &ThinkingSpec{Mode: "on"}
	body := buildProviderBody(t, "qwen", "https://dashscope.aliyuncs.com/compatible-mode/v1", r)

	if bytes.Contains(body, []byte(`"enable_thinking"`)) {
		t.Errorf("stream guard: enable_thinking must not appear when DisableStream=true+Mode=on; body: %s", body)
	}
}

// TestQwen_BuildRequest_NilThinking_NoThinkingFields verifies that nil Thinking
// emits no thinking fields (regression guard).
//
// 验证 nil Thinking 不含任何 thinking 字段（回归守卫）。
func TestQwen_BuildRequest_NilThinking_NoThinkingFields(t *testing.T) {
	body := buildProviderBody(t, "qwen", "https://dashscope.aliyuncs.com/compatible-mode/v1", minimalReq("qwen-plus"))
	assertNoThinkingFields(t, body)
}

// ──────────────────────────────────────────────────────────────────────────────
// L2: ParseStream via httptest
// ──────────────────────────────────────────────────────────────────────────────

// collectQwenFromServer points qwenProvider at the given test server and
// collects all StreamEvents from ParseStream.
//
// collectQwenFromServer 把 qwenProvider 指向测试服务器，收集所有 StreamEvent。
func collectQwenFromServer(t *testing.T, srv *httptest.Server) []StreamEvent {
	t.Helper()
	resp, err := http.Get(srv.URL)
	if err != nil {
		t.Fatalf("http.Get: %v", err)
	}
	p := newQwenProvider()
	req := Request{ModelID: "qwen-plus", BaseURL: srv.URL}
	var events []StreamEvent
	for ev := range p.ParseStream(context.Background(), resp, req) {
		events = append(events, ev)
	}
	return events
}

// TestQwen_ParseStream_ReasoningContentBeforeContent verifies Qwen streams
// reasoning_content before content and both are correctly mapped.
//
// 验证 Qwen 先流 reasoning_content 再流 content，两者均正确映射。
func TestQwen_ParseStream_ReasoningContentBeforeContent(t *testing.T) {
	fixture := `data: {"choices":[{"delta":{"reasoning_content":"思考中..."},"finish_reason":null}]}

data: {"choices":[{"delta":{"content":"上海天气晴。"},"finish_reason":"stop"}]}

data: [DONE]
`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectQwenFromServer(t, srv)

	reasoning := filterType(events, EventReasoning)
	if len(reasoning) != 1 || reasoning[0].Delta != "思考中..." {
		t.Errorf("reasoning events = %+v", reasoning)
	}
	texts := filterType(events, EventText)
	if len(texts) != 1 || texts[0].Delta != "上海天气晴。" {
		t.Errorf("text events = %+v", texts)
	}

	// Reasoning must precede text in event order.
	// reasoning 事件必须在 text 之前。
	var firstR, firstT int
	firstR, firstT = -1, -1
	for i, ev := range events {
		if ev.Type == EventReasoning && firstR < 0 {
			firstR = i
		}
		if ev.Type == EventText && firstT < 0 {
			firstT = i
		}
	}
	if firstR >= firstT {
		t.Errorf("reasoning must precede text; reasoning@%d text@%d", firstR, firstT)
	}
}

// TestQwen_ParseStream_FlatErrorEnvelope verifies Qwen's flat error envelope
// {code,message,request_id} arriving as a 200 SSE chunk maps to EventError
// wrapping ErrProviderError (not silently dropped).
//
// 验证 Qwen 扁平错误信封（顶层 code/message/request_id，200 SSE chunk）正确映射为
// EventError（含 ErrProviderError sentinel），不被静默丢弃。
func TestQwen_ParseStream_FlatErrorEnvelope(t *testing.T) {
	fixture := `data: {"code":"InvalidParameter","message":"enable_thinking must be set to false for non-streaming calls","request_id":"req-abc123"}

`
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, fixture)
	}))
	defer srv.Close()
	events := collectQwenFromServer(t, srv)

	errEvents := filterType(events, EventError)
	if len(errEvents) != 1 {
		t.Fatalf("want 1 EventError for Qwen flat error, got %d: %+v", len(errEvents), events)
	}
	ev := errEvents[0]
	if ev.Err == nil {
		t.Fatal("EventError.Err must not be nil")
	}
	if !errors.Is(ev.Err, ErrProviderError) {
		t.Errorf("error must wrap ErrProviderError; got: %v", ev.Err)
	}
	if !strings.Contains(ev.Err.Error(), "InvalidParameter") {
		t.Errorf("error should contain code 'InvalidParameter'; got: %v", ev.Err)
	}
	if !strings.Contains(ev.Err.Error(), "enable_thinking") {
		t.Errorf("error should contain message text; got: %v", ev.Err)
	}
}

// TestQwen_ParseStream_FlatError_NoSilentTermination ensures a Qwen flat error
// does not result in zero events (pre-fix: no choices → return true, no error).
//
// 确保 Qwen 扁平错误不以零事件终止流（修复前：无 choices → return true，无 EventError）。
func TestQwen_ParseStream_FlatError_NoSilentTermination(t *testing.T) {
	fixture := `data: {"code":"Throttling.RateQuota","message":"Requests rate limit exceeded","request_id":"rq-123"}

`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectQwenFromServer(t, srv)
	if len(filterType(events, EventError)) == 0 {
		t.Errorf("Qwen flat error must yield EventError; events: %+v", events)
	}
}

// TestQwen_ParseStream_ToolCall verifies tool-call streaming through the Qwen provider.
//
// 验证 Qwen provider 的 tool-call 流式解析。
func TestQwen_ParseStream_ToolCall(t *testing.T) {
	fixture := `data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"get_weather","arguments":""}}]},"finish_reason":null}]}

data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\"location\":\"Shanghai\"}"}}]},"finish_reason":null}]}

data: {"choices":[{"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":15,"completion_tokens":10}}

data: [DONE]
`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectQwenFromServer(t, srv)

	starts := filterType(events, EventToolStart)
	if len(starts) != 1 || starts[0].ToolName != "get_weather" {
		t.Errorf("tool starts = %+v", starts)
	}
	deltas := filterType(events, EventToolDelta)
	if len(deltas) != 1 || deltas[0].ArgsDelta != `{"location":"Shanghai"}` {
		t.Errorf("tool deltas = %+v", deltas)
	}
	finishes := filterType(events, EventFinish)
	if len(finishes) != 1 || finishes[0].FinishReason != "tool_calls" {
		t.Errorf("finishes = %+v", finishes)
	}
	if finishes[0].InputTokens != 15 || finishes[0].OutputTokens != 10 {
		t.Errorf("usage: in=%d out=%d, want 15/10", finishes[0].InputTokens, finishes[0].OutputTokens)
	}
}

// TestQwen_DefaultBaseURL verifies the canonical DashScope compatible-mode URL.
//
// 验证 Qwen DefaultBaseURL 为正确的 DashScope compatible-mode URL。
func TestQwen_DefaultBaseURL(t *testing.T) {
	p := newQwenProvider()
	want := "https://dashscope.aliyuncs.com/compatible-mode/v1"
	if got := p.DefaultBaseURL(); got != want {
		t.Errorf("DefaultBaseURL = %q, want %q", got, want)
	}
}
