// dispatch_loop_parallel.go — LoopDispatcher + ParallelDispatcher. V1
// minimal: loop iterates over an inline array (config.items) and emits
// the items as the "out" port without a body subgraph. parallel is a
// pass-through (executeRun already runs the natural parallel edges of
// the graph concurrently via dispatchBatch).
//
// Full loop body subgraph + parallel branch execution are deferred to
// Plan 06 — V1 workflows that don't need them work today;those that do
// hit a "not supported" sentinel.
//
// dispatch_loop_parallel.go —— V1 loop + parallel 最小实现;body subgraph +
// branch execution 留 Plan 06。

package scheduler

import (
	"context"
	"errors"
	"fmt"
)

// ErrLoopBodyNotSupported is returned when loop.config.body is non-empty
// (V1 doesn't implement body subgraph execution).
//
// ErrLoopBodyNotSupported V1 不支持 loop body subgraph。
var ErrLoopBodyNotSupported = errors.New("scheduler: loop body subgraph not supported in V1")

// LoopDispatcher iterates over config.items and emits them on "out".
// config.body subgraph execution is Plan 06 — returns
// ErrLoopBodyNotSupported when body is non-empty.
//
// LoopDispatcher 遍历 config.items 当 "out" 发;body 留 Plan 06。
type LoopDispatcher struct{}

// NewLoopDispatcher constructs LoopDispatcher.
//
// NewLoopDispatcher 构造 LoopDispatcher。
func NewLoopDispatcher() *LoopDispatcher { return &LoopDispatcher{} }

// Dispatch reads config.items and emits them as an array output. If
// config.body is present, errors with ErrLoopBodyNotSupported.
//
// Dispatch 读 config.items 整体当 out 发;config.body 非空时返错。
func (d *LoopDispatcher) Dispatch(_ context.Context, in DispatchInput) DispatchOutput {
	if body, ok := in.Node.Config["body"]; ok && body != nil {
		if arr, isArr := body.([]any); isArr && len(arr) > 0 {
			return DispatchOutput{
				Error: fmt.Errorf("loop node %q: %w", in.Node.ID, ErrLoopBodyNotSupported),
			}
		}
	}
	items, _ := in.Node.Config["items"].([]any)
	return DispatchOutput{
		Outputs: map[string]any{"out": items, "count": len(items)},
	}
}

// ErrParallelBranchNotSupported is returned when parallel.config.branches
// is non-empty (V1 doesn't implement branch subgraph execution).
//
// ErrParallelBranchNotSupported V1 不支持 parallel branch subgraph。
var ErrParallelBranchNotSupported = errors.New("scheduler: parallel branch subgraph not supported in V1")

// ParallelDispatcher is a pass-through in V1 — executeRun's dispatchBatch
// already runs natural parallel edges of the graph concurrently. The
// config.branches subgraph path is Plan 06.
//
// ParallelDispatcher V1 pass-through;branches subgraph 留 Plan 06。
type ParallelDispatcher struct{}

// NewParallelDispatcher constructs ParallelDispatcher.
//
// NewParallelDispatcher 构造 ParallelDispatcher。
func NewParallelDispatcher() *ParallelDispatcher { return &ParallelDispatcher{} }

// Dispatch is a no-op pass through (returns OK).
//
// Dispatch pass-through。
func (d *ParallelDispatcher) Dispatch(_ context.Context, in DispatchInput) DispatchOutput {
	if branches, ok := in.Node.Config["branches"]; ok && branches != nil {
		if arr, isArr := branches.([]any); isArr && len(arr) > 0 {
			return DispatchOutput{
				Error: fmt.Errorf("parallel node %q: %w", in.Node.ID, ErrParallelBranchNotSupported),
			}
		}
	}
	return DispatchOutput{Outputs: map[string]any{"out": "passthrough"}}
}
