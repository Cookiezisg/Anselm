package scheduler

import (
	"context"
	"errors"
	"fmt"
	"sync"

	workflowapp "github.com/sunweilin/forgify/backend/internal/app/workflow"
	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
)

// LoopOnErrorStop / LoopOnErrorContinue are the two failure modes for the loop body subgraph.
//
// LoopOnErrorStop / LoopOnErrorContinue 是 loop body 子图的两种失败模式。
const (
	LoopOnErrorStop     = "stop"     // default: any iteration failure → propagate, stop the loop
	LoopOnErrorContinue = "continue" // collect failed indices, keep going
)

// DefaultLoopConcurrencyCap caps parallel iterations when config.concurrency unset (avoids 1000-LLM-call explosion).
//
// DefaultLoopConcurrencyCap 是 config.concurrency 未设时的并行上限（防 1000 个 LLM call 同时发）。
const DefaultLoopConcurrencyCap = 5

// LoopDispatcher iterates over config.items; runs config.body subgraph per item if set, else passes items through.
//
// LoopDispatcher 遍历 config.items；config.body 存在则每项跑子图，否则透传 items。
type LoopDispatcher struct {
	svc *Service // back-ref for ExecuteSubDAG; nil → body subgraph disabled
}

// NewLoopDispatcher constructs LoopDispatcher; pass non-nil svc to enable body subgraph (§5.1).
//
// NewLoopDispatcher 构造 LoopDispatcher；传非 nil svc 启用 body 子图（§5.1）。
func NewLoopDispatcher(svc *Service) *LoopDispatcher {
	return &LoopDispatcher{svc: svc}
}

// Dispatch: if config.body is set, run it once per item with $loop bound; else passthrough.
//
// Dispatch：config.body 存在则每项跑子图（绑 $loop）；否则透传。
func (d *LoopDispatcher) Dispatch(ctx context.Context, in DispatchInput) DispatchOutput {
	items := d.resolveItems(in)

	bodyRaw, _ := in.Node.Config["body"].(map[string]any)
	if !hasBody(bodyRaw) {
		// V1 minimal: passthrough.
		// V1 最小：透传。
		return DispatchOutput{Outputs: map[string]any{"out": items, "count": len(items)}}
	}

	if d.svc == nil {
		return DispatchOutput{Error: fmt.Errorf("loop node %q: body set but no scheduler back-ref (test wiring bug)", in.Node.ID)}
	}

	body, err := SubDAGFromBody(bodyRaw)
	if err != nil {
		return DispatchOutput{Error: fmt.Errorf("loop node %q: decode body: %w", in.Node.ID, err)}
	}

	onError := loopOnError(in.Node.Config)
	parallel := loopParallel(in.Node.Config)
	concurrency := loopConcurrency(in.Node.Config)

	results := make([]map[string]map[string]any, len(items))
	failures := make([]loopIterFailure, 0)
	var failMu sync.Mutex

	runOne := func(i int) error {
		item := items[i]
		// Substitute {{ .loop.item }} / {{ .loop.index }} in body node configs.
		// 给 body 各节点 config 做 loop template 替换。
		evalCtx := workflowapp.EvalContext{
			Vars:     in.ExecCtx.Variables,
			NodesOut: in.ExecCtx.Outputs,
			Loop:     &workflowapp.LoopContext{Item: item, Index: i},
			Run: workflowapp.RunContext{
				ID:        in.ExecCtx.Run.ID,
				StartedAt: in.ExecCtx.Run.StartedAt.Format("2006-01-02T15:04:05Z07:00"),
			},
		}
		concreteBody, subErr := materializeBody(body, evalCtx)
		if subErr != nil {
			return fmt.Errorf("iteration %d: body templating: %w", i, subErr)
		}

		out := d.svc.ExecuteSubDAG(ctx, SubDAGRequest{
			Parent:         in.ExecCtx,
			Body:           concreteBody,
			ParentLoopNode: in.Node.ID,
			IterationIndex: i,
			Loop:           &workflowapp.LoopContext{Item: item, Index: i},
		})
		results[i] = out.Outputs
		if out.Err != nil {
			return out.Err
		}
		return nil
	}

	if parallel {
		errs := concurrentRun(len(items), concurrency, runOne)
		for i, e := range errs {
			if e == nil {
				continue
			}
			failMu.Lock()
			failures = append(failures, loopIterFailure{Index: i, Err: e.Error()})
			failMu.Unlock()
			if onError == LoopOnErrorStop {
				// We still let other in-flight goroutines finish (we already awaited via concurrentRun).
				// 已 await 所有并发；后续不再发起新轮。
			}
		}
	} else {
		for i := range items {
			if err := runOne(i); err != nil {
				failures = append(failures, loopIterFailure{Index: i, Err: err.Error()})
				if onError == LoopOnErrorStop {
					break
				}
			}
		}
	}

	if len(failures) > 0 && onError == LoopOnErrorStop {
		return DispatchOutput{Error: fmt.Errorf("loop node %q: iteration %d failed: %s",
			in.Node.ID, failures[0].Index, failures[0].Err)}
	}

	// Aggregate: per iteration, pick the body's terminal-node output (heuristic: last-listed node).
	// 聚合：每轮取 body 终端节点输出（启发式：最后一个节点）。
	terminalOut := pickTerminalOutputs(results, body)
	failuresOut := failuresToList(failures)

	return DispatchOutput{
		Outputs: map[string]any{
			"out":        terminalOut,
			"count":      len(items),
			"failures":   failuresOut,
			"successes":  len(items) - len(failures),
		},
	}
}

