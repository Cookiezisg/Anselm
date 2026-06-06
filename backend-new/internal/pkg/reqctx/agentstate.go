package reqctx

import (
	"context"

	agentstatepkg "github.com/sunweilin/forgify/backend/internal/pkg/agentstate"
)

type agentStateKey struct{}

// WithAgentState returns a copy of ctx carrying s. The host (chat / agent /
// scheduler) seeds it before invoking the loop, so tools within the run can
// cooperate on cross-call invariants (e.g. filesystem's write-before-read).
// Seeding nil is allowed and equivalent to not seeding — GetAgentState will
// return ok=false, and fail-closed tools (Write / Edit) will refuse.
//
// WithAgentState 返回携带 s 的 ctx 拷贝。host（chat / agent / scheduler）跑 loop 前埋下，
// 使本次运行内的工具能就跨调用不变式协作（如 filesystem 的写前必读）。允许 seed nil，
// 等价于不 seed——GetAgentState 返 ok=false，fail-closed 工具（Write / Edit）会拒绝。
func WithAgentState(ctx context.Context, s *agentstatepkg.AgentState) context.Context {
	return context.WithValue(ctx, agentStateKey{}, s)
}

// GetAgentState returns the AgentState pointer; ok=false when absent or nil.
// Filesystem tools treat ok=false as fail-closed for write operations — silently
// allowing a Write without the read-first guard would defeat the invariant.
// Read-only tools tolerate ok=false (they just skip MarkRead).
//
// GetAgentState 返回 AgentState 指针；缺失或 nil 时 ok=false。filesystem 工具对写操作
// 把 ok=false 视为 fail-closed——静默放过没有读前守卫的 Write 会让不变式形同虚设。
// 只读工具容忍 ok=false（仅跳过 MarkRead）。
func GetAgentState(ctx context.Context) (*agentstatepkg.AgentState, bool) {
	s, ok := ctx.Value(agentStateKey{}).(*agentstatepkg.AgentState)
	if !ok || s == nil {
		return nil, false
	}
	return s, true
}
