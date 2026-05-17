package scheduler

import (
	"context"
	"errors"
	"fmt"
	"sync"

	workflowapp "github.com/sunweilin/forgify/backend/internal/app/workflow"
	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
)

// SubDAGRequest is one invocation of a sub-graph by a container node (e.g. loop iteration).
//
// SubDAGRequest 是容器节点对子图的一次调用（如 loop 单次迭代）。
type SubDAGRequest struct {
	Parent           *ExecutionContext
	Body             *workflowdomain.Graph
	ParentLoopNode   string
	IterationIndex   int
	Loop             *workflowapp.LoopContext // bound into EvalContext for body-internal templates
}

// SubDAGResult is the terminal state of one sub-DAG run.
//
// SubDAGResult 是单次子图运行的终态。
type SubDAGResult struct {
	Outputs map[string]map[string]any // body node ID → its DispatchOutput.Outputs
	Status  string                    // flowrundomain.StatusCompleted / StatusFailed / StatusCancelled
	Err     error
}

// ErrSubDAGContainsApproval is returned when a sub-graph contains an approval node;
// pausing mid-iteration is unsupported in V1.
//
// ErrSubDAGContainsApproval 在子图含 approval 节点时返；V1 不支持中途暂停。
var ErrSubDAGContainsApproval = errors.New("scheduler: sub-DAG cannot contain approval nodes (V1)")

// ExecuteSubDAG runs one sub-graph synchronously; iteration variables bind via Loop into ExecutionContext.
// Used by LoopDispatcher per iteration; future ParallelDispatcher branches reuse it.
//
// ExecuteSubDAG 同步跑一次子图；迭代变量经 Loop 注入 ExecutionContext。
// LoopDispatcher 每轮调一次；未来 ParallelDispatcher 分支复用。
func (s *Service) ExecuteSubDAG(ctx context.Context, req SubDAGRequest) SubDAGResult {
	if req.Body == nil || len(req.Body.Nodes) == 0 {
		return SubDAGResult{Status: flowrundomain.StatusCompleted, Outputs: map[string]map[string]any{}}
	}
	// Reject approval nodes: pause semantics for mid-iteration is undefined.
	// 拒 approval：迭代中途暂停的语义未定义。
	for _, n := range req.Body.Nodes {
		if n.Type == workflowdomain.NodeTypeApproval {
			return SubDAGResult{Status: flowrundomain.StatusFailed, Err: ErrSubDAGContainsApproval}
		}
	}

	subCtx := s.newSubExecutionContext(req)
	topo := buildTopo(req.Body)
	ready := topo.initialReady()

	status, errCode, errMsg, paused := s.runReadyLoop(ctx, req.Parent.Run, subCtx, topo, ready)
	if paused {
		// Defensive: rejected above. If reached, treat as failed.
		// 防御：上面已拒；走到这里当 failed。
		return SubDAGResult{Status: flowrundomain.StatusFailed, Err: fmt.Errorf("sub-DAG unexpectedly paused")}
	}
	res := SubDAGResult{Status: status, Outputs: subCtx.Outputs}
	if status != flowrundomain.StatusCompleted {
		res.Err = fmt.Errorf("sub-DAG %s: %s (%s)", status, errMsg, errCode)
	}
	return res
}

// newSubExecutionContext creates an iteration-scoped ExecutionContext that inherits Run/Variables/parent-Outputs but isolates Done/Failed/Outputs.
//
// newSubExecutionContext 构造迭代级 ExecutionContext：复用 Run/Variables/父 Outputs，隔离 Done/Failed/Outputs。
func (s *Service) newSubExecutionContext(req SubDAGRequest) *ExecutionContext {
	// Shallow-clone parent outputs so body nodes see upstream results but sub-writes don't leak.
	// 浅拷父 outputs，body 能看到上游结果，但 sub 写入不外泄。
	parentOutputs := make(map[string]map[string]any, len(req.Parent.Outputs))
	for k, v := range req.Parent.Outputs {
		parentOutputs[k] = v
	}
	return &ExecutionContext{
		Run:              req.Parent.Run,
		Graph:            req.Body,
		Variables:        req.Parent.Variables, // share (no per-iter mutation expected)
		Outputs:          parentOutputs,
		Done:             make(map[string]bool),
		Failed:           make(map[string]string),
		Attempts:         make(map[string]int),
		NextPort:         make(map[string]string),
		Loop:             req.Loop,
		ParentLoopNodeID: req.ParentLoopNode,
		IterationIndex:   req.IterationIndex,
		DryRun:           req.Parent.DryRun,
	}
}

