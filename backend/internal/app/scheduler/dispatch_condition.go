package scheduler

import (
	"context"
	"fmt"

	workflowapp "github.com/sunweilin/forgify/backend/internal/app/workflow"
)

// ConditionDispatcher evaluates condition expressions for branching using CEL (replacing text/template).
// The old-style condition node (config.condition = a single CEL expression) routes to "true" or "false"
// port. In new workflows use the case node with per-branch when: guards instead.
//
// ConditionDispatcher 用 CEL 评估 condition（取代旧 text/template）；新 workflow 推荐 case 节点。
type ConditionDispatcher struct{}

// NewConditionDispatcher constructs ConditionDispatcher.
//
// NewConditionDispatcher 构造 ConditionDispatcher。
func NewConditionDispatcher() *ConditionDispatcher { return &ConditionDispatcher{} }

// Dispatch evaluates the CEL condition and routes to the "true" or "false" port.
// On eval error: fail-to-false (G9) — routes to "false" instead of aborting.
//
// Dispatch 评估 CEL condition 走 true/false port；求值出错按 fail-to-false(G9)走 false。
func (d *ConditionDispatcher) Dispatch(_ context.Context, in DispatchInput) DispatchOutput {
	exprSrc, _ := in.Node.Config["condition"].(string)
	if exprSrc == "" {
		return DispatchOutput{Error: fmt.Errorf("condition node %q: condition required", in.Node.ID)}
	}

	prg, compileErr := workflowapp.CompileCEL(exprSrc)
	if compileErr != nil {
		return DispatchOutput{Error: fmt.Errorf("condition node %q: compile: %w", in.Node.ID, compileErr)}
	}

	// Build payload + ctx map the same way the interpreter does for case nodes.
	payload := in.NodeIn
	if payload == nil {
		payload = map[string]any{}
	}
	ctxMap := map[string]any{}
	if in.ExecCtx != nil && in.ExecCtx.Run != nil {
		ctxMap["runId"] = in.ExecCtx.Run.ID
	}

	// G9 fail-to-false: eval error → treat as false (don't abort the flowrun).
	matched, evalErr := prg.EvalBool(payload, ctxMap)
	if evalErr != nil {
		matched = false
	}

	port := "false"
	if matched {
		port = "true"
	}
	return DispatchOutput{
		Outputs:  map[string]any{"out": matched, "branch": port},
		NextPort: port,
	}
}
