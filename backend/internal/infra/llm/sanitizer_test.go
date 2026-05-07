// sanitizer_test.go — exercise the message-history sanitizer that
// guards against orphan tool blocks (the failure mode that locks
// Claude Code conversations into permanent 400 traps when a tool call
// is interrupted before its result returns).
//
// sanitizer_test.go ——演练消息历史 sanitizer，防 orphan tool block 把
// 对话永久锁进 400 陷阱（Claude Code 真实事故）。

package llm

import (
	"testing"
)

func TestSanitize_NoOpOnWellFormed(t *testing.T) {
	in := []LLMMessage{
		{Role: RoleUser, Content: "hi"},
		{Role: RoleAssistant, Content: "let me check", ToolCalls: []LLMToolCall{
			{ID: "call_1", Name: "search", Arguments: "{}"},
		}},
		{Role: RoleTool, ToolCallID: "call_1", Content: "result"},
		{Role: RoleAssistant, Content: "done"},
	}
	out := SanitizeMessages(in)
	if len(out) != 4 {
		t.Fatalf("well-formed history changed length: %d → %d", len(in), len(out))
	}
}

// TestSanitize_MissingToolMessage_StubInserted is the headline failure
// scenario: assistant emits tool_calls but is interrupted before the
// tool result arrives. Without the sanitizer, the next request 400s
// with "tool_calls must be followed by tool messages" and the
// conversation is permanently stuck.
//
// TestSanitize_MissingToolMessage_StubInserted：标志性事故场景。
// assistant 发出 tool_calls 但 tool 结果还没到就被中断；无 sanitizer
// 下次请求 400 锁死。
func TestSanitize_MissingToolMessage_StubInserted(t *testing.T) {
	in := []LLMMessage{
		{Role: RoleAssistant, ToolCalls: []LLMToolCall{
			{ID: "call_X", Name: "search", Arguments: "{}"},
		}},
		// User retries / sends new message — no tool result for call_X.
		// 用户重试或发新消息——没有 call_X 的 tool result。
		{Role: RoleUser, Content: "what happened?"},
	}
	out := SanitizeMessages(in)
	if len(out) != 3 {
		t.Fatalf("want 3 messages (assistant + stub tool + user), got %d", len(out))
	}
	if out[1].Role != RoleTool || out[1].ToolCallID != "call_X" {
		t.Errorf("synthesized tool stub missing or wrong id: %+v", out[1])
	}
	if out[1].Content == "" {
		t.Errorf("stub tool message must have non-empty content (LLM looks at it)")
	}
}

// TestSanitize_PartialMissing_StubsForUnpaired covers the case of a
// parallel tool call where one tool returned but the other didn't.
// Only the missing one should get a stub.
//
// 并行工具调用部分缺失场景：只给缺的合成 stub。
func TestSanitize_PartialMissing_StubsForUnpaired(t *testing.T) {
	in := []LLMMessage{
		{Role: RoleAssistant, ToolCalls: []LLMToolCall{
			{ID: "call_A", Name: "tool_a"},
			{ID: "call_B", Name: "tool_b"},
		}},
		{Role: RoleTool, ToolCallID: "call_A", Content: "A result"},
		// call_B never returned.
	}
	out := SanitizeMessages(in)
	if len(out) != 3 {
		t.Fatalf("want 3 messages, got %d: %+v", len(out), out)
	}
	if out[1].ToolCallID != "call_A" || out[1].Content != "A result" {
		t.Errorf("real tool result mangled: %+v", out[1])
	}
	if out[2].ToolCallID != "call_B" {
		t.Errorf("missing call_B stub")
	}
}

// TestSanitize_StrayToolMessageDropped: a tool message whose ID has no
// matching prior assistant.tool_calls is unusable — the LLM has nothing
// to anchor it to. Drop silently.
//
// 游离 tool message（ID 无匹配 tool_call）→ 丢。
func TestSanitize_StrayToolMessageDropped(t *testing.T) {
	in := []LLMMessage{
		{Role: RoleUser, Content: "hi"},
		{Role: RoleTool, ToolCallID: "call_orphan", Content: "lost result"},
		{Role: RoleAssistant, Content: "hello"},
	}
	out := SanitizeMessages(in)
	if len(out) != 2 {
		t.Fatalf("stray tool message should be dropped; got %d messages: %+v", len(out), out)
	}
	for _, m := range out {
		if m.Role == RoleTool {
			t.Errorf("stray tool survived: %+v", m)
		}
	}
}

// TestSanitize_IDMismatchInRunDropped: tool message whose ID doesn't
// match any of the preceding assistant's tool_calls (despite being in
// the right position) is dropped, and the actual tool_call gets a stub.
//
// 段内 ID 不匹配的 tool message → 丢；真 tool_call 仍补 stub。
func TestSanitize_IDMismatchInRunDropped(t *testing.T) {
	in := []LLMMessage{
		{Role: RoleAssistant, ToolCalls: []LLMToolCall{
			{ID: "call_X"},
		}},
		{Role: RoleTool, ToolCallID: "call_TYPO", Content: "bogus"},
		{Role: RoleUser, Content: "next"},
	}
	out := SanitizeMessages(in)
	if len(out) != 3 {
		t.Fatalf("want 3 messages (assistant + stub + user), got %d: %+v", len(out), out)
	}
	if out[1].ToolCallID != "call_X" {
		t.Errorf("expected stub for call_X, got %+v", out[1])
	}
}

// TestSanitize_Idempotent: running sanitize twice on already-sanitized
// input produces identical output. Important because the function is
// called on every request build — must not amplify or mutate
// previously-stubbed messages.
//
// 幂等性：sanitize 已 sanitize 过的输入结果不变。每次 build 都调，必须
// 不能放大或改动已合成的 stub。
func TestSanitize_Idempotent(t *testing.T) {
	in := []LLMMessage{
		{Role: RoleAssistant, ToolCalls: []LLMToolCall{{ID: "call_1"}}},
		{Role: RoleUser, Content: "next"},
	}
	once := SanitizeMessages(in)
	twice := SanitizeMessages(once)
	if len(once) != len(twice) {
		t.Fatalf("not idempotent: %d → %d", len(once), len(twice))
	}
}

// TestSanitize_EmptyInput: paranoid edge case.
func TestSanitize_EmptyInput(t *testing.T) {
	out := SanitizeMessages(nil)
	if len(out) != 0 {
		t.Errorf("nil input should return nil/empty, got %+v", out)
	}
}
