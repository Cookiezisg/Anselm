package llm

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

// ──────────────────────────────────────────────────────────────────────────────
// L1: BuildRequest shape (Zhipu GLM golden wire format per 03 §7)
// ──────────────────────────────────────────────────────────────────────────────

// TestZhipu_BuildRequest_GoldenShape verifies the Zhipu BuildRequest wire shape:
// model, messages, tools in OpenAI shape, tool_choice:"auto", stream:true,
// stream_options, thinking:{type:"enabled"}. Matches 03 §7 golden request.
//
// 验证 Zhipu BuildRequest wire shape：model/messages/tools/tool_choice="auto"/
// stream/stream_options/thinking:{type:"enabled"}；对照 03 §7 黄金请求体。
func TestZhipu_BuildRequest_GoldenShape(t *testing.T) {
	p := newZhipuProvider()
	req := Request{
		ModelID: "glm-4.6",
		BaseURL: "https://open.bigmodel.cn/api/paas/v4",
		Key:     "sk-test",
		Messages: []LLMMessage{
			{Role: RoleUser, Content: "Weather in Beijing?"},
		},
		Tools: []ToolDef{
			{
				Name:        "get_weather",
				Description: "",
				Parameters:  json.RawMessage(`{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}`),
			},
		},
		Thinking: &ThinkingSpec{Mode: "on"},
	}
	httpReq, err := p.BuildRequest(context.Background(), req)
	if err != nil {
		t.Fatalf("BuildRequest: %v", err)
	}

	var body zhipuRequest
	if err := json.NewDecoder(httpReq.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}

	if body.Model != "glm-4.6" {
		t.Errorf("model = %q, want glm-4.6", body.Model)
	}
	if !body.Stream {
		t.Error("stream must be true")
	}
	if body.StreamOptions == nil || !body.StreamOptions.IncludeUsage {
		t.Error("stream_options.include_usage must be true")
	}
	if len(body.Tools) != 1 || body.Tools[0].Function.Name != "get_weather" {
		t.Errorf("tools = %+v, want 1 tool named get_weather", body.Tools)
	}
	// tool_choice must be "auto" — Zhipu only supports "auto".
	// tool_choice 必须是 "auto"——Zhipu 只支持此值。
	if body.ToolChoice != "auto" {
		t.Errorf("tool_choice = %q, want auto", body.ToolChoice)
	}
	if body.Thinking == nil || body.Thinking.Type != "enabled" {
		t.Errorf("thinking = %+v, want {type:enabled}", body.Thinking)
	}
}

// TestZhipu_BuildRequest_ToolChoiceAuto_OnlyWhenToolsPresent verifies that
// tool_choice:"auto" is only sent when tools are present.
//
// 验证 tool_choice:"auto" 只在有 tools 时发送。
func TestZhipu_BuildRequest_ToolChoiceAuto_OnlyWhenToolsPresent(t *testing.T) {
	p := newZhipuProvider()
	req := Request{
		ModelID:  "glm-4.6",
		BaseURL:  "https://open.bigmodel.cn/api/paas/v4",
		Key:      "k",
		Messages: []LLMMessage{{Role: RoleUser, Content: "hi"}},
		// No tools.
	}
	httpReq, err := p.BuildRequest(context.Background(), req)
	if err != nil {
		t.Fatalf("BuildRequest: %v", err)
	}
	var body zhipuRequest
	json.NewDecoder(httpReq.Body).Decode(&body)
	if body.ToolChoice != "" {
		t.Errorf("tool_choice should be absent when no tools; got %q", body.ToolChoice)
	}
}

// TestZhipu_BuildRequest_ThinkingOn_ThinkingEnabled verifies Mode="on" emits
// thinking:{type:"enabled"}. Matches 03 §7 golden.
//
// 验证 Zhipu Mode="on" emit thinking:{type:"enabled"}，对照 03 §7。
func TestZhipu_BuildRequest_ThinkingOn_ThinkingEnabled(t *testing.T) {
	r := minimalReq("glm-4.6")
	r.Thinking = &ThinkingSpec{Mode: "on"}
	body := buildProviderBody(t, "zhipu", "https://open.bigmodel.cn/api/paas/v4", r)

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
	if _, ok := parsed["reasoning_effort"]; ok {
		t.Errorf("zhipu should not emit 'reasoning_effort'")
	}
}

// TestZhipu_BuildRequest_ThinkingOff_ThinkingDisabled verifies Mode="off" emits
// thinking:{type:"disabled"}.
//
// 验证 Zhipu Mode="off" emit thinking:{type:"disabled"}。
func TestZhipu_BuildRequest_ThinkingOff_ThinkingDisabled(t *testing.T) {
	r := minimalReq("glm-4.6")
	r.Thinking = &ThinkingSpec{Mode: "off"}
	body := buildProviderBody(t, "zhipu", "https://open.bigmodel.cn/api/paas/v4", r)

	var parsed map[string]json.RawMessage
	json.Unmarshal(body, &parsed)
	var thinking map[string]string
	json.Unmarshal(parsed["thinking"], &thinking)
	if thinking["type"] != "disabled" {
		t.Errorf("thinking.type = %q, want disabled", thinking["type"])
	}
}

