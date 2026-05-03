package reqctx

import (
	"context"
	"errors"
)

// ErrMissingConversationID is returned by RequireConversationID when no
// conversation ID is present in ctx — typically a wiring bug (the chat
// runner did not stamp it before invoking a tool).
//
// ErrMissingConversationID 由 RequireConversationID 在 ctx 无
// conversation ID 时返回——通常是接线 bug（chat runner 漏在调 tool 前印）。
var ErrMissingConversationID = errors.New("reqctx: missing conversation id in context")

// agentrun.go — Per-agent-run identifiers stamped by the chat layer just before
// invoking a tool's Execute. Tool implementations read them to scope SSE event
// publishing or DB writes.
//
// Lifetime is shorter than user/locale: those last the whole HTTP request,
// these last one tool call. Missing values are not bugs — events with empty
// filter keys silently go nowhere.
//
// agentrun.go — chat 层在调用 tool.Execute 前注入的 per-agent-run 标识符。
// tool 实现读取它们用于 SSE 事件发布或 DB 写入的范围限定。
//
// 生命周期比 user/locale 短：那两个跨整个 HTTP 请求，这三个仅单次 tool 调用。
// 缺失不是 bug——事件 filter key 为空就静默不到达任何订阅者。

// ── ctx keys ──────────────────────────────────────────────────────────────────
// Each ID gets its own private empty-struct key to avoid collisions with
// string keys or other reqctx data.
//
// 每个 ID 独立的私有 empty-struct key，避免与 string key 或其他 reqctx 数据冲突。

type conversationIDKey struct{}
type messageIDKey struct{}
type toolCallIDKey struct{}

// ── conversation ID ───────────────────────────────────────────────────────────

// WithConversationID returns a copy of ctx carrying the given conversation ID.
// Stamped by chat/runner.go before invoking the agent loop.
//
// WithConversationID 返回携带该 conversation ID 的 ctx 拷贝。
// 由 chat/runner.go 在 agent 循环开始前注入。
func WithConversationID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, conversationIDKey{}, id)
}

// GetConversationID retrieves the conversation ID. False if absent or empty.
//
// GetConversationID 取 conversation ID。缺失或为空时返 false。
func GetConversationID(ctx context.Context) (string, bool) {
	id, ok := ctx.Value(conversationIDKey{}).(string)
	return id, ok && id != ""
}

// RequireConversationID returns the conversation ID or ErrMissingConversationID.
// Use this when the caller wants to bubble up the sentinel rather than
// handle a bool.
//
// RequireConversationID 返回 conversation ID 或 ErrMissingConversationID。
// 调用方想上抛 sentinel 而不处理 bool 时使用。
func RequireConversationID(ctx context.Context) (string, error) {
	if id, ok := GetConversationID(ctx); ok {
		return id, nil
	}
	return "", ErrMissingConversationID
}

// ── assistant message ID ──────────────────────────────────────────────────────

// WithMessageID returns a copy of ctx carrying the assistant message ID
// currently being generated. Stamped by chat/tools.go::runOneTool.
//
// WithMessageID 返回携带当前生成中的 assistant 消息 ID 的 ctx 拷贝。
// 由 chat/tools.go::runOneTool 注入。
func WithMessageID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, messageIDKey{}, id)
}

// GetMessageID retrieves the assistant message ID. False if absent or empty.
//
// GetMessageID 取 assistant 消息 ID。缺失或为空时返 false。
func GetMessageID(ctx context.Context) (string, bool) {
	id, ok := ctx.Value(messageIDKey{}).(string)
	return id, ok && id != ""
}

// ── LLM tool-call ID ──────────────────────────────────────────────────────────

// WithToolCallID returns a copy of ctx carrying the LLM-assigned tool call ID
// for the current tool invocation.
//
// WithToolCallID 返回携带 LLM 分配的当前 tool call ID 的 ctx 拷贝。
func WithToolCallID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, toolCallIDKey{}, id)
}

// GetToolCallID retrieves the LLM tool call ID. False if absent or empty.
//
// GetToolCallID 取 LLM tool call ID。缺失或为空时返 false。
func GetToolCallID(ctx context.Context) (string, bool) {
	id, ok := ctx.Value(toolCallIDKey{}).(string)
	return id, ok && id != ""
}
