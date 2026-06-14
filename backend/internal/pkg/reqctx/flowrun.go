package reqctx

import "context"

// Flowrun identity: which flowrun + node a piece of work executes under. Injected by the
// workflow scheduler right before dispatching a node into an execution entity (function run /
// handler call / mcp call / agent invoke), and read by each entity's audit recorder to fill the
// flowrun_id / flowrun_node_id columns — the "which executions did this flowrun produce?" axis.
// Get-only (no Require): absence simply means "not a workflow-dispatched run", never an error.
//
// Flowrun 身份：一段工作在哪个 flowrun + 节点之下执行。由 workflow 调度器在把节点派发进执行实体
// （function run / handler call / mcp call / agent invoke）前注入，由各实体的审计记账读取、填
// flowrun_id / flowrun_node_id 列——「这个 flowrun 产生了哪些执行」的查询轴。只有 Get（无
// Require）：缺席只表示「非 workflow 派发的运行」，绝不是错误。

type (
	flowrunIDKey     struct{}
	flowrunNodeIDKey struct{}
)

// SetFlowrunID returns a copy of ctx carrying the flowrun id (fr_).
//
// SetFlowrunID 返回携带 flowrun id（fr_）的 ctx 拷贝。
func SetFlowrunID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, flowrunIDKey{}, id)
}

// GetFlowrunID returns the flowrun id; ok=false when missing or empty.
//
// GetFlowrunID 取 flowrun id；缺失或为空时 ok=false。
func GetFlowrunID(ctx context.Context) (string, bool) {
	id, ok := ctx.Value(flowrunIDKey{}).(string)
	return id, ok && id != ""
}

// SetFlowrunNodeID returns a copy of ctx carrying the graph node id being executed.
//
// SetFlowrunNodeID 返回携带正在执行的图节点 id 的 ctx 拷贝。
func SetFlowrunNodeID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, flowrunNodeIDKey{}, id)
}

// GetFlowrunNodeID returns the node id; ok=false when missing or empty.
//
// GetFlowrunNodeID 取节点 id；缺失或为空时 ok=false。
func GetFlowrunNodeID(ctx context.Context) (string, bool) {
	id, ok := ctx.Value(flowrunNodeIDKey{}).(string)
	return id, ok && id != ""
}
