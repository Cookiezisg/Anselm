// sanitizer.go — Protocol-level invariant enforcement for LLM message
// histories before they ship to ANY provider. Both OpenAI-compat and
// Anthropic-native APIs require strict pairing between assistant
// `tool_calls` and the subsequent `tool` (OpenAI) / `tool_result`
// (Anthropic) messages. Mismatches are NOT tolerated — most providers
// respond with HTTP 400 and the conversation is permanently broken
// because every retry replays the same poisoned history.
//
// Real-world hits this guards against:
//   - User cancels (ESC) mid-stream after the assistant emitted
//     "I'll call tool X" but before tool X actually ran.
//   - Backend crashes after persisting the tool_call block but
//     before the tool_result block.
//   - DB hand-edits / corruption produce an orphan tool block.
//   - Compaction / history truncation accidentally drops one half
//     of a tool_call ↔ tool_result pair.
//
// Without this sanitizer, any of the above turns the conversation into
// a permanent 400 trap (reproduced live by Claude Code: anthropics/
// claude-code#14132, #10693, #40305 and openai/codex#7275).
//
// sanitizer.go ——发往任何 provider 前对 LLM message 历史做协议级不变量
// 校验。OpenAI-compat 和 Anthropic 都严格要求 assistant `tool_calls`
// 与后续 `tool` / `tool_result` message 一一配对，不匹配 → 400 → 整段
// 对话永久死锁（Claude Code 自己中过招）。本兜底防御真实生产事故链。

package llm

// SanitizeMessages enforces the assistant.tool_calls ↔ tool message
// pairing invariant on a message history. Returns a NEW slice (input
// is not mutated). Three classes of fix:
//
//  1. Missing tool message for some assistant.tool_calls[i].id →
//     synthesize a stub tool message with content
//     "[interrupted: tool call did not complete]". Lets the LLM see
//     "this tool was attempted but didn't return" without violating
//     the pairing requirement.
//  2. Stray tool message whose tool_call_id has no matching prior
//     assistant.tool_calls → drop it silently. (No way to repair —
//     the LLM has nothing to anchor it to.)
//  3. Order: tool messages must immediately follow the assistant
//     turn that issued the tool_calls. We don't reorder, but the
//     pairing check operates on "first run of tool messages after
//     each tool-calling assistant message" which matches all
//     well-formed histories.
//
// Single-pass linear scan. Safe to call repeatedly (idempotent on
// already-sanitized input).
//
// SanitizeMessages 守 assistant.tool_calls ↔ tool message 配对不变量。
// 三类修复：缺 tool message → 合成 stub；游离 tool message → 丢；
// 顺序假定为"tool message 紧跟发起 tool_calls 的 assistant turn"。
// 单次线性扫描，幂等。
func SanitizeMessages(msgs []LLMMessage) []LLMMessage {
	if len(msgs) == 0 {
		return msgs
	}
	out := make([]LLMMessage, 0, len(msgs))
	i := 0
	for i < len(msgs) {
		m := msgs[i]
		i++

		// Stray tool message (no preceding assistant tool_calls in the
		// "current run") — drop silently. The only legitimate place a
		// tool message lives is in the run immediately after an
		// assistant.tool_calls, which is handled below.
		// 游离 tool message —— 丢。
		if m.Role == RoleTool {
			continue
		}

		out = append(out, m)
		if m.Role != RoleAssistant || len(m.ToolCalls) == 0 {
			continue
		}

		// Collect the run of tool messages immediately following this
		// assistant turn. Pair by ToolCallID; drop ID-mismatched strays;
		// remember which IDs we've seen so we can stub the missing ones
		// after the run ends.
		// 收集紧跟的 tool message 段，按 ToolCallID 配对。
		expected := make(map[string]bool, len(m.ToolCalls))
		for _, tc := range m.ToolCalls {
			expected[tc.ID] = true
		}
		for i < len(msgs) && msgs[i].Role == RoleTool {
			t := msgs[i]
			i++
			if t.ToolCallID == "" || !expected[t.ToolCallID] {
				// Stray tool message inside the run — ID doesn't match
				// any of the assistant's tool_calls. Drop.
				// 段内游离 tool message —— ID 不匹配，丢。
				continue
			}
			out = append(out, t)
			delete(expected, t.ToolCallID)
		}

		// Synthesize stub tool messages for any unmatched IDs. Sentinel
		// content makes the interruption obvious to the model on replay.
		// 给未匹配的 ID 合成 stub。哨兵内容让模型看回放时知道是被打断。
		for _, tc := range m.ToolCalls {
			if expected[tc.ID] {
				out = append(out, LLMMessage{
					Role:       RoleTool,
					ToolCallID: tc.ID,
					Content:    "[interrupted: tool call did not complete]",
				})
			}
		}
	}
	return out
}
