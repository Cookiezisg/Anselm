package reqctx

import (
	"context"

	agentstatepkg "github.com/sunweilin/forgify/backend/internal/pkg/agentstate"
)

// agentstate.go — Per-conversation AgentState ferried through ctx so any
// tool's Execute can read SeenFiles (Write/Edit must-Read-first) without
// each tool needing a struct field for it.
//
// The AgentState pointer is stamped by chat/runner.go::processTask once per
// task. Lifetime spans the conversation queue; missing the value indicates
// a server-side wiring bug (chat layer didn't stamp it) — tools should
// either fail loudly or skip the SeenFiles check defensively, depending on
// their semantics.
//
// agentstate.go — 通过 ctx 转运的 per-conversation AgentState，让任何 tool 的
// Execute 都能读 SeenFiles（Write/Edit 的 must-Read-first 约束），无需每个
// tool 自己挂结构字段。
//
// AgentState 指针由 chat/runner.go::processTask 在每个 task 起头时注入。
// 生命周期跨 conversation queue；缺值意味着服务端接线 bug（chat 层未注入）——
// tool 应根据自身语义选择 fail loud 或防御性跳过 SeenFiles 检查。

type agentStateKey struct{}

// WithAgentState returns a copy of ctx carrying the AgentState pointer.
// Stamped by chat/runner.go::processTask once per agent task.
//
// WithAgentState 返回携带 AgentState 指针的 ctx 拷贝。
// 由 chat/runner.go::processTask 在每个 agent task 起头时注入。
func WithAgentState(ctx context.Context, s *agentstatepkg.AgentState) context.Context {
	return context.WithValue(ctx, agentStateKey{}, s)
}

// GetAgentState retrieves the AgentState pointer. False if absent or nil
// — caller decides whether to fail or defensively skip.
//
// GetAgentState 取 AgentState 指针。缺失或 nil 时返 false——调用方自行决定
// fail 或防御性跳过。
func GetAgentState(ctx context.Context) (*agentstatepkg.AgentState, bool) {
	s, ok := ctx.Value(agentStateKey{}).(*agentstatepkg.AgentState)
	return s, ok && s != nil
}
