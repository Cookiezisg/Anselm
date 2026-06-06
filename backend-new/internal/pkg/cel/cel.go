// Package cel compiles and evaluates bare CEL expressions over a `payload` (and optional
// `ctx`) variable. The env exposes no now()/wall-clock function, so guards stay
// replay-deterministic. Shared by trigger sensors (condition/output) and — later — the
// workflow interpreter (case.when / emit / tool.args), so it lives in pkg, not in a domain.
//
// Package cel 编译并求值裸 CEL 表达式（读 `payload` + 可选 `ctx`）。env 无 now()/墙钟，保证重放确定。
// 由 trigger sensor（condition/output）与（日后）workflow 解释器共用，故放 pkg 而非某个 domain。
package cel

import (
	"fmt"

	celgo "github.com/google/cel-go/cel"
	"github.com/google/cel-go/common/types/ref"
)

// env is the shared CEL environment. Expressions read `payload` and `ctx` only.
//
// env 是共享 CEL 环境；表达式只读 payload/ctx。
var env *celgo.Env

func init() {
	e, err := celgo.NewEnv(
		celgo.Variable("payload", celgo.DynType),
		celgo.Variable("ctx", celgo.DynType),
	)
	if err != nil {
		panic(fmt.Sprintf("pkg/cel: env init: %v", err))
	}
	env = e
}

// Program is a compiled bare-CEL expression.
//
// Program 是编译后的裸 CEL 表达式。
type Program struct {
	prg celgo.Program
	src string
}

// Compile compiles a bare CEL expression that reads payload/ctx. A syntax error or an unknown
// function (e.g. now()) fails here — call it at create/edit time so authoring errors fail fast.
//
// Compile 编译读 payload/ctx 的裸 CEL 表达式；语法错 / 未知函数（如 now()）在此失败——create/edit 时调以快速失败。
func Compile(expr string) (*Program, error) {
	ast, iss := env.Compile(expr)
	if iss != nil && iss.Err() != nil {
		return nil, fmt.Errorf("cel.Compile %q: %w", expr, iss.Err())
	}
	prg, err := env.Program(ast)
	if err != nil {
		return nil, fmt.Errorf("cel.Compile %q: program: %w", expr, err)
	}
	return &Program{prg: prg, src: expr}, nil
}

// Eval evaluates to a native Go value (recursing into lists/maps), e.g. building a fire payload.
//
// Eval 求值为 native Go 值（递归 list/map），如构造 fire payload。
func (p *Program) Eval(payload, ctxVar map[string]any) (any, error) {
	out, _, err := p.prg.Eval(activation(payload, ctxVar))
	if err != nil {
		return nil, fmt.Errorf("cel.Eval %q: %w", p.src, err)
	}
	return refToGo(out), nil
}

// EvalBool evaluates to bool (a condition guard). A non-bool result is an authoring error.
//
// EvalBool 求值为 bool（条件守卫）；非 bool 结果是编写错误。
func (p *Program) EvalBool(payload, ctxVar map[string]any) (bool, error) {
	out, _, err := p.prg.Eval(activation(payload, ctxVar))
	if err != nil {
		return false, fmt.Errorf("cel.EvalBool %q: %w", p.src, err)
	}
	if b, ok := out.Value().(bool); ok {
		return b, nil
	}
	return false, fmt.Errorf("cel.EvalBool %q: result is %T, not bool", p.src, out.Value())
}

func activation(payload, ctxVar map[string]any) map[string]any {
	if payload == nil {
		payload = map[string]any{}
	}
	if ctxVar == nil {
		ctxVar = map[string]any{}
	}
	return map[string]any{"payload": payload, "ctx": ctxVar}
}

// refToGo converts a CEL ref.Val to native Go, recursing into lists/maps.
//
// refToGo 把 CEL ref.Val 转 native Go，递归 list/map。
func refToGo(v ref.Val) any {
	switch val := v.Value().(type) {
	case []ref.Val:
		out := make([]any, len(val))
		for i, e := range val {
			out[i] = refToGo(e)
		}
		return out
	case map[ref.Val]ref.Val:
		out := make(map[string]any, len(val))
		for k, e := range val {
			out[fmt.Sprint(k.Value())] = refToGo(e)
		}
		return out
	default:
		return val
	}
}
