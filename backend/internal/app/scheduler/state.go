// state.go — ExecutionContext + topo state + per-run loop. Owns the
// in-flight mutable state for one FlowRun and drives the DAG: pick
// ready nodes → dispatch in parallel → advance → repeat until done,
// cancelled, or failed (per onError stop policy).
//
// state.go —— ExecutionContext + topo 状态 + per-run 主循环。管一个
// FlowRun 的 in-flight 可变状态;DAG 推进:pick ready → 并发 dispatch →
// advance → 直到完成 / 取消 / failed-stop。

package scheduler

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"

	"go.uber.org/zap"

	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
)

// ExecutionContext is the per-run mutable state. Persisted as PausedState
// JSON when an approval/wait node pauses (E10);rehydrated at boot.
//
// ExecutionContext 是 per-run 可变状态;approval/wait 暂停时整体序列化
// 到 PausedState JSON;boot 时 rehydrate。
type ExecutionContext struct {
	Run       *flowrundomain.FlowRun
	Graph     *workflowdomain.Graph
	Variables map[string]any                    // workflow-level vars
	Outputs   map[string]map[string]any         // nodeID → output by port
	Done      map[string]bool                   // nodeID → completed?
	Failed    map[string]string                 // nodeID → error message (if any)
	Attempts  map[string]int                    // nodeID → retry attempts so far
	NextPort  map[string]string                 // condition routing (nodeID → port)
}

// newExecutionContext builds an ExecutionContext seeded with trigger input
// in the workflow Variables (under reserved key "trigger").
//
// newExecutionContext 用 trigger input 初始化 workflow Variables(reserved
// key "trigger")。
func newExecutionContext(run *flowrundomain.FlowRun, graph *workflowdomain.Graph) *ExecutionContext {
	vars := make(map[string]any, len(graph.Variables)+1)
	for _, v := range graph.Variables {
		if v.Default != nil {
			vars[v.Name] = v.Default
		}
	}
	vars["trigger"] = run.TriggerInput
	return &ExecutionContext{
		Run:       run,
		Graph:     graph,
		Variables: vars,
		Outputs:   make(map[string]map[string]any),
		Done:      make(map[string]bool),
		Failed:    make(map[string]string),
		Attempts:  make(map[string]int),
		NextPort:  make(map[string]string),
	}
}

// topoState tracks in-degree per node + downstream edges for the
// pick-ready-after-advance loop. Built once at executeRun start;mutated
// as nodes complete.
//
// topoState 跟踪每节点 in-degree + 下游边;executeRun 起跑时建,节点完成
// 时变更。
type topoState struct {
	inDegree   map[string]int
	downstream map[string][]workflowdomain.EdgeSpec // nodeID → outgoing edges
	byID       map[string]workflowdomain.NodeSpec
}

func buildTopo(graph *workflowdomain.Graph) *topoState {
	t := &topoState{
		inDegree:   make(map[string]int),
		downstream: make(map[string][]workflowdomain.EdgeSpec),
		byID:       make(map[string]workflowdomain.NodeSpec),
	}
	for _, n := range graph.Nodes {
		t.byID[n.ID] = n
		if _, ok := t.inDegree[n.ID]; !ok {
			t.inDegree[n.ID] = 0
		}
	}
	for _, e := range graph.Edges {
		toNode := splitNodePort(e.To).node
		fromNode := splitNodePort(e.From).node
		t.inDegree[toNode]++
		t.downstream[fromNode] = append(t.downstream[fromNode], e)
	}
	return t
}

// nodePort splits a "nodeId" or "nodeId.port" string into its parts.
// Empty port → default ("out" for outgoing, "in" for incoming — consumer
// decides which empty default applies).
//
// nodePort 拆 "nodeId" / "nodeId.port";空 port 由消费方决定默认。
type nodePort struct {
	node string
	port string
}

func splitNodePort(s string) nodePort {
	if i := strings.IndexByte(s, '.'); i >= 0 {
		return nodePort{node: s[:i], port: s[i+1:]}
	}
	return nodePort{node: s}
}

