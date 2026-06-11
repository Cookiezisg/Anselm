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

func TestSanitizeMessagesDropsStrayTool(t *testing.T) {
	out := SanitizeMessages([]LLMMessage{
		{Role: RoleUser, Content: "q"},
		{Role: RoleTool, ToolCallID: "orphan", Content: "x"}, // no preceding assistant tool_call
	})
	if len(out) != 1 || out[0].Role != RoleUser {
		t.Errorf("stray tool result should be dropped: %+v", out)
	}
}
