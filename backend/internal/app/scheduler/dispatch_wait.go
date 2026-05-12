// dispatch_wait.go — WaitDispatcher. Reads node.Config key `duration`
// (millis) or `until` (RFC3339 timestamp) and sleeps until that point
// or ctx.Done. Plan 05 §3.2 wait.
//
// dispatch_wait.go —— WaitDispatcher;sleep duration ms 或到 until 时间。

package scheduler

import (
	"context"
	"fmt"
	"time"
)

// WaitDispatcher pauses the dispatcher goroutine until duration / until
// elapses or ctx is cancelled.
//
// WaitDispatcher 睡 duration / 到 until,或 ctx 取消时退。
type WaitDispatcher struct{}

// NewWaitDispatcher constructs WaitDispatcher.
//
// NewWaitDispatcher 构造 WaitDispatcher。
func NewWaitDispatcher() *WaitDispatcher { return &WaitDispatcher{} }

// Dispatch sleeps for the configured duration / until.
//
// Dispatch 睡 duration / 到 until。
func (d *WaitDispatcher) Dispatch(ctx context.Context, in DispatchInput) DispatchOutput {
	var sleep time.Duration

	if durMs, ok := configInt(in.Node.Config["duration"]); ok && durMs > 0 {
		sleep = time.Duration(durMs) * time.Millisecond
	} else if untilStr, ok := in.Node.Config["until"].(string); ok && untilStr != "" {
		until, err := time.Parse(time.RFC3339, untilStr)
		if err != nil {
			return DispatchOutput{Error: fmt.Errorf("wait node %q: parse until: %w", in.Node.ID, err)}
		}
		sleep = time.Until(until)
	} else {
		return DispatchOutput{Error: fmt.Errorf("wait node %q: duration or until required", in.Node.ID)}
	}

	if sleep <= 0 {
		return DispatchOutput{Outputs: map[string]any{"out": "already past"}}
	}

	t := time.NewTimer(sleep)
	defer t.Stop()
	select {
	case <-ctx.Done():
		return DispatchOutput{Error: ctx.Err()}
	case <-t.C:
		return DispatchOutput{Outputs: map[string]any{"out": "elapsed"}}
	}
}

// configInt tolerates int / int64 / float64 JSON shapes.
//
// configInt 容忍 int/int64/float64 三种 JSON 形状。
func configInt(v any) (int64, bool) {
	switch n := v.(type) {
	case int:
		return int64(n), true
	case int64:
		return n, true
	case float64:
		return int64(n), true
	}
	return 0, false
}
