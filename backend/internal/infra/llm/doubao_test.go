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
// L1: BuildRequest shape (Doubao golden wire format per 03 §9)
// ──────────────────────────────────────────────────────────────────────────────

// TestDoubao_BuildRequest_GoldenShape verifies the Doubao BuildRequest wire shape:
// model, messages, tools in OpenAI shape, stream:true, stream_options,
// no thinking fields when Thinking is nil. Matches 03 §9 golden request.
//
// 验证豆包 BuildRequest wire shape：model/messages/tools/stream/stream_options，
// Thinking 为 nil 时无 thinking 字段；对照 03 §9 黄金请求体。
func TestDoubao_BuildRequest_GoldenShape(t *testing.T) {
	p := newDoubaoProvider()
	req := Request{
		ModelID: "doubao-seed-1-6-thinking-250715",
		BaseURL: "https://ark.cn-beijing.volces.com/api/v3",
		Key:     "sk-test",
		Messages: []LLMMessage{
			{Role: RoleUser, Content: "Weather in Toronto?"},
		},
		Tools: []ToolDef{
			{
				Name:        "get_current_weather",
				Description: "",
				Parameters:  json.RawMessage(`{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}`),
			},
		},
	}
	httpReq, err := p.BuildRequest(context.Background(), req)
	if err != nil {
		t.Fatalf("BuildRequest: %v", err)
	}

	var body doubaoRequest
	if err := json.NewDecoder(httpReq.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}

	if body.Model != "doubao-seed-1-6-thinking-250715" {
		t.Errorf("model = %q, want doubao-seed-1-6-thinking-250715", body.Model)
	}
	if !body.Stream {
		t.Error("stream must be true")
	}
	if body.StreamOptions == nil || !body.StreamOptions.IncludeUsage {
		t.Error("stream_options.include_usage must be true")
	}
	if len(body.Tools) != 1 || body.Tools[0].Function.Name != "get_current_weather" {
		t.Errorf("tools = %+v, want 1 tool named get_current_weather", body.Tools)
	}
	if body.Thinking != nil {
		t.Errorf("nil Thinking → thinking must be absent; got %+v", body.Thinking)
	}
}

// TestDoubao_BuildRequest_ThinkingOn_EnabledWithBudget verifies Mode="on"+Budget
// emits thinking:{type:"enabled", budget_tokens:N}. Matches 03 §9 golden.
//
// 验证豆包 Mode="on"+Budget emit thinking:{type:"enabled",budget_tokens:N}，对照 03 §9。
func TestDoubao_BuildRequest_ThinkingOn_EnabledWithBudget(t *testing.T) {
	r := minimalReq("doubao-seed-1-6-thinking-250715")
	r.Thinking = &ThinkingSpec{Mode: "on", Budget: 32000}
	body := buildProviderBody(t, "doubao", "https://ark.cn-beijing.volces.com/api/v3", r)

	var parsed map[string]json.RawMessage
	if err := json.Unmarshal(body, &parsed); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if _, ok := parsed["thinking"]; !ok {
		t.Fatalf("body missing 'thinking' field; body: %s", body)
	}
	var thinking map[string]json.RawMessage
	json.Unmarshal(parsed["thinking"], &thinking)
	var typStr string
	json.Unmarshal(thinking["type"], &typStr)
	if typStr != "enabled" {
		t.Errorf("thinking.type = %q, want enabled", typStr)
	}
	var budget int
	json.Unmarshal(thinking["budget_tokens"], &budget)
	if budget != 32000 {
		t.Errorf("thinking.budget_tokens = %d, want 32000", budget)
	}
}

// TestDoubao_BuildRequest_ThinkingOn_NoBudget verifies Mode="on" without Budget
// emits thinking:{type:"enabled"} without budget_tokens.
//
// 验证豆包 Mode="on" 无 Budget 时 emit thinking:{type:"enabled"}（无 budget_tokens）。
func TestDoubao_BuildRequest_ThinkingOn_NoBudget(t *testing.T) {
	r := minimalReq("doubao-seed-1-6-thinking-250715")
	r.Thinking = &ThinkingSpec{Mode: "on"}
	body := buildProviderBody(t, "doubao", "https://ark.cn-beijing.volces.com/api/v3", r)

	if bytes.Contains(body, []byte(`"budget_tokens"`)) {
		t.Errorf("budget_tokens must not appear when Budget=0; body: %s", body)
	}
	if !bytes.Contains(body, []byte(`"enabled"`)) {
		t.Errorf("thinking.type=enabled must appear; body: %s", body)
	}
}

// TestDoubao_BuildRequest_ThinkingOff_Disabled verifies Mode="off" emits
// thinking:{type:"disabled"}.
//
// 验证豆包 Mode="off" emit thinking:{type:"disabled"}。
func TestDoubao_BuildRequest_ThinkingOff_Disabled(t *testing.T) {
	r := minimalReq("doubao-seed-1-6-thinking-250715")
	r.Thinking = &ThinkingSpec{Mode: "off"}
	body := buildProviderBody(t, "doubao", "https://ark.cn-beijing.volces.com/api/v3", r)

	var parsed map[string]json.RawMessage
	json.Unmarshal(body, &parsed)
	var thinking map[string]string
	json.Unmarshal(parsed["thinking"], &thinking)
	if thinking["type"] != "disabled" {
		t.Errorf("thinking.type = %q, want disabled", thinking["type"])
	}
}

