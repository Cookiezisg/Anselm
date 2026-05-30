package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

// ──────────────────────────────────────────────────────────────────────────────
// L1: BuildRequest shape (Moonshot Kimi golden wire format per 03 §8)
// ──────────────────────────────────────────────────────────────────────────────

// TestMoonshot_BuildRequest_GoldenShape verifies the Moonshot BuildRequest wire
// shape for an intrinsic-thinking model (kimi-k2-thinking): model, messages,
// tools in OpenAI shape, stream:true, stream_options, no thinking field.
// Matches 03 §8 golden request (model-id carries intrinsic thinking, no param).
//
// 验证 Moonshot kimi-k2-thinking 的 BuildRequest wire shape：model/messages/
// tools/stream/stream_options，无 thinking 字段（model-id 内禀 thinking）。
// 对照 03 §8 黄金请求体。
func TestMoonshot_BuildRequest_GoldenShape(t *testing.T) {
	p := newMoonshotProvider()
	req := Request{
		ModelID: "kimi-k2-thinking",
		BaseURL: "https://api.moonshot.cn/v1",
		Key:     "sk-test",
		System: "You are Kimi.",
		Messages: []LLMMessage{
			{Role: RoleUser, Content: "9.11 or 9.9 bigger?"},
		},
		Tools: []ToolDef{
			{
				Name:        "calculator",
				Description: "",
				Parameters:  json.RawMessage(`{"type":"object","properties":{"expr":{"type":"string"}},"required":["expr"]}`),
			},
		},
		// Nil Thinking — kimi-k2-thinking is intrinsic, no param needed.
		// Nil Thinking——kimi-k2-thinking 内禀，无需参数。
	}
	httpReq, err := p.BuildRequest(context.Background(), req)
	if err != nil {
		t.Fatalf("BuildRequest: %v", err)
	}

	var body moonshotRequest
	if err := json.NewDecoder(httpReq.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}

	if body.Model != "kimi-k2-thinking" {
		t.Errorf("model = %q, want kimi-k2-thinking", body.Model)
	}
	if !body.Stream {
		t.Error("stream must be true")
	}
	if body.StreamOptions == nil || !body.StreamOptions.IncludeUsage {
		t.Error("stream_options.include_usage must be true")
	}
	if len(body.Tools) != 1 || body.Tools[0].Function.Name != "calculator" {
		t.Errorf("tools = %+v, want 1 tool named calculator", body.Tools)
	}
	// Nil ThinkingSpec → thinking field must be absent.
	// Nil ThinkingSpec → thinking 字段必须省略。
	if body.Thinking != nil {
		t.Errorf("nil Thinking → thinking must be absent; got %+v", body.Thinking)
	}
}

// TestMoonshot_BuildRequest_ThinkingOn_ThinkingEnabled verifies Mode="on" emits
// thinking:{type:"enabled"} for k2.5/k2.6-style models. Matches 03 §8.
//
// 验证 Moonshot Mode="on" emit thinking:{type:"enabled"}（k2.5/k2.6 模型），
// 对照 03 §8。
func TestMoonshot_BuildRequest_ThinkingOn_ThinkingEnabled(t *testing.T) {
	r := minimalReq("kimi-k2.5")
	r.Thinking = &ThinkingSpec{Mode: "on"}
	body := buildProviderBody(t, "moonshot", "https://api.moonshot.cn/v1", r)

	var parsed map[string]json.RawMessage
	if err := json.Unmarshal(body, &parsed); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if _, ok := parsed["thinking"]; !ok {
		t.Fatalf("body missing 'thinking' field; body: %s", body)
	}
	var thinking map[string]string
	json.Unmarshal(parsed["thinking"], &thinking)
	if thinking["type"] != "enabled" {
		t.Errorf("thinking.type = %q, want enabled", thinking["type"])
	}
}

