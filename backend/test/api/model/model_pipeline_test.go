//go:build pipeline

// Package model runs end-to-end tests for /api/v1/model-configs/*.
//
// Package model 跑 /api/v1/model-configs/* 端到端测试。
package model

import (
	"net/http"
	"testing"

	th "github.com/sunweilin/forgify/backend/test/harness"
)

// putModelConfig is shorthand for PUT /api/v1/model-configs/{scenario}.
//
// putModelConfig 是 PUT /api/v1/model-configs/{scenario} 的简写。
func putModelConfig(t *testing.T, h *th.Harness, scenario, apiKeyID, modelID string, out any) int {
	t.Helper()
	return th.DoRequest(t, h, "PUT", "/api/v1/model-configs/"+scenario, map[string]any{
		"apiKeyId": apiKeyID,
		"modelId":  modelID,
	}, out)
}

// covers: PUT /api/v1/model-configs/{scenario}
// covers: GET /api/v1/model-configs
func TestModel_UpsertAndList_Roundtrip(t *testing.T) {
	h := th.New(t)
	// SeedDeepSeek primes 3 model_configs already; this test exercises a
	// fresh PUT path so we seed only an api_key to satisfy Upsert's F1
	// (api_key must exist) without pre-populating model_configs.
	// SeedDeepSeek 已建 3 配置；此测试需独立 PUT 路径,改种 api_key 即可。
	apiKeyID := h.SeedDeepSeek(t, "test-key")

	var resp struct {
		Data struct {
			ID       string `json:"id"`
			Scenario string `json:"scenario"`
			APIKeyID string `json:"apiKeyId"`
			ModelID  string `json:"modelId"`
		} `json:"data"`
	}
	if s := putModelConfig(t, h, "dialogue", apiKeyID, "deepseek-chat", &resp); s != http.StatusOK {
		t.Fatalf("PUT /model-configs/dialogue status=%d, want 200", s)
	}
	if resp.Data.ID == "" {
		t.Fatal("empty id in upsert response")
	}
	if resp.Data.Scenario != "dialogue" {
		t.Errorf("scenario=%q, want dialogue", resp.Data.Scenario)
	}
	if resp.Data.APIKeyID != apiKeyID {
		t.Errorf("apiKeyId=%q, want %q", resp.Data.APIKeyID, apiKeyID)
	}
	if resp.Data.ModelID != "deepseek-chat" {
		t.Errorf("modelId=%q, want deepseek-chat", resp.Data.ModelID)
	}

	var listResp struct {
		Data []struct {
			ID       string `json:"id"`
			Scenario string `json:"scenario"`
		} `json:"data"`
	}
	h.GetJSON("/api/v1/model-configs", &listResp)
	// SeedDeepSeek seeded 3 (dialogue/utility/agent); our PUT re-upserts
	// dialogue → 3 total rows expected.
	// SeedDeepSeek 已种 3 条，此 PUT 是覆盖 → 列表仍 3 条。
	if len(listResp.Data) != 3 {
		t.Fatalf("list: got %d items, want 3", len(listResp.Data))
	}
}

// covers: PUT /api/v1/model-configs/{scenario}
func TestModel_Upsert_Idempotent_IDUnchanged(t *testing.T) {
	h := th.New(t)
	apiKeyID := h.SeedDeepSeek(t, "test-key")

	first := struct {
		Data struct {
			ID string `json:"id"`
		} `json:"data"`
	}{}
	if s := putModelConfig(t, h, "dialogue", apiKeyID, "deepseek-chat", &first); s != http.StatusOK {
		t.Fatalf("first PUT status=%d", s)
	}

	second := struct {
		Data struct {
			ID string `json:"id"`
		} `json:"data"`
	}{}
	if s := putModelConfig(t, h, "dialogue", apiKeyID, "deepseek-reasoner", &second); s != http.StatusOK {
		t.Fatalf("second PUT status=%d", s)
	}

	if first.Data.ID != second.Data.ID {
		t.Errorf("ID changed: %q → %q", first.Data.ID, second.Data.ID)
	}
}

// covers: PUT /api/v1/model-configs/{scenario} (invalid_scenario_400)
// covers: errcode:INVALID_SCENARIO
func TestModel_Upsert_InvalidScenario_Returns400(t *testing.T) {
	h := th.New(t)
	apiKeyID := h.SeedDeepSeek(t, "test-key")
	var errResp th.ErrEnvelope
	if s := putModelConfig(t, h, "not-a-real-scenario", apiKeyID, "deepseek-chat", &errResp); s != http.StatusBadRequest {
		t.Errorf("status=%d, want 400", s)
	}
	if errResp.Error.Code != "INVALID_SCENARIO" {
		t.Errorf("error.code=%q, want INVALID_SCENARIO", errResp.Error.Code)
	}
}

// covers: PUT /api/v1/model-configs/{scenario} (missing_api_key_id_400)
// covers: errcode:API_KEY_ID_REQUIRED
func TestModel_Upsert_MissingAPIKeyID_Returns400(t *testing.T) {
	h := th.New(t)
	var errResp th.ErrEnvelope
	if s := putModelConfig(t, h, "dialogue", "", "deepseek-chat", &errResp); s != http.StatusBadRequest {
		t.Errorf("status=%d, want 400", s)
	}
	if errResp.Error.Code != "API_KEY_ID_REQUIRED" {
		t.Errorf("error.code=%q, want API_KEY_ID_REQUIRED", errResp.Error.Code)
	}
}

// covers: PUT /api/v1/model-configs/{scenario} (unknown_api_key_404)
// covers: errcode:API_KEY_NOT_FOUND
func TestModel_Upsert_UnknownAPIKeyID_Returns404(t *testing.T) {
	h := th.New(t)
	var errResp th.ErrEnvelope
	if s := putModelConfig(t, h, "dialogue", "aki_doesnotexist000000", "deepseek-chat", &errResp); s != http.StatusNotFound {
		t.Errorf("status=%d, want 404", s)
	}
	if errResp.Error.Code != "API_KEY_NOT_FOUND" {
		t.Errorf("error.code=%q, want API_KEY_NOT_FOUND", errResp.Error.Code)
	}
}