// TestZhipu_BuildRequest_NilThinking_NoThinkingFields verifies nil Thinking
// emits no thinking fields.
//
// 验证 nil Thinking 不含任何 thinking 字段。
func TestZhipu_BuildRequest_NilThinking_NoThinkingFields(t *testing.T) {
	body := buildProviderBody(t, "zhipu", "https://open.bigmodel.cn/api/paas/v4", minimalReq("glm-4.6"))
	assertNoThinkingFields(t, body)
}

// ──────────────────────────────────────────────────────────────────────────────
// L2: ParseStream via httptest
// ──────────────────────────────────────────────────────────────────────────────

// collectZhipuFromServer points zhipuProvider at the given test server and
// collects all StreamEvents from ParseStream.
//
// collectZhipuFromServer 把 zhipuProvider 指向测试服务器，收集所有 StreamEvent。
func collectZhipuFromServer(t *testing.T, srv *httptest.Server) []StreamEvent {
	t.Helper()
	resp, err := http.Get(srv.URL)
	if err != nil {
		t.Fatalf("http.Get: %v", err)
	}
	p := newZhipuProvider()
	req := Request{ModelID: "glm-4.6", BaseURL: srv.URL}
	var events []StreamEvent
	for ev := range p.ParseStream(context.Background(), resp, req) {
		events = append(events, ev)
	}
	return events
}

// TestZhipu_ParseStream_ReasoningContentBeforeContent verifies Zhipu streams
// reasoning_content before content and both are correctly mapped.
//
// 验证 Zhipu 先流 reasoning_content 再流 content，两者均正确映射。
func TestZhipu_ParseStream_ReasoningContentBeforeContent(t *testing.T) {
	fixture := `data: {"choices":[{"delta":{"reasoning_content":"正在思考..."},"finish_reason":null}]}

data: {"choices":[{"delta":{"content":"北京天气晴。"},"finish_reason":"stop"}]}

data: [DONE]
`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectZhipuFromServer(t, srv)

	reasoning := filterType(events, EventReasoning)
	if len(reasoning) != 1 || reasoning[0].Delta != "正在思考..." {
		t.Errorf("reasoning events = %+v", reasoning)
	}
	texts := filterType(events, EventText)
	if len(texts) != 1 || texts[0].Delta != "北京天气晴。" {
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

// TestZhipu_ParseStream_FinishReason_Sensitive verifies that Zhipu's extended
// finish_reason "sensitive" is passed through as-is in EventFinish.
//
// 验证 Zhipu 扩展 finish_reason "sensitive" 直接透传到 EventFinish。
func TestZhipu_ParseStream_FinishReason_Sensitive(t *testing.T) {
	fixture := `data: {"choices":[{"delta":{"content":"sorry"},"finish_reason":"sensitive"}]}

data: [DONE]
`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectZhipuFromServer(t, srv)

	finishes := filterType(events, EventFinish)
	if len(finishes) != 1 || finishes[0].FinishReason != "sensitive" {
		t.Errorf("finish events = %+v, want finish_reason=sensitive", finishes)
	}
}

// TestZhipu_ParseStream_FinishReason_NetworkError verifies that Zhipu's extended
// finish_reason "network_error" is passed through as-is in EventFinish.
//
// 验证 Zhipu 扩展 finish_reason "network_error" 直接透传到 EventFinish。
func TestZhipu_ParseStream_FinishReason_NetworkError(t *testing.T) {
	fixture := `data: {"choices":[{"delta":{},"finish_reason":"network_error"}]}

data: [DONE]
`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectZhipuFromServer(t, srv)

	finishes := filterType(events, EventFinish)
	if len(finishes) != 1 || finishes[0].FinishReason != "network_error" {
		t.Errorf("finish events = %+v, want finish_reason=network_error", finishes)
	}
}

// TestZhipu_ParseStream_InStreamError verifies that nested {error:{}} chunks
// map to EventError wrapping ErrProviderError.
//
// 验证 Zhipu 嵌套 {error:{}} chunk 正确映射为 EventError。
func TestZhipu_ParseStream_InStreamError(t *testing.T) {
	fixture := `data: {"error":{"message":"model overloaded","type":"server_error"}}

`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectZhipuFromServer(t, srv)

	errEvents := filterType(events, EventError)
	if len(errEvents) != 1 {
		t.Fatalf("want 1 EventError, got %d: %+v", len(errEvents), events)
	}
	if !errors.Is(errEvents[0].Err, ErrProviderError) {
		t.Errorf("error must wrap ErrProviderError; got: %v", errEvents[0].Err)
	}
}

// TestZhipu_DefaultBaseURL verifies the canonical Zhipu BigModel URL.
//
// 验证 Zhipu DefaultBaseURL 为正确的 BigModel URL。
func TestZhipu_DefaultBaseURL(t *testing.T) {
	p := newZhipuProvider()
	want := "https://open.bigmodel.cn/api/paas/v4"
	if got := p.DefaultBaseURL(); got != want {
		t.Errorf("DefaultBaseURL = %q, want %q", got, want)
	}
}
