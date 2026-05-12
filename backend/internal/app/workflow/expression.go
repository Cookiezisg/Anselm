// expression.go — Go text/template-backed expression language for node
// configs. {{ vars.x }} / {{ in.field }} / {{ nodes.<id>.output.field }} /
// {{ loop.item }} / {{ loop.index }} / {{ run.id }} / {{ run.startedAt }} /
// {{ env.X }} (env whitelist below).
//
// Authoring-side responsibility: compile-check syntax (workflowapp.Compile),
// and confirm referenced variables exist (validate.go::checkVariableRefs).
// Runtime evaluation lives in the scheduler (Plan 05) — Execute() here is
// provided for tests + future scheduler reuse.
//
// V1 deliberately does NOT support: arithmetic, ternary, JSONPath. Complex
// shape transforms → write a function node.
//
// expression.go —— Go text/template 实现的表达式语言。authoring 侧职责:
// syntax 编译期校验(Compile)+ 引用变量声明检测(validate.go)。运行时求值
// 留 Plan 05 scheduler;本文件 Execute 给单测 + 未来复用。

package workflow

import (
	"bytes"
	"fmt"
	"strings"
	"text/template"
)

// EnvWhitelist is the safe set of OS env variables exposed to workflow
// expressions via {{ env.X }}. Anything outside this list returns ""
// (avoids leaking secrets like API keys / DB passwords). V1 conservative
// — extend as concrete need surfaces.
//
// EnvWhitelist 是 workflow 表达式 {{ env.X }} 允许暴露的 OS env 白名单。
// 名单外返 "",防 API_KEY / DB_PASSWORD 泄漏。V1 保守,按需扩展。
var EnvWhitelist = map[string]bool{
	"USER":     true,
	"HOME":     true,
	"LANG":     true,
	"TZ":       true,
	"HOSTNAME": true,
}

// EvalContext is the runtime input bag for expression evaluation. The
// scheduler builds this per node invocation and passes it to Execute.
//
// EvalContext 是运行期表达式求值的输入袋;scheduler 每节点构造一次。
type EvalContext struct {
	Vars      map[string]any            // workflow-level variables (current values)
	In        map[string]any            // current node's input port data
	NodesOut  map[string]map[string]any // upstream nodes' outputs by node id; inner map keyed by port name
	Loop      *LoopContext              // populated inside loop bodies; nil otherwise
	Run       RunContext                // FlowRun metadata
	Env       map[string]string         // OS env (caller pre-filtered to EnvWhitelist)
}

// LoopContext is the per-iteration state inside a loop body. Populated by
// the scheduler when executing nodes inside a loop's body subgraph.
//
// LoopContext 是 loop body 每次迭代的状态;scheduler 进入 body 时填。
type LoopContext struct {
	Item  any
	Index int
}

// RunContext is the FlowRun-level metadata exposed as {{ run.* }}.
//
// RunContext 是 FlowRun 级元信息,暴露为 {{ run.* }}。
type RunContext struct {
	ID        string
	StartedAt string // RFC3339
}

// Compile parses s as a Go text/template. Returns the compiled template
// or a syntax error wrapped with the original source for context. Use
// this at authoring time to validate before saving — the scheduler caches
// compiled templates per node config string.
//
// Compile 把 s 解析为 Go text/template;syntax 错误带原文返。authoring 侧
// 在保存前调用;scheduler 按 node config string 缓存编译产物。
func Compile(s string) (*template.Template, error) {
	if !strings.Contains(s, "{{") {
		// Pure literal — no template syntax to validate. Returning a nil
		// template is intentional; Execute treats nil as "passthrough".
		// 无 {{ 子串 = 纯字面量;不需要 template,Execute 直返 s。
		return nil, nil
	}
	tmpl, err := template.New("expr").Funcs(funcMap()).Parse(s)
	if err != nil {
		return nil, fmt.Errorf("expression syntax error: %w (source: %q)", err, s)
	}
	return tmpl, nil
}

// Execute runs a compiled template against ctx and returns the resulting
// string. nil template (returned by Compile for pure literals) passes
// through the original source — callers should keep the source string
// around for that case.
//
// Execute 把编译产物在 ctx 上跑返字符串;tmpl 为 nil(纯字面量)由 callers
// 保留原 s 直接返。
func Execute(tmpl *template.Template, ctx EvalContext, literal string) (string, error) {
	if tmpl == nil {
		return literal, nil
	}
	// Filter Env to whitelist before exposing — defence in depth (caller
	// should pre-filter but we double-check so a misconfigured scheduler
	// can't leak).
	// 暴露前白名单过滤 env;调用方应已过滤,这里 defence in depth。
	safeEnv := make(map[string]string, len(ctx.Env))
	for k, v := range ctx.Env {
		if EnvWhitelist[k] {
			safeEnv[k] = v
		}
	}
	data := map[string]any{
		"vars":  ctx.Vars,
		"in":    ctx.In,
		"nodes": ctx.NodesOut,
		"run": map[string]any{
			"id":        ctx.Run.ID,
			"startedAt": ctx.Run.StartedAt,
		},
		"env": safeEnv,
	}
	if ctx.Loop != nil {
		data["loop"] = map[string]any{
			"item":  ctx.Loop.Item,
			"index": ctx.Loop.Index,
		}
	}
	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, data); err != nil {
		return "", fmt.Errorf("expression eval: %w", err)
	}
	return buf.String(), nil
}

// funcMap is the template func registry. V1 has no funcs — Go's text/
// template default actions (field access, range, if/else, with) cover
// the §6.2 reference forms. V1.5 will add lightweight helpers (printf,
// json, default) here as concrete needs surface.
//
// funcMap 是 template 函数表;V1 空,模板内置 action 已够 §6.2 引用;
// V1.5 按需加 printf/json/default 等轻量 helper。
func funcMap() template.FuncMap {
	return template.FuncMap{}
}
