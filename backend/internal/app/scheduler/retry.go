package scheduler

import (
	"context"
	"errors"
	"fmt"
	"time"

	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
)

// nodeTimeoutDuration returns ONLY an explicit per-node override; the scheduler
// imposes no default wall-clock. A workflow node that legitimately runs for
// minutes (LLM / agent / function) must not be killed by a guessed timeout —
// run-level ctx (scheduler.Cancel / app shutdown / user "stop run") plus each
// dispatcher's own bound (HTTP node client timeout, handler RPC ctx, LLM idle
// timeout) govern liveness; unattended cost is bounded by agent-node maxTurns,
// not a clock (#1 ctx-over-timeout decision).
//
// nodeTimeoutDuration 只返显式 per-node 覆盖；调度器不再强加默认墙钟。合理跑数
// 分钟的节点（LLM/agent/function）不该被拍脑袋超时杀——run-level ctx + 各
// dispatcher 自身 bound 管控存活；无人值守成本由 agent maxTurns 兜，不靠时钟。
func nodeTimeoutDuration(node workflowdomain.NodeSpec) time.Duration {
	if node.Timeout > 0 {
		return time.Duration(node.Timeout) * time.Millisecond
	}
	return 0
}

type retryAttemptFn func(ctx context.Context) DispatchOutput

// withRetry runs fn under NodeSpec.Retry; success or a fatal sentinel returns immediately.
//
// withRetry 按 NodeSpec.Retry 跑 fn；成功或 fatal sentinel 立即返回。
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
		if isFatalErr(lastOut.Error) {
			return lastOut
		}
		if attempt == maxAttempts {
			return lastOut
		}
		select {
		case <-ctx.Done():
			return DispatchOutput{Error: ctx.Err()}
		case <-time.After(delay):
		}
		delay = nextDelay(backoff, delay, retry)
	}
	return lastOut
}

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
	default:
		return current
	}
}

func isFatalErr(err error) bool {
	return errors.Is(err, ErrApprovalRequired) ||
		errors.Is(err, ErrLoopBodyNotSupported) ||
		errors.Is(err, ErrParallelBranchNotSupported)
}

// dryRunMockOutput returns a synthetic DispatchOutput for a side-effect node;
// approval auto-routes "approved" so the DAG continues past the gate.
//
// dryRunMockOutput 返副作用节点的合成 DispatchOutput；approval 自动走 "approved"
// 让 DAG 越过审批关。
func dryRunMockOutput(node workflowdomain.NodeSpec) DispatchOutput {
	out := DispatchOutput{
		Outputs: map[string]any{
			"out":     fmt.Sprintf("[DRY RUN: %s]", node.Type),
			"_dryRun": true,
		},
	}
	if node.Type == workflowdomain.NodeTypeApproval {
		out.NextPort = "approved"
	}
	return out
}

// dryRunSideEffectNodes lists NodeTypes whose dispatchers cause external side effects
// and must be mocked in dry-run mode. Pure-logic nodes (condition / variable / loop / parallel / trigger)
// still execute normally so the DAG flow remains observable.
//
// dryRunSideEffectNodes 列出有副作用的 NodeType，dry-run 模式下需 mock；
// 纯逻辑节点（condition / variable / loop / parallel / trigger）仍正常跑，DAG 流可见。
var dryRunSideEffectNodes = map[string]bool{
	workflowdomain.NodeTypeFunction: true,
	workflowdomain.NodeTypeHandler:  true,
	workflowdomain.NodeTypeMCP:      true,
	workflowdomain.NodeTypeSkill:    true,
	workflowdomain.NodeTypeLLM:      true,
	workflowdomain.NodeTypeAgent:    true,
	workflowdomain.NodeTypeHTTP:     true,
	workflowdomain.NodeTypeApproval: true, // mock auto-approve
	workflowdomain.NodeTypeWait:     true, // skip sleep
}

func (s *Service) dispatchWithPolicies(ctx context.Context, node workflowdomain.NodeSpec, input map[string]any, execCtx *ExecutionContext) DispatchOutput {
	if execCtx.DryRun && dryRunSideEffectNodes[node.Type] {
		return dryRunMockOutput(node)
	}
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
		if out.Error == nil && callCtx.Err() == context.DeadlineExceeded {
			out.Error = context.DeadlineExceeded
		}
		return out
	})
}
