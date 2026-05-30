package llm

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
)

// ──────────────────────────────────────────────────────────────────────────────
// L1: BuildRequest shape (Ollama golden wire format per 03 §11)
// ──────────────────────────────────────────────────────────────────────────────

// TestOllama_BuildRequest_GoldenShape verifies the Ollama BuildRequest wire
// shape: model, messages, stream:true (no tools), no thinking fields.
// Matches 03 §11.
//
// 验证 Ollama BuildRequest wire shape：model/messages/stream:true（无 tools），
// 无 thinking 字段；对照 03 §11。
func TestOllama_BuildRequest_GoldenShape(t *testing.T) {
	p := newOllamaProvider()
	req := Request{
		ModelID: "deepseek-r1",
		BaseURL: "http://localhost:11434/v1",
		Key:     "ollama",
		Messages: []LLMMessage{
			{Role: RoleUser, Content: "Weather in Toronto?"},
		},
	}
	httpReq, err := p.BuildRequest(context.Background(), req)
	if err != nil {
		t.Fatalf("BuildRequest: %v", err)
	}

	var body ollamaRequest
	if err := json.NewDecoder(httpReq.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}

	if body.Model != "deepseek-r1" {
		t.Errorf("model = %q, want deepseek-r1", body.Model)
	}
	if !body.Stream {
		t.Error("stream must be true (no tools present)")
	}
	if body.StreamOptions == nil || !body.StreamOptions.IncludeUsage {
		t.Error("stream_options.include_usage must be true")
	}
	if body.ReasoningEffort != "" {
		t.Errorf("nil Thinking → reasoning_effort must be absent; got %q", body.ReasoningEffort)
	}
}

// TestOllama_BuildRequest_ToolsForceNonStreaming verifies that tools present
// forces stream:false and stream_options absent. Matches the stream-disable quirk.
//
// 验证有 tools 时强制 stream:false 且 stream_options 缺失；对照流式关闭 quirk。
func TestOllama_BuildRequest_ToolsForceNonStreaming(t *testing.T) {
	p := newOllamaProvider()
	req := Request{
		ModelID: "qwen3",
		BaseURL: "http://localhost:11434/v1",
		Key:     "ollama",
		Messages: []LLMMessage{
			{Role: RoleUser, Content: "search for cats"},
		},
		Tools: []ToolDef{{
			Name:       "search",
			Parameters: json.RawMessage(`{"type":"object","properties":{}}`),
		}},
	}
	httpReq, err := p.BuildRequest(context.Background(), req)
	if err != nil {
		t.Fatalf("BuildRequest: %v", err)
	}

	var body ollamaRequest
	if err := json.NewDecoder(httpReq.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}

	if body.Stream {
		t.Error("stream must be false when tools present (Ollama drops tool_calls when streaming)")
	}
	if body.StreamOptions != nil {
		t.Error("stream_options must be absent when non-streaming")
	}
	if len(body.Tools) != 1 {
		t.Errorf("tools = %d, want 1", len(body.Tools))
	}
}

// TestOllama_BuildRequest_ThinkingOn_ReasoningEffortHigh verifies Mode="on"+Effort="high"
// emits reasoning_effort:"high". Matches 03 §11.
//
// 验证 Ollama Mode="on"+Effort="high" emit reasoning_effort:"high"，对照 03 §11。
func TestOllama_BuildRequest_ThinkingOn_ReasoningEffortHigh(t *testing.T) {
	r := minimalReq("deepseek-r1")
	r.Thinking = &ThinkingSpec{Mode: "on", Effort: "high"}
	body := buildProviderBody(t, "ollama", "http://localhost:11434/v1", r)

	var parsed map[string]json.RawMessage
	if err := json.Unmarshal(body, &parsed); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if _, ok := parsed["reasoning_effort"]; !ok {
		t.Fatalf("body missing 'reasoning_effort' field; body: %s", body)
	}
	var effort string
	json.Unmarshal(parsed["reasoning_effort"], &effort)
	if effort != "high" {
		t.Errorf("reasoning_effort = %q, want high", effort)
	}
	if _, ok := parsed["thinking"]; ok {
		t.Errorf("ollama must not emit 'thinking' object; body: %s", body)
	}
}

