package llm

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"
)

func geminiBody(t *testing.T, req Request) geminiRequest {
	t.Helper()
	httpReq, err := newGeminiProvider().BuildRequest(context.Background(), req)
	if err != nil {
		t.Fatal(err)
	}
	raw, _ := io.ReadAll(httpReq.Body)
	var gr geminiRequest
	if err := json.Unmarshal(raw, &gr); err != nil {
		t.Fatal(err)
	}
	return gr
}

func TestGeminiBuildRequest(t *testing.T) {
	p := newGeminiProvider()
	req := Request{
		ModelID:   "gemini-2.5-pro",
		Key:       "goog-key",
		BaseURL:   "https://generativelanguage.googleapis.com/v1beta",
		MaxTokens: 4096,
		System:    "be brief",
		Messages:  []LLMMessage{{Role: RoleUser, Content: "hi"}},
		Tools:     []ToolDef{{Name: "f", Description: "d", Parameters: json.RawMessage(`{"type":"object"}`)}},
	}
	httpReq, err := p.BuildRequest(context.Background(), req)
	if err != nil {
		t.Fatal(err)
	}
	// model lives in the URL path, with the SSE query.
	if got := httpReq.URL.String(); !strings.Contains(got, "/models/gemini-2.5-pro:streamGenerateContent") || !strings.Contains(got, "alt=sse") {
		t.Errorf("url = %s", got)
	}
	if httpReq.Header.Get("x-goog-api-key") != "goog-key" {
		t.Errorf("x-goog-api-key = %q", httpReq.Header.Get("x-goog-api-key"))
	}
	raw, _ := io.ReadAll(httpReq.Body)
	var gr geminiRequest
	if err := json.Unmarshal(raw, &gr); err != nil {
		t.Fatal(err)
	}
	if len(gr.Contents) != 1 || gr.Contents[0].Role != "user" {
		t.Errorf("contents = %+v", gr.Contents)
	}
	if gr.SystemInstruction == nil || gr.SystemInstruction.Parts[0].Text != "be brief" {
		t.Errorf("systemInstruction = %+v", gr.SystemInstruction)
	}
	if len(gr.Tools) != 1 || len(gr.Tools[0].FunctionDeclarations) != 1 || gr.Tools[0].FunctionDeclarations[0].Name != "f" {
		t.Errorf("tools = %+v", gr.Tools)
	}
	if gr.GenerationConfig == nil || gr.GenerationConfig.MaxOutputTokens == nil || *gr.GenerationConfig.MaxOutputTokens != 4096 {
		t.Errorf("maxOutputTokens not set from MaxTokens: %+v", gr.GenerationConfig)
	}
}

func TestGeminiThinkingModes(t *testing.T) {
	base := Request{ModelID: "m", Messages: []LLMMessage{{Role: RoleUser, Content: "x"}}}

	base.Thinking = nil
	if gr := geminiBody(t, base); gr.GenerationConfig != nil && gr.GenerationConfig.ThinkingConfig != nil {
		t.Errorf("auto → thinkingConfig should be omitted")
	}
	base.Thinking = &ThinkingSpec{Mode: "off"}
	gr := geminiBody(t, base)
	if gr.GenerationConfig.ThinkingConfig == nil || gr.GenerationConfig.ThinkingConfig.ThinkingBudget == nil || *gr.GenerationConfig.ThinkingConfig.ThinkingBudget != 0 {
		t.Errorf("off → thinkingBudget 0, got %+v", gr.GenerationConfig.ThinkingConfig)
	}
	base.Thinking = &ThinkingSpec{Mode: "on"}
	gr = geminiBody(t, base)
	tc := gr.GenerationConfig.ThinkingConfig
	if tc == nil || tc.ThinkingBudget == nil || *tc.ThinkingBudget != -1 || !tc.IncludeThoughts {
		t.Errorf("on (no budget) → dynamic -1 + includeThoughts, got %+v", tc)
	}
}

func TestGeminiToolResponseResolvesName(t *testing.T) {
	// A tool message's functionResponse must recover the function NAME from the
	// preceding assistant tool_call (Gemini pairs by name).
	gr := geminiBody(t, Request{
		ModelID: "m",
		Messages: []LLMMessage{
			{Role: RoleUser, Content: "q"},
			{Role: RoleAssistant, ToolCalls: []LLMToolCall{{ID: "c1", Name: "get_weather"}}},
			{Role: RoleTool, ToolCallID: "c1", Content: "sunny"},
		},
	})
	last := gr.Contents[len(gr.Contents)-1]
	if last.Role != "user" || len(last.Parts) != 1 || last.Parts[0].FunctionResponse == nil {
		t.Fatalf("tool turn = %+v", last)
	}
	fr := last.Parts[0].FunctionResponse
	if fr.Name != "get_weather" || fr.ID != "c1" {
		t.Errorf("functionResponse name/id = %q/%q, want get_weather/c1", fr.Name, fr.ID)
	}
	// plain-string tool output must be wrapped as a JSON object
	if !strings.Contains(string(fr.Response), `"result"`) {
		t.Errorf("response should wrap plain string: %s", fr.Response)
	}
}

func TestGeminiParseStream(t *testing.T) {
	sse := strings.Join([]string{
		`data: {"candidates":[{"content":{"parts":[{"text":"Hel"}]}}]}`,
		`data: {"candidates":[{"content":{"parts":[{"thought":true,"text":"reason"},{"thought":true,"thoughtSignature":"sig9"}]}}]}`,
		`data: {"candidates":[{"content":{"parts":[{"functionCall":{"name":"f","args":{"x":1}}}]}}]}`,
		`data: {"candidates":[{"content":{"parts":[]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":3,"candidatesTokenCount":2,"thoughtsTokenCount":4}}`,
	}, "\n\n") + "\n\n"

	resp := &http.Response{Body: io.NopCloser(strings.NewReader(sse))}
	events := collect(newGeminiProvider().ParseStream(context.Background(), resp, Request{}))

	var text, reasoning, sig, toolArgs string
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
			if ev.ToolName != "f" {
				t.Errorf("tool_start = %+v", ev)
			}
		case EventToolDelta:
			toolArgs = ev.ArgsDelta
		case EventFinish:
			sawFinish = true
			if ev.FinishReason != "STOP" || ev.InputTokens != 3 || ev.OutputTokens != 6 {
				t.Errorf("finish = %+v (output should sum candidates+thoughts = 6)", ev)
			}
		case EventError:
			t.Fatalf("unexpected error: %v", ev.Err)
		}
	}
	if text != "Hel" || reasoning != "reason" || sig != "sig9" {
		t.Errorf("text=%q reasoning=%q sig=%q", text, reasoning, sig)
	}
	if !sawToolStart || !sawFinish || !strings.Contains(toolArgs, `"x":1`) {
		t.Errorf("toolStart=%v finish=%v args=%q", sawToolStart, sawFinish, toolArgs)
	}
}
