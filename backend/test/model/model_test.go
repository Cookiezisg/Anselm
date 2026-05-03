//go:build pipeline

// model_test.go — end-to-end tests for /api/v1/model-configs/*.
// Covers the 2 endpoints (GET list + PUT upsert) including idempotency and
// validation. All tests run offline (no external network).
//
// model_test.go — /api/v1/model-configs/* 2 个端点的端到端测试。
// 覆盖幂等性和校验，全部离线运行。
package model

import (
	"net/http"
	"testing"

	th "github.com/sunweilin/forgify/backend/test/harness"
)

// putModelConfig is a shorthand: PUT /api/v1/model-configs/{scenario}.
// Returns (status, decoded data struct).
//
// putModelConfig 简写：PUT /api/v1/model-configs/{scenario}。
func putModelConfig(t *testing.T, h *th.Harness, scenario, provider, modelID string, out any) int {
	t.Helper()
	return th.DoRequest(t, h, "PUT", "/api/v1/model-configs/"+scenario, map[string]any{
		"provider": provider,
		"modelId":  modelID,
	}, out)
}

// ── 1. Upsert + List round-trip ──────────────────────────────────────────────

func TestModel_UpsertAndList_Roundtrip(t *testing.T) {
	h := th.New(t)

	var resp struct {
		Data struct {
			ID       string `json:"id"`
			Scenario string `json:"scenario"`
			Provider string `json:"provider"`
			ModelID  string `json:"modelId"`
		} `json:"data"`
	}
	if s := putModelConfig(t, h, "chat", "deepseek", "deepseek-chat", &resp); s != http.StatusOK {
		t.Fatalf("PUT /model-configs/chat status=%d, want 200", s)
	}
	if resp.Data.ID == "" {
		t.Fatal("empty id in upsert response")
	}
	if resp.Data.Scenario != "chat" {
		t.Errorf("scenario=%q, want chat", resp.Data.Scenario)
	}
	if resp.Data.Provider != "deepseek" {
		t.Errorf("provider=%q, want deepseek", resp.Data.Provider)
	}
	if resp.Data.ModelID != "deepseek-chat" {
		t.Errorf("modelId=%q, want deepseek-chat", resp.Data.ModelID)
	}
	configID := resp.Data.ID

	var listResp struct {
		Data []struct {
			ID       string `json:"id"`
			Scenario string `json:"scenario"`
		} `json:"data"`
	}
	h.GetJSON("/api/v1/model-configs", &listResp)
	if len(listResp.Data) != 1 {
		t.Fatalf("list: got %d items, want 1", len(listResp.Data))
	}
	if listResp.Data[0].ID != configID {
		t.Errorf("list[0].id=%q, want %q", listResp.Data[0].ID, configID)
	}
}

// ── 2. Upsert is idempotent — ID stable across calls ────────────────────────

func TestModel_Upsert_Idempotent_IDUnchanged(t *testing.T) {
	h := th.New(t)

	first := struct {
		Data struct{ ID string `json:"id"` } `json:"data"`
	}{}
	if s := putModelConfig(t, h, "chat", "deepseek", "deepseek-chat", &first); s != http.StatusOK {
		t.Fatalf("first PUT status=%d", s)
	}

	second := struct {
		Data struct{ ID string `json:"id"` } `json:"data"`
	}{}
	// Second PUT changes the model but same scenario → same row, same ID.
	// 第二次 PUT 换 modelId 但 scenario 不变 → 同行，ID 不变。
	if s := putModelConfig(t, h, "chat", "deepseek", "deepseek-reasoner", &second); s != http.StatusOK {
		t.Fatalf("second PUT status=%d", s)
	}

	// N6: PUT upsert always returns 200; ID must be stable.
	// N6：PUT upsert 总返 200；ID 跨调用必须稳定。
	if first.Data.ID != second.Data.ID {
		t.Errorf("ID changed: %q → %q", first.Data.ID, second.Data.ID)
	}
}

// ── 3. Invalid scenario → 400 INVALID_SCENARIO ───────────────────────────────

func TestModel_Upsert_InvalidScenario_Returns400(t *testing.T) {
	h := th.New(t)
	var errResp th.ErrEnvelope
	if s := putModelConfig(t, h, "not-a-real-scenario", "deepseek", "deepseek-chat", &errResp); s != http.StatusBadRequest {
		t.Errorf("status=%d, want 400", s)
	}
	if errResp.Error.Code != "INVALID_SCENARIO" {
		t.Errorf("error.code=%q, want INVALID_SCENARIO", errResp.Error.Code)
	}
}

// ── 4. Missing provider → 400 PROVIDER_REQUIRED ──────────────────────────────

func TestModel_Upsert_MissingProvider_Returns400(t *testing.T) {
	h := th.New(t)
	var errResp th.ErrEnvelope
	if s := putModelConfig(t, h, "chat", "", "deepseek-chat", &errResp); s != http.StatusBadRequest {
		t.Errorf("status=%d, want 400", s)
	}
	if errResp.Error.Code != "PROVIDER_REQUIRED" {
		t.Errorf("error.code=%q, want PROVIDER_REQUIRED", errResp.Error.Code)
	}
}
