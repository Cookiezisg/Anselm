//go:build pipeline

// fake_llm_scripts.go — convenience factories for common LLM Script patterns.
// Import this alongside fake_llm.go; add factories here as new test scenarios
// need them.
//
// fake_llm_scripts.go — 常见 LLM Script 模式的快捷工厂函数。
// 按需在这里增加新工厂，不要在 test body 里手写 ChunkAction 列表。
package harness

import "time"

// ScriptText emits content split across multiple SSE chunks, guaranteeing that
// the entity-state model delivers several monotonically-growing snapshots.
// Suitable for any test that asserts on text content or streaming snapshots.
//
// ScriptText 把 content 分成多帧发送，保证 entity-state 快照单调增长。
// 适合断言文字内容或流式快照的所有测试。
func ScriptText(content string) Script {
	return Script{
		Actions:      splitTextActions(content, 3),
		FinishReason: "stop",
		InputTokens:  12,
		OutputTokens: 5,
	}
}

// ScriptSlowText emits content as multiple chunks with chunkDelay between each.
// Use for cancel-mid-stream tests where the client needs time to send the
// cancel before the stream finishes.
//
// ScriptSlowText 把 content 分多帧发出，帧间插 chunkDelay 延迟。
// 用于 cancel-mid-stream 测试，给客户端留出取消时间窗。
func ScriptSlowText(content string, chunkDelay time.Duration) Script {
	chunks := splitTextActions(content, 8)
	actions := make([]ChunkAction, 0, len(chunks)*2)
	for _, c := range chunks {
		actions = append(actions, c)
		actions = append(actions, ChunkAction{Kind: "delay", Delay: chunkDelay})
	}
	return Script{
		Actions:      actions,
		FinishReason: "stop",
		InputTokens:  20,
		OutputTokens: 10,
	}
}

// ScriptSingleToolCall emits one tool call (name + complete args in one delta),
// finishing with finish_reason="tool_calls". argsJSON must be a valid JSON
// object string; include "summary" if simulating a real LLM that injects it.
//
// ScriptSingleToolCall 发出一次 tool call（name + 完整 args 一次发），
// finish_reason="tool_calls"。argsJSON 须是合法 JSON object 字符串。
func ScriptSingleToolCall(name, toolID, argsJSON string) Script {
	return Script{
		Actions: []ChunkAction{
			{Kind: "tool_call_start", Name: name, ToolID: toolID, Index: 0},
			{Kind: "tool_call_delta", Index: 0, Content: argsJSON},
		},
		FinishReason: "tool_calls",
		InputTokens:  15,
		OutputTokens: 8,
	}
}

// ScriptHTTPError returns a Script that causes the fake server to respond with
// the given HTTP status code immediately (no streaming). Use to test LLM
// provider error paths (401 invalid key, 429 rate limit, 502 upstream down).
//
// ScriptHTTPError 让 fake server 直接返回指定 HTTP 状态（不流式）。
// 测试 LLM provider 错误路径（401 / 429 / 502 等）。
func ScriptHTTPError(status int) Script {
	return Script{HTTPStatus: status}
}

// ScriptRawJSON emits a single text chunk containing payload verbatim.
// Use for internal Generate() calls (ranking, auto-title) that need a
// specific JSON payload back from the LLM.
//
// ScriptRawJSON 发出含 payload 的单帧 text chunk。
// 用于内部 Generate() 调用（排名、自动标题等）需要特定 JSON 返回的场景。
func ScriptRawJSON(payload string) Script {
	return Script{
		Actions:      []ChunkAction{{Kind: "text", Content: payload}},
		FinishReason: "stop",
		InputTokens:  5,
		OutputTokens: 3,
	}
}

// ToolCallSpec describes one tool call for use with ScriptParallelToolCalls.
//
// ToolCallSpec 描述 ScriptParallelToolCalls 里的一次 tool call。
type ToolCallSpec struct {
	Name     string
	ToolID   string
	ArgsJSON string
}

// ScriptParallelToolCalls emits multiple tool calls in one LLM response
// (different indexes), finishing with finish_reason="tool_calls".
// The chat runner should batch all safe calls and execute them concurrently.
//
// ScriptParallelToolCalls 在一次 LLM 响应中发出多个 tool call（不同 index），
// finish_reason="tool_calls"。chat runner 应把所有 safe call 打包并发执行。
func ScriptParallelToolCalls(calls []ToolCallSpec) Script {
	actions := make([]ChunkAction, 0, len(calls)*2)
	for i, c := range calls {
		actions = append(actions,
			ChunkAction{Kind: "tool_call_start", Name: c.Name, ToolID: c.ToolID, Index: i},
			ChunkAction{Kind: "tool_call_delta", Index: i, Content: c.ArgsJSON},
		)
	}
	return Script{
		Actions:      actions,
		FinishReason: "tool_calls",
		InputTokens:  15,
		OutputTokens: 10,
	}
}

// splitTextActions divides content into up to n roughly equal text chunk actions.
//
// splitTextActions 把 content 分成最多 n 个大致等长的 text chunk action。
func splitTextActions(content string, n int) []ChunkAction {
	runes := []rune(content)
	total := len(runes)
	if total == 0 || n <= 1 {
		return []ChunkAction{{Kind: "text", Content: content}}
	}
	chunkSize := (total + n - 1) / n
	actions := make([]ChunkAction, 0, n)
	for i := 0; i < total; i += chunkSize {
		end := i + chunkSize
		if end > total {
			end = total
		}
		actions = append(actions, ChunkAction{Kind: "text", Content: string(runes[i:end])})
	}
	return actions
}