// initialReady returns nodes with in-degree 0 (entry points — should be
// trigger nodes after validate.go's ErrNoTrigger gate, but any orphan
// node also lands here).
//
// initialReady 返 in-degree=0 的入口节点。
func (t *topoState) initialReady() []string {
	out := make([]string, 0)
	for id, deg := range t.inDegree {
		if deg == 0 {
			out = append(out, id)
		}
	}
	return out
}

// advance decrements downstream in-degrees of done and returns the new
// ready set. condition/approval's NextPort filter selects which downstream
// edges to follow (other-branch edges stay parked → those To-nodes never
// become ready → never run, never block).
//
// nextPort empty means "follow edges whose From-port is also empty or
// 'out'" (the default linear path).
//
// advance 减下游 in-degree;返新 ready;condition/approval 的 NextPort
// 过滤走哪条边(其他分支永不 ready,也永不 run/block)。
func (t *topoState) advance(done string, nextPort string) []string {
	ready := make([]string, 0)
	for _, e := range t.downstream[done] {
		fromPort := splitNodePort(e.From).port
		if !portMatches(fromPort, nextPort) {
			// Edge's from-port doesn't match chosen branch — decrement
			// the To-node's in-degree anyway so it can never be ready
			// (parks the unselected branch). This is the same effect as
			// pruning the edge entirely from the topo for this run.
			// 边的 from-port 不匹配 → 把目标 in-degree 减成不会归零的负数
			// (= 永不 ready,等价剪掉这条边)。
			toNode := splitNodePort(e.To).node
			t.inDegree[toNode]--
			if t.inDegree[toNode] == 0 {
				// shouldn't happen unless graph is degenerate;guard log
				// at caller (executeRun does nothing special here).
				// 不该出现;degenerate 图才会;caller 自然忽略。
			}
			continue
		}
		toNode := splitNodePort(e.To).node
		t.inDegree[toNode]--
		if t.inDegree[toNode] == 0 {
			ready = append(ready, toNode)
		}
	}
	return ready
}

// portMatches returns true when an edge's from-port matches the
// dispatcher-chosen NextPort. Empty NextPort matches "" or "out"
// (the default linear port name).
//
// portMatches 边的 from-port 跟 dispatcher 选的 NextPort 是否匹配;
// 空 NextPort 匹配 "" 或 "out"(默认线性 port 名)。
func portMatches(fromPort, nextPort string) bool {
	if nextPort == "" {
		return fromPort == "" || fromPort == "out"
	}
	return fromPort == nextPort
}

