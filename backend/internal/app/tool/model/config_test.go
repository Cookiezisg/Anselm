package model

import (
	"encoding/json"
	"testing"

	modelapp "github.com/sunweilin/anselm/backend/internal/app/model"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

// TestGetModelConfig_Contract — F68: lock the read-only config tool's contract (Execute itself is
// verified end-to-end on a live backend: the agent calls it + gets the real masked config, no FS grep).
func TestGetModelConfig_Contract(t *testing.T) {
	tools := ModelConfigTools(nil, nil, nil)
	if len(tools) != 1 {
		t.Fatalf("ModelConfigTools should return 1 tool, got %d", len(tools))
	}
	tool := tools[0]
	if tool.Name() != "get_model_config" {
		t.Fatalf("name = %q, want get_model_config", tool.Name())
	}
	var schema map[string]any
	if err := json.Unmarshal(tool.Parameters(), &schema); err != nil {
		t.Fatalf("Parameters not valid JSON: %v", err)
	}
	if _, hasRequired := schema["required"]; hasRequired {
		t.Errorf("get_model_config is a no-arg read tool; should declare no required params")
	}
	if err := tool.ValidateInput(json.RawMessage(`{}`)); err != nil {
		t.Errorf("ValidateInput({}) = %v, want nil", err)
	}
}

func TestCapabilityPayloadIncludesOptionsAndModalLimits(t *testing.T) {
	payload := capabilityPayload(modelapp.CapabilityView{
		APIKeyID: "aki_1", Provider: "qwen", ModelID: "qwen3.7-plus", DisplayName: "Qwen 3.7 Plus",
		ContextWindow: 1_000_000, MaxOutput: 64_000, TextInputLimit: 1_000_000, MultimodalInputLimit: 1_000_000,
		Vision: true, Video: true, NativeDocs: false, MaxMediaParts: 8, MaxMediaBytes: 3 << 20,
		Knobs: []llminfra.Knob{{
			Key: "enable_thinking", Label: "Thinking", Type: "bool", Default: "false",
		}},
	})
	if payload["apiKeyId"] != "aki_1" || payload["contextWindow"] != 1_000_000 || payload["maxOutput"] != 64_000 {
		t.Fatalf("basic capability payload missing: %#v", payload)
	}
	if payload["vision"] != true || payload["video"] != true || payload["nativeDocs"] != false ||
		payload["multimodalInputLimit"] != 1_000_000 {
		t.Fatalf("modal capability payload missing: %#v", payload)
	}
	knobs, ok := payload["nativeOptions"].([]llminfra.Knob)
	if !ok || len(knobs) != 1 || knobs[0].Key != "enable_thinking" {
		t.Fatalf("native options missing: %#v", payload["nativeOptions"])
	}
}
