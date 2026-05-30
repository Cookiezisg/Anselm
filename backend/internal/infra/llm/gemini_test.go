package llm

// gemini_test.go — native generateContent provider tests: golden BuildRequest
// (contents/role mapping, systemInstruction, tools.functionDeclarations,
// thinkingConfig, model-in-path URL, x-goog-api-key) + httptest ParseStream of
// a native SSE fixture (thought part + signature + text + functionCall + usage).
//
// The OpenAI-compat assertions are obsolete: google now speaks its own native
// dialect (reasoning-text readback + thoughtSignature round-trip).

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

// buildGeminiBody fires the native google provider's BuildRequest and returns
// the parsed body plus the constructed *http.Request (for URL/header asserts).
//
// buildGeminiBody 调原生 google provider 的 BuildRequest，返回解析后的 body
// 与构造出的 *http.Request（供 URL/header 断言）。
func buildGeminiBody(t *testing.T, req Request) (geminiRequest, *http.Request) {
	t.Helper()
	p, ok := providerRegistry["google"]
	if !ok {
		t.Fatal("google provider not in registry")
	}
	req.BaseURL = geminiDefaultBaseURL
	httpReq, err := p.BuildRequest(context.Background(), req)
	if err != nil {
		t.Fatalf("BuildRequest: %v", err)
	}
	var body geminiRequest
	if err := json.NewDecoder(httpReq.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	return body, httpReq
}

// ──────────────────────────────────────────────────────────────────────────────
// L1: golden BuildRequest — native body + URL + auth header
// ──────────────────────────────────────────────────────────────────────────────

// TestGemini_BuildRequest_NativeShape feeds a chat+tools+thinking request and
// asserts the full native wire shape: contents role mapping, systemInstruction,
// tools.functionDeclarations, generationConfig.thinkingConfig, the
// model-in-path streaming URL, and the x-goog-api-key header.
//
// TestGemini_BuildRequest_NativeShape 用 chat+tools+thinking 请求断言完整原生
// wire 形状：contents 角色映射、systemInstruction、tools.functionDeclarations、
// thinkingConfig、model-in-path 流式 URL、x-goog-api-key 头。
func TestGemini_BuildRequest_NativeShape(t *testing.T) {
	req := Request{
		ModelID: "gemini-2.5-flash",
		Key:     "aistudio-test-key",
		System:  "You are a weather assistant.",
		Messages: []LLMMessage{
			{Role: RoleUser, Content: "Weather in SF?"},
		},
		Tools: []ToolDef{{
			Name:        "get_weather",
			Description: "Get current weather",
			Parameters:  json.RawMessage(`{"type":"object","properties":{"location":{"type":"string"}},"required":["location"]}`),
		}},
		Thinking: &ThinkingSpec{Mode: "on", Budget: 1024},
	}
	body, httpReq := buildGeminiBody(t, req)

	// URL: model in the PATH + streaming + alt=sse.
	wantURL := geminiDefaultBaseURL + "/models/gemini-2.5-flash:streamGenerateContent?alt=sse"
	if httpReq.URL.String() != wantURL {
		t.Errorf("URL = %q, want %q", httpReq.URL.String(), wantURL)
	}
	// Auth header.
	if got := httpReq.Header.Get("x-goog-api-key"); got != "aistudio-test-key" {
		t.Errorf("x-goog-api-key = %q, want aistudio-test-key", got)
	}
	if got := httpReq.Header.Get("Authorization"); got != "" {
		t.Errorf("native Gemini must not send Authorization, got %q", got)
	}

	// systemInstruction.
	if body.SystemInstruction == nil || len(body.SystemInstruction.Parts) != 1 ||
		body.SystemInstruction.Parts[0].Text != "You are a weather assistant." {
		t.Errorf("systemInstruction = %+v, want single text part", body.SystemInstruction)
	}

	// contents: one user turn, role "user", text part.
	if len(body.Contents) != 1 {
		t.Fatalf("contents len = %d, want 1", len(body.Contents))
	}
	if body.Contents[0].Role != "user" {
		t.Errorf("contents[0].role = %q, want user", body.Contents[0].Role)
	}
	if len(body.Contents[0].Parts) != 1 || body.Contents[0].Parts[0].Text != "Weather in SF?" {
		t.Errorf("contents[0].parts = %+v, want single text", body.Contents[0].Parts)
	}

	// tools.functionDeclarations.
	if len(body.Tools) != 1 || len(body.Tools[0].FunctionDeclarations) != 1 {
		t.Fatalf("tools = %+v, want one functionDeclaration", body.Tools)
	}
	fd := body.Tools[0].FunctionDeclarations[0]
	if fd.Name != "get_weather" {
		t.Errorf("functionDeclaration.name = %q, want get_weather", fd.Name)
	}
	var schema map[string]any
	if err := json.Unmarshal(fd.Parameters, &schema); err != nil {
		t.Errorf("functionDeclaration.parameters not valid JSON schema: %v", err)
	}
	if schema["type"] != "object" {
		t.Errorf("functionDeclaration.parameters.type = %v, want object", schema["type"])
	}

	// generationConfig.thinkingConfig.
	if body.GenerationConfig == nil || body.GenerationConfig.ThinkingConfig == nil {
		t.Fatalf("generationConfig.thinkingConfig missing: %+v", body.GenerationConfig)
	}
	tc := body.GenerationConfig.ThinkingConfig
	if tc.ThinkingBudget == nil || *tc.ThinkingBudget != 1024 {
		t.Errorf("thinkingBudget = %v, want 1024", tc.ThinkingBudget)
	}
	if !tc.IncludeThoughts {
		t.Error("thinkingConfig.includeThoughts must be true when thinking is on")
	}
}

// TestGemini_BuildRequest_RoleMappingAndToolLoop asserts the assistant→"model"
// / tool→"user"+functionResponse mapping across a multi-turn tool loop, and that
// functionResponse recovers the function NAME from the preceding functionCall.
//
// TestGemini_BuildRequest_RoleMappingAndToolLoop 断言多轮工具循环里
// assistant→"model" / tool→"user"+functionResponse 的映射，且 functionResponse
// 从前序 functionCall 找回函数名。
func TestGemini_BuildRequest_RoleMappingAndToolLoop(t *testing.T) {
	req := Request{
		ModelID: "gemini-2.5-flash",
		Key:     "k",
		Messages: []LLMMessage{
			{Role: RoleUser, Content: "Weather in SF?"},
			{
				Role:               RoleAssistant,
				ReasoningContent:   "I should call the weather tool.",
				ReasoningSignature: "sig-abc",
				ToolCalls: []LLMToolCall{
					{ID: "call_1", Name: "get_weather", Arguments: `{"location":"SF"}`},
				},
			},
			{Role: RoleTool, ToolCallID: "call_1", Content: `{"tempC":18}`},
		},
	}
	body, _ := buildGeminiBody(t, req)

	if len(body.Contents) != 3 {
		t.Fatalf("contents len = %d, want 3 (user, model, tool→user)", len(body.Contents))
	}

	// Turn 0: user.
	if body.Contents[0].Role != "user" {
		t.Errorf("contents[0].role = %q, want user", body.Contents[0].Role)
	}

	// Turn 1: assistant → "model", reasoning part (with signature) + functionCall.
	model := body.Contents[1]
	if model.Role != "model" {
		t.Errorf("contents[1].role = %q, want model", model.Role)
	}
	var sawThought, sawCall bool
	for _, p := range model.Parts {
		if p.Thought {
			sawThought = true
			if p.ThoughtSignature != "sig-abc" {
				t.Errorf("thought part signature = %q, want sig-abc", p.ThoughtSignature)
			}
			if p.Text != "I should call the weather tool." {
				t.Errorf("thought part text = %q", p.Text)
			}
		}
		if p.FunctionCall != nil {
			sawCall = true
			if p.FunctionCall.Name != "get_weather" {
				t.Errorf("functionCall.name = %q, want get_weather", p.FunctionCall.Name)
			}
			if p.FunctionCall.ID != "call_1" {
				t.Errorf("functionCall.id = %q, want call_1", p.FunctionCall.ID)
			}
			var args map[string]any
			if err := json.Unmarshal(p.FunctionCall.Args, &args); err != nil {
				t.Errorf("functionCall.args not valid JSON: %v", err)
			}
			if args["location"] != "SF" {
				t.Errorf("functionCall.args.location = %v, want SF", args["location"])
			}
		}
	}
	if !sawThought {
		t.Error("model turn must carry the reasoning thought part (signature round-trip)")
	}
	if !sawCall {
		t.Error("model turn must carry the functionCall part")
	}

	// Turn 2: tool → "user" with functionResponse keyed by NAME (recovered) + id.
	toolTurn := body.Contents[2]
	if toolTurn.Role != "user" {
		t.Errorf("contents[2].role = %q, want user (tool response)", toolTurn.Role)
	}
	if len(toolTurn.Parts) != 1 || toolTurn.Parts[0].FunctionResponse == nil {
		t.Fatalf("tool turn must have one functionResponse part, got %+v", toolTurn.Parts)
	}
	fr := toolTurn.Parts[0].FunctionResponse
	if fr.Name != "get_weather" {
		t.Errorf("functionResponse.name = %q, want get_weather (recovered from preceding call)", fr.Name)
	}
	if fr.ID != "call_1" {
		t.Errorf("functionResponse.id = %q, want call_1", fr.ID)
	}
	// response is already a JSON object → passed through.
	var resp map[string]any
	if err := json.Unmarshal(fr.Response, &resp); err != nil {
		t.Errorf("functionResponse.response not valid JSON object: %v", err)
	}
	if resp["tempC"] != float64(18) {
		t.Errorf("functionResponse.response.tempC = %v, want 18", resp["tempC"])
	}
}

// TestGemini_BuildRequest_WrapsNonObjectToolResult asserts plain-string tool
// output is wrapped as {"result": <text>} so functionResponse.response stays a
// JSON object (Gemini requires an object).
//
// TestGemini_BuildRequest_WrapsNonObjectToolResult 断言纯字符串 tool 输出被
// 包装为 {"result": <text>}，保证 functionResponse.response 是 JSON object。
func TestGemini_BuildRequest_WrapsNonObjectToolResult(t *testing.T) {
	req := Request{
		ModelID: "gemini-2.5-flash",
		Key:     "k",
		Messages: []LLMMessage{
			{Role: RoleAssistant, ToolCalls: []LLMToolCall{{ID: "c1", Name: "echo", Arguments: `{}`}}},
			{Role: RoleTool, ToolCallID: "c1", Content: "plain text result"},
		},
	}
	body, _ := buildGeminiBody(t, req)
	fr := body.Contents[len(body.Contents)-1].Parts[0].FunctionResponse
	if fr == nil {
		t.Fatal("expected functionResponse part")
	}
	var resp map[string]string
	if err := json.Unmarshal(fr.Response, &resp); err != nil {
		t.Fatalf("response not a JSON object: %v (raw %s)", err, fr.Response)
	}
	if resp["result"] != "plain text result" {
		t.Errorf("wrapped response = %v, want {result: plain text result}", resp)
	}
}

// TestGemini_BuildRequest_NonStreamingURL asserts DisableStream switches the URL
// method to :generateContent (no alt=sse).
//
// TestGemini_BuildRequest_NonStreamingURL 断言 DisableStream 把 URL 方法切到
// :generateContent（无 alt=sse）。
func TestGemini_BuildRequest_NonStreamingURL(t *testing.T) {
	req := Request{
		ModelID:       "gemini-2.5-flash",
		Key:           "k",
		Messages:      []LLMMessage{{Role: RoleUser, Content: "hi"}},
		DisableStream: true,
	}
	_, httpReq := buildGeminiBody(t, req)
	want := geminiDefaultBaseURL + "/models/gemini-2.5-flash:generateContent"
	if httpReq.URL.String() != want {
		t.Errorf("URL = %q, want %q", httpReq.URL.String(), want)
	}
}

// ──────────────────────────────────────────────────────────────────────────────
// L2: ParseStream — native generateContent SSE
// ──────────────────────────────────────────────────────────────────────────────

// collectGeminiStream points the native google provider at an SSE test server,
// fires ParseStream, and returns all events.
//
// collectGeminiStream 把原生 google provider 指向 SSE 测试服务器，跑 ParseStream，
// 返回全部事件。
func collectGeminiStream(t *testing.T, fixture string) []StreamEvent {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(fixture))
	}))
	defer srv.Close()

	resp, err := http.Get(srv.URL)
	if err != nil {
		t.Fatalf("http.Get: %v", err)
	}
	p := newGeminiProvider()
	req := Request{ModelID: "gemini-2.5-flash", BaseURL: srv.URL}
	var events []StreamEvent
	for ev := range p.ParseStream(context.Background(), resp, req) {
		events = append(events, ev)
	}
	return events
}

