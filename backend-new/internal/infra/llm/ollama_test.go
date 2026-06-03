package llm

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"
)

func TestOllamaBuildRequest(t *testing.T) {
	p := newOllamaProvider()
	req := Request{
		ModelID:  "qwen3",
		Key:      "ollama-key",
		BaseURL:  "http://localhost:11434/v1",
		System:   "you are helpful",
		Messages: []LLMMessage{{Role: RoleUser, Content: "hi"}},
		Thinking: &ThinkingSpec{Mode: "on", Effort: "high"},
	}
	httpReq, err := p.BuildRequest(context.Background(), req)
	if err != nil {
		t.Fatal(err)
	}
	if httpReq.Method != http.MethodPost {
		t.Errorf("method = %s, want POST", httpReq.Method)
	}
	if got := httpReq.URL.String(); got != "http://localhost:11434/v1/chat/completions" {
		t.Errorf("url = %s", got)
	}
	if got := httpReq.Header.Get("Authorization"); got != "Bearer ollama-key" {
		t.Errorf("auth = %q", got)
	}
	body, _ := io.ReadAll(httpReq.Body)
	var ol ollamaRequest
	if err := json.Unmarshal(body, &ol); err != nil {
		t.Fatal(err)
	}
	if ol.Model != "qwen3" || !ol.Stream {
		t.Errorf("model=%s stream=%v", ol.Model, ol.Stream)
	}
	if ol.ReasoningEffort != "high" {
		t.Errorf("reasoning_effort = %q, want high", ol.ReasoningEffort)
	}
	if len(ol.Messages) != 2 || ol.Messages[0].Role != "system" || ol.Messages[1].Role != "user" {
		t.Errorf("messages = %+v", ol.Messages)
	}
}

func TestOllamaBuildRequestThinkingModes(t *testing.T) {
	p := newOllamaProvider()
	base := Request{ModelID: "qwen3", Key: "k", BaseURL: "http://x"}
	effortOf := func(req Request) string {
		httpReq, err := p.BuildRequest(context.Background(), req)
		if err != nil {
			t.Fatal(err)
		}
		body, _ := io.ReadAll(httpReq.Body)
		var ol ollamaRequest
		_ = json.Unmarshal(body, &ol)
		return ol.ReasoningEffort
	}
	if got := effortOf(base); got != "" {
		t.Errorf("auto (nil) → %q, want omitted", got)
	}
	base.Thinking = &ThinkingSpec{Mode: "auto"}
	if got := effortOf(base); got != "" {
		t.Errorf("auto → %q, want omitted", got)
	}
	base.Thinking = &ThinkingSpec{Mode: "off"}
	if got := effortOf(base); got != "none" {
		t.Errorf("off → %q, want none", got)
	}
	base.Thinking = &ThinkingSpec{Mode: "on", Effort: "bogus"}
	if got := effortOf(base); got != "medium" {
		t.Errorf("on+bogus → %q, want clamped medium", got)
	}
	base.Thinking = &ThinkingSpec{Mode: "on", Effort: "low"}
	if got := effortOf(base); got != "low" {
		t.Errorf("on+low → %q, want low", got)
	}
}

// TestOllamaBuildRequestToolsForceNonStream verifies the Ollama quirk: any request with
// tools is forced non-streaming (stream:false) because Ollama drops tool_calls when
// streaming.
//
// 验证 Ollama 怪癖：带 tools 的请求强制非流式（stream:false），因为 Ollama streaming 会吞 tool_calls。
func TestOllamaBuildRequestToolsForceNonStream(t *testing.T) {
	p := newOllamaProvider()
	req := Request{
		ModelID:  "qwen3",
		Key:      "k",
		BaseURL:  "http://x",
		Messages: []LLMMessage{{Role: RoleUser, Content: "hi"}},
		Tools:    []ToolDef{{Name: "get_weather", Description: "d", Parameters: json.RawMessage(`{"type":"object"}`)}},
	}
	httpReq, err := p.BuildRequest(context.Background(), req)
	if err != nil {
		t.Fatal(err)
	}
	body, _ := io.ReadAll(httpReq.Body)
	var ol ollamaRequest
	if err := json.Unmarshal(body, &ol); err != nil {
		t.Fatal(err)
	}
	if ol.Stream {
		t.Errorf("stream = true, want false when tools present")
	}
	if ol.StreamOptions != nil {
		t.Errorf("stream_options = %+v, want nil when non-streaming", ol.StreamOptions)
	}
	if len(ol.Tools) != 1 || ol.Tools[0].Function.Name != "get_weather" {
		t.Errorf("tools = %+v", ol.Tools)
	}
}

func TestOllamaParseStream(t *testing.T) {
	p := newOllamaProvider()
	resp := &http.Response{Body: sseBody(
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

// TestOllamaParseNonStreaming feeds a single non-streaming JSON response (the path taken
// when tools are present) and verifies reasoning/text/tool_start/finish synthesis. Ollama's
// non-streaming message carries thinking in "reasoning" (no underscore).
//
// 喂单条非流式 JSON 响应（有 tools 时走此路径），验 reasoning/text/tool_start/finish 合成。
// Ollama 非流式 message 用 "reasoning"（无下划线）传思考。
func TestOllamaParseNonStreaming(t *testing.T) {
	p := newOllamaProvider()
	body := `{"choices":[{"message":{"role":"assistant","reasoning":"hmm","content":"done","tool_calls":[{"id":"call_1","function":{"name":"f","arguments":"{\"q\":1}"}}]},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":5,"completion_tokens":1}}`
	resp := &http.Response{Body: io.NopCloser(strings.NewReader(body))}
	events := collect(p.ParseStream(context.Background(), resp, Request{DisableStream: true}))

	var text, reasoning strings.Builder
	var sawToolStart, sawToolDelta, sawFinish bool
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
		case EventToolDelta:
			sawToolDelta = true
			if ev.ArgsDelta != `{"q":1}` {
				t.Errorf("tool_delta args = %q", ev.ArgsDelta)
			}
		case EventFinish:
			sawFinish = true
			if ev.FinishReason != "tool_calls" || ev.InputTokens != 5 || ev.OutputTokens != 1 {
				t.Errorf("finish = %+v", ev)
			}
		case EventError:
			t.Fatalf("unexpected error event: %v", ev.Err)
		}
	}
	if reasoning.String() != "hmm" {
		t.Errorf("reasoning = %q, want hmm", reasoning.String())
	}
	if text.String() != "done" {
		t.Errorf("text = %q, want done", text.String())
	}
	if !sawToolStart || !sawToolDelta || !sawFinish {
		t.Errorf("missing events: toolStart=%v toolDelta=%v finish=%v", sawToolStart, sawToolDelta, sawFinish)
	}
}
