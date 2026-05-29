package llm

// gemini_test.go — L1 base-URL regression guard + L2 ParseStream tests for
// the Gemini OpenAI-compat provider.
//
// Gemini uses the OpenAI-compat surface (works for chat+tools). Native
// generateContent (for reasoning-text readback + thoughtSignature) is a
// documented future enhancement, not in this round — the compat path is
// bug-free for config+chat+tools.

import (
	"context"
	"encoding/json"
	"testing"
)

// ──────────────────────────────────────────────────────────────────────────────
// L1: DefaultBaseURL regression guard (P1 fix pin)
// ──────────────────────────────────────────────────────────────────────────────

// TestGemini_DefaultBaseURL_EndsWithV1BetaOpenAI is the regression guard for
// the P1 base-URL fix: Gemini's DefaultBaseURL must end with /v1beta/openai
// (the compat surface). Without this, requests route to the wrong path and 404.
// 03-implementation-reference §5: "🔴 Forgify 现存的 base 缺 /v1beta/openai → 404".
//
// 回归守卫：Gemini DefaultBaseURL 必须以 /v1beta/openai 结尾（compat 表面）。
// 没有这个 P1 修复请求会 404。
func TestGemini_DefaultBaseURL_EndsWithV1BetaOpenAI(t *testing.T) {
	p, ok := providerRegistry["google"]
	if !ok {
		t.Fatal("google provider not in registry")
	}
	got := p.DefaultBaseURL()
	want := "https://generativelanguage.googleapis.com/v1beta/openai"
	if got != want {
		t.Errorf("Gemini DefaultBaseURL = %q, want %q (P1 fix regression)", got, want)
	}
	// Must end with /v1beta/openai — the bare /v1beta or /v1beta/openai/ (trailing slash) would also 404.
	// 必须以 /v1beta/openai 结尾——多余斜杠或少段都会 404。
	const suffix = "/v1beta/openai"
	if len(got) < len(suffix) || got[len(got)-len(suffix):] != suffix {
		t.Errorf("DefaultBaseURL %q must end with %q", got, suffix)
	}
}

// TestGemini_ChatURL_IsBaseSlashChatCompletions asserts that the Gemini compat
// provider's chat URL is exactly base+/chat/completions, matching the P1 fix.
// Any regression here means Gemini calls 404 at the network layer.
//
// 断言 Gemini compat chat URL = base + /chat/completions，这是 P1 修复的锚点。
func TestGemini_ChatURL_IsBaseSlashChatCompletions(t *testing.T) {
	p, ok := providerRegistry["google"]
	if !ok {
		t.Fatal("google provider not in registry")
	}
	cp, ok := p.(*openAICompatProvider)
	if !ok {
		t.Fatalf("google provider is not openAICompatProvider: %T", p)
	}

	base := "https://generativelanguage.googleapis.com/v1beta/openai"
	req := Request{
		ModelID: "gemini-2.5-flash",
		BaseURL: base,
		Key:     "aistudio-test-key",
		Messages: []LLMMessage{
			{Role: RoleUser, Content: "List 3 physicists"},
		},
	}
	httpReq, err := cp.BuildRequest(context.Background(), req)
	if err != nil {
		t.Fatalf("BuildRequest: %v", err)
	}
	wantURL := base + "/chat/completions"
	if httpReq.URL.String() != wantURL {
		t.Errorf("chat URL = %q, want %q (P1 fix regression guard)", httpReq.URL.String(), wantURL)
	}
}

// ──────────────────────────────────────────────────────────────────────────────
// L2: ParseStream — standard OpenAI-compat SSE through Gemini provider
// ──────────────────────────────────────────────────────────────────────────────

