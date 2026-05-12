// dispatch_handler.go — HandlerDispatcher. Reads node.Config keys
// `handlerName` + `method` + `args` and calls handlerapp.Service.Call
// with Owner{Kind="flowrun", ID=runID} so handler instances live for
// the whole FlowRun lifetime (cross-node state sharing).
//
// dispatch_handler.go —— HandlerDispatcher;Owner{Kind=flowrun,ID=runID}
// 让 instance 跨节点共享状态;run 终态时 scheduler 统一 destroy。

package scheduler

import (
	"context"
	"fmt"

	handlerapp "github.com/sunweilin/forgify/backend/internal/app/handler"
)

// HandlerDispatcher bridges workflow handler nodes to handlerapp.Service.Call.
//
// HandlerDispatcher 桥接 workflow handler 节点到 handlerapp.Call。
type HandlerDispatcher struct {
	svc *handlerapp.Service
}

// NewHandlerDispatcher constructs HandlerDispatcher.
//
// NewHandlerDispatcher 构造 HandlerDispatcher。
func NewHandlerDispatcher(svc *handlerapp.Service) *HandlerDispatcher {
	return &HandlerDispatcher{svc: svc}
}

// Dispatch reads handlerName + method + args from node.Config, calls the
// handler method, returns the result on the default "out" port.
//
// Dispatch 读 handlerName/method/args 调 handler method。
func (d *HandlerDispatcher) Dispatch(ctx context.Context, in DispatchInput) DispatchOutput {
	name, _ := in.Node.Config["handlerName"].(string)
	method, _ := in.Node.Config["method"].(string)
	if name == "" {
		return DispatchOutput{Error: fmt.Errorf("handler node %q: handlerName required", in.Node.ID)}
	}
	if method == "" {
		return DispatchOutput{Error: fmt.Errorf("handler node %q: method required", in.Node.ID)}
	}
	args, _ := in.Node.Config["args"].(map[string]any)

	result, err := d.svc.Call(ctx, handlerapp.CallInput{
		HandlerName: name,
		Method:      method,
		Args:        args,
		Owner: handlerapp.Owner{
			Kind: "flowrun",
			ID:   in.ExecCtx.Run.ID,
		},
	})
	if err != nil {
		return DispatchOutput{Error: err}
	}
	return DispatchOutput{Outputs: map[string]any{"out": result}}
}