// TestOllama_BuildRequest_ThinkingOn_EmptyEffort_DefaultsMedium verifies
// empty Effort defaults to "medium".
//
// 验证 Ollama 空 Effort 默认 "medium"。
func TestOllama_BuildRequest_ThinkingOn_EmptyEffort_DefaultsMedium(t *testing.T) {
	r := minimalReq("deepseek-r1")
	r.Thinking = &ThinkingSpec{Mode: "on", Effort: ""}
	body := buildProviderBody(t, "ollama", "http://localhost:11434/v1", r)

	var parsed map[string]json.RawMessage
	json.Unmarshal(body, &parsed)
	var effort string
	json.Unmarshal(parsed["reasoning_effort"], &effort)
	if effort != "medium" {
		t.Errorf("empty Effort should default to medium; got %q", effort)
	}
}

// TestOllama_BuildRequest_ThinkingOff_EmitsNone verifies Mode="off" emits
// reasoning_effort:"none".
//
// 验证 Ollama Mode="off" emit reasoning_effort:"none"。
func TestOllama_BuildRequest_ThinkingOff_EmitsNone(t *testing.T) {
	r := minimalReq("deepseek-r1")
	r.Thinking = &ThinkingSpec{Mode: "off"}
	body := buildProviderBody(t, "ollama", "http://localhost:11434/v1", r)

	var parsed map[string]json.RawMessage
	json.Unmarshal(body, &parsed)
	var effort string
	json.Unmarshal(parsed["reasoning_effort"], &effort)
	if effort != "none" {
		t.Errorf("Mode=off reasoning_effort = %q, want none", effort)
	}
}

// TestOllama_BuildRequest_NilThinking_NoThinkingFields verifies nil Thinking
// emits no thinking fields.
//
// 验证 nil Thinking 不含任何 thinking 字段。
func TestOllama_BuildRequest_NilThinking_NoThinkingFields(t *testing.T) {
	body := buildProviderBody(t, "ollama", "http://localhost:11434/v1", minimalReq("deepseek-r1"))
	assertNoThinkingFields(t, body)
}

// TestOllama_DefaultBaseURL verifies Ollama DefaultBaseURL is empty (caller must supply).
//
// 验证 Ollama DefaultBaseURL 为空（caller 必须提供）。
func TestOllama_DefaultBaseURL(t *testing.T) {
	p := newOllamaProvider()
	if got := p.DefaultBaseURL(); got != "" {
		t.Errorf("DefaultBaseURL = %q, want empty (caller must supply)", got)
	}
}

// ──────────────────────────────────────────────────────────────────────────────
// L2: ParseStream via httptest
// ──────────────────────────────────────────────────────────────────────────────

// collectOllamaFromServer points ollamaProvider at the given test server and
// collects all StreamEvents from ParseStream.
//
// collectOllamaFromServer 把 ollamaProvider 指向测试服务器，收集所有 StreamEvent。
func collectOllamaFromServer(t *testing.T, srv *httptest.Server) []StreamEvent {
	t.Helper()
	resp, err := http.Get(srv.URL)
	if err != nil {
		t.Fatalf("http.Get: %v", err)
	}
	p := newOllamaProvider()
	req := Request{ModelID: "deepseek-r1", BaseURL: srv.URL}
	var events []StreamEvent
	for ev := range p.ParseStream(context.Background(), resp, req) {
		events = append(events, ev)
	}
	return events
}

