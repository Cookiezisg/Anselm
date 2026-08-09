package reqctx

import (
	"context"
	"sync"
)

type turnControlKey struct{}

// TurnControl carries run-local control signals from a tool back to the ReAct loop.
// It is intentionally a pointer in context: tool execution receives a derived context,
// while the loop owns the parent context and must observe the signal after execution.
//
// TurnControl 携带工具回传给 ReAct loop 的、仅限本次 run 的控制信号。它刻意以指针放进 context：
// 工具执行拿到的是派生 context，而 loop 持有父 context，必须在执行结束后观察到该信号。
type TurnControl struct {
	mu                        sync.RWMutex
	toolsDisabledOnNextSample bool
}

// NewTurnControl returns an empty run-local control object.
func NewTurnControl() *TurnControl { return &TurnControl{} }

// SetTurnControl attaches control to ctx. A nil control is treated as absent.
func SetTurnControl(ctx context.Context, control *TurnControl) context.Context {
	if control == nil {
		return ctx
	}
	return context.WithValue(ctx, turnControlKey{}, control)
}

// GetTurnControl returns the run-local control object, when one was seeded.
func GetTurnControl(ctx context.Context) (*TurnControl, bool) {
	control, ok := ctx.Value(turnControlKey{}).(*TurnControl)
	return control, ok && control != nil
}

// RequestToolsDisabled requests that the next LLM sample be textual-only. The current tool
// batch is allowed to finish; the signal is for the following sample and never crosses runs.
//
// RequestToolsDisabled 请求下一次 LLM 采样只生成文本。本批已开始的工具允许收尾；信号只作用于
// 下一次采样，绝不跨 run。
func RequestToolsDisabled(ctx context.Context) {
	control, ok := GetTurnControl(ctx)
	if !ok {
		return
	}
	control.mu.Lock()
	control.toolsDisabledOnNextSample = true
	control.mu.Unlock()
}

// ToolsDisabled reports whether the next sample must omit the tool set.
func ToolsDisabled(ctx context.Context) bool {
	control, ok := GetTurnControl(ctx)
	if !ok {
		return false
	}
	control.mu.RLock()
	defer control.mu.RUnlock()
	return control.toolsDisabledOnNextSample
}