// TestDoubao_BuildRequest_NilThinking_NoThinkingFields verifies that nil Thinking
// emits no thinking fields (regression guard).
//
// 验证 nil Thinking 不含任何 thinking 字段（回归守卫）。
func TestDoubao_BuildRequest_NilThinking_NoThinkingFields(t *testing.T) {
	body := buildProviderBody(t, "doubao", "https://ark.cn-beijing.volces.com/api/v3", minimalReq("doubao-seed-1-6-thinking-250715"))
	assertNoThinkingFields(t, body)
}

// TestDoubao_URL_IsChatCompletions verifies the request URL is base + /chat/completions.
//
// 验证豆包请求 URL 为 base + /chat/completions。
func TestDoubao_URL_IsChatCompletions(t *testing.T) {
	p := newDoubaoProvider()
	req := Request{
		ModelID:  "doubao-seed-1-6-thinking-250715",
		BaseURL:  "https://ark.cn-beijing.volces.com/api/v3",
		Key:      "k",
		Messages: []LLMMessage{{Role: RoleUser, Content: "hi"}},
	}
	httpReq, err := p.BuildRequest(context.Background(), req)
	if err != nil {
		t.Fatalf("BuildRequest: %v", err)
	}
	want := "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
	if httpReq.URL.String() != want {
		t.Errorf("URL = %q, want %q", httpReq.URL.String(), want)
	}
}

// TestDoubao_DefaultBaseURL verifies the canonical Volcengine Ark URL.
//
// 验证豆包 DefaultBaseURL 为正确的 Volcengine Ark URL。
func TestDoubao_DefaultBaseURL(t *testing.T) {
	p := newDoubaoProvider()
	want := "https://ark.cn-beijing.volces.com/api/v3"
	if got := p.DefaultBaseURL(); got != want {
		t.Errorf("DefaultBaseURL = %q, want %q", got, want)
	}
}

// ──────────────────────────────────────────────────────────────────────────────
// L2: ParseStream via httptest
// ──────────────────────────────────────────────────────────────────────────────

// collectDoubaoFromServer points doubaoProvider at the given test server and
// collects all StreamEvents from ParseStream.
//
// collectDoubaoFromServer 把 doubaoProvider 指向测试服务器，收集所有 StreamEvent。
func collectDoubaoFromServer(t *testing.T, srv *httptest.Server) []StreamEvent {
	t.Helper()
	resp, err := http.Get(srv.URL)
	if err != nil {
		t.Fatalf("http.Get: %v", err)
	}
	p := newDoubaoProvider()
	req := Request{ModelID: "doubao-seed-1-6-thinking-250715", BaseURL: srv.URL}
	var events []StreamEvent
	for ev := range p.ParseStream(context.Background(), resp, req) {
		events = append(events, ev)
	}
	return events
}

// TestDoubao_ParseStream_ReasoningContentBeforeContent verifies Doubao streams
// reasoning_content before content and both are correctly mapped.
//
// 验证豆包先流 reasoning_content 再流 content，两者均正确映射。
func TestDoubao_ParseStream_ReasoningContentBeforeContent(t *testing.T) {
	fixture := `data: {"choices":[{"delta":{"reasoning_content":"思考中..."},"finish_reason":null}]}

data: {"choices":[{"delta":{"content":"多伦多天气晴。"},"finish_reason":"stop"}]}

data: [DONE]
`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectDoubaoFromServer(t, srv)

	reasoning := filterType(events, EventReasoning)
	if len(reasoning) != 1 || reasoning[0].Delta != "思考中..." {
		t.Errorf("reasoning events = %+v", reasoning)
	}
	texts := filterType(events, EventText)
	if len(texts) != 1 || texts[0].Delta != "多伦多天气晴。" {
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

// TestDoubao_ParseStream_ToolCall verifies tool-call streaming through the Doubao provider.
//
// 验证豆包 provider 的 tool-call 流式解析。
func TestDoubao_ParseStream_ToolCall(t *testing.T) {
	fixture := `data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"get_current_weather","arguments":""}}]},"finish_reason":null}]}

data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\"city\":\"Toronto\"}"}}]},"finish_reason":null}]}

data: {"choices":[{"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":15,"completion_tokens":10}}

data: [DONE]
`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectDoubaoFromServer(t, srv)

	starts := filterType(events, EventToolStart)
	if len(starts) != 1 || starts[0].ToolName != "get_current_weather" {
		t.Errorf("tool starts = %+v", starts)
	}
	deltas := filterType(events, EventToolDelta)
	if len(deltas) != 1 || deltas[0].ArgsDelta != `{"city":"Toronto"}` {
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

// TestDoubao_ParseStream_InStreamError verifies mid-stream error envelopes map to EventError.
//
// 验证豆包流中错误信封正确映射为 EventError。
func TestDoubao_ParseStream_InStreamError(t *testing.T) {
	fixture := `data: {"choices":[{"delta":{"content":"hi"},"finish_reason":null}]}

data: {"error":{"message":"upstream timeout","type":"upstream_error"}}

`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectDoubaoFromServer(t, srv)

	errEvents := filterType(events, EventError)
	if len(errEvents) != 1 {
		t.Fatalf("want 1 EventError, got %d: %+v", len(errEvents), events)
	}
	if !errors.Is(errEvents[0].Err, ErrProviderError) {
		t.Errorf("error must wrap ErrProviderError; got: %v", errEvents[0].Err)
	}
}
