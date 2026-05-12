// dispatch_variable.go — VariableDispatcher. Reads node.Config keys
// `operation` ("set" / "unset") and `name` + `value` to mutate
// ExecCtx.Variables. Plan 05 §3.2 variable.
//
// dispatch_variable.go —— VariableDispatcher;set/unset ExecCtx.Variables。

package scheduler

import (
	"context"
	"fmt"
)

// VariableDispatcher mutates workflow-level Variables in-place.
//
// VariableDispatcher 原地改 workflow-level Variables。
type VariableDispatcher struct{}

// NewVariableDispatcher constructs VariableDispatcher.
//
// NewVariableDispatcher 构造 VariableDispatcher。
func NewVariableDispatcher() *VariableDispatcher { return &VariableDispatcher{} }

// Dispatch performs the set/unset op against ExecCtx.Variables.
//
// Dispatch 在 ExecCtx.Variables 执行 set/unset。
func (d *VariableDispatcher) Dispatch(_ context.Context, in DispatchInput) DispatchOutput {
	op, _ := in.Node.Config["operation"].(string)
	name, _ := in.Node.Config["name"].(string)
	if name == "" {
		return DispatchOutput{Error: fmt.Errorf("variable node %q: name required", in.Node.ID)}
	}
	switch op {
	case "set", "":
		in.ExecCtx.Variables[name] = in.Node.Config["value"]
	case "unset":
		delete(in.ExecCtx.Variables, name)
	default:
		return DispatchOutput{Error: fmt.Errorf("variable node %q: unknown operation %q", in.Node.ID, op)}
	}
	return DispatchOutput{Outputs: map[string]any{"out": in.ExecCtx.Variables[name]}}
}
