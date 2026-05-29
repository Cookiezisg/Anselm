package llm

import "testing"

func TestLookupProvider_KnownNamesResolveToSelf(t *testing.T) {
	cases := []struct {
		provider string
		wantName string
		wantBase string
	}{
		{"openai", "openai", "https://api.openai.com/v1"},
		{"deepseek", "deepseek", "https://api.deepseek.com"},
		{"google", "google", "https://generativelanguage.googleapis.com/v1beta/openai"},
		{"qwen", "qwen", "https://dashscope.aliyuncs.com/compatible-mode/v1"},
		{"zhipu", "zhipu", "https://open.bigmodel.cn/api/paas/v4"},
		{"moonshot", "moonshot", "https://api.moonshot.cn/v1"},
		{"doubao", "doubao", "https://ark.cn-beijing.volces.com/api/v3"},
		{"openrouter", "openrouter", "https://openrouter.ai/api/v1"},
		{"anthropic", "anthropic", "https://api.anthropic.com"},
	}
	for _, tc := range cases {
		t.Run(tc.provider, func(t *testing.T) {
			p := lookupProvider(Config{Provider: tc.provider})
			if p.Name() != tc.wantName {
				t.Errorf("Name() = %q, want %q", p.Name(), tc.wantName)
			}
			if p.DefaultBaseURL() != tc.wantBase {
				t.Errorf("DefaultBaseURL() = %q, want %q", p.DefaultBaseURL(), tc.wantBase)
			}
		})
	}
}

func TestLookupProvider_UnknownFallsBackToOpenAICompat(t *testing.T) {
	p := lookupProvider(Config{Provider: "not-a-real-provider"})
	if p.Name() != "openai" {
		t.Errorf("unknown provider should fall back to openai-compat, got %q", p.Name())
	}
}

// custom defaults to the OpenAI-compat wire dialect (its own identity, compat
// body/SSE) — only an explicit anthropic-compatible APIFormat reroutes it to
// the Anthropic provider.
//
// custom 默认走 OpenAI-compat wire 方言（自有身份，compat body/SSE）；只有显式
// anthropic-compatible 才改路由到 Anthropic。
func TestLookupProvider_CustomDefaultsToOpenAICompat(t *testing.T) {
	p := lookupProvider(Config{Provider: "custom"})
	if _, ok := p.(*openAICompatProvider); !ok {
		t.Errorf("bare custom should use the openai-compat dialect, got %T", p)
	}
	if p.Name() != "custom" {
		t.Errorf("bare custom should keep its own identity, got Name()=%q", p.Name())
	}
}

func TestLookupProvider_CustomAnthropicCompatRoutesToAnthropic(t *testing.T) {
	p := lookupProvider(Config{Provider: "custom", APIFormat: "anthropic-compatible"})
	if p.Name() != "anthropic" {
		t.Errorf("custom+anthropic-compatible should route to anthropic provider, got %q", p.Name())
	}
}

// ollama is OpenAI-compat with an empty default base URL — the caller must
// supply base_url, matching resolveBaseURL's required-base-url path.
//
// ollama 是 OpenAI-compat 但默认 base URL 为空——caller 必须给 base_url。
func TestLookupProvider_OllamaIsCompatWithEmptyBase(t *testing.T) {
	p := lookupProvider(Config{Provider: "ollama"})
	if p.Name() != "ollama" {
		t.Errorf("Name() = %q, want ollama", p.Name())
	}
	if p.DefaultBaseURL() != "" {
		t.Errorf("ollama DefaultBaseURL() = %q, want empty", p.DefaultBaseURL())
	}
}

// mock is intentionally absent from the registry — Build short-circuits to the
// MockClient, so the wire registry has no mock Provider to resolve.
//
// mock 故意不在 registry——Build 直接短路到 MockClient，wire registry 无 mock Provider。
func TestProviderRegistry_OmitsMock(t *testing.T) {
	if _, ok := providerRegistry["mock"]; ok {
		t.Error("mock must not be a wire Provider; Build short-circuits to MockClient")
	}
}