// executeRun is the real Service.ExecuteFn (set by NewService). Drives
// the DAG until completion / cancellation / fatal failure, writes a
// flowrun_nodes row per dispatched node (terminal write only, per spec
// 08-executions §3), finalizes the FlowRun status, and publishes a
// terminal notification.
//
// executeRun 是 Service.ExecuteFn 的真实实现;DAG 推进到完成/取消/失败;
// 每节点写一行 flowrun_nodes 终态;finalize FlowRun status + 推 terminal
// 通知。
func (s *Service) executeRun(ctx context.Context, run *flowrundomain.FlowRun, graph *workflowdomain.Graph) {
	if graph == nil || len(graph.Nodes) == 0 {
		s.finalizeRun(ctx, run, flowrundomain.StatusCompleted, map[string]any{"empty": true}, "", "")
		return
	}

	execCtx := newExecutionContext(run, graph)
	topo := buildTopo(graph)
	ready := topo.initialReady()

	terminalStatus := flowrundomain.StatusCompleted
	var terminalErr string
	var terminalErrCode string

	for len(ready) > 0 {
		select {
		case <-ctx.Done():
			terminalStatus = flowrundomain.StatusCancelled
			terminalErr = ctx.Err().Error()
			ready = nil
			goto FINALIZE
		default:
		}

		nodes := make([]workflowdomain.NodeSpec, 0, len(ready))
		for _, id := range ready {
			nodes = append(nodes, topo.byID[id])
		}

		// Dispatch in parallel.
		results := s.dispatchBatch(ctx, nodes, execCtx)

		// Process results sequentially so map mutations are safe.
		// 串行处理结果(map 改动避免锁)。
		nextReady := make([]string, 0)
		for _, res := range results {
			s.recordNode(ctx, run, res, execCtx)

			if res.Output.Error != nil {
				policy := nodeOnError(res.Node)
				switch policy {
				case workflowdomain.OnErrorContinue:
					// Treat as completed with null output.
					// 视为 completed + 空输出。
					execCtx.Done[res.Node.ID] = true
					nextReady = append(nextReady, topo.advance(res.Node.ID, "")...)
				case workflowdomain.OnErrorBranch:
					// Route to "error" port (E9 retry layer adds this).
					// 走 "error" port(E9 retry 层补)。
					execCtx.Done[res.Node.ID] = true
					nextReady = append(nextReady, topo.advance(res.Node.ID, "error")...)
				default: // OnErrorStop or empty
					terminalStatus = flowrundomain.StatusFailed
					terminalErrCode = "NODE_FAILED"
					terminalErr = fmt.Sprintf("node %q: %v", res.Node.ID, res.Output.Error)
					ready = nil
					goto FINALIZE
				}
				continue
			}

			execCtx.Done[res.Node.ID] = true
			if res.Output.Outputs != nil {
				execCtx.Outputs[res.Node.ID] = res.Output.Outputs
			}
			execCtx.NextPort[res.Node.ID] = res.Output.NextPort
			nextReady = append(nextReady, topo.advance(res.Node.ID, res.Output.NextPort)...)
		}
		ready = nextReady
	}

FINALIZE:
	output := map[string]any{
		"nodesCompleted": len(execCtx.Done),
		"nodesTotal":     len(graph.Nodes),
	}
	s.finalizeRun(ctx, run, terminalStatus, output, terminalErrCode, terminalErr)
}

// dispatchResult bundles one node's input + output for sequential
// post-processing after the parallel dispatch batch.
//
// dispatchResult 把一节点输入输出绑一起,并发批后串行处理。
type dispatchResult struct {
	Node      workflowdomain.NodeSpec
	Input     map[string]any
	Output    DispatchOutput
	StartedAt time.Time
	EndedAt   time.Time
}

// dispatchBatch runs `nodes` in parallel via goroutines.
//
// dispatchBatch 并发 dispatch 一批 ready 节点。
func (s *Service) dispatchBatch(ctx context.Context, nodes []workflowdomain.NodeSpec, execCtx *ExecutionContext) []dispatchResult {
	results := make([]dispatchResult, len(nodes))
	var wg sync.WaitGroup
	for i, n := range nodes {
		wg.Add(1)
		go func(idx int, node workflowdomain.NodeSpec) {
			defer wg.Done()
			defer func() {
				if r := recover(); r != nil {
					results[idx].Output = DispatchOutput{
						Error: fmt.Errorf("dispatcher panic: %v", r),
					}
					results[idx].EndedAt = time.Now().UTC()
					s.log.Error("dispatcher panic",
						zap.String("nodeID", node.ID),
						zap.String("nodeType", node.Type),
						zap.Any("recover", r))
				}
			}()
			input := buildNodeInput(node, execCtx)
			start := time.Now().UTC()
			out := s.router.Dispatch(ctx, DispatchInput{
				Node:    node,
				NodeIn:  input,
				ExecCtx: execCtx,
			})
			results[idx] = dispatchResult{
				Node:      node,
				Input:     input,
				Output:    out,
				StartedAt: start,
				EndedAt:   time.Now().UTC(),
			}
		}(i, n)
	}
	wg.Wait()
	return results
}

// buildNodeInput resolves the node's input port data from upstream
// outputs + workflow variables. V1 minimal: passes upstream "out" outputs
// merged + trigger payload. E7-E8 dispatchers may template / project
// further per their needs.
//
// buildNodeInput 从上游 output + workflow Variables 拼节点输入;V1 最小化。
func buildNodeInput(_ workflowdomain.NodeSpec, _ *ExecutionContext) map[string]any {
	// V1 passes empty input map — each dispatcher reads what it needs from
	// node.Config + execCtx.Outputs + execCtx.Variables directly. This
	// keeps the framework simple;E7-E8 dispatchers do per-type resolution.
	// V1 不通用解析输入;dispatcher 各自从 node.Config + execCtx 读所需。
	return map[string]any{}
}

