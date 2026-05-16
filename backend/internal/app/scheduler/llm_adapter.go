package scheduler

import (
	"context"
	"fmt"

	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	llmclientpkg "github.com/sunweilin/forgify/backend/internal/pkg/llmclient"
)

// DefaultLLMCaller implements LLMCaller by routing every Generate call
// through llmclient.Resolve(picker, keys, factory) + llminfra.Generate.
// V1 ignores `scenario` (always uses chat scenario) — workflow `llm`
// nodes just need a single-shot text completion; bespoke scenarios are
// out of scope until model_picker grows per-scenario methods.
//
// DefaultLLMCaller 实现 LLMCaller:每次 Generate 走 llmclient.Resolve
// + llminfra.Generate。V1 忽略 scenario(始终用 chat 场景)——workflow `llm`
// 节点只要单次补全,自定义 scenario 等 model_picker 扩字段。
type DefaultLLMCaller struct {
	picker  modeldomain.ModelPicker
	keys    apikeydomain.KeyProvider
	factory *llminfra.Factory
}

// NewDefaultLLMCaller wires the three resolver deps; any nil causes Generate to err.
//
// NewDefaultLLMCaller 装配 3 个解析依赖;任一 nil 时 Generate 返错。
func NewDefaultLLMCaller(
	picker modeldomain.ModelPicker,
	keys apikeydomain.KeyProvider,
	factory *llminfra.Factory,
) *DefaultLLMCaller {
	return &DefaultLLMCaller{picker: picker, keys: keys, factory: factory}
}

func (a *DefaultLLMCaller) Generate(ctx context.Context, scenario, prompt string, _ map[string]any) (string, error) {
	if a.picker == nil || a.keys == nil || a.factory == nil {
		return "", fmt.Errorf("DefaultLLMCaller: missing picker/keys/factory")
	}
	bundle, err := llmclientpkg.Resolve(ctx, a.picker, a.keys, a.factory)
	if err != nil {
		return "", fmt.Errorf("DefaultLLMCaller.Generate: %w", err)
	}
	req := llminfra.Request{
		ModelID: bundle.ModelID,
		Key:     bundle.Key,
		BaseURL: bundle.BaseURL,
		System:  "You are a workflow LLM step. Respond concisely.",
		Messages: []llminfra.LLMMessage{
			{Role: llminfra.RoleUser, Content: prompt},
		},
	}
	out, err := llminfra.Generate(ctx, bundle.Client, req)
	if err != nil {
		return "", fmt.Errorf("DefaultLLMCaller.Generate: %w", err)
	}
	return out, nil
}
