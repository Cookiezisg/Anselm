package llm

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"
)

func anthropicBody(t *testing.T, req Request) anthropicRequest {
	t.Helper()
	httpReq, err := newAnthropicProvider().BuildRequest(context.Background(), req)
	if err != nil {
		t.Fatal(err)
	}
	raw, _ := io.ReadAll(httpReq.Body)
	var ar anthropicRequest
	if err := json.Unmarshal(raw, &ar); err != nil {
		t.Fatal(err)
	}
	return ar
}

func TestAnthropicBuildRequest(t *testing.T) {
	p := newAnthropicProvider()
	req := Request{
		ModelID:   "claude-sonnet-4",
		Key:       "sk-ant",
		BaseURL:   "https://api.anthropic.com",
		MaxTokens: 4096,
		System:    "be brief",
		Messages:  []LLMMessage{{Role: RoleUser, Content: "hi"}},
		Tools:     []ToolDef{{Name: "t", Description: "d", Parameters: json.RawMessage(`{"type":"object"}`)}},
	}
	httpReq, err := p.BuildRequest(context.Background(), req)
	if err != nil {
		t.Fatal(err)
	}
	if httpReq.URL.String() != "https://api.anthropic.com/v1/messages" {
		t.Errorf("url = %s", httpReq.URL.String())
	}
	if httpReq.Header.Get("x-api-key") != "sk-ant" {
		t.Errorf("x-api-key = %q", httpReq.Header.Get("x-api-key"))
	}
	if httpReq.Header.Get("anthropic-version") != anthropicVersion {
		t.Errorf("anthropic-version = %q", httpReq.Header.Get("anthropic-version"))
	}
	raw, _ := io.ReadAll(httpReq.Body)
	var ar anthropicRequest
	if err := json.Unmarshal(raw, &ar); err != nil {
		t.Fatal(err)
	}
	if ar.Model != "claude-sonnet-4" || ar.MaxTokens != 4096 || !ar.Stream {
		t.Errorf("body = %+v", ar)
	}
	if len(ar.Messages) != 1 || ar.Messages[0].Role != "user" {
		t.Errorf("messages = %+v", ar.Messages)
	}
	if len(ar.Tools) != 1 || ar.Tools[0].CacheControl == nil {
		t.Errorf("tools should have a cache breakpoint on the last entry: %+v", ar.Tools)
	}
	// system must be a block array carrying cache_control
	var sysBlocks []anthropicSystemBlock
	if err := json.Unmarshal(ar.System, &sysBlocks); err != nil {
		t.Fatalf("system not a block array: %v", err)
	}
	if len(sysBlocks) != 1 || sysBlocks[0].Text != "be brief" || sysBlocks[0].CacheControl == nil {
		t.Errorf("system block = %+v", sysBlocks)
	}
}

func TestAnthropicMaxTokensDefault(t *testing.T) {
	ar := anthropicBody(t, Request{ModelID: "m", Messages: []LLMMessage{{Role: RoleUser, Content: "x"}}})
	if ar.MaxTokens != anthropicDefaultMaxTokens {
		t.Errorf("MaxTokens = %d, want default %d", ar.MaxTokens, anthropicDefaultMaxTokens)
	}
}

func TestAnthropicThinkingModes(t *testing.T) {
	base := Request{ModelID: "m", MaxTokens: 8000, Messages: []LLMMessage{{Role: RoleUser, Content: "x"}}}

	base.Thinking = nil
	if ar := anthropicBody(t, base); ar.Thinking != nil {
		t.Errorf("auto → thinking should be omitted, got %+v", ar.Thinking)
	}
	base.Thinking = &ThinkingSpec{Mode: "off"}
	if ar := anthropicBody(t, base); ar.Thinking == nil || ar.Thinking.Type != "disabled" {
		t.Errorf("off → %+v, want disabled", ar.Thinking)
	}
	base.Thinking = &ThinkingSpec{Mode: "on", Budget: 2000}
	if ar := anthropicBody(t, base); ar.Thinking == nil || ar.Thinking.Type != "enabled" || ar.Thinking.BudgetTokens != 2000 {
		t.Errorf("on → %+v, want enabled budget 2000", ar.Thinking)
	}
}

func TestAnthropicThinkingBudgetBumpsMaxTokens(t *testing.T) {
	// budget >= max_tokens must bump max_tokens above budget (Anthropic 400s otherwise).
	ar := anthropicBody(t, Request{
		ModelID:   "m",
		MaxTokens: 1500,
		Messages:  []LLMMessage{{Role: RoleUser, Content: "x"}},
		Thinking:  &ThinkingSpec{Mode: "on", Budget: 4000},
	})
	if ar.Thinking.BudgetTokens != 4000 || ar.MaxTokens <= 4000 {
		t.Errorf("budget=%d max_tokens=%d; max_tokens must exceed budget", ar.Thinking.BudgetTokens, ar.MaxTokens)
	}
}

func TestAnthropicParseStream(t *testing.T) {
	sse := strings.Join([]string{
		"event: message_start",
		`data: {"message":{"usage":{"input_tokens":10}}}`,
		"event: content_block_start",
		`data: {"index":0,"content_block":{"type":"tool_use","id":"tu_1","name":"f"}}`,
		"event: content_block_delta",
		`data: {"index":1,"delta":{"type":"text_delta","text":"hi"}}`,
		"event: content_block_delta",
		`data: {"index":2,"delta":{"type":"thinking_delta","thinking":"hmm"}}`,
		"event: content_block_delta",
		`data: {"index":2,"delta":{"type":"signature_delta","signature":"sig123"}}`,
		"event: content_block_delta",
		`data: {"index":0,"delta":{"type":"input_json_delta","partial_json":"{}"}}`,
		"event: message_delta",
		`data: {"delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":5}}`,
	}, "\n") + "\n"

	resp := &http.Response{Body: io.NopCloser(strings.NewReader(sse))}
	events := collect(newAnthropicProvider().ParseStream(context.Background(), resp, Request{}))

	var text, reasoning, sig string
	var sawToolStart, sawFinish bool
	for _, ev := range events {
		switch ev.Type {
		case EventText:
			text += ev.Delta
		case EventReasoning:
			reasoning += ev.Delta
			if ev.Signature != "" {
				sig = ev.Signature
			}
		case EventToolStart:
			sawToolStart = true
			if ev.ToolID != "tu_1" || ev.ToolName != "f" {
				t.Errorf("tool_start = %+v", ev)
			}
		case EventFinish:
			sawFinish = true
			if ev.FinishReason != "end_turn" || ev.InputTokens != 10 || ev.OutputTokens != 5 {
				t.Errorf("finish = %+v", ev)
			}
		case EventError:
			t.Fatalf("unexpected error: %v", ev.Err)
		}
	}
	if text != "hi" || reasoning != "hmm" || sig != "sig123" {
		t.Errorf("text=%q reasoning=%q sig=%q", text, reasoning, sig)
	}
	if !sawToolStart || !sawFinish {
		t.Errorf("missing events: toolStart=%v finish=%v", sawToolStart, sawFinish)
	}
}