// recordNode writes one terminal flowrun_nodes row (best-effort — failure
// logs but does not abort the run). Uses detached ctx via runCtx variant
// since the caller ctx may be cancelled during finalization.
//
// recordNode 写 flowrun_nodes 终态(best-effort 失败 log 不挂 run);用
// caller ctx(已 detached from HTTP)所以可写。
func (s *Service) recordNode(ctx context.Context, run *flowrundomain.FlowRun, res dispatchResult, execCtx *ExecutionContext) {
	status := flowrundomain.NodeStatusOK
	if res.Output.Error != nil {
		status = flowrundomain.NodeStatusFailed
	}
	if ctx.Err() != nil && res.Output.Error == nil {
		// Run was cancelled — anything that hadn't reported its own error
		// is marked cancelled (it likely propagated ctx.Done internally
		// but didn't return an Error before our select picked it up).
		// 运行已取消 — 未自报错的节点标 cancelled。
		status = flowrundomain.NodeStatusCancelled
	}

	row := &flowrundomain.Node{
		ID:          idgenpkg.New("frn"),
		UserID:      run.UserID,
		Status:      status,
		TriggeredBy: flowrundomain.TriggerKindCron, // overridden below
		Input:       res.Input,
		Output:      res.Output.Outputs,
		StartedAt:   res.StartedAt,
		EndedAt:     res.EndedAt,
		ElapsedMs:   res.EndedAt.Sub(res.StartedAt).Milliseconds(),
		FlowrunID:   run.ID,
		NodeID:      res.Node.ID,
		NodeType:    res.Node.Type,
		Attempts:    1 + execCtx.Attempts[res.Node.ID],
	}
	row.TriggeredBy = "workflow" // Node executions are workflow-scoped (see 08-executions §2)
	if res.Output.Error != nil {
		row.ErrorMessage = res.Output.Error.Error()
		row.ErrorCode = "NODE_FAILED"
	}
	if err := s.repo.CreateNode(ctx, row); err != nil {
		s.log.Warn("scheduler.recordNode: create failed",
			zap.String("runID", run.ID),
			zap.String("nodeID", res.Node.ID),
			zap.Error(err))
	}
}

// finalizeRun writes the FlowRun terminal status + applies retention
// pruning (§6.7) + publishes a notification.
//
// finalizeRun 写 FlowRun 终态 + 保留策略剪 + 推通知。
func (s *Service) finalizeRun(ctx context.Context, run *flowrundomain.FlowRun, status string, output any, errCode, errMsg string) {
	endedAt := time.Now().UTC()
	elapsedMs := endedAt.Sub(run.StartedAt).Milliseconds()
	if err := s.repo.UpdateStatus(ctx, run.ID, status, output, errCode, errMsg, &endedAt, elapsedMs); err != nil {
		s.log.Error("scheduler.finalizeRun: UpdateStatus failed",
			zap.String("runID", run.ID), zap.Error(err))
	}
	// Retention prune (best-effort §6.7).
	if err := s.repo.HardDeleteOldest(ctx, run.WorkflowID, flowrundomain.DefaultRetentionLimit); err != nil {
		s.log.Warn("scheduler.finalizeRun: HardDeleteOldest failed",
			zap.String("workflowID", run.WorkflowID), zap.Error(err))
	}
	s.publish(ctx, run.ID, run.WorkflowID, status, map[string]any{
		"elapsedMs": elapsedMs,
	})
}

// nodeOnError reads the NodeSpec's OnError policy. Empty → stop.
//
// nodeOnError 读 OnError 策略;空 → stop。
func nodeOnError(n workflowdomain.NodeSpec) string {
	if n.OnError == "" {
		return workflowdomain.OnErrorStop
	}
	return n.OnError
}
