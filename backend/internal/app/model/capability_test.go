package model

import (
	"context"
	"errors"
	"testing"

	"go.uber.org/zap"

	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
)

// fakeProbeReader feeds canned probe archives without an apikey store.
//
// fakeProbeReader 在无 apikey store 下喂预设探测档案。
type fakeProbeReader struct {
	keys []apikeydomain.ProbedKey
	err  error
}

func (f fakeProbeReader) ListProbed(_ context.Context) ([]apikeydomain.ProbedKey, error) {
	return f.keys, f.err
}

func TestCapabilityListAggregates(t *testing.T) {
	probed := []apikeydomain.ProbedKey{
		// live OpenAI key — both ids are in the static catalog → 2 views attributed to it.
		{ID: "aki_oa", DisplayName: "My OpenAI", Provider: "openai", TestStatus: apikeydomain.TestStatusOK,
			TestResponse: `{"object":"list","data":[{"id":"gpt-5.5"},{"id":"gpt-4o"}]}`},
		// non-OK key contributes nothing.
		{ID: "aki_dead", DisplayName: "Dead", Provider: "openai", TestStatus: apikeydomain.TestStatusError,
			TestResponse: `{"data":[{"id":"gpt-5.5"}]}`},
		// unparseable body contributes nothing but must not blank the whole catalog.
		{ID: "aki_bad", DisplayName: "Bad", Provider: "deepseek", TestStatus: apikeydomain.TestStatusOK,
			TestResponse: `not json`},
	}
	svc := NewCapabilityService(fakeProbeReader{keys: probed}, zap.NewNop())
	views, err := svc.List(context.Background())
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if len(views) != 2 {
		t.Fatalf("got %d views, want 2 (only the live OpenAI key's catalog models)", len(views))
	}
	byModel := map[string]CapabilityView{}
	for _, v := range views {
		if v.APIKeyID != "aki_oa" || v.KeyName != "My OpenAI" || v.Provider != "openai" {
			t.Errorf("view not attributed to the live key: %+v", v)
		}
		if v.ContextWindow == 0 {
			t.Errorf("model %q missing context window", v.ModelID)
		}
		byModel[v.ModelID] = v
	}
	// gpt-5.5 is a reasoning model → carries native knobs; gpt-4o is not → no knobs.
	// gpt-5.5 是推理模型→带原生旋钮；gpt-4o 非推理→无旋钮。
	if len(byModel["gpt-5.5"].Knobs) == 0 {
		t.Error("gpt-5.5 should expose native reasoning knobs")
	}
	if len(byModel["gpt-4o"].Knobs) != 0 {
		t.Error("gpt-4o (non-reasoning) should expose no knobs")
	}
}

func TestCapabilityListEmptyOnNoKeys(t *testing.T) {
	svc := NewCapabilityService(fakeProbeReader{}, zap.NewNop())
	views, err := svc.List(context.Background())
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if len(views) != 0 {
		t.Errorf("got %d views, want 0", len(views))
	}
}

func TestCapabilityValidateOptions_OnlyPermitsPublishedNativeContract(t *testing.T) {
	svc := NewCapabilityService(fakeProbeReader{keys: []apikeydomain.ProbedKey{{
		ID: "aki_oa", Provider: "openai", TestStatus: apikeydomain.TestStatusOK,
		TestResponse: `{"object":"list","data":[{"id":"gpt-5.5"},{"id":"gpt-4o"}]}`,
	}}}, zap.NewNop())
	ctx := context.Background()

	if err := svc.ValidateOptions(ctx, modeldomain.ModelRef{APIKeyID: "aki_oa", ModelID: "gpt-5.5", Options: map[string]string{"reasoning_effort": "high"}}); err != nil {
		t.Fatalf("published enum value must pass: %v", err)
	}
	if err := svc.ValidateOptions(ctx, modeldomain.ModelRef{APIKeyID: "aki_oa", ModelID: "gpt-5.5", Options: map[string]string{"reasoning_effort": "turbo"}}); !errors.Is(err, modeldomain.ErrOptionValueInvalid) {
		t.Fatalf("unknown enum value = MODEL_OPTION_VALUE_INVALID, got %v", err)
	}
	if err := svc.ValidateOptions(ctx, modeldomain.ModelRef{APIKeyID: "aki_oa", ModelID: "gpt-4o", Options: map[string]string{"reasoning_effort": "high"}}); !errors.Is(err, modeldomain.ErrOptionUnsupported) {
		t.Fatalf("unpublished knob = MODEL_OPTION_UNSUPPORTED, got %v", err)
	}
	if err := svc.ValidateOptions(ctx, modeldomain.ModelRef{APIKeyID: "aki_oa", ModelID: "unlisted-but-runnable", Options: map[string]string{"reasoning_effort": "high"}}); !errors.Is(err, modeldomain.ErrOptionUnsupported) {
		t.Fatalf("unprobed model cannot gain an implicit passthrough, got %v", err)
	}
	if err := svc.ValidateOptions(ctx, modeldomain.ModelRef{APIKeyID: "aki_oa", ModelID: "unlisted-but-runnable"}); err != nil {
		t.Fatalf("unknown model with no native settings remains usable: %v", err)
	}
}
