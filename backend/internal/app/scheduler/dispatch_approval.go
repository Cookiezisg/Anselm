// dispatch_approval.go — ApprovalDispatcher. Emits a sentinel error
// (ErrApprovalRequired) carrying the prompt + timeout config. executeRun
// (E10) catches this and persists PausedState + flips run to paused
// instead of treating it as a normal failure.
//
// V1 baseline: this dispatcher itself doesn't block / persist — that
// state-machine wiring lands in E10. For now Dispatch returns immediately
// with ErrApprovalRequired so the run halts at approval boundaries.
//
// dispatch_approval.go —— ApprovalDispatcher;返 ErrApprovalRequired
// 让 executeRun 走 pause 路径。E10 接 PausedState 持久化 + 真正暂停。

package scheduler

import (
	"context"
	"errors"
	"fmt"
)

// ErrApprovalRequired signals the run reached an approval gate. E10's
// executeRun handles this specially (PausedState write + status=paused);
// pre-E10, executeRun treats it as a regular dispatch error → run.status=
// failed which is wrong but visible in tests.
//
// ErrApprovalRequired 信号 run 到达 approval 关卡。E10 让 executeRun
// 走 pause;pre-E10 当普通失败 → failed(测试可见但路径错)。
var ErrApprovalRequired = errors.New("scheduler: approval required")

// ApprovalDispatcher emits ErrApprovalRequired with prompt context.
//
// ApprovalDispatcher 返 ErrApprovalRequired + prompt 信息。
type ApprovalDispatcher struct{}

// NewApprovalDispatcher constructs ApprovalDispatcher.
//
// NewApprovalDispatcher 构造 ApprovalDispatcher。
func NewApprovalDispatcher() *ApprovalDispatcher { return &ApprovalDispatcher{} }

// Dispatch reads prompt + timeout from node.Config and returns
// ErrApprovalRequired wrapped with the prompt for downstream E10 logic.
//
// Dispatch 读 prompt + timeout,返 ErrApprovalRequired wrap prompt。
func (d *ApprovalDispatcher) Dispatch(_ context.Context, in DispatchInput) DispatchOutput {
	prompt, _ := in.Node.Config["prompt"].(string)
	if prompt == "" {
		prompt = "Approval required"
	}
	return DispatchOutput{
		Error: fmt.Errorf("%w: node %q: %s", ErrApprovalRequired, in.Node.ID, prompt),
	}
}