// TestMoonshot_BuildRequest_ThinkingOff_ThinkingDisabled verifies Mode="off"
// emits thinking:{type:"disabled"}.
//
// 验证 Moonshot Mode="off" emit thinking:{type:"disabled"}。
func TestMoonshot_BuildRequest_ThinkingOff_ThinkingDisabled(t *testing.T) {
	r := minimalReq("kimi-k2.5")
	r.Thinking = &ThinkingSpec{Mode: "off"}
	body := buildProviderBody(t, "moonshot", "https://api.moonshot.cn/v1", r)

	var parsed map[string]json.RawMessage
	json.Unmarshal(body, &parsed)
	var thinking map[string]string
	json.Unmarshal(parsed["thinking"], &thinking)
	if thinking["type"] != "disabled" {
		t.Errorf("thinking.type = %q, want disabled", thinking["type"])
	}
}

// TestMoonshot_BuildRequest_NilThinking_NoThinkingFields verifies nil Thinking
// emits no thinking fields (regression guard — kimi-k2-thinking intrinsic case).
//
// 验证 nil Thinking 不含任何 thinking 字段（回归守卫；kimi-k2-thinking 内禀场景）。
func TestMoonshot_BuildRequest_NilThinking_NoThinkingFields(t *testing.T) {
	body := buildProviderBody(t, "moonshot", "https://api.moonshot.cn/v1", minimalReq("kimi-k2-thinking"))
	assertNoThinkingFields(t, body)
}

// TestMoonshot_BuildRequest_NoReasoningEffort verifies Moonshot never emits
// reasoning_effort (that's OpenAI/Ollama's field, not Moonshot's).
//
// 验证 Moonshot 从不 emit reasoning_effort（那是 OpenAI/Ollama 的字段）。
func TestMoonshot_BuildRequest_NoReasoningEffort(t *testing.T) {
	r := minimalReq("kimi-k2.5")
	r.Thinking = &ThinkingSpec{Mode: "on"}
	body := buildProviderBody(t, "moonshot", "https://api.moonshot.cn/v1", r)
	if bytes.Contains(body, []byte(`"reasoning_effort"`)) {
		t.Errorf("moonshot must not emit reasoning_effort; body: %s", body)
	}
}

// ──────────────────────────────────────────────────────────────────────────────
// L2: ParseStream via httptest
// ──────────────────────────────────────────────────────────────────────────────

// collectMoonshotFromServer points moonshotProvider at the given test server
// and collects all StreamEvents from ParseStream.
//
// collectMoonshotFromServer 把 moonshotProvider 指向测试服务器，收集所有 StreamEvent。
func collectMoonshotFromServer(t *testing.T, srv *httptest.Server) []StreamEvent {
	t.Helper()
	resp, err := http.Get(srv.URL)
	if err != nil {
		t.Fatalf("http.Get: %v", err)
	}
	p := newMoonshotProvider()
	req := Request{ModelID: "kimi-k2-thinking", BaseURL: srv.URL}
	var events []StreamEvent
	for ev := range p.ParseStream(context.Background(), resp, req) {
		events = append(events, ev)
	}
	return events
}

