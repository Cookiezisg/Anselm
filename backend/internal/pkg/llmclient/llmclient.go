// Package llmclient resolves the per-request LLM client by walking the
// canonical three-step dance every chat / forge callsite shares:
//
//  1. picker.PickForChat(ctx)        → (provider, modelID)
//  2. keys.ResolveCredentials(ctx,…) → (key, baseURL)
//  3. factory.Build(Config{…})       → (client, baseURL)
//
// Centralised here so callers (chat.runner / tool/forge tools / forgeapp's
// LLMClient adapter / e2e harness) all use the same wiring without inlining
// 12+ lines per site.
//
// Package llmclient 把每个 chat / forge 调用点共享的 LLM 客户端解析三段舞
// 集中实现：
//
//  1. picker.PickForChat(ctx)        → (provider, modelID)
//  2. keys.ResolveCredentials(ctx,…) → (key, baseURL)
//  3. factory.Build(Config{…})       → (client, baseURL)
//
// 让调用方（chat.runner / tool/forge 工具 / forgeapp 的 LLMClient 适配器 /
// e2e harness）走同一套装配，不用每处内联 12+ 行。
package llmclient

import (
	"context"
	"errors"
	"fmt"

	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
)

// Step sentinels mark which of the three resolve stages failed. Callers that
// surface different user-facing error codes per stage (e.g. chat.runner
// emitting MODEL_NOT_CONFIGURED vs API_KEY_PROVIDER_NOT_FOUND vs
// LLM_PROVIDER_ERROR) use errors.Is on these to dispatch.
//
// Step sentinel 标记三段解析中的具体失败步骤。需按步骤分用户可见错误码的
// 调用方（如 chat.runner 区分 MODEL_NOT_CONFIGURED / API_KEY_PROVIDER_NOT_FOUND
// / LLM_PROVIDER_ERROR）用 errors.Is 分派。
var (
	ErrPickModel    = errors.New("llmclient: pick model failed")
	ErrResolveCreds = errors.New("llmclient: resolve credentials failed")
	ErrBuildClient  = errors.New("llmclient: build client failed")
)

// Bundle is the resolved per-request LLM bundle: a ready streaming Client
// plus the identity fields callers need to populate llminfra.Request.
//
// Bundle 是单次请求解析后的 LLM 打包：随时可流式调用的 Client，加上调用方
// 填 llminfra.Request 时需要的身份字段。
type Bundle struct {
	Client   llminfra.Client
	Provider string
	ModelID  string
	Key      string
	BaseURL  string
}

// Resolve walks the three-step picker → keys → factory dance and returns
// the resolved Bundle. Errors at any step are wrapped with "llmclient.Resolve:".
//
// Resolve 走 picker → keys → factory 三段，返回解析后的 Bundle。
// 任一步骤失败用 "llmclient.Resolve:" 前缀包装。
func Resolve(
	ctx context.Context,
	picker modeldomain.ModelPicker,
	keys apikeydomain.KeyProvider,
	factory *llminfra.Factory,
) (*Bundle, error) {
	provider, modelID, err := picker.PickForChat(ctx)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrPickModel, err)
	}
	return finishResolve(ctx, provider, modelID, keys, factory)
}

// ResolveForWebSummary resolves the LLM bundle the WebFetch tool uses to
// summarise fetched content. Tries the user's web_summary scenario first;
// if not configured, transparently falls back to the chat scenario so
// summarisation works out of the box without a separate setup step.
//
// ResolveForWebSummary 解析 WebFetch 工具用于摘要的 LLM bundle。先尝试
// 用户的 web_summary 场景；未配置则透明 fallback 到 chat 场景，保证摘要
// 开箱即用，无需额外配置。
func ResolveForWebSummary(
	ctx context.Context,
	picker modeldomain.ModelPicker,
	keys apikeydomain.KeyProvider,
	factory *llminfra.Factory,
) (*Bundle, error) {
	provider, modelID, err := picker.PickForWebSummary(ctx)
	if errors.Is(err, modeldomain.ErrNotConfigured) {
		provider, modelID, err = picker.PickForChat(ctx)
	}
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrPickModel, err)
	}
	return finishResolve(ctx, provider, modelID, keys, factory)
}

// finishResolve runs the keys → factory portion shared by Resolve and
// ResolveForWebSummary so the picker step is the only thing that varies
// between callsites.
//
// finishResolve 跑 keys → factory 部分，被 Resolve 与 ResolveForWebSummary
// 共用——picker 步骤是两者唯一差异。
func finishResolve(
	ctx context.Context,
	provider, modelID string,
	keys apikeydomain.KeyProvider,
	factory *llminfra.Factory,
) (*Bundle, error) {
	creds, err := keys.ResolveCredentials(ctx, provider)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrResolveCreds, err)
	}
	client, baseURL, err := factory.Build(llminfra.Config{
		Provider: provider,
		ModelID:  modelID,
		Key:      creds.Key,
		BaseURL:  creds.BaseURL,
	})
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrBuildClient, err)
	}
	return &Bundle{
		Client:   client,
		Provider: provider,
		ModelID:  modelID,
		Key:      creds.Key,
		BaseURL:  baseURL,
	}, nil
}
