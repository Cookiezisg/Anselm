package llmclient_test

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	llmclientpkg "github.com/sunweilin/forgify/backend/internal/pkg/llmclient"
)

// fakePicker returns canned (apiKeyID, modelID) per scenario.
// Note: ModelRef now uses APIKeyID instead of Provider.
type fakePicker struct {
	dialogue, utility, agent *modeldomain.ModelRef
}

func (f *fakePicker) PickForDialogue(ctx context.Context) (string, string, *modeldomain.ThinkingSpec, error) {
	if f.dialogue == nil {
		return "", "", nil, modeldomain.ErrNotConfigured
	}
	return f.dialogue.APIKeyID, f.dialogue.ModelID, f.dialogue.Thinking, nil
}
func (f *fakePicker) PickForUtility(ctx context.Context) (string, string, *modeldomain.ThinkingSpec, error) {
	if f.utility == nil {
		return "", "", nil, modeldomain.ErrNotConfigured
	}
	return f.utility.APIKeyID, f.utility.ModelID, f.utility.Thinking, nil
}
func (f *fakePicker) PickForAgent(ctx context.Context) (string, string, *modeldomain.ThinkingSpec, error) {
	if f.agent == nil {
		return "", "", nil, modeldomain.ErrNotConfigured
	}
	return f.agent.APIKeyID, f.agent.ModelID, f.agent.Thinking, nil
}

// fakeKeys returns canned credentials keyed by api_key id.
type fakeKeys struct {
	byID map[string]apikeydomain.Credentials
}

func (k *fakeKeys) ResolveCredentialsByID(ctx context.Context, apiKeyID string) (apikeydomain.Credentials, error) {
	if c, ok := k.byID[apiKeyID]; ok {
		return c, nil
	}
	return apikeydomain.Credentials{}, apikeydomain.ErrNotFound
}
func (k *fakeKeys) ResolveCredentials(ctx context.Context, provider string) (apikeydomain.Credentials, error) {
	return apikeydomain.Credentials{}, apikeydomain.ErrNotFoundForProvider
}
func (k *fakeKeys) MarkInvalid(ctx context.Context, provider string, reason string) error {
	return nil
}
func (k *fakeKeys) DefaultSearchProvider(ctx context.Context) string { return "" }

func newKeys() *fakeKeys {
	return &fakeKeys{byID: map[string]apikeydomain.Credentials{
		"aki_ant1": {Provider: "anthropic", Key: "sk-fake-ant", BaseURL: ""},
		"aki_ds1":  {Provider: "deepseek", Key: "sk-fake-ds", BaseURL: ""},
		"aki_oai1": {Provider: "openai", Key: "sk-fake-oai", BaseURL: ""},
	}}
}

func newFactory(t *testing.T) *llminfra.Factory {
	t.Helper()
	return llminfra.NewFactory()
}

func TestResolveDialogueWithOverride_NoOverride_UsesPicker(t *testing.T) {
	picker := &fakePicker{dialogue: &modeldomain.ModelRef{APIKeyID: "aki_ant1", ModelID: "sonnet"}}
	b, err := llmclientpkg.ResolveDialogueWithOverride(context.Background(), nil, picker, newKeys(), newFactory(t))
	if err != nil {
		t.Fatal(err)
	}
	if b.APIKeyID != "aki_ant1" || b.ModelID != "sonnet" || b.Provider != "anthropic" {
		t.Fatalf("got (%q,%q,%q)", b.APIKeyID, b.ModelID, b.Provider)
	}
}

func TestResolveDialogueWithOverride_WithOverride_BeatsPicker(t *testing.T) {
	picker := &fakePicker{dialogue: &modeldomain.ModelRef{APIKeyID: "aki_ant1", ModelID: "sonnet"}}
	override := &modeldomain.ModelRef{APIKeyID: "aki_oai1", ModelID: "gpt-4o"}
	b, err := llmclientpkg.ResolveDialogueWithOverride(context.Background(), override, picker, newKeys(), newFactory(t))
	if err != nil {
		t.Fatal(err)
	}
	if b.APIKeyID != "aki_oai1" || b.ModelID != "gpt-4o" {
		t.Fatalf("override ignored, got (%q,%q)", b.APIKeyID, b.ModelID)
	}
}