// TestMoonshot_ParseStream_ReasoningContentBeforeContent verifies official
// api.moonshot.cn uses delta.reasoning_content (underscore form) → EventReasoning,
// ordered before content → EventText.
//
// 验证官方 api.moonshot.cn 的 delta.reasoning_content（下划线形）→EventReasoning，
// 先于 content→EventText。
func TestMoonshot_ParseStream_ReasoningContentBeforeContent(t *testing.T) {
	// Official api.moonshot.cn SSE — reasoning_content (underscore), not "reasoning".
	// 官方 api.moonshot.cn SSE 用 reasoning_content（下划线形），非裸 reasoning。
	fixture := `data: {"choices":[{"delta":{"reasoning_content":"9.11 < 9.9 因为..."},"finish_reason":null}]}

data: {"choices":[{"delta":{"content":"9.9 更大。"},"finish_reason":"stop"}]}

data: [DONE]
`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectMoonshotFromServer(t, srv)

	reasoning := filterType(events, EventReasoning)
	if len(reasoning) != 1 || reasoning[0].Delta != "9.11 < 9.9 因为..." {
		t.Errorf("reasoning events = %+v", reasoning)
	}
	texts := filterType(events, EventText)
	if len(texts) != 1 || texts[0].Delta != "9.9 更大。" {
		t.Errorf("text events = %+v", texts)
	}

	// Reasoning must precede text in event order.
	// reasoning 必须在 text 之前。
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

// TestMoonshot_ParseStream_NoFallbackToReasoningAlias verifies that a chunk
// with only "reasoning" (no underscore) — Together/NIM alias — is NOT mapped
// to EventReasoning by the Moonshot provider. The official Moonshot field is
// reasoning_content; the bare alias must not leak in.
//
// 验证 Moonshot provider 不把 "reasoning"（无下划线，Together/NIM 别名）映射到
// EventReasoning。官方字段是 reasoning_content，别名不得透入本 provider。
func TestMoonshot_ParseStream_NoFallbackToReasoningAlias(t *testing.T) {
	// A chunk that only has "reasoning" (bare form, no underscore).
	// 只有裸 "reasoning" 的 chunk（无下划线）。
	fixture := `data: {"choices":[{"delta":{"reasoning":"this is not Moonshot's field"},"finish_reason":null}]}

data: {"choices":[{"delta":{"content":"answer"},"finish_reason":"stop"}]}

data: [DONE]
`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectMoonshotFromServer(t, srv)

	// Moonshot provider does not recognise bare "reasoning" — no EventReasoning.
	// Moonshot provider 不识别裸 "reasoning"——无 EventReasoning。
	reasoning := filterType(events, EventReasoning)
	if len(reasoning) != 0 {
		t.Errorf("Moonshot provider must not emit EventReasoning for bare 'reasoning' field; got: %+v", reasoning)
	}
	// But text should still arrive normally.
	// text 仍应正常到达。
	texts := filterType(events, EventText)
	if len(texts) != 1 || texts[0].Delta != "answer" {
		t.Errorf("text events = %+v", texts)
	}
}

// TestMoonshot_ParseStream_ToolCall verifies tool-call streaming through the
// Moonshot provider.
//
// 验证 Moonshot provider 的 tool-call 流式解析。
func TestMoonshot_ParseStream_ToolCall(t *testing.T) {
	fixture := `data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"calculator","arguments":""}}]},"finish_reason":null}]}

data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\"expr\":\"9.9-9.11\"}"}}]},"finish_reason":null}]}

data: {"choices":[{"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":20,"completion_tokens":12}}

data: [DONE]
`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectMoonshotFromServer(t, srv)

	starts := filterType(events, EventToolStart)
	if len(starts) != 1 || starts[0].ToolName != "calculator" {
		t.Errorf("tool starts = %+v", starts)
	}
	deltas := filterType(events, EventToolDelta)
	if len(deltas) != 1 || deltas[0].ArgsDelta != `{"expr":"9.9-9.11"}` {
		t.Errorf("tool deltas = %+v", deltas)
	}
	finishes := filterType(events, EventFinish)
	if len(finishes) != 1 || finishes[0].FinishReason != "tool_calls" {
		t.Errorf("finishes = %+v", finishes)
	}
	if finishes[0].InputTokens != 20 || finishes[0].OutputTokens != 12 {
		t.Errorf("usage: in=%d out=%d, want 20/12", finishes[0].InputTokens, finishes[0].OutputTokens)
	}
}

// TestMoonshot_ParseStream_InStreamError verifies that nested {error:{}} chunks
// map to EventError wrapping ErrProviderError.
//
// 验证 Moonshot 嵌套 {error:{}} chunk 正确映射为 EventError。
func TestMoonshot_ParseStream_InStreamError(t *testing.T) {
	fixture := `data: {"error":{"message":"context_length_exceeded","type":"invalid_request_error"}}

`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectMoonshotFromServer(t, srv)

	errEvents := filterType(events, EventError)
	if len(errEvents) != 1 {
		t.Fatalf("want 1 EventError, got %d: %+v", len(errEvents), events)
	}
	if !errors.Is(errEvents[0].Err, ErrProviderError) {
		t.Errorf("error must wrap ErrProviderError; got: %v", errEvents[0].Err)
	}
}

// TestMoonshot_DefaultBaseURL verifies the canonical Moonshot API URL.
//
// 验证 Moonshot DefaultBaseURL 为正确的 api.moonshot.cn URL。
func TestMoonshot_DefaultBaseURL(t *testing.T) {
	p := newMoonshotProvider()
	want := "https://api.moonshot.cn/v1"
	if got := p.DefaultBaseURL(); got != want {
		t.Errorf("DefaultBaseURL = %q, want %q", got, want)
	}
}