type loopIterFailure struct {
	Index int
	Err   string
}

func failuresToList(fs []loopIterFailure) []map[string]any {
	out := make([]map[string]any, len(fs))
	for i, f := range fs {
		out[i] = map[string]any{"index": f.Index, "error": f.Err}
	}
	return out
}

func pickTerminalOutputs(perIter []map[string]map[string]any, body *workflowdomain.Graph) []any {
	if body == nil || len(body.Nodes) == 0 {
		return nil
	}
	terminalID := body.Nodes[len(body.Nodes)-1].ID
	out := make([]any, len(perIter))
	for i, m := range perIter {
		if m == nil {
			out[i] = nil
			continue
		}
		out[i] = m[terminalID]
	}
	return out
}

// resolveItems pulls config.items as a literal []any; expression resolution at top level
// is the caller's job (the loop node's items field may be set by upstream node output via mapping in V2).
//
// resolveItems 取 config.items 字面量列表；表达式解析当前在调用方（V2 可加上游 mapping）。
func (d *LoopDispatcher) resolveItems(in DispatchInput) []any {
	raw, ok := in.Node.Config["items"]
	if !ok || raw == nil {
		return nil
	}
	switch v := raw.(type) {
	case []any:
		return v
	default:
		return nil
	}
}

func hasBody(raw map[string]any) bool {
	if raw == nil {
		return false
	}
	nodes, _ := raw["nodes"].([]any)
	return len(nodes) > 0
}

func loopOnError(cfg map[string]any) string {
	v, _ := cfg["onError"].(string)
	switch v {
	case LoopOnErrorContinue:
		return LoopOnErrorContinue
	default:
		return LoopOnErrorStop
	}
}

func loopParallel(cfg map[string]any) bool {
	v, _ := cfg["parallel"].(bool)
	return v
}

func loopConcurrency(cfg map[string]any) int {
	if v, ok := cfg["concurrency"]; ok {
		switch n := v.(type) {
		case int:
			if n > 0 {
				return n
			}
		case float64:
			if n > 0 {
				return int(n)
			}
		}
	}
	return DefaultLoopConcurrencyCap
}

// materializeBody returns a deep-substituted copy of body where each node's
// Config has been templated against evalCtx (so {{ .loop.item }} resolves per iteration).
//
// materializeBody 返 body 的深替换拷贝：每节点 Config 按 evalCtx 模板化（{{ .loop.item }} 按轮解析）。
func materializeBody(body *workflowdomain.Graph, evalCtx workflowapp.EvalContext) (*workflowdomain.Graph, error) {
	out := &workflowdomain.Graph{
		Edges:     body.Edges,
		Variables: body.Variables,
	}
	out.Nodes = make([]workflowdomain.NodeSpec, len(body.Nodes))
	for i, n := range body.Nodes {
		newCfg, err := SubstituteLoopTemplates(n.Config, evalCtx)
		if err != nil {
			return nil, fmt.Errorf("node %q: %w", n.ID, err)
		}
		out.Nodes[i] = n
		out.Nodes[i].Config = newCfg
	}
	return out, nil
}

// ErrLoopBodyNotSupported is kept for backward compat (tests).
// Now: body IS supported; sentinel reserved for future "body too deep / cycle" edge cases.
//
// ErrLoopBodyNotSupported 保留兼容旧测试。当前 body 已支持；sentinel 留给未来"太深 / cycle"边界。
var ErrLoopBodyNotSupported = errors.New("scheduler: loop body subgraph error")

// ErrParallelBranchNotSupported is returned when parallel.config.branches is non-empty.
//
// ErrParallelBranchNotSupported 在 parallel.config.branches 非空时返回。
var ErrParallelBranchNotSupported = errors.New("scheduler: parallel branch subgraph not supported in V1")

// ParallelDispatcher is a pass-through; natural parallel edges run concurrently in executeRun.
//
// ParallelDispatcher 是 pass-through；天然并行边由 executeRun 并发跑。
type ParallelDispatcher struct{}

// NewParallelDispatcher constructs ParallelDispatcher.
//
// NewParallelDispatcher 构造 ParallelDispatcher。
func NewParallelDispatcher() *ParallelDispatcher { return &ParallelDispatcher{} }

// Dispatch passes through; errors on non-empty config.branches.
//
// Dispatch pass-through；branches 非空时返错。
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
