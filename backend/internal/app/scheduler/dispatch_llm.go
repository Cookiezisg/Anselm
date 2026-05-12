// dispatch_llm.go — LLMDispatcher. Reads node.Config keys `scenario` +
// `prompt` and calls the injected LLMCaller. Kept behind an interface
// so the scheduler doesn't depend directly on model/apikey/llminfra
// (E15 main.go wires the concrete LLMCaller).
//
// dispatch_llm.go —— LLMDispatcher;经 LLMCaller 接口调 LLM,scheduler
// 不直接依赖 model/apikey/llminfra。

package scheduler

import (
	"context"
	"fmt"
)

// LLMCaller is the port LLMDispatcher consumes. main.go (E15) wires a
// concrete impl that resolves scenario → model + apikey → llminfra.Client
// → Generate. A nil LLMCaller makes the dispatcher fail every node — fine
// in tests that don't exercise the LLM path.
//
// LLMCaller 是 LLMDispatcher 消费的端口;E15 main.go 接真实现(scenario →
// model + apikey → llminfra.Client → Generate)。nil → 节点全失败,测试
// 不触 LLM 路径时 OK。
type LLMCaller interface {
	// Generate calls the configured scenario's LLM with prompt + optional
	// inputs map (templated into the prompt by the caller), returning the
	// generated text.
	//
	// Generate 调指定 scenario 的 LLM,返生成文本。
	Generate(ctx context.Context, scenario, prompt string, vars map[string]any) (string, error)
}

// LLMDispatcher bridges workflow llm nodes to the LLMCaller port.
//
// LLMDispatcher 桥接 workflow llm 节点到 LLMCaller。
type LLMDispatcher struct {
	caller LLMCaller
}

// NewLLMDispatcher constructs LLMDispatcher. caller may be nil — every
// dispatch returns an error in that case.
//
// NewLLMDispatcher 构造 LLMDispatcher;caller nil 时每次 dispatch 返错。
func NewLLMDispatcher(caller LLMCaller) *LLMDispatcher {
	return &LLMDispatcher{caller: caller}
}

// Dispatch reads scenario + prompt from node.Config.
//
// Dispatch 读 scenario + prompt 调 LLM。
func (d *LLMDispatcher) Dispatch(ctx context.Context, in DispatchInput) DispatchOutput {
	if d.caller == nil {
		return DispatchOutput{Error: fmt.Errorf("llm node %q: no LLMCaller wired", in.Node.ID)}
	}
	scenario, _ := in.Node.Config["scenario"].(string)
	prompt, _ := in.Node.Config["prompt"].(string)
	if scenario == "" {
		scenario = "chat"
	}
	if prompt == "" {
		return DispatchOutput{Error: fmt.Errorf("llm node %q: prompt required", in.Node.ID)}
	}

	out, err := d.caller.Generate(ctx, scenario, prompt, in.ExecCtx.Variables)
	if err != nil {
		return DispatchOutput{Error: err}
	}
	return DispatchOutput{Outputs: map[string]any{"out": out}}
}