// TestParseStream_Gemini_ThoughtTextToolAndUsage feeds a native SSE fixture with
// a thought part (carrying thoughtSignature), a text part, a functionCall part,
// and usageMetadata, and asserts:
//   - EventReasoning for the thought text + a signature-carrying EventReasoning
//   - EventText for the visible text
//   - EventToolStart + EventToolDelta (full args, since Gemini sends the
//     complete functionCall, not deltas)
//   - EventFinish with summed token counts (candidates + thoughts)
//
// TestParseStream_Gemini_ThoughtTextToolAndUsage 用含 thought（带签名）/ text /
// functionCall / usageMetadata 的原生 SSE fixture 断言 reasoning(+signature) /
// text / tool(full args) / finish(token 合计) 解析正确。
func TestParseStream_Gemini_ThoughtTextToolAndUsage(t *testing.T) {
	fixture := `data: {"candidates":[{"content":{"role":"model","parts":[{"text":"Let me think about the weather.","thought":true,"thoughtSignature":"sig-xyz"}]}}]}

data: {"candidates":[{"content":{"role":"model","parts":[{"text":"It is sunny in SF."}]}}]}

data: {"candidates":[{"content":{"role":"model","parts":[{"functionCall":{"id":"fc_1","name":"get_weather","args":{"location":"SF"}}}]}}]}

data: {"candidates":[{"content":{"role":"model","parts":[]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":12,"candidatesTokenCount":8,"thoughtsTokenCount":40}}

`
	events := collectGeminiStream(t, fixture)

	// Reasoning: one text-carrying + one signature-carrying event.
	reasoning := filterType(events, EventReasoning)
	if len(reasoning) != 2 {
		t.Fatalf("want 2 EventReasoning (text + signature), got %d: %+v", len(reasoning), reasoning)
	}
	if reasoning[0].Delta != "Let me think about the weather." {
		t.Errorf("reasoning text = %q", reasoning[0].Delta)
	}
	if reasoning[1].Signature != "sig-xyz" {
		t.Errorf("reasoning signature = %q, want sig-xyz", reasoning[1].Signature)
	}

	// Text.
	texts := filterType(events, EventText)
	if len(texts) != 1 || texts[0].Delta != "It is sunny in SF." {
		t.Errorf("text events = %+v", texts)
	}

	// Tool: start + full-args delta.
	starts := filterType(events, EventToolStart)
	if len(starts) != 1 {
		t.Fatalf("want 1 EventToolStart, got %d", len(starts))
	}
	if starts[0].ToolName != "get_weather" || starts[0].ToolID != "fc_1" {
		t.Errorf("tool start = name:%q id:%q, want get_weather/fc_1", starts[0].ToolName, starts[0].ToolID)
	}
	deltas := filterType(events, EventToolDelta)
	if len(deltas) != 1 {
		t.Fatalf("want 1 EventToolDelta (complete args), got %d", len(deltas))
	}
	var args map[string]any
	if err := json.Unmarshal([]byte(deltas[0].ArgsDelta), &args); err != nil {
		t.Errorf("tool args not valid JSON: %q err: %v", deltas[0].ArgsDelta, err)
	}
	if args["location"] != "SF" {
		t.Errorf("tool args.location = %v, want SF", args["location"])
	}

	// Finish: tokens summed (candidates 8 + thoughts 40 = 48 output).
	finishes := filterType(events, EventFinish)
	if len(finishes) != 1 {
		t.Fatalf("want 1 EventFinish, got %d", len(finishes))
	}
	if finishes[0].FinishReason != "STOP" {
		t.Errorf("finishReason = %q, want STOP", finishes[0].FinishReason)
	}
	if finishes[0].InputTokens != 12 {
		t.Errorf("InputTokens = %d, want 12", finishes[0].InputTokens)
	}
	if finishes[0].OutputTokens != 48 {
		t.Errorf("OutputTokens = %d, want 48 (8 candidates + 40 thoughts)", finishes[0].OutputTokens)
	}

	if errs := filterType(events, EventError); len(errs) != 0 {
		t.Errorf("unexpected error events: %+v", errs)
	}
}

// TestParseStream_Gemini_TextOnly verifies the simplest native path: a single
// text part then a STOP finish with usage.
//
// TestParseStream_Gemini_TextOnly 验证最简原生路径：单 text part + STOP finish。
func TestParseStream_Gemini_TextOnly(t *testing.T) {
	fixture := `data: {"candidates":[{"content":{"role":"model","parts":[{"text":"Newton, Maxwell, Dirac"}]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":6,"candidatesTokenCount":5}}

`
	events := collectGeminiStream(t, fixture)

	texts := filterType(events, EventText)
	if len(texts) != 1 || texts[0].Delta != "Newton, Maxwell, Dirac" {
		t.Errorf("text events = %+v", texts)
	}
	finishes := filterType(events, EventFinish)
	if len(finishes) != 1 || finishes[0].FinishReason != "STOP" {
		t.Fatalf("finish events = %+v", finishes)
	}
	if finishes[0].InputTokens != 6 || finishes[0].OutputTokens != 5 {
		t.Errorf("usage: in=%d out=%d, want in=6 out=5", finishes[0].InputTokens, finishes[0].OutputTokens)
	}
}
