package llm

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"
)

func TestDoubaoBuildRequest(t *testing.T) {
	p := newDoubaoProvider()
	req := Request{
		ModelID:  "doubao-seed-1-6",
		Key:      "ark-test",
		BaseURL:  "https://ark.cn-beijing.volces.com/api/v3",
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
	if got := httpReq.URL.String(); got != "https://ark.cn-beijing.volces.com/api/v3/chat/completions" {
		t.Errorf("url = %s", got)
	}
	if got := httpReq.Header.Get("Authorization"); got != "Bearer ark-test" {
		t.Errorf("auth = %q", got)
	}
	body, _ := io.ReadAll(httpReq.Body)
	var db doubaoRequest
	if err := json.Unmarshal(body, &db); err != nil {
		t.Fatal(err)
	}
	if db.Model != "doubao-seed-1-6" || !db.Stream {
		t.Errorf("model=%s stream=%v", db.Model, db.Stream)
	}
	if len(db.Tools) != 1 || db.Tools[0].Function.Name != "get_weather" {
		t.Errorf("tools = %+v", db.Tools)
	}
	if len(db.Messages) != 2 || db.Messages[0].Role != "system" || db.Messages[1].Role != "user" {
		t.Errorf("messages = %+v", db.Messages)
	}
	// nil Thinking → auto → no thinking object.
	// nil Thinking → auto → 不发 thinking 对象。
	if db.Thinking != nil {
		t.Errorf("auto (nil) thinking = %+v, want omitted", db.Thinking)
	}
}

func TestDoubaoBuildRequestThinkingModes(t *testing.T) {
	p := newDoubaoProvider()
	base := Request{ModelID: "doubao-seed-1-6", Key: "k", BaseURL: "https://x"}
	thinkingOf := func(req Request) *doubaoThinking {
		httpReq, err := p.BuildRequest(context.Background(), req)
		if err != nil {
			t.Fatal(err)
		}
		body, _ := io.ReadAll(httpReq.Body)
		var db doubaoRequest
		_ = json.Unmarshal(body, &db)
		return db.Thinking
	}

	// auto / nil → omitted.
	// auto / nil → 省略。
	if got := thinkingOf(base); got != nil {
		t.Errorf("auto (nil) → %+v, want omitted", got)
	}

	base.Thinking = &ThinkingSpec{Mode: "auto"}
	if got := thinkingOf(base); got != nil {
		t.Errorf("auto → %+v, want omitted", got)
	}

	// off → {type:disabled}, no budget.
	// off → {type:disabled}，无 budget。
	base.Thinking = &ThinkingSpec{Mode: "off"}
	if got := thinkingOf(base); got == nil || got.Type != "disabled" || got.BudgetTokens != 0 {
		t.Errorf("off → %+v, want {disabled,0}", got)
	}

	// on → {type:enabled}, budget passed through.
	// on → {type:enabled}，budget 透传。
	base.Thinking = &ThinkingSpec{Mode: "on", Budget: 4096}
	if got := thinkingOf(base); got == nil || got.Type != "enabled" || got.BudgetTokens != 4096 {
		t.Errorf("on+budget → %+v, want {enabled,4096}", got)
	}

	// on without budget → {type:enabled}, budget omitted (0).
	// on 无 budget → {type:enabled}，budget 省略（0）。
	base.Thinking = &ThinkingSpec{Mode: "on"}
	if got := thinkingOf(base); got == nil || got.Type != "enabled" || got.BudgetTokens != 0 {
		t.Errorf("on → %+v, want {enabled,0}", got)
	}
}

func TestDoubaoParseStream(t *testing.T) {
	p := newDoubaoProvider()
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
		case EventReasoning:
			reasoning.WriteString(ev.Delta)
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
	if reasoning.String() != "think" {
		t.Errorf("reasoning = %q, want think", reasoning.String())
	}
	if text.String() != "Hello" {
		t.Errorf("text = %q, want Hello", text.String())
	}
	if !sawToolStart || !sawFinish {
		t.Errorf("missing events: toolStart=%v finish=%v", sawToolStart, sawFinish)
	}
}

func TestDoubaoParseNonStreaming(t *testing.T) {
	p := newDoubaoProvider()
	body := `{"choices":[{"message":{"role":"assistant","content":"done"},"finish_reason":"stop"}],"usage":{"prompt_tokens":5,"completion_tokens":1}}`
	resp := &http.Response{Body: io.NopCloser(strings.NewReader(body))}
	events := collect(p.ParseStream(context.Background(), resp, Request{DisableStream: true}))
	if len(events) != 2 || events[0].Type != EventText || events[0].Delta != "done" || events[1].Type != EventFinish {
		t.Errorf("non-streaming events = %+v", events)
	}
}
