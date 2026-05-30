package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

// ──────────────────────────────────────────────────────────────────────────────
// L1: BuildRequest shape (custom provider — plain OpenAI-compat, no thinking)
// ──────────────────────────────────────────────────────────────────────────────

// TestCustom_BuildRequest_GoldenShape verifies the custom BuildRequest wire
// shape: model, messages, tools in OpenAI shape, stream:true, stream_options,
// no thinking fields. The custom provider is intentionally generic — it never
// emits thinking fields regardless of the ThinkingSpec.
//
// 验证 custom BuildRequest wire shape：model/messages/tools/stream/stream_options，
// 无 thinking 字段。custom provider 是通用接口，任何情况下均不发 thinking 字段。
func TestCustom_BuildRequest_GoldenShape(t *testing.T) {
	p := newCustomProvider()
	req := Request{
		ModelID: "my-model",
		BaseURL: "http://localhost:8080",
		Key:     "local-key",
		Messages: []LLMMessage{
			{Role: RoleUser, Content: "hi"},
		},
		Tools: []ToolDef{
			{
				Name:        "search",
				Description: "",
				Parameters:  json.RawMessage(`{"type":"object","properties":{"q":{"type":"string"}},"required":["q"]}`),
			},
		},
	}
	httpReq, err := p.BuildRequest(context.Background(), req)
	if err != nil {
		t.Fatalf("BuildRequest: %v", err)
	}

	var body customRequest
	if err := json.NewDecoder(httpReq.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}

	if body.Model != "my-model" {
		t.Errorf("model = %q, want my-model", body.Model)
	}
	if !body.Stream {
		t.Error("stream must be true")
	}
	if body.StreamOptions == nil || !body.StreamOptions.IncludeUsage {
		t.Error("stream_options.include_usage must be true")
	}
	if len(body.Tools) != 1 || body.Tools[0].Function.Name != "search" {
		t.Errorf("tools = %+v, want 1 tool named search", body.Tools)
	}
}

// TestCustom_BuildRequest_ThinkingSpec_NoThinkingFields verifies that a non-nil
// ThinkingSpec emits no thinking fields — custom endpoints are generic and must
// not receive provider-specific thinking parameters they don't understand.
//
// 验证非 nil ThinkingSpec 时 custom provider 不发任何 thinking 字段——自定义端点是
// 通用接口，不得接收它不理解的 thinking 参数。
func TestCustom_BuildRequest_ThinkingSpec_NoThinkingFields(t *testing.T) {
	for _, mode := range []string{"on", "off", "auto"} {
		r := minimalReq("my-model")
		r.Thinking = &ThinkingSpec{Mode: mode, Effort: "high", Budget: 4096}
		body := buildProviderBody(t, "custom", "http://localhost:8080", r)
		assertNoThinkingFields(t, body)
		if bytes.Contains(body, []byte(`"thinking"`)) {
			t.Errorf("mode=%s: 'thinking' field must be absent; body: %s", mode, body)
		}
		if bytes.Contains(body, []byte(`"reasoning"`)) {
			t.Errorf("mode=%s: 'reasoning' field must be absent; body: %s", mode, body)
		}
	}
}

// TestCustom_BuildRequest_NilThinking_NoThinkingFields regression guard.
//
// nil Thinking 回归守卫。
func TestCustom_BuildRequest_NilThinking_NoThinkingFields(t *testing.T) {
	body := buildProviderBody(t, "custom", "http://localhost:8080", minimalReq("my-model"))
	assertNoThinkingFields(t, body)
}

// TestCustom_BuildRequest_URL_IsChatCompletions verifies the request URL is
// base + /chat/completions.
//
// 验证 custom 请求 URL 为 base + /chat/completions。
func TestCustom_BuildRequest_URL_IsChatCompletions(t *testing.T) {
	p := newCustomProvider()
	req := Request{
		ModelID:  "my-model",
		BaseURL:  "http://localhost:8080",
		Key:      "k",
		Messages: []LLMMessage{{Role: RoleUser, Content: "hi"}},
	}
	httpReq, err := p.BuildRequest(context.Background(), req)
	if err != nil {
		t.Fatalf("BuildRequest: %v", err)
	}
	want := "http://localhost:8080/chat/completions"
	if httpReq.URL.String() != want {
		t.Errorf("URL = %q, want %q", httpReq.URL.String(), want)
	}
}

