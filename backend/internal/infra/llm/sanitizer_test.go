package llm

import "testing"

func TestSanitizeMessagesKeepsPaired(t *testing.T) {
	out := SanitizeMessages([]LLMMessage{
		{Role: RoleUser, Content: "q"},
		{Role: RoleAssistant, ToolCalls: []LLMToolCall{{ID: "t1", Name: "f"}}},
		{Role: RoleTool, ToolCallID: "t1", Content: "result"},
	})
	if len(out) != 3 {
		t.Errorf("paired call+result: len = %d, want 3", len(out))
	}
}

func TestSanitizeMessagesStubsOrphanToolCall(t *testing.T) {
	out := SanitizeMessages([]LLMMessage{
		{Role: RoleAssistant, ToolCalls: []LLMToolCall{{ID: "t1", Name: "f"}}},
	})
	if len(out) != 2 || out[1].Role != RoleTool || out[1].ToolCallID != "t1" {
		t.Fatalf("orphan tool_call should get a stub reply: %+v", out)
	}
	if out[1].Content == "" {
		t.Error("stub reply should carry an interrupted marker")
	}
}

func TestSanitizeMessagesStubsOnlyMissingCallsInBatch(t *testing.T) {
	out := SanitizeMessages([]LLMMessage{
		{Role: RoleUser, Content: "q"},
		{Role: RoleAssistant, ToolCalls: []LLMToolCall{
			{ID: "done", Name: "finished"},
			{ID: "cancelled", Name: "interrupted"},
		}},
		{Role: RoleTool, ToolCallID: "done", Content: "real result"},
		{Role: RoleUser, Content: "continue"},
	})
	if len(out) != 5 {
		t.Fatalf("sanitized batch = %+v, want user + assistant + result + stub + next user", out)
	}
	if out[2].Role != RoleTool || out[2].ToolCallID != "done" || out[2].Content != "real result" {
		t.Fatalf("completed tool result changed: %+v", out[2])
	}
	if out[3].Role != RoleTool || out[3].ToolCallID != "cancelled" || out[3].Content == "" {
		t.Fatalf("missing call was not stubbed: %+v", out[3])
	}
	if out[4].Role != RoleUser || out[4].Content != "continue" {
		t.Fatalf("next user message was not preserved: %+v", out[4])
	}
}

func TestSanitizeMessagesDropsStrayTool(t *testing.T) {
	out := SanitizeMessages([]LLMMessage{
		{Role: RoleUser, Content: "q"},
		{Role: RoleTool, ToolCallID: "orphan", Content: "x"}, // no preceding assistant tool_call
	})
	if len(out) != 1 || out[0].Role != RoleUser {
		t.Errorf("stray tool result should be dropped: %+v", out)
	}
}