func TestResolveDialogueWithOverride_PickerErrPickModel(t *testing.T) {
	picker := &fakePicker{}
	_, err := llmclientpkg.ResolveDialogueWithOverride(context.Background(), nil, picker, newKeys(), newFactory(t))
	if !errors.Is(err, llmclientpkg.ErrPickModel) {
		t.Fatalf("want ErrPickModel, got %v", err)
	}
}

func TestResolveUtility(t *testing.T) {
	picker := &fakePicker{utility: &modeldomain.ModelRef{APIKeyID: "aki_ant1", ModelID: "haiku"}}
	b, err := llmclientpkg.ResolveUtility(context.Background(), picker, newKeys(), newFactory(t))
	if err != nil {
		t.Fatal(err)
	}
	if b.APIKeyID != "aki_ant1" || b.ModelID != "haiku" {
		t.Fatalf("got (%q,%q)", b.APIKeyID, b.ModelID)
	}
}

func TestResolveAgentWithOverride_NoOverride_UsesPicker(t *testing.T) {
	picker := &fakePicker{agent: &modeldomain.ModelRef{APIKeyID: "aki_ds1", ModelID: "deepseek-chat"}}
	b, err := llmclientpkg.ResolveAgentWithOverride(context.Background(), nil, picker, newKeys(), newFactory(t))
	if err != nil {
		t.Fatal(err)
	}
	if b.APIKeyID != "aki_ds1" || b.Provider != "deepseek" {
		t.Fatalf("got (%q,%q)", b.APIKeyID, b.Provider)
	}
}

func TestResolveAgentWithOverride_WithOverride_Beats(t *testing.T) {
	picker := &fakePicker{agent: &modeldomain.ModelRef{APIKeyID: "aki_ds1", ModelID: "deepseek-chat"}}
	override := &modeldomain.ModelRef{APIKeyID: "aki_ant1", ModelID: "sonnet"}
	b, err := llmclientpkg.ResolveAgentWithOverride(context.Background(), override, picker, newKeys(), newFactory(t))
	if err != nil {
		t.Fatal(err)
	}
	if b.APIKeyID != "aki_ant1" || b.ModelID != "sonnet" {
		t.Fatalf("override ignored, got (%q,%q)", b.APIKeyID, b.ModelID)
	}
}

func TestResolveDialogueWithOverride_OverrideRefersToMissingKey_ErrResolveCreds(t *testing.T) {
	picker := &fakePicker{dialogue: &modeldomain.ModelRef{APIKeyID: "aki_ant1", ModelID: "sonnet"}}
	override := &modeldomain.ModelRef{APIKeyID: "aki_deleted", ModelID: "gpt-4o"}
	_, err := llmclientpkg.ResolveDialogueWithOverride(context.Background(), override, picker, newKeys(), newFactory(t))
	if !errors.Is(err, llmclientpkg.ErrResolveCreds) {
		t.Fatalf("want ErrResolveCreds, got %v", err)
	}
}

func TestResolveDialogueWithOverride_OverrideThinking_FlowsToBundle(t *testing.T) {
	// override carries Thinking {on, high} → Bundle.Thinking must mirror it in infra form.
	// override 携带 Thinking {on, high} → Bundle.Thinking 必须映射为 infra 形式。
	override := &modeldomain.ModelRef{
		APIKeyID: "aki_ant1",
		ModelID:  "sonnet",
		Thinking: &modeldomain.ThinkingSpec{Mode: "on", Effort: "high"},
	}
	picker := &fakePicker{dialogue: &modeldomain.ModelRef{APIKeyID: "aki_ds1", ModelID: "deepseek-chat"}}
	b, err := llmclientpkg.ResolveDialogueWithOverride(context.Background(), override, picker, newKeys(), newFactory(t))
	if err != nil {
		t.Fatal(err)
	}
	if b.Thinking == nil {
		t.Fatal("Bundle.Thinking is nil, want {on, high, 0}")
	}
	if b.Thinking.Mode != "on" || b.Thinking.Effort != "high" || b.Thinking.Budget != 0 {
		t.Errorf("Bundle.Thinking = %+v, want {on high 0}", b.Thinking)
	}
}