// TestOllama_ParseStream_ReasoningField verifies Ollama /v1 delta.reasoning (no
// underscore) is correctly mapped to EventReasoning. This is the critical Ollama
// distinction: "reasoning" NOT "reasoning_content".
//
// 验证 Ollama /v1 delta.reasoning（无下划线）正确映射为 EventReasoning。
// 这是 Ollama 与 CN 家族的关键区别：用 "reasoning" 而非 "reasoning_content"。
func TestOllama_ParseStream_ReasoningField(t *testing.T) {
	fixture := `data: {"choices":[{"delta":{"reasoning":"I should check the weather API first."},"finish_reason":null}]}

data: {"choices":[{"delta":{"content":"The weather in Toronto is rainy."},"finish_reason":"stop"}]}

data: [DONE]
`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectOllamaFromServer(t, srv)

	reasoning := filterType(events, EventReasoning)
	if len(reasoning) != 1 || reasoning[0].Delta != "I should check the weather API first." {
		t.Errorf("ollama reasoning field: events = %+v", reasoning)
	}
	texts := filterType(events, EventText)
	if len(texts) != 1 || texts[0].Delta != "The weather in Toronto is rainy." {
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

// TestOllama_ParseStream_NonStreaming_WithTools verifies the non-streaming path
// (used when tools are present) correctly synthesizes StreamEvents including
// reasoning (Ollama "reasoning" field).
//
// 验证非流式路径（有 tools 时使用）正确合成 StreamEvent，包括 reasoning 字段。
func TestOllama_ParseStream_NonStreaming_WithTools(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, `{
			"choices": [{
				"message": {
					"role": "assistant",
					"content": "",
					"reasoning": "Let me use the search tool.",
					"tool_calls": [
						{"index": 0, "id": "call_X", "function": {"name": "search", "arguments": "{\"q\":\"toronto weather\"}"}}
					]
				},
				"finish_reason": "tool_calls"
			}],
			"usage": {"prompt_tokens": 20, "completion_tokens": 8}
		}`)
	}))
	defer srv.Close()

	resp, err := http.Get(srv.URL)
	if err != nil {
		t.Fatalf("http.Get: %v", err)
	}
	p := newOllamaProvider()
	// DisableStream=true simulates the tools-present path.
	// DisableStream=true 模拟有 tools 时的场景。
	req := Request{ModelID: "qwen3", BaseURL: srv.URL, DisableStream: true}
	var events []StreamEvent
	for ev := range p.ParseStream(context.Background(), resp, req) {
		events = append(events, ev)
	}

	reasoning := filterType(events, EventReasoning)
	if len(reasoning) != 1 || reasoning[0].Delta != "Let me use the search tool." {
		t.Errorf("reasoning events = %+v", reasoning)
	}
	starts := filterType(events, EventToolStart)
	if len(starts) != 1 || starts[0].ToolName != "search" {
		t.Errorf("tool starts = %+v", starts)
	}
	deltas := filterType(events, EventToolDelta)
	if len(deltas) != 1 || deltas[0].ArgsDelta != `{"q":"toronto weather"}` {
		t.Errorf("tool deltas = %+v", deltas)
	}
	finishes := filterType(events, EventFinish)
	if len(finishes) != 1 || finishes[0].FinishReason != "tool_calls" {
		t.Errorf("finishes = %+v", finishes)
	}
	if finishes[0].InputTokens != 20 || finishes[0].OutputTokens != 8 {
		t.Errorf("usage: in=%d out=%d, want 20/8", finishes[0].InputTokens, finishes[0].OutputTokens)
	}
}

// TestOllama_ParseStream_UsageChunk verifies usage-only chunks emit EventFinish.
//
// 验证 usage-only chunk 正确 emit EventFinish（含 token 数）。
func TestOllama_ParseStream_UsageChunk(t *testing.T) {
	fixture := `data: {"choices":[{"delta":{"content":"hi"},"finish_reason":"stop"}]}

data: {"choices":[],"usage":{"prompt_tokens":5,"completion_tokens":1}}

data: [DONE]
`
	srv := sseServer(fixture)
	defer srv.Close()
	events := collectOllamaFromServer(t, srv)

	finishes := filterType(events, EventFinish)
	found := false
	for _, f := range finishes {
		if f.InputTokens == 5 && f.OutputTokens == 1 {
			found = true
		}
	}
	if !found {
		t.Errorf("no EventFinish with usage tokens 5/1; got: %+v", finishes)
	}
}
