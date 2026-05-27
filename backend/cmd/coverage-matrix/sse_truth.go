package main

// SSETruth is the closed enumeration of SSE protocol surfaces.
// 3 streams × N events × optional sub-discriminator (block type / forge kind /
// notification type). Mirrors CLAUDE.md §E1 + events-design.md.
//
// SSETruth 是 SSE 协议封闭枚举。3 流 × N 事件 × 可选子区分符
// (block 类型 / forge kind / notification 类型)。对位 CLAUDE.md §E1 + events-design.md。
func SSETruth() []SSEEvent {
	var out []SSEEvent

	// 1) eventlog stream — 5 events × 7 block types.
	// message_start / message_stop don't carry block type.
	// block_start / block_delta / block_stop carry one of 7 block types.
	//
	// 1) eventlog 流 — 5 事件 × 7 block 类型。
	// message_start / message_stop 不带 block 类型;
	// block_start / block_delta / block_stop 带 7 种 block 之一。
	out = append(out,
		SSEEvent{Stream: "eventlog", Event: "message_start"},
		SSEEvent{Stream: "eventlog", Event: "message_stop"},
	)
	blockTypes := []string{"text", "reasoning", "tool_call", "tool_result", "progress", "message", "compaction"}
	for _, bt := range blockTypes {
		for _, ev := range []string{"block_start", "block_delta", "block_stop"} {
			out = append(out, SSEEvent{Stream: "eventlog", Event: ev, BlockType: bt})
		}
	}

	// 2) forge stream — 4 events × 3 kinds (function / handler / workflow).
	//
	// 2) forge 流 — 4 事件 × 3 kind(function / handler / workflow)。
	forgeKinds := []string{"function", "handler", "workflow"}
	for _, k := range forgeKinds {
		for _, ev := range []string{"forge_started", "forge_op_applied", "forge_env_attempt", "forge_completed"} {
			out = append(out, SSEEvent{Stream: "forge", Event: ev, Kind: k})
		}
	}

	// 3) notifications stream — open vocabulary; hardcoded list of known types
	// (extend when the publisher emits a new one).
	//
	// 3) notifications 流 — 开放词表;此处 hardcode 已知 type
	// (publisher 新增 type 时跟齐)。
	notifTypes := []string{
		"conversation", "function", "handler", "workflow", "flowrun",
		"mcp_server", "skill", "memory", "todo", "sandbox_env",
		"compaction", "document", "ask",
	}
	for _, nt := range notifTypes {
		out = append(out, SSEEvent{Stream: "notifications", Event: "notification", NotifType: nt})
	}

	return out
}
