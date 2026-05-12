// retry.go — per-node retry policy + per-node timeout wrappers.
// Plan 05 §6.8 (node-level timeout default + override) + §3.1 retry.
//
// Retry policy: MaxAttempts total tries (initial + retries),
// Backoff = exponential / linear / fixed, DelayMs initial delay.
// Timeout: ctx.WithTimeout per attempt. Ctx-cancel (run cancellation)
// short-circuits retry — we don't retry a cancelled run.
//
// retry.go —— per-node retry 策略 + per-node timeout 包装。retry
// MaxAttempts 总尝试次数;Backoff 三选一;Timeout 每 attempt 一次
// ctx.WithTimeout;ctx-cancel 短路 retry。

package scheduler

import (
	"context"
	"errors"
	"time"

	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
)

// Default per-NodeType timeouts (Plan 05 §6.8). NodeSpec.Timeout (ms)
// overrides when non-zero. 0 = no timeout (ctx parent only).
//
// 默认 per-NodeType timeout(§6.8);NodeSpec.Timeout(ms)非零时覆盖;
// 0 = 无 timeout 走 ctx parent。
var defaultTimeouts = map[string]time.Duration{
	workflowdomain.NodeTypeFunction: 30 * time.Second,
	workflowdomain.NodeTypeHandler:  30 * time.Second,
	workflowdomain.NodeTypeMCP:      30 * time.Second,
	workflowdomain.NodeTypeSkill:    60 * time.Second,
	workflowdomain.NodeTypeLLM:      60 * time.Second,
	workflowdomain.NodeTypeHTTP:     30 * time.Second,
	workflowdomain.NodeTypeApproval: 7 * 24 * time.Hour,
	// trigger/condition/loop/parallel/wait/variable are not capability nodes;
	// no defaults (NodeSpec.Timeout=0 → no enforced timeout).
	// 非 capability 节点无默认 timeout。
}

// nodeTimeoutDuration resolves the timeout for a node: NodeSpec.Timeout
// (ms) wins; default per-NodeType fallback; 0 = no enforced timeout.
//
// nodeTimeoutDuration 解析节点 timeout;NodeSpec.Timeout 优先,缺则用
// per-NodeType 默认;0 不 enforce。
func nodeTimeoutDuration(node workflowdomain.NodeSpec) time.Duration {
	if node.Timeout > 0 {
		return time.Duration(node.Timeout) * time.Millisecond
	}
	return defaultTimeouts[node.Type]
}

// retryAttemptFn is the closure dispatchWithPolicies wraps with retry +
// timeout layers.
//
// retryAttemptFn 是 dispatchWithPolicies 用 retry + timeout 包的闭包。
type retryAttemptFn func(ctx context.Context) DispatchOutput

// withRetry runs fn under a per-NodeSpec retry policy. node.Retry==nil
// or MaxAttempts ≤ 1 → single attempt. Backoff selects delay growth.
// ctx cancellation short-circuits the retry loop.
//
// On a successful attempt OR a fatal error (sentinel: approval-required,
// loop body unsupported, parallel branch unsupported) returns immediately.
//
// withRetry 按 NodeSpec.Retry 跑 fn;nil 或 MaxAttempts≤1 单次;Backoff 决
// 定 delay 增长;ctx cancel 短路;成功 OR fatal sentinel 立刻返。
func withRetry(ctx context.Context, node workflowdomain.NodeSpec, execCtx *ExecutionContext, fn retryAttemptFn) DispatchOutput {
	retry := node.Retry
	maxAttempts := 1
	delay := time.Duration(0)
	backoff := ""
	if retry != nil {
		if retry.MaxAttempts > 1 {
			maxAttempts = retry.MaxAttempts
		}
		if retry.DelayMs > 0 {
			delay = time.Duration(retry.DelayMs) * time.Millisecond
		}
		backoff = retry.Backoff
	}

	var lastOut DispatchOutput
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		if err := ctx.Err(); err != nil {
			return DispatchOutput{Error: err}
		}
		execCtx.Attempts[node.ID] = attempt
		lastOut = fn(ctx)
		if lastOut.Error == nil {
			return lastOut
		}
		// Fatal sentinels — never retry these (they require human / out-
		// of-band resolution, not a retry).
		if isFatalErr(lastOut.Error) {
			return lastOut
		}
		// Last attempt — return the failure.
		if attempt == maxAttempts {
			return lastOut
		}
		// Sleep before next attempt unless ctx cancels.
		select {
		case <-ctx.Done():
			return DispatchOutput{Error: ctx.Err()}
		case <-time.After(delay):
		}
		delay = nextDelay(backoff, delay, retry)
	}
	return lastOut
}

// nextDelay grows the delay per backoff strategy. fixed → unchanged;
// linear → +initial; exponential → ×2.
//
// nextDelay 按 backoff 策略增长;fixed 不变 / linear +initial / exponential ×2。
func nextDelay(strategy string, current time.Duration, retry *workflowdomain.RetryConfig) time.Duration {
	switch strategy {
	case "exponential":
		if current <= 0 {
			return time.Second
		}
		return current * 2
	case "linear":
		if retry != nil && retry.DelayMs > 0 {
			return current + time.Duration(retry.DelayMs)*time.Millisecond
		}
		return current
	default: // "fixed" or empty
		return current
	}
}

// isFatalErr returns true for sentinels that must short-circuit retry.
// Approval / loop-body-unsupported / parallel-branch-unsupported aren't
// transient — retrying just spams the failure.
//
// isFatalErr 判 sentinel 是否必须短路 retry。
func isFatalErr(err error) bool {
	return errors.Is(err, ErrApprovalRequired) ||
		errors.Is(err, ErrLoopBodyNotSupported) ||
		errors.Is(err, ErrParallelBranchNotSupported)
}

// dispatchWithPolicies is the per-node entry point used by dispatchBatch.
// Layers timeout-per-attempt inside the retry loop and tracks attempts in
// execCtx for the flowrun_nodes row.
//
// dispatchWithPolicies dispatchBatch 用的入口;retry 套 timeout-per-attempt;
// attempts 进 execCtx 写 flowrun_nodes 行。
func (s *Service) dispatchWithPolicies(ctx context.Context, node workflowdomain.NodeSpec, input map[string]any, execCtx *ExecutionContext) DispatchOutput {
	timeout := nodeTimeoutDuration(node)
	return withRetry(ctx, node, execCtx, func(rctx context.Context) DispatchOutput {
		callCtx := rctx
		if timeout > 0 {
			tctx, cancel := context.WithTimeout(rctx, timeout)
			defer cancel()
			callCtx = tctx
		}
		out := s.router.Dispatch(callCtx, DispatchInput{
			Node:    node,
			NodeIn:  input,
			ExecCtx: execCtx,
		})
		// Translate ctx-timeout to a friendlier dispatch error (vs raw
		// context.DeadlineExceeded). Caller's onError policy still applies.
		// ctx-timeout 翻成友好错误;调用方 onError 仍然走。
		if out.Error == nil && callCtx.Err() == context.DeadlineExceeded {
			out.Error = context.DeadlineExceeded
		}
		return out
	})
}
