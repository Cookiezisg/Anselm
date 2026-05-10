package reqctx

import (
	"context"
	"errors"
)

// Per-agent-run identifiers (conversation / assistant message / LLM tool call).
// Stamped by the chat layer just before invoking a tool. Lifetime: one tool
// call. Missing values are not bugs — events with empty filter keys silently
// go nowhere; only conversationID has a Require-form sentinel for callers
// that need to surface it.
//
// Per-agent-run ID（conversation / 助手消息 / LLM tool call）。chat 层调 tool
// 前注入。生命周期：单次 tool 调用。缺失非 bug——事件 filter key 为空时静默
// 无订阅者；仅 conversationID 提供 Require-form sentinel 供需上抛的调用方用。

// ErrMissingConversationID is returned by RequireConversationID.
//
// ErrMissingConversationID 由 RequireConversationID 返回。
var ErrMissingConversationID = errors.New("reqctx: missing conversation id in context")

type conversationIDKey struct{}
type messageIDKey struct{}
type toolCallIDKey struct{}
type parentBlockIDKey struct{}

// WithConversationID returns a copy of ctx carrying id.
//
// WithConversationID 返回携带 id 的 ctx 拷贝。
func WithConversationID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, conversationIDKey{}, id)
}

// GetConversationID returns the conversation ID; ok=false when absent or empty.
//
// GetConversationID 取 conversation ID；缺失或空时 ok=false。
func GetConversationID(ctx context.Context) (string, bool) {
	id, ok := ctx.Value(conversationIDKey{}).(string)
	return id, ok && id != ""
}

// RequireConversationID returns the ID or ErrMissingConversationID.
//
// RequireConversationID 返回 ID 或 ErrMissingConversationID。
func RequireConversationID(ctx context.Context) (string, error) {
	if id, ok := GetConversationID(ctx); ok {
		return id, nil
	}
	return "", ErrMissingConversationID
}

// WithMessageID returns a copy of ctx carrying the in-flight assistant message ID.
//
// WithMessageID 返回携带当前生成中的 assistant 消息 ID 的 ctx 拷贝。
func WithMessageID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, messageIDKey{}, id)
}

// GetMessageID returns the assistant message ID; ok=false when absent or empty.
//
// GetMessageID 取 assistant 消息 ID；缺失或空时 ok=false。
func GetMessageID(ctx context.Context) (string, bool) {
	id, ok := ctx.Value(messageIDKey{}).(string)
	return id, ok && id != ""
}

// WithToolCallID returns a copy of ctx carrying the LLM tool-call ID.
//
// WithToolCallID 返回携带 LLM tool-call ID 的 ctx 拷贝。
func WithToolCallID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, toolCallIDKey{}, id)
}

// GetToolCallID returns the LLM tool-call ID; ok=false when absent or empty.
//
// GetToolCallID 取 LLM tool-call ID；缺失或空时 ok=false。
func GetToolCallID(ctx context.Context) (string, bool) {
	id, ok := ctx.Value(toolCallIDKey{}).(string)
	return id, ok && id != ""
}

// WithParentBlockID returns a copy of ctx carrying the current emit-tree
// parent block. Used by pkg/eventlog so nested emits (tool progress
// inside a tool_call, subagent text inside a message-block) automatically
// get the correct parentId field without each emitter recomputing it.
//
// WithParentBlockID 返回携带当前 emit 树父 block 的 ctx 拷贝。pkg/eventlog
// 用它让嵌套 emit（tool_call 下的 progress、message-block 下的 subagent
// 文本）自动取得正确 parentId，不需各 emitter 重算。
func WithParentBlockID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, parentBlockIDKey{}, id)
}

// GetParentBlockID returns the current emit-tree parent block ID;
// ok=false when absent or empty (top-level emit).
//
// GetParentBlockID 返回当前 emit 树父 block ID；缺失或空时 ok=false（顶层 emit）。
func GetParentBlockID(ctx context.Context) (string, bool) {
	id, ok := ctx.Value(parentBlockIDKey{}).(string)
	return id, ok && id != ""
}

// Subagent ctx key: SubagentDepth gates the recursion check inside
// SubagentTool.Execute (the structural defense is registry-level tool
// filtering, but depth is a runtime belt-and-suspenders).
//
// Subagent ctx key：SubagentDepth 给 SubagentTool.Execute 内的递归检查兜底
// （结构性防线是注册表层的工具过滤，深度只是运行时双保险）。
type subagentDepthKey struct{}

// WithSubagentDepth returns a copy of ctx with depth (≥ 0). Increment by
// one each time SubagentTool.Execute spawns a sub-runner.
//
// WithSubagentDepth 返回带 depth（≥ 0）的 ctx 拷贝。每次 SubagentTool
// .Execute 起 sub-runner 时 +1。
func WithSubagentDepth(ctx context.Context, depth int) context.Context {
	return context.WithValue(ctx, subagentDepthKey{}, depth)
}

// GetSubagentDepth returns the current subagent depth (0 in main chat).
// Always returns a usable int; absent means depth=0.
//
// GetSubagentDepth 返回当前 subagent 深度（主对话为 0）。总返可用 int；
// 缺失即 depth=0。
func GetSubagentDepth(ctx context.Context) int {
	if d, ok := ctx.Value(subagentDepthKey{}).(int); ok {
		return d
	}
	return 0
}