// SubDAGFromBody decodes loop.config.body / parallel.config.body into a *workflowdomain.Graph.
//
// SubDAGFromBody 把 loop.config.body / parallel.config.body 解到 *workflowdomain.Graph。
func SubDAGFromBody(raw map[string]any) (*workflowdomain.Graph, error) {
	rawNodes, _ := raw["nodes"].([]any)
	rawEdges, _ := raw["edges"].([]any)
	nodes := make([]workflowdomain.NodeSpec, 0, len(rawNodes))
	for _, rn := range rawNodes {
		m, ok := rn.(map[string]any)
		if !ok {
			return nil, fmt.Errorf("body.nodes element not an object")
		}
		var n workflowdomain.NodeSpec
		n.ID, _ = m["id"].(string)
		n.Type, _ = m["type"].(string)
		n.OnError, _ = m["onError"].(string)
		n.Config, _ = m["config"].(map[string]any)
		if n.ID == "" || n.Type == "" {
			return nil, fmt.Errorf("body node missing id or type")
		}
		nodes = append(nodes, n)
	}
	edges := make([]workflowdomain.EdgeSpec, 0, len(rawEdges))
	for _, re := range rawEdges {
		m, ok := re.(map[string]any)
		if !ok {
			return nil, fmt.Errorf("body.edges element not an object")
		}
		var e workflowdomain.EdgeSpec
		e.From, _ = m["from"].(string)
		e.To, _ = m["to"].(string)
		e.FromPort, _ = m["fromPort"].(string)
		e.ToPort, _ = m["toPort"].(string)
		if e.From == "" || e.To == "" {
			return nil, fmt.Errorf("body edge missing from or to")
		}
		edges = append(edges, e)
	}
	return &workflowdomain.Graph{Nodes: nodes, Edges: edges}, nil
}

// SubstituteLoopTemplates deep-walks a config map; string leaf values containing
// "{{" are compiled + executed against the loop's EvalContext. Non-string leaves
// pass through. Returns a fresh map; original untouched.
//
// SubstituteLoopTemplates 深度遍历 config map；含 "{{" 的字符串叶值按 loop 的
// EvalContext 编译执行；非字符串叶值原样透传。返新 map，不动入参。
func SubstituteLoopTemplates(raw map[string]any, evalCtx workflowapp.EvalContext) (map[string]any, error) {
	out := make(map[string]any, len(raw))
	for k, v := range raw {
		nv, err := substituteValue(v, evalCtx)
		if err != nil {
			return nil, fmt.Errorf("config key %q: %w", k, err)
		}
		out[k] = nv
	}
	return out, nil
}

func substituteValue(v any, evalCtx workflowapp.EvalContext) (any, error) {
	switch val := v.(type) {
	case string:
		tmpl, err := workflowapp.Compile(val)
		if err != nil {
			return nil, err
		}
		if tmpl == nil {
			return val, nil
		}
		return workflowapp.Execute(tmpl, evalCtx, val)
	case map[string]any:
		return SubstituteLoopTemplates(val, evalCtx)
	case []any:
		out := make([]any, len(val))
		for i, item := range val {
			niv, err := substituteValue(item, evalCtx)
			if err != nil {
				return nil, err
			}
			out[i] = niv
		}
		return out, nil
	default:
		return val, nil
	}
}

// concurrentRun runs N functions with up to `cap` concurrency; collects all errors.
// Used by LoopDispatcher in parallel mode.
//
// concurrentRun 用至多 cap 并发跑 N 个函数；收集所有错误。LoopDispatcher 并发模式用。
func concurrentRun(n, cap int, fn func(i int) error) []error {
	if cap <= 0 {
		cap = 1
	}
	if cap > n {
		cap = n
	}
	errs := make([]error, n)
	sem := make(chan struct{}, cap)
	var wg sync.WaitGroup
	for i := 0; i < n; i++ {
		wg.Add(1)
		sem <- struct{}{}
		go func(idx int) {
			defer wg.Done()
			defer func() { <-sem }()
			errs[idx] = fn(idx)
		}(i)
	}
	wg.Wait()
	return errs
}
