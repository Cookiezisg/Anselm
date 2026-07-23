package contextcheckpoint

import (
	"context"
	"iter"
	"strings"
	"testing"
	"unicode/utf8"

	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

type checkpointClient struct {
	requests []llminfra.Request
}

func (c *checkpointClient) Stream(_ context.Context, req llminfra.Request) iter.Seq[llminfra.StreamEvent] {
	c.requests = append(c.requests, req)
	return func(yield func(llminfra.StreamEvent) bool) {
		if !yield(llminfra.StreamEvent{Type: llminfra.EventText, Delta: "Goal & constraints: preserve /exact/path and wf_123."}) {
			return
		}
		yield(llminfra.StreamEvent{Type: llminfra.EventFinish, FinishReason: "stop"})
	}
}

func TestCompactOmitsRawMediaAndKeepsCompleteRecentToolGroups(t *testing.T) {
	history := []llminfra.LLMMessage{{
		Role: llminfra.RoleUser,
		Parts: []llminfra.ContentPart{
			{Type: llminfra.PartText, Text: "inspect /exact/path"},
			{Type: llminfra.PartImageURL, ImageURL: "data:image/png;base64,SECRET_RAW_MEDIA"},
		},
	}}
	for _, id := range []string{"call_a", "call_b", "call_c", "call_d"} {
		history = append(history,
			llminfra.LLMMessage{
				Role:             llminfra.RoleAssistant,
				ReasoningContent: "complete reasoning " + id,
				ToolCalls: []llminfra.LLMToolCall{{
					ID: id, Name: "inspect", Arguments: `{"id":"wf_123"}`,
				}},
			},
			llminfra.LLMMessage{Role: llminfra.RoleTool, ToolCallID: id, Content: "exact result " + id},
		)
	}

	client := &checkpointClient{}
	got, err := Compact(context.Background(), client, llminfra.Request{
		System: "old system", Tools: []llminfra.ToolDef{{Name: "must_not_leak"}},
	}, history, 10_000, 3)
	if err != nil {
		t.Fatal(err)
	}
	if len(client.requests) != 1 {
		t.Fatalf("checkpoint requests=%d, want 1", len(client.requests))
	}
	req := client.requests[0]
	if len(req.Tools) != 0 || req.MaxTokens != outputTokens || !strings.Contains(req.System, "continuation checkpoint") {
		t.Fatalf("checkpoint request was not isolated: %+v", req)
	}
	source := req.Messages[0].Content
	if strings.Contains(source, "SECRET_RAW_MEDIA") ||
		!strings.Contains(source, "native media image_url consumed earlier") ||
		!strings.Contains(source, "/exact/path") ||
		!strings.Contains(source, "wf_123") {
		t.Fatalf("unsafe/incomplete checkpoint source: %q", source)
	}
	if len(got) != 7 || !strings.Contains(got[0].Content, "/exact/path") || !strings.Contains(got[0].Content, "wf_123") {
		t.Fatalf("bad compacted prompt: %+v", got)
	}
	for i := 1; i < len(got); i += 2 {
		if got[i].Role != llminfra.RoleAssistant || got[i].ReasoningContent == "" || len(got[i].ToolCalls) == 0 ||
			i+1 >= len(got) || got[i+1].Role != llminfra.RoleTool ||
			got[i+1].ToolCallID != got[i].ToolCalls[0].ID {
			t.Fatalf("recent provider protocol was split at index %d: %+v", i, got)
		}
	}
}

func TestSplitUTF8NeverCutsRune(t *testing.T) {
	source := strings.Repeat("你好a", 5_000)
	chunks := splitUTF8(source, 8*1024)
	if len(chunks) < 2 || strings.Join(chunks, "") != source {
		t.Fatalf("UTF-8 chunking did not round-trip: chunks=%d", len(chunks))
	}
	for i, chunk := range chunks {
		if !utf8.ValidString(chunk) {
			t.Fatalf("chunk %d is invalid UTF-8", i)
		}
	}
}
