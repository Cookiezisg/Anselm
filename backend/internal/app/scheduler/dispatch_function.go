// dispatch_function.go — FunctionDispatcher. Reads node.Config keys
// `functionId` + `input` (map) + optional `version`, calls
// functionapp.Service.RunFunction with TriggeredBy=workflow + the
// flowrun_node linkage propagated via ctx (E15 will refine ctx wiring).
//
// dispatch_function.go —— FunctionDispatcher;读 node.Config 调
// functionapp.RunFunction(TriggeredBy=workflow)。

package scheduler

import (
	"context"
	"fmt"

	functionapp "github.com/sunweilin/forgify/backend/internal/app/function"
	functiondomain "github.com/sunweilin/forgify/backend/internal/domain/function"
)

// FunctionDispatcher bridges workflow function nodes to functionapp.
//
// FunctionDispatcher 桥接 workflow function 节点到 functionapp。
type FunctionDispatcher struct {
	svc *functionapp.Service
}

// NewFunctionDispatcher constructs FunctionDispatcher with the function service.
//
// NewFunctionDispatcher 构造 FunctionDispatcher。
func NewFunctionDispatcher(svc *functionapp.Service) *FunctionDispatcher {
	return &FunctionDispatcher{svc: svc}
}

// Dispatch reads functionId + input from node.Config and runs the function.
//
// Dispatch 读 functionId + input 跑 function。
func (d *FunctionDispatcher) Dispatch(ctx context.Context, in DispatchInput) DispatchOutput {
	fnID, _ := in.Node.Config["functionId"].(string)
	if fnID == "" {
		return DispatchOutput{Error: fmt.Errorf("function node %q: functionId required", in.Node.ID)}
	}
	args, _ := in.Node.Config["input"].(map[string]any)
	versionID, _ := in.Node.Config["version"].(string)

	result, err := d.svc.RunFunction(ctx, functionapp.RunInput{
		FunctionID:  fnID,
		VersionID:   versionID,
		Input:       args,
		TriggeredBy: functiondomain.TriggeredByWorkflow,
	})
	if err != nil {
		return DispatchOutput{Error: err}
	}
	if result != nil && !result.OK {
		// User-code error (functionapp wraps as ExecutionResult.OK=false);
		// surface to dispatcher caller as a non-nil error so onError policy
		// can drive next step.
		// 用户代码错(ExecutionResult.OK=false)→ 给 dispatcher caller 一个
		// non-nil error 让 onError 决策。
		return DispatchOutput{Error: fmt.Errorf("function %q: %s", fnID, result.ErrorMsg)}
	}
	out := map[string]any{}
	if result != nil {
		out["out"] = result.Output
		out["elapsedMs"] = result.ElapsedMs
	}
	return DispatchOutput{Outputs: out}
}