// TestCustom_DefaultBaseURL verifies custom DefaultBaseURL is empty (caller must supply).
//
// 验证 custom DefaultBaseURL 为空（caller 必须提供）。
func TestCustom_DefaultBaseURL(t *testing.T) {
	p := newCustomProvider()
	if got := p.DefaultBaseURL(); got != "" {
		t.Errorf("DefaultBaseURL = %q, want empty (caller must supply)", got)
	}
}

// ──────────────────────────────────────────────────────────────────────────────
// L2: ParseStream via httptest
// ──────────────────────────────────────────────────────────────────────────────

// TestCustom_ParseStream_StandardContent verifies standard content + finish
// through the custom provider.
//
// 验证 custom provider 标准 content delta + finish 流式解析。
func TestCustom_ParseStream_StandardContent(t *testing.T) {
	fixture := `data: {"choices":[{"delta":{"content":"Hello "},"finish_reason":null}]}

data: {"choices":[{"delta":{"content":"world"},"finish_reason":"stop"}],"usage":{"prompt_tokens":5,"completion_tokens":2}}

data: [DONE]
`
	srv := sseServer(fixture)
	defer srv.Close()

	resp, err := newHTTPGetFromServer(srv)
	if err != nil {
		t.Fatalf("http.Get: %v", err)
	}
	p := newCustomProvider()
	req := Request{ModelID: "my-model", BaseURL: srv.URL}
	var events []StreamEvent
	for ev := range p.ParseStream(context.Background(), resp, req) {
		events = append(events, ev)
	}

	texts := filterType(events, EventText)
	if len(texts) != 2 || texts[0].Delta != "Hello " || texts[1].Delta != "world" {
		t.Errorf("text events = %+v", texts)
	}
	finishes := filterType(events, EventFinish)
	if len(finishes) != 1 || finishes[0].FinishReason != "stop" {
		t.Errorf("finishes = %+v", finishes)
	}
	if finishes[0].InputTokens != 5 || finishes[0].OutputTokens != 2 {
		t.Errorf("usage: in=%d out=%d, want 5/2", finishes[0].InputTokens, finishes[0].OutputTokens)
	}
}

// TestCustom_ParseStream_ReasoningContentPassthrough verifies that reasoning_content
// from a compatible upstream endpoint is passed through to EventReasoning.
//
// 验证来自兼容上游的 reasoning_content 透传为 EventReasoning。
func TestCustom_ParseStream_ReasoningContentPassthrough(t *testing.T) {
	fixture := `data: {"choices":[{"delta":{"reasoning_content":"thinking..."},"finish_reason":null}]}

data: {"choices":[{"delta":{"content":"answer"},"finish_reason":"stop"}]}

data: [DONE]
`
	srv := sseServer(fixture)
	defer srv.Close()

	resp, err := newHTTPGetFromServer(srv)
	if err != nil {
		t.Fatalf("http.Get: %v", err)
	}
	p := newCustomProvider()
	req := Request{ModelID: "my-model", BaseURL: srv.URL}
	var events []StreamEvent
	for ev := range p.ParseStream(context.Background(), resp, req) {
		events = append(events, ev)
	}

	reasoning := filterType(events, EventReasoning)
	if len(reasoning) != 1 || reasoning[0].Delta != "thinking..." {
		t.Errorf("reasoning passthrough: events = %+v", reasoning)
	}
}

// newHTTPGetFromServer is a test helper that issues a plain GET to the given server.
//
// newHTTPGetFromServer 向测试服务器发 GET 请求的辅助函数。
func newHTTPGetFromServer(srv *httptest.Server) (*http.Response, error) {
	return http.Get(srv.URL)
}
