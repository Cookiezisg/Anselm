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
// L1: BuildRequest shape (OpenRouter golden wire format per 03 §10)
// ──────────────────────────────────────────────────────────────────────────────

// TestOpenRouter_BuildRequest_GoldenShape verifies the OpenRouter BuildRequest
// wire shape: model, messages, tools in OpenAI shape, stream:true,
// stream_options, no reasoning field when Thinking is nil. Matches 03 §10.
//
// 验证 OpenRouter BuildRequest wire shape：model/messages/tools/stream/stream_options，
// Thinking 为 nil 时无 reasoning 字段；对照 03 §10 黄金请求体。
func TestOpenRouter_BuildRequest_GoldenShape(t *testing.T) {
	p := newOpenRouterProvider()
	req := Request{
		ModelID: "anthropic/claude-sonnet-4",
		BaseURL: "https://openrouter.ai/api/v1",
		Key:     "sk-or-test",
		Messages: []LLMMessage{
			{Role: RoleUser, Content: "2+2 and why?"},
		},
		Tools: []ToolDef{
			{
				Name:        "calculator",
				Description: "",
				Parameters:  json.RawMessage(`{"type":"object","properties":{"expr":{"type":"string"}},"required":["expr"]}`),
			},
		},
	}
	httpReq, err := p.BuildRequest(context.Background(), req)
	if err != nil {
		t.Fatalf("BuildRequest: %v", err)
	}

	var body orRequest
	if err := json.NewDecoder(httpReq.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}

	if body.Model != "anthropic/claude-sonnet-4" {
		t.Errorf("model = %q, want anthropic/claude-sonnet-4", body.Model)
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
	if body.Reasoning != nil {
		t.Errorf("nil Thinking → reasoning must be absent; got %+v", body.Reasoning)
	}
}

// TestOpenRouter_BuildRequest_ThinkingOn_EffortHigh verifies Mode="on"+Effort="high"
// emits reasoning:{effort:"high"}. Matches 03 §10 golden.
//
// 验证 OpenRouter Mode="on"+Effort="high" emit reasoning:{effort:"high"}，对照 03 §10。
func TestOpenRouter_BuildRequest_ThinkingOn_EffortHigh(t *testing.T) {
	r := minimalReq("anthropic/claude-sonnet-4")
	r.Thinking = &ThinkingSpec{Mode: "on", Effort: "high"}
	body := buildProviderBody(t, "openrouter", "https://openrouter.ai/api/v1", r)

	var parsed map[string]json.RawMessage
	if err := json.Unmarshal(body, &parsed); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if _, ok := parsed["reasoning"]; !ok {
		t.Fatalf("body missing 'reasoning' field; body: %s", body)
	}
	var reasoning map[string]json.RawMessage
	json.Unmarshal(parsed["reasoning"], &reasoning)
	var effort string
	json.Unmarshal(reasoning["effort"], &effort)
	if effort != "high" {
		t.Errorf("reasoning.effort = %q, want high", effort)
	}
	if _, ok := reasoning["max_tokens"]; ok {
		t.Errorf("reasoning.max_tokens must not appear when effort is set")
	}
}

// TestOpenRouter_BuildRequest_ThinkingOn_BudgetWhenNoEffort verifies Mode="on"+Budget
// (no Effort) emits reasoning:{max_tokens:N}.
//
// 验证 OpenRouter Mode="on"+Budget（无 Effort）emit reasoning:{max_tokens:N}。
func TestOpenRouter_BuildRequest_ThinkingOn_BudgetWhenNoEffort(t *testing.T) {
	r := minimalReq("anthropic/claude-sonnet-4")
	r.Thinking = &ThinkingSpec{Mode: "on", Budget: 4096}
	body := buildProviderBody(t, "openrouter", "https://openrouter.ai/api/v1", r)

	var parsed map[string]json.RawMessage
	json.Unmarshal(body, &parsed)
	var reasoning map[string]json.RawMessage
	json.Unmarshal(parsed["reasoning"], &reasoning)
	var mt int
	json.Unmarshal(reasoning["max_tokens"], &mt)
	if mt != 4096 {
		t.Errorf("reasoning.max_tokens = %d, want 4096", mt)
	}
	if _, ok := reasoning["effort"]; ok {
		t.Errorf("reasoning.effort must not appear when Budget is used without Effort")
	}
}

// TestOpenRouter_BuildRequest_ThinkingOn_EffortPreferredOverBudget verifies effort
// is preferred when both Effort and Budget are set (mutually exclusive).
//
// 验证 Effort 和 Budget 同时设置时 effort 优先（互斥字段）。
func TestOpenRouter_BuildRequest_ThinkingOn_EffortPreferredOverBudget(t *testing.T) {
	r := minimalReq("anthropic/claude-sonnet-4")
	r.Thinking = &ThinkingSpec{Mode: "on", Effort: "medium", Budget: 4096}
	body := buildProviderBody(t, "openrouter", "https://openrouter.ai/api/v1", r)

	var parsed map[string]json.RawMessage
	json.Unmarshal(body, &parsed)
	var reasoning map[string]json.RawMessage
	json.Unmarshal(parsed["reasoning"], &reasoning)
	var effort string
	json.Unmarshal(reasoning["effort"], &effort)
	if effort != "medium" {
		t.Errorf("effort should be preferred over budget; got %q", effort)
	}
	if _, ok := reasoning["max_tokens"]; ok {
		t.Errorf("max_tokens must not appear when effort is set")
	}
}

// TestOpenRouter_BuildRequest_ThinkingOn_NoEffortNoBudget_DefaultsMedium verifies
// that Mode="on" with no Effort and no Budget defaults to reasoning:{effort:"medium"}.
//
// 验证 Mode="on" 无 Effort 无 Budget 时默认 reasoning:{effort:"medium"}。
func TestOpenRouter_BuildRequest_ThinkingOn_NoEffortNoBudget_DefaultsMedium(t *testing.T) {
	r := minimalReq("anthropic/claude-sonnet-4")
	r.Thinking = &ThinkingSpec{Mode: "on"}
	body := buildProviderBody(t, "openrouter", "https://openrouter.ai/api/v1", r)

	var parsed map[string]json.RawMessage
	json.Unmarshal(body, &parsed)
	var reasoning map[string]json.RawMessage
	json.Unmarshal(parsed["reasoning"], &reasoning)
	var effort string
	json.Unmarshal(reasoning["effort"], &effort)
	if effort != "medium" {
		t.Errorf("default reasoning.effort = %q, want medium", effort)
	}
}

// TestOpenRouter_BuildRequest_ThinkingOff_NoReasoningField verifies Mode="off"
// omits the reasoning field (no documented clean disable form).
//
// 验证 OpenRouter Mode="off" 不发 reasoning 字段（无文档化关闭形）。
func TestOpenRouter_BuildRequest_ThinkingOff_NoReasoningField(t *testing.T) {
	r := minimalReq("anthropic/claude-sonnet-4")
	r.Thinking = &ThinkingSpec{Mode: "off"}
	body := buildProviderBody(t, "openrouter", "https://openrouter.ai/api/v1", r)

	if bytes.Contains(body, []byte(`"reasoning"`)) {
		t.Errorf("openrouter off: reasoning field must be absent; body: %s", body)
	}
}

// TestOpenRouter_BuildRequest_NilThinking_NoThinkingFields verifies nil Thinking
// emits no thinking fields.
//
// 验证 nil Thinking 不含任何 thinking 字段。
func TestOpenRouter_BuildRequest_NilThinking_NoThinkingFields(t *testing.T) {
	body := buildProviderBody(t, "openrouter", "https://openrouter.ai/api/v1", minimalReq("anthropic/claude-sonnet-4"))
	assertNoThinkingFields(t, body)
}

// TestOpenRouter_DefaultBaseURL verifies the canonical OpenRouter URL.
//
// 验证 OpenRouter DefaultBaseURL 为正确的 URL。
func TestOpenRouter_DefaultBaseURL(t *testing.T) {
	p := newOpenRouterProvider()
	want := "https://openrouter.ai/api/v1"
	if got := p.DefaultBaseURL(); got != want {
		t.Errorf("DefaultBaseURL = %q, want %q", got, want)
	}
}

// ──────────────────────────────────────────────────────────────────────────────
// L2: ParseStream via httptest
// ──────────────────────────────────────────────────────────────────────────────

// collectOpenRouterFromServer points openrouterProvider at the given test server
// and collects all StreamEvents from ParseStream.
//
// collectOpenRouterFromServer 把 openrouterProvider 指向测试服务器，收集所有 StreamEvent。
func collectOpenRouterFromServer(t *testing.T, srv *httptest.Server) []StreamEvent {
	t.Helper()
	resp, err := http.Get(srv.URL)
	if err != nil {
		t.Fatalf("http.Get: %v", err)
	}
	p := newOpenRouterProvider()
	req := Request{ModelID: "anthropic/claude-sonnet-4", BaseURL: srv.URL}
	var events []StreamEvent
	for ev := range p.ParseStream(context.Background(), resp, req) {
		events = append(events, ev)
	}
	return events
}

// TestOpenRouter_ParseStream_ReasoningFieldBeforeContent verifies OpenRouter maps
// delta.reasoning → EventReasoning before delta.content → EventText.
//
// 验证 OpenRouter delta.reasoning 先于 content 流到，正确映射为 EventReasoning。
func TestOpenRouter_ParseStream_ReasoningFieldBeforeContent(t *testing.T) {
	fixture := `data: {"choices":[{"delta":{"reasoning":"Step 1: add 2+2."},"finish_reason":null}]}

data: {"choices":[{"delta":{"content":"The answer is 4."},"finish_reason":"stop"}]}

data: [DONE]
`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectOpenRouterFromServer(t, srv)

	reasoning := filterType(events, EventReasoning)
	if len(reasoning) != 1 || reasoning[0].Delta != "Step 1: add 2+2." {
		t.Errorf("reasoning events = %+v", reasoning)
	}
	texts := filterType(events, EventText)
	if len(texts) != 1 || texts[0].Delta != "The answer is 4." {
		t.Errorf("text events = %+v", texts)
	}
	// Reasoning must precede text.
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

// TestOpenRouter_ParseStream_ReasoningContentAlias verifies that delta.reasoning_content
// (the CN-family alias) is also mapped to EventReasoning.
//
// 验证 delta.reasoning_content（CN 家族别名）也映射为 EventReasoning。
func TestOpenRouter_ParseStream_ReasoningContentAlias(t *testing.T) {
	fixture := `data: {"choices":[{"delta":{"reasoning_content":"思考中..."},"finish_reason":null}]}

data: {"choices":[{"delta":{"content":"answer"},"finish_reason":"stop"}]}

data: [DONE]
`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectOpenRouterFromServer(t, srv)

	reasoning := filterType(events, EventReasoning)
	if len(reasoning) != 1 || reasoning[0].Delta != "思考中..." {
		t.Errorf("reasoning_content alias: events = %+v", reasoning)
	}
}

// TestOpenRouter_ParseStream_CommentLineSkip verifies OpenRouter SSE keep-alive
// comment lines (": OPENROUTER PROCESSING") are skipped without error.
// scanSSELines already handles this via the "data: " prefix filter.
//
// 验证 OpenRouter SSE 心跳注释行（": OPENROUTER PROCESSING"）被跳过，不产生错误。
// scanSSELines 已通过 "data: " 前缀过滤处理。
func TestOpenRouter_ParseStream_CommentLineSkip(t *testing.T) {
	fixture := `: OPENROUTER PROCESSING

data: {"choices":[{"delta":{"content":"Hello "},"finish_reason":null}]}

: OPENROUTER PROCESSING

data: {"choices":[{"delta":{"content":"world"},"finish_reason":"stop"}]}

data: [DONE]
`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectOpenRouterFromServer(t, srv)

	errEvents := filterType(events, EventError)
	if len(errEvents) != 0 {
		t.Errorf("no errors expected with comment lines; got: %+v", errEvents)
	}
	texts := filterType(events, EventText)
	if len(texts) != 2 {
		t.Fatalf("want 2 EventText, got %d", len(texts))
	}
	if texts[0].Delta != "Hello " || texts[1].Delta != "world" {
		t.Errorf("text deltas = %q %q", texts[0].Delta, texts[1].Delta)
	}
}

// TestOpenRouter_ParseStream_InStreamError verifies mid-stream error envelopes
// map to EventError wrapping ErrProviderError.
//
// 验证 OpenRouter 流中错误信封正确映射为 EventError（含 ErrProviderError）。
func TestOpenRouter_ParseStream_InStreamError(t *testing.T) {
	fixture := `data: {"choices":[{"delta":{"content":"hi "},"finish_reason":null}]}

data: {"error":{"message":"upstream model timeout","type":"upstream_error","code":"timeout"}}

`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectOpenRouterFromServer(t, srv)

	texts := filterType(events, EventText)
	if len(texts) != 1 || texts[0].Delta != "hi " {
		t.Errorf("text before error = %+v", texts)
	}
	errEvents := filterType(events, EventError)
	if len(errEvents) != 1 {
		t.Fatalf("want 1 EventError, got %d: %+v", len(errEvents), events)
	}
	if !errors.Is(errEvents[0].Err, ErrProviderError) {
		t.Errorf("error must wrap ErrProviderError; got: %v", errEvents[0].Err)
	}
	if !strings.Contains(errEvents[0].Err.Error(), "upstream model timeout") {
		t.Errorf("error should contain message; got: %v", errEvents[0].Err)
	}
}

// TestOpenRouter_ParseStream_ReasoningDetailsIgnored verifies that a chunk with
// reasoning_details (structured field) does not crash the parser.
//
// 验证含 reasoning_details 的 chunk 不会导致 parser 崩溃。
func TestOpenRouter_ParseStream_ReasoningDetailsIgnored(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		w.WriteHeader(http.StatusOK)
		// reasoning_details is structured — unknown fields should be silently ignored.
		// reasoning_details 是结构化字段——未知字段应静默忽略。
		fmt.Fprint(w, `data: {"choices":[{"delta":{"reasoning":"think","reasoning_details":[{"type":"reasoning.text","data":"think"}]},"finish_reason":null}]}

data: {"choices":[{"delta":{"content":"answer"},"finish_reason":"stop"}]}

data: [DONE]
`)
	}))
	defer srv.Close()
	events := collectOpenRouterFromServer(t, srv)

	errEvents := filterType(events, EventError)
	if len(errEvents) != 0 {
		t.Errorf("reasoning_details must not cause errors; got: %+v", errEvents)
	}
	reasoning := filterType(events, EventReasoning)
	if len(reasoning) != 1 || reasoning[0].Delta != "think" {
		t.Errorf("reasoning events = %+v", reasoning)
	}
}
