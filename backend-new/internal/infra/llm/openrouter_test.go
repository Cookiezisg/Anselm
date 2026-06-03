package llm

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"testing"
)

func TestOpenRouterBuildRequest(t *testing.T) {
	p := newOpenRouterProvider()
	req := Request{
		ModelID:  "anthropic/claude-3.5-sonnet",
		Key:      "sk-or-test",
		BaseURL:  "https://openrouter.ai/api/v1",
		System:   "you are helpful",
		Messages: []LLMMessage{{Role: RoleUser, Content: "hi"}},
		Tools:    []ToolDef{{Name: "get_weather", Description: "d", Parameters: json.RawMessage(`{"type":"object"}`)}},
		Thinking: &ThinkingSpec{Mode: "on", Effort: "high"},
	}
	httpReq, err := p.BuildRequest(context.Background(), req)
	if err != nil {
		t.Fatal(err)
	}
	if httpReq.Method != http.MethodPost {
		t.Errorf("method = %s, want POST", httpReq.Method)
	}
	if got := httpReq.URL.String(); got != "https://openrouter.ai/api/v1/chat/completions" {
		t.Errorf("url = %s", got)
	}
	if got := httpReq.Header.Get("Authorization"); got != "Bearer sk-or-test" {
		t.Errorf("auth = %q", got)
	}
	body, _ := io.ReadAll(httpReq.Body)
	var or orRequest
	if err := json.Unmarshal(body, &or); err != nil {
		t.Fatal(err)
	}
	if or.Model != "anthropic/claude-3.5-sonnet" || !or.Stream {
		t.Errorf("model=%s stream=%v", or.Model, or.Stream)
	}
	if or.Reasoning == nil || or.Reasoning.Effort != "high" || or.Reasoning.MaxTokens != 0 {
		t.Errorf("reasoning = %+v, want {effort:high}", or.Reasoning)
	}
	if len(or.Tools) != 1 || or.Tools[0].Function.Name != "get_weather" {
		t.Errorf("tools = %+v", or.Tools)
	}
	if len(or.Messages) != 2 || or.Messages[0].Role != "system" || or.Messages[1].Role != "user" {
		t.Errorf("messages = %+v", or.Messages)
	}
}

func TestOpenRouterBuildRequestThinkingModes(t *testing.T) {
	p := newOpenRouterProvider()
	base := Request{ModelID: "m", Key: "k", BaseURL: "https://x"}
	reasoningOf := func(req Request) *orReasoningField {
		httpReq, err := p.BuildRequest(context.Background(), req)
		if err != nil {
			t.Fatal(err)
		}
		body, _ := io.ReadAll(httpReq.Body)
		var or orRequest
		_ = json.Unmarshal(body, &or)
		return or.Reasoning
	}

	// auto (nil) → no reasoning field at all.
	// auto（nil）→完全不发 reasoning 字段。
	if got := reasoningOf(base); got != nil {
		t.Errorf("auto (nil) → %+v, want omitted", got)
	}

	// off → still omitted (OpenRouter has no clean disable form).
	// off → 同样省略（OpenRouter 无干净关闭形式）。
	base.Thinking = &ThinkingSpec{Mode: "off"}
	if got := reasoningOf(base); got != nil {
		t.Errorf("off → %+v, want omitted", got)
	}

	// on + Effort → reasoning:{effort}.
	// on + Effort → reasoning:{effort}。
	base.Thinking = &ThinkingSpec{Mode: "on", Effort: "low"}
	if got := reasoningOf(base); got == nil || got.Effort != "low" || got.MaxTokens != 0 {
		t.Errorf("on+effort → %+v, want {effort:low}", got)
	}

	// on + Budget (no Effort) → reasoning:{max_tokens}.
	// on + Budget（无 Effort）→ reasoning:{max_tokens}。
	base.Thinking = &ThinkingSpec{Mode: "on", Budget: 2048}
	if got := reasoningOf(base); got == nil || got.MaxTokens != 2048 || got.Effort != "" {
		t.Errorf("on+budget → %+v, want {max_tokens:2048}", got)
	}

	// on + neither → default reasoning:{effort:medium}.
	// on 无参 → 默认 reasoning:{effort:medium}。
	base.Thinking = &ThinkingSpec{Mode: "on"}
	if got := reasoningOf(base); got == nil || got.Effort != "medium" {
		t.Errorf("on+neither → %+v, want {effort:medium}", got)
	}
}

func TestOpenRouterParseStream(t *testing.T) {
	p := newOpenRouterProvider()
	resp := &http.Response{Body: sseBody(
		`: OPENROUTER PROCESSING`,
		`data: {"choices":[{"delta":{"reasoning":"think"}}]}`,
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

// TestOpenRouterParseStreamReasoningContentAlias verifies the CN-family alias
// (reasoning_content) is read when the primary reasoning field is absent.
//
// 验证主 reasoning 字段缺失时，读取 CN 家族别名 reasoning_content。
func TestOpenRouterParseStreamReasoningContentAlias(t *testing.T) {
	p := newOpenRouterProvider()
	resp := &http.Response{Body: sseBody(
		`data: {"choices":[{"delta":{"reasoning_content":"deep"}}]}`,
		`data: [DONE]`,
	)}
	events := collect(p.ParseStream(context.Background(), resp, Request{}))
	var reasoning strings.Builder
	for _, ev := range events {
		if ev.Type == EventReasoning {
			reasoning.WriteString(ev.Delta)
		}
	}
	if reasoning.String() != "deep" {
		t.Errorf("reasoning = %q, want deep", reasoning.String())
	}
}

// TestOpenRouterParseStreamInStreamError verifies a mid-stream error object surfaces as a
// terminal EventError wrapping ErrProviderError — OpenRouter's quirk of reporting upstream
// failures after a 200.
//
// 验证流中 error 对象冒泡为终态 EventError 并包 ErrProviderError——OpenRouter 在 200 后报
// 上游失败的怪癖。
func TestOpenRouterParseStreamInStreamError(t *testing.T) {
	p := newOpenRouterProvider()
	resp := &http.Response{Body: sseBody(
		`data: {"choices":[{"delta":{"content":"partial"}}]}`,
		`data: {"error":{"message":"upstream exploded"}}`,
		`data: [DONE]`,
	)}
	events := collect(p.ParseStream(context.Background(), resp, Request{}))

	var sawErr bool
	for _, ev := range events {
		if ev.Type == EventError {
			sawErr = true
			if !errors.Is(ev.Err, ErrProviderError) {
				t.Errorf("err = %v, want wraps ErrProviderError", ev.Err)
			}
			if !strings.Contains(ev.Err.Error(), "upstream exploded") {
				t.Errorf("err = %v, want contains upstream message", ev.Err)
			}
		}
	}
	if !sawErr {
		t.Error("expected in-stream EventError, got none")
	}
}
