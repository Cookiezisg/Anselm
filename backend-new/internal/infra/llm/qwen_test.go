package llm

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"
)

func TestQwenBuildRequest(t *testing.T) {
	p := newQwenProvider()
	req := Request{
		ModelID:  "qwen3-max",
		Key:      "sk-qwen",
		BaseURL:  "https://dashscope.aliyuncs.com/compatible-mode/v1",
		System:   "you are helpful",
		Messages: []LLMMessage{{Role: RoleUser, Content: "hi"}},
		Tools:    []ToolDef{{Name: "get_weather", Description: "d", Parameters: json.RawMessage(`{"type":"object"}`)}},
	}
	httpReq, err := p.BuildRequest(context.Background(), req)
	if err != nil {
		t.Fatal(err)
	}
	if httpReq.Method != http.MethodPost {
		t.Errorf("method = %s, want POST", httpReq.Method)
	}
	if got := httpReq.URL.String(); got != "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions" {
		t.Errorf("url = %s", got)
	}
	if got := httpReq.Header.Get("Authorization"); got != "Bearer sk-qwen" {
		t.Errorf("auth = %q", got)
	}
	body, _ := io.ReadAll(httpReq.Body)
	var qr qwenRequest
	if err := json.Unmarshal(body, &qr); err != nil {
		t.Fatal(err)
	}
	if qr.Model != "qwen3-max" || !qr.Stream {
		t.Errorf("model=%s stream=%v", qr.Model, qr.Stream)
	}
	if len(qr.Tools) != 1 || qr.Tools[0].Function.Name != "get_weather" {
		t.Errorf("tools = %+v", qr.Tools)
	}
	if len(qr.Messages) != 2 || qr.Messages[0].Role != "system" || qr.Messages[1].Role != "user" {
		t.Errorf("messages = %+v", qr.Messages)
	}
}

func TestQwenBuildRequestThinkingModes(t *testing.T) {
	p := newQwenProvider()
	thinkingOf := func(req Request) qwenRequest {
		httpReq, err := p.BuildRequest(context.Background(), req)
		if err != nil {
			t.Fatal(err)
		}
		body, _ := io.ReadAll(httpReq.Body)
		var qr qwenRequest
		_ = json.Unmarshal(body, &qr)
		return qr
	}

	// auto (nil) → enable_thinking omitted entirely.
	// auto（nil）→ 完全省略 enable_thinking。
	if qr := thinkingOf(Request{ModelID: "qwen3-max", Key: "k", BaseURL: "https://x"}); qr.EnableThinking != nil {
		t.Errorf("auto → enable_thinking = %v, want nil", *qr.EnableThinking)
	}

	// off → enable_thinking=false, no budget.
	// off → enable_thinking=false，无 budget。
	qr := thinkingOf(Request{ModelID: "qwen3-max", Key: "k", BaseURL: "https://x", Thinking: &ThinkingSpec{Mode: "off"}})
	if qr.EnableThinking == nil || *qr.EnableThinking {
		t.Errorf("off → enable_thinking = %v, want false", qr.EnableThinking)
	}
	if qr.ThinkingBudget != 0 {
		t.Errorf("off → thinking_budget = %d, want 0", qr.ThinkingBudget)
	}

	// on + budget → enable_thinking=true + thinking_budget.
	// on + budget → enable_thinking=true + thinking_budget。
	qr = thinkingOf(Request{ModelID: "qwen3-max", Key: "k", BaseURL: "https://x", Thinking: &ThinkingSpec{Mode: "on", Budget: 4096}})
	if qr.EnableThinking == nil || !*qr.EnableThinking {
		t.Errorf("on → enable_thinking = %v, want true", qr.EnableThinking)
	}
	if qr.ThinkingBudget != 4096 {
		t.Errorf("on → thinking_budget = %d, want 4096", qr.ThinkingBudget)
	}

	// on without budget → enable_thinking=true, budget omitted.
	// on 无 budget → enable_thinking=true，省略 budget。
	qr = thinkingOf(Request{ModelID: "qwen3-max", Key: "k", BaseURL: "https://x", Thinking: &ThinkingSpec{Mode: "on"}})
	if qr.EnableThinking == nil || !*qr.EnableThinking {
		t.Errorf("on/no-budget → enable_thinking = %v, want true", qr.EnableThinking)
	}
	if qr.ThinkingBudget != 0 {
		t.Errorf("on/no-budget → thinking_budget = %d, want 0", qr.ThinkingBudget)
	}
}

