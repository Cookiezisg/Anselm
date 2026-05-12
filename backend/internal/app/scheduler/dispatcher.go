// dispatcher.go — Dispatcher port + Router + DispatchInput/Output shapes.
// E7-E8 implement the 13 per-NodeType dispatchers and register them
// with NewRouter via Set(nodeType, dispatcher). E6 executeRun uses the
// Router to dispatch each ready node.
//
// dispatcher.go —— Dispatcher 端口 + Router + 派发请求/响应形状。E7-E8
// 实现 13 个 per-NodeType dispatcher 调 Router.Set(...) 注册;E6 executeRun
// 调 Router.Dispatch 派发每个 ready 节点。

package scheduler

import (
	"context"

	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
)

// Dispatcher is the per-NodeType executor. Each NodeType (function /
// handler / mcp / skill / llm / http / condition / loop / parallel /
// approval / wait / variable / trigger) has one impl in E7-E8.
//
// Dispatcher 是 per-NodeType 执行器;每 NodeType 一个实现。
type Dispatcher interface {
	// Dispatch runs the node and returns its outputs by port name.
	// Output["out"] is the conventional default port for linear nodes;
	// condition/loop emit per-branch ports (Output["true"] / ["false"] /
	// per-iteration etc.). Error == nil means "node OK"; non-nil triggers
	// onError policy at the caller.
	//
	// Dispatch 跑节点;返各 port 名 → 输出。"out" 是常规默认 port;condition/
	// loop 用 per-branch port。Error 非 nil 触发 onError 策略。
	Dispatch(ctx context.Context, in DispatchInput) DispatchOutput
}

// DispatchInput is the per-call argument to Dispatcher.Dispatch.
//
// DispatchInput 是 Dispatcher.Dispatch 的入参。
type DispatchInput struct {
	Node    workflowdomain.NodeSpec
	NodeIn  map[string]any // resolved input port data
	ExecCtx *ExecutionContext
}

// DispatchOutput is the response from Dispatcher.Dispatch.
//
// DispatchOutput 是 Dispatcher.Dispatch 的返。
type DispatchOutput struct {
	Outputs  map[string]any // by port name; nil = no output
	NextPort string         // for condition/approval routing (empty = default "out" path)
	Error    error
}

// Router maps NodeType → Dispatcher. Built once at startup by main.go +
// harness;executeRun reads it (no locks needed because writes happen
// before any StartRun call).
//
// Router 映射 NodeType → Dispatcher;启动期建一次,executeRun 只读。
type Router struct {
	dispatchers map[string]Dispatcher
}

// NewRouter constructs an empty Router. Use Set to register dispatchers.
//
// NewRouter 构造空 Router;用 Set 注册。
func NewRouter() *Router {
	return &Router{dispatchers: make(map[string]Dispatcher)}
}

// Set registers a Dispatcher for a NodeType. Replaces any existing one.
//
// Set 注册某 NodeType 的 Dispatcher;已存在则替换。
func (r *Router) Set(nodeType string, d Dispatcher) {
	r.dispatchers[nodeType] = d
}

// Dispatch looks up the registered Dispatcher and runs the node. If no
// Dispatcher is registered for the type, returns ErrNoDispatcherForType
// as the DispatchOutput.Error (test stubs only register the types they
// exercise).
//
// Dispatch 查 Dispatcher 跑节点;未注册返 ErrNoDispatcherForType(测试
// stub 只注册要跑的类型)。
func (r *Router) Dispatch(ctx context.Context, in DispatchInput) DispatchOutput {
	d, ok := r.dispatchers[in.Node.Type]
	if !ok {
		return DispatchOutput{Error: ErrNoDispatcherForType{Type: in.Node.Type}}
	}
	return d.Dispatch(ctx, in)
}

// ErrNoDispatcherForType is the error returned when a node type has no
// registered Dispatcher. Surfaces as run.error_code=NO_DISPATCHER if it
// propagates terminal.
//
// ErrNoDispatcherForType 是未注册 NodeType 时返的错误。
type ErrNoDispatcherForType struct{ Type string }

func (e ErrNoDispatcherForType) Error() string {
	return "scheduler: no dispatcher registered for node type " + e.Type
}

// DispatcherFunc adapts a plain function to the Dispatcher interface
// (useful for inline test stubs).
//
// DispatcherFunc 把普通函数适配为 Dispatcher 接口(测试 stub 用)。
type DispatcherFunc func(ctx context.Context, in DispatchInput) DispatchOutput

// Dispatch delegates to the underlying function.
//
// Dispatch 委派给底层 function。
func (f DispatcherFunc) Dispatch(ctx context.Context, in DispatchInput) DispatchOutput {
	return f(ctx, in)
}