// TestParseStream_Gemini_ContentAndToolCall feeds a standard OpenAI-compat SSE
// fixture through the Gemini (google) compat provider and asserts:
//   - content deltas → EventText
//   - tool-call deltas → EventToolStart + EventToolDelta with assembled args
//   - finish + usage → EventFinish
//
// Gemini's compat surface does NOT return reasoning text (write-only per 03 §5),
// so no reasoning-delta assertion is made here. Native generateContent would be
// needed for reasoning-text readback — that is a documented future enhancement.
//
// 通过 Gemini compat provider 跑标准 OpenAI-compat SSE fixture；
// 验证 content/tool-call/finish 正确解析。
// Gemini compat 不返回 reasoning 文本（03 §5 write-only），无 reasoning 断言。
func TestParseStream_Gemini_ContentAndToolCall(t *testing.T) {
	fixture := `data: {"choices":[{"delta":{"content":"Here are 3 physicists: "},"finish_reason":null}]}

data: {"choices":[{"delta":{"content":"Einstein, Bohr, Feynman."},"finish_reason":null}]}

data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_gem_1","function":{"name":"lookup_physicist","arguments":""}}]},"finish_reason":null}]}

data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\"name\":"}}]},"finish_reason":null}]}

data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\"Einstein\"}"}}]},"finish_reason":null}]}

data: {"choices":[{"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":30,"completion_tokens":15}}

data: [DONE]
`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectFromServer(t, srv)

	// content deltas → EventText.
	texts := filterType(events, EventText)
	if len(texts) != 2 {
		t.Fatalf("want 2 EventText, got %d", len(texts))
	}
	if texts[0].Delta != "Here are 3 physicists: " {
		t.Errorf("text[0] = %q", texts[0].Delta)
	}
	if texts[1].Delta != "Einstein, Bohr, Feynman." {
		t.Errorf("text[1] = %q", texts[1].Delta)
	}

	// tool-call deltas → EventToolStart + EventToolDelta.
	starts := filterType(events, EventToolStart)
	if len(starts) != 1 {
		t.Fatalf("want 1 EventToolStart, got %d", len(starts))
	}
	if starts[0].ToolName != "lookup_physicist" {
		t.Errorf("tool name = %q, want lookup_physicist", starts[0].ToolName)
	}
	if starts[0].ToolID != "call_gem_1" {
		t.Errorf("tool id = %q, want call_gem_1", starts[0].ToolID)
	}

	deltas := filterType(events, EventToolDelta)
	if len(deltas) != 2 {
		t.Fatalf("want 2 EventToolDelta, got %d", len(deltas))
	}
	assembled := deltas[0].ArgsDelta + deltas[1].ArgsDelta
	var args map[string]any
	if err := json.Unmarshal([]byte(assembled), &args); err != nil {
		t.Errorf("assembled tool args not valid JSON: %q err: %v", assembled, err)
	}
	if args["name"] != "Einstein" {
		t.Errorf("args.name = %v, want Einstein", args["name"])
	}

	// finish + usage → EventFinish.
	finishes := filterType(events, EventFinish)
	if len(finishes) != 1 {
		t.Fatalf("want 1 EventFinish, got %d", len(finishes))
	}
	if finishes[0].FinishReason != "tool_calls" {
		t.Errorf("finish_reason = %q, want tool_calls", finishes[0].FinishReason)
	}
	if finishes[0].InputTokens != 30 || finishes[0].OutputTokens != 15 {
		t.Errorf("usage: in=%d out=%d, want in=30 out=15",
			finishes[0].InputTokens, finishes[0].OutputTokens)
	}

	// No error events.
	errEvents := filterType(events, EventError)
	if len(errEvents) != 0 {
		t.Errorf("unexpected error events: %+v", errEvents)
	}
}

// TestParseStream_Gemini_TextOnly verifies the simplest compat path:
// content-only response with stop finish.
//
// 验证最简 compat 路径：纯 content 响应。
func TestParseStream_Gemini_TextOnly(t *testing.T) {
	fixture := `data: {"choices":[{"delta":{"content":"Newton, Maxwell, Dirac"},"finish_reason":null}]}

data: {"choices":[{"delta":{},"finish_reason":"stop"}],"usage":{"prompt_tokens":12,"completion_tokens":6}}

data: [DONE]
`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectFromServer(t, srv)

	texts := filterType(events, EventText)
	if len(texts) != 1 || texts[0].Delta != "Newton, Maxwell, Dirac" {
		t.Errorf("text events = %+v", texts)
	}
	finishes := filterType(events, EventFinish)
	if len(finishes) != 1 || finishes[0].FinishReason != "stop" {
		t.Errorf("finish events = %+v", finishes)
	}
	if finishes[0].InputTokens != 12 || finishes[0].OutputTokens != 6 {
		t.Errorf("usage: in=%d out=%d, want in=12 out=6",
			finishes[0].InputTokens, finishes[0].OutputTokens)
	}
}

// TestParseStream_Gemini_NoReasoningText documents that the Gemini compat
// surface does NOT emit reasoning text. A fixture with reasoning_content is
// technically possible from other compat providers but NOT expected from
// Gemini's compat surface per 03 §5 ("不返回 reasoning，write-only").
// This test confirms the parser handles such a chunk gracefully (it would
// emit EventReasoning if present — but Gemini won't send it on compat).
//
// 记录 Gemini compat 不返回 reasoning 文本（03 §5 write-only）。
// 这是未来切 native generateContent 的文档依据。
func TestParseStream_Gemini_NoReasoningText(t *testing.T) {
	// A plain content-only response — Gemini compat never has reasoning_content.
	// 纯 content 响应——Gemini compat 不发 reasoning_content。
	fixture := `data: {"choices":[{"delta":{"content":"The answer is 42."},"finish_reason":"stop"}]}

data: [DONE]
`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectFromServer(t, srv)

	// Assert zero reasoning events — Gemini compat returns none.
	// 断言零 reasoning 事件——Gemini compat 不返回。
	reasoning := filterType(events, EventReasoning)
	if len(reasoning) != 0 {
		t.Errorf("Gemini compat must not emit reasoning events (write-only per 03 §5); got: %+v", reasoning)
	}
	texts := filterType(events, EventText)
	if len(texts) != 1 || texts[0].Delta != "The answer is 42." {
		t.Errorf("text events = %+v", texts)
	}
	t.Log("Note: to read back reasoning/thoughtSignature from Gemini, a native " +
		"generateContent adapter is needed — the compat surface is write-only for reasoning " +
		"(03 §5, §12). That is a documented future enhancement beyond this P2 round.")
}
