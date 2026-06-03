package llm

import (
	"context"
	"encoding/json"
	"io"
	"iter"
	"net/http"
	"strings"
	"testing"
)

// collect drains a StreamEvent iterator into a slice.
//
// collect 把 StreamEvent 迭代器抽干成 slice。
func collect(seq iter.Seq[StreamEvent]) []StreamEvent {
	var out []StreamEvent
	for ev := range seq {
		out = append(out, ev)
	}
	return out
}

func sseBody(lines ...string) io.ReadCloser {
	return io.NopCloser(strings.NewReader(strings.Join(lines, "\n\n") + "\n\n"))
}

func TestOpenAIBuildRequest(t *testing.T) {
	p := newOpenAIProvider()
	req := Request{
		ModelID:  "gpt-4o",
		Key:      "sk-test",
		BaseURL:  "https://api.openai.com/v1",
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
	if got := httpReq.URL.String(); got != "https://api.openai.com/v1/chat/completions" {
		t.Errorf("url = %s", got)
	}
	if got := httpReq.Header.Get("Authorization"); got != "Bearer sk-test" {
		t.Errorf("auth = %q", got)
	}
	body, _ := io.ReadAll(httpReq.Body)
	var oa oaiRequest
	if err := json.Unmarshal(body, &oa); err != nil {
		t.Fatal(err)
	}
	if oa.Model != "gpt-4o" || !oa.Stream {
		t.Errorf("model=%s stream=%v", oa.Model, oa.Stream)
	}
	if oa.ReasoningEffort != "high" {
		t.Errorf("reasoning_effort = %q, want high", oa.ReasoningEffort)
	}
	if len(oa.Tools) != 1 || oa.Tools[0].Function.Name != "get_weather" {
		t.Errorf("tools = %+v", oa.Tools)
	}
	if len(oa.Messages) != 2 || oa.Messages[0].Role != "system" || oa.Messages[1].Role != "user" {
		t.Errorf("messages = %+v", oa.Messages)
	}
}

func TestOpenAIBuildRequestThinkingModes(t *testing.T) {
	p := newOpenAIProvider()
	base := Request{ModelID: "o3", Key: "k", BaseURL: "https://x"}
	effortOf := func(req Request) string {
		httpReq, err := p.BuildRequest(context.Background(), req)
		if err != nil {
			t.Fatal(err)
		}
		body, _ := io.ReadAll(httpReq.Body)
		var oa oaiRequest
		_ = json.Unmarshal(body, &oa)
		return oa.ReasoningEffort
	}
	if got := effortOf(base); got != "" {
		t.Errorf("auto (nil) → %q, want omitted", got)
	}
	base.Thinking = &ThinkingSpec{Mode: "off"}
	if got := effortOf(base); got != "none" {
		t.Errorf("off → %q, want none", got)
	}
	base.Thinking = &ThinkingSpec{Mode: "on", Effort: "bogus"}
	if got := effortOf(base); got != "medium" {
		t.Errorf("on+bogus → %q, want clamped medium", got)
	}
}

func TestOpenAIParseStream(t *testing.T) {
	p := newOpenAIProvider()
	resp := &http.Response{Body: sseBody(
		`data: {"choices":[{"delta":{"content":"Hel"}}]}`,
		`data: {"choices":[{"delta":{"content":"lo"}}]}`,
		`data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"f","arguments":"{}"}}]}}]}`,
		`data: {"choices":[{"finish_reason":"stop"}],"usage":{"prompt_tokens":3,"completion_tokens":2}}`,
		`data: [DONE]`,
	)}
	events := collect(p.ParseStream(context.Background(), resp, Request{}))

	var text strings.Builder
	var sawToolStart, sawFinish bool
	for _, ev := range events {
		switch ev.Type {
		case EventText:
			text.WriteString(ev.Delta)
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
	if !sawToolStart || !sawFinish {
		t.Errorf("missing events: toolStart=%v finish=%v", sawToolStart, sawFinish)
	}
}

func TestOpenAIParseNonStreaming(t *testing.T) {
	p := newOpenAIProvider()
	body := `{"choices":[{"message":{"role":"assistant","content":"done"},"finish_reason":"stop"}],"usage":{"prompt_tokens":5,"completion_tokens":1}}`
	resp := &http.Response{Body: io.NopCloser(strings.NewReader(body))}
	events := collect(p.ParseStream(context.Background(), resp, Request{DisableStream: true}))
	if len(events) != 2 || events[0].Type != EventText || events[0].Delta != "done" || events[1].Type != EventFinish {
		t.Errorf("non-streaming events = %+v", events)
	}
}