func TestResolveDialogueWithOverride_PickerThinking_FlowsToBundle(t *testing.T) {
	// override absent; dialogue ModelConfig has Thinking {on, budget:5000} → Bundle.Thinking == {on, 5000}.
	// override 缺失；dialogue ModelConfig 有 Thinking {on, budget:5000} → Bundle.Thinking == {on, 5000}。
	picker := &fakePicker{dialogue: &modeldomain.ModelRef{
		APIKeyID: "aki_ant1",
		ModelID:  "sonnet",
		Thinking: &modeldomain.ThinkingSpec{Mode: "on", Budget: 5000},
	}}
	b, err := llmclientpkg.ResolveDialogueWithOverride(context.Background(), nil, picker, newKeys(), newFactory(t))
	if err != nil {
		t.Fatal(err)
	}
	if b.Thinking == nil {
		t.Fatal("Bundle.Thinking is nil, want {on,  5000}")
	}
	if b.Thinking.Mode != "on" || b.Thinking.Effort != "" || b.Thinking.Budget != 5000 {
		t.Errorf("Bundle.Thinking = %+v, want {on  5000}", b.Thinking)
	}
}

func TestResolveDialogueWithOverride_NoThinking_BundleThinkingIsNil(t *testing.T) {
	// No thinking anywhere → Bundle.Thinking must be nil (= auto, no wire change).
	// 全无 thinking → Bundle.Thinking 必须为 nil（= auto，线上不变）。
	picker := &fakePicker{dialogue: &modeldomain.ModelRef{APIKeyID: "aki_ant1", ModelID: "sonnet"}}
	b, err := llmclientpkg.ResolveDialogueWithOverride(context.Background(), nil, picker, newKeys(), newFactory(t))
	if err != nil {
		t.Fatal(err)
	}
	if b.Thinking != nil {
		t.Errorf("Bundle.Thinking = %+v, want nil", b.Thinking)
	}
}

func TestResolveDialogue_CustomAnthropicCompat_RoutesToAnthropicClient(t *testing.T) {
	// A custom+anthropic-compatible key must reach the Anthropic wire client, which
	// POSTs to /v1/messages — not the OpenAI /chat/completions endpoint.
	// custom+anthropic-compatible key 必须走 Anthropic wire client（POST /v1/messages），而非 OpenAI。
	var gotPath string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		// Return a minimal SSE message_stop so the Anthropic client terminates cleanly.
		w.Header().Set("Content-Type", "text/event-stream")
		_, _ = w.Write([]byte("data: {\"type\":\"message_stop\"}\n\n"))
	}))
	defer srv.Close()

	keys := &fakeKeys{byID: map[string]apikeydomain.Credentials{
		"aki_custom1": {
			Provider:  "custom",
			Key:       "sk-custom",
			BaseURL:   srv.URL,
			APIFormat: apikeydomain.APIFormatAnthropicCompatible,
		},
	}}
	picker := &fakePicker{dialogue: &modeldomain.ModelRef{APIKeyID: "aki_custom1", ModelID: "my-model"}}
	b, err := llmclientpkg.ResolveDialogueWithOverride(context.Background(), nil, picker, keys, newFactory(t))
	if err != nil {
		t.Fatalf("ResolveDialogueWithOverride: %v", err)
	}

	// Consume the stream to trigger the HTTP call; we only care which path was hit.
	// The caller must populate Key/BaseURL/ModelID on Request from the Bundle (chat runner pattern).
	// 调用方需从 Bundle 把 Key/BaseURL/ModelID 填入 Request（同 chat runner 用法）。
	for range b.Client.Stream(context.Background(), llminfra.Request{
		Key:      b.Key,
		BaseURL:  b.BaseURL,
		ModelID:  b.ModelID,
		Messages: []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: "hi"}},
	}) {
	}

	if gotPath != "/v1/messages" {
		t.Errorf("client hit path %q, want /v1/messages (anthropic endpoint); custom+anthropic-compatible routed to wrong client", gotPath)
	}
}