// TestQwenBuildRequestStreamGuard verifies enable_thinking=true is suppressed on a
// non-streaming request — Qwen 400s on the conflicting parameter.
//
// TestQwenBuildRequestStreamGuard 验非流式请求时 enable_thinking=true 被抑制——Qwen
// 会因冲突参数返 400。
func TestQwenBuildRequestStreamGuard(t *testing.T) {
	p := newQwenProvider()
	req := Request{
		ModelID:       "qwen3-max",
		Key:           "k",
		BaseURL:       "https://x",
		DisableStream: true,
		Thinking:      &ThinkingSpec{Mode: "on", Budget: 4096},
	}
	httpReq, err := p.BuildRequest(context.Background(), req)
	if err != nil {
		t.Fatal(err)
	}
	body, _ := io.ReadAll(httpReq.Body)
	var qr qwenRequest
	_ = json.Unmarshal(body, &qr)
	if qr.Stream {
		t.Errorf("stream = true, want false on DisableStream")
	}
	if qr.EnableThinking != nil {
		t.Errorf("on + DisableStream → enable_thinking = %v, want omitted (stream guard)", *qr.EnableThinking)
	}
	if qr.ThinkingBudget != 0 {
		t.Errorf("on + DisableStream → thinking_budget = %d, want 0", qr.ThinkingBudget)
	}
}

func TestQwenParseStream(t *testing.T) {
	p := newQwenProvider()
	resp := &http.Response{Body: sseBody(
		`data: {"choices":[{"delta":{"reasoning_content":"think"}}]}`,
		`data: {"choices":[{"delta":{"content":"Hel"}}]}`,
		`data: {"choices":[{"delta":{"content":"lo"}}]}`,
		`data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"f","arguments":"{}"}}]}}]}`,
		`data: {"choices":[{"finish_reason":"stop"}],"usage":{"prompt_tokens":3,"completion_tokens":2}}`,
		`data: [DONE]`,
	)}
	events := collect(p.ParseStream(context.Background(), resp, Request{}))

	var text, reasoning strings.Builder
	var sawToolStart, sawFinish bool
	for _, ev := range events {
		switch ev.Type {
		case EventText:
			text.WriteString(ev.Delta)
		case EventReasoning:
			reasoning.WriteString(ev.Delta)
		case EventToolStart:
			sawToolStart = true
			if ev.ToolName != "f" || ev.ToolID != "call_1" {
				t.Errorf("tool_start = %+v", ev)
			}
		case EventFinish:
			sawFinish = true
			if ev.FinishReason != "stop" || ev.InputTokens != 3 || ev.OutputTokens != 2 {
				t.Errorf("finish = %+v", ev)
			}
		case EventError:
			t.Fatalf("unexpected error event: %v", ev.Err)
		}
	}
	if text.String() != "Hello" {
		t.Errorf("text = %q, want Hello", text.String())
	}
	if reasoning.String() != "think" {
		t.Errorf("reasoning = %q, want think", reasoning.String())
	}
	if !sawToolStart || !sawFinish {
		t.Errorf("missing events: toolStart=%v finish=%v", sawToolStart, sawFinish)
	}
}

// TestQwenParseStreamFlatError verifies the DashScope flat error envelope
// {code,message,request_id} arriving as a 200 chunk (no nested "error") surfaces as a
// provider EventError rather than being silently dropped.
//
// TestQwenParseStreamFlatError 验 DashScope 扁平错误信封 {code,message,request_id} 以
// 200 chunk 返回（无嵌套 "error"）时 emit provider EventError，而非静默丢弃。
func TestQwenParseStreamFlatError(t *testing.T) {
	p := newQwenProvider()
	resp := &http.Response{Body: sseBody(
		`data: {"code":"InvalidParameter","message":"enable_thinking must be set to false for non-streaming calls","request_id":"req-1"}`,
	)}
	events := collect(p.ParseStream(context.Background(), resp, Request{}))
	if len(events) != 1 {
		t.Fatalf("events = %+v, want exactly 1 error", events)
	}
	ev := events[0]
	if ev.Type != EventError {
		t.Fatalf("type = %s, want error", ev.Type)
	}
	if ev.Err == nil || !strings.Contains(ev.Err.Error(), "InvalidParameter") {
		t.Errorf("err = %v, want flat code surfaced", ev.Err)
	}
}
