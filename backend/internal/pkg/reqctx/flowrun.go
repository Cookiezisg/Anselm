package reqctx

import "context"

// Flowrun identity: which flowrun + node a piece of work executes under. Injected by the
// workflow scheduler right before dispatching a node into an execution entity (function run /
// handler call / mcp call / agent invoke), and read by each entity's audit recorder to fill the
// flowrun_id / flowrun_node_id / flowrun_iteration columns — the "which executions did this flowrun
// produce, and on which loop turn?" axis.
// Get-only (no Require): absence simply means "not a workflow-dispatched run", never an error.
//
// Flowrun 身份：一段工作在哪个 flowrun + 节点之下执行。由 workflow 调度器在把节点派发进执行实体
// （function run / handler call / mcp call / agent invoke）前注入，由各实体的审计记账读取、填
// flowrun_id / flowrun_node_id 列——「这个 flowrun 产生了哪些执行」的查询轴。只有 Get（无
// Require）：缺席只表示「非 workflow 派发的运行」，绝不是错误。

type (
	flowrunIDKey        struct{}
	flowrunNodeIDKey    struct{}
	flowrunIterationKey struct{}
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

// SetFlowrunIteration returns a copy of ctx carrying the loop iteration (0-based) of the node being
// executed — so an entity's audit record can record WHICH loop turn produced it. Without it, a node
// run at iterations 0,1,2 of a back-edge loop produces audit rows with the identical (flowrun_id,
// flowrun_node_id), un-joinable to the right flowrun_nodes truth row (F175-M12).
//
// SetFlowrunIteration 返回携带正在执行节点的循环轮次（0-based）的 ctx 拷贝——使实体审计记录能记下是
// 哪一轮循环产出的。没它，回边循环中 iteration 0,1,2 跑的节点产出 (flowrun_id, flowrun_node_id) 相同的
// 审计行、无法 join 到正确的 flowrun_nodes 真相行（F175-M12）。
func SetFlowrunIteration(ctx context.Context, iter int) context.Context {
	return context.WithValue(ctx, flowrunIterationKey{}, iter)
}

// GetFlowrunIteration returns the loop iteration; ok=false when absent (not a workflow-dispatched run).
//
// GetFlowrunIteration 取循环轮次；缺席（非 workflow 派发运行）时 ok=false。
func GetFlowrunIteration(ctx context.Context) (int, bool) {
	iter, ok := ctx.Value(flowrunIterationKey{}).(int)
	return iter, ok
}
