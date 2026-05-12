// dispatch_trigger.go — TriggerDispatcher. Plan 05 §3.2: trigger nodes
// are no-op at execution time;they're just the topo entry point. The
// trigger source already fired by the time executeRun starts.
//
// dispatch_trigger.go —— TriggerDispatcher;§3.2 trigger 节点执行时 no-op,
// 只做 topo 入口。trigger source 已在 executeRun 起跑前 fire。

package scheduler

import (
	"context"
)

// TriggerDispatcher passes the trigger input straight to the "out" port.
// Other nodes read it via execCtx.Variables["trigger"] (set by
// newExecutionContext).
//
// TriggerDispatcher 把 trigger input 透传 "out" port;其他节点经
// execCtx.Variables["trigger"] 拿。
type TriggerDispatcher struct{}

// NewTriggerDispatcher constructs the no-op trigger dispatcher.
//
// NewTriggerDispatcher 构造 no-op trigger dispatcher。
func NewTriggerDispatcher() *TriggerDispatcher { return &TriggerDispatcher{} }

// Dispatch returns the run's TriggerInput as the default output port.
//
// Dispatch 把 run.TriggerInput 当默认 out port 返。
func (d *TriggerDispatcher) Dispatch(_ context.Context, in DispatchInput) DispatchOutput {
	return DispatchOutput{
		Outputs: map[string]any{
			"out": in.ExecCtx.Run.TriggerInput,
		},
	}
}
