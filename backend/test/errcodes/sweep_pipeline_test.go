//go:build pipeline

// Package cross sweeps sentinel error codes to verify HTTP status + envelope mappings.
//
// Package cross 扫 sentinel 错误码验证 HTTP 状态 + envelope 映射。
package errcodes

import (
	"net/http"
	"testing"

	th "github.com/sunweilin/forgify/backend/test/harness"
)

// covers: errcode:INVALID_REQUEST
// covers: errcode:API_KEY_NOT_FOUND
// covers: errcode:INVALID_PROVIDER
// covers: errcode:BASE_URL_REQUIRED
// covers: errcode:KEY_REQUIRED
// covers: errcode:API_FORMAT_REQUIRED
// covers: errcode:INVALID_SCENARIO
// covers: errcode:API_KEY_ID_REQUIRED
// covers: errcode:MODEL_ID_REQUIRED
// covers: errcode:CONVERSATION_NOT_FOUND
// covers: errcode:STREAM_NOT_FOUND
func TestErrCodes_Sweep(t *testing.T) {
	h := th.New(t)

	var convResp struct {
		Data struct {
			ID string `json:"id"`
		} `json:"data"`
	}
	h.PostJSON("/api/v1/conversations", map[string]any{"title": "errcode-conv"}, &convResp)
	convID := convResp.Data.ID

	cases := []struct {
		name   string
		method string
		path   string
		body   any
		want   int
		code   string
	}{
		{
			"INVALID_REQUEST",
			"POST", "/api/v1/conversations",
			map[string]any{"unknownField": "x"},
			http.StatusBadRequest, "INVALID_REQUEST",
		},

		{
			"NOT_FOUND",
			"GET", "/api/v1/this_route_does_not_exist",
			nil, http.StatusNotFound, "NOT_FOUND",
		},

		{
			"API_KEY_NOT_FOUND",
			"PATCH", "/api/v1/api-keys/aki_doesnotexist000000",
			map[string]any{},
			http.StatusNotFound, "API_KEY_NOT_FOUND",
		},

		{
			"INVALID_PROVIDER",
			"POST", "/api/v1/api-keys",
			map[string]any{"provider": "alien-provider", "key": "k"},
			http.StatusBadRequest, "INVALID_PROVIDER",
		},

		{
			"BASE_URL_REQUIRED",
			"POST", "/api/v1/api-keys",
			map[string]any{"provider": "ollama", "key": "k"},
			http.StatusBadRequest, "BASE_URL_REQUIRED",
		},

		{
			"KEY_REQUIRED",
			"POST", "/api/v1/api-keys",
			map[string]any{"provider": "deepseek"},
			http.StatusBadRequest, "KEY_REQUIRED",
		},

		{
			"API_FORMAT_REQUIRED",
			"POST", "/api/v1/api-keys",
			map[string]any{"provider": "custom", "key": "k", "baseUrl": "http://localhost"},
			http.StatusBadRequest, "API_FORMAT_REQUIRED",
		},

		{
			"INVALID_SCENARIO",
			"PUT", "/api/v1/model-configs/not-a-real-scenario",
			map[string]any{"apiKeyId": "aki_irrelevant000000", "modelId": "x"},
			http.StatusBadRequest, "INVALID_SCENARIO",
		},

		{
			"API_KEY_ID_REQUIRED",
			"PUT", "/api/v1/model-configs/dialogue",
			map[string]any{"apiKeyId": "", "modelId": "deepseek-chat"},
			http.StatusBadRequest, "API_KEY_ID_REQUIRED",
		},

		{
			"MODEL_ID_REQUIRED",
			"PUT", "/api/v1/model-configs/dialogue",
			map[string]any{"apiKeyId": "aki_irrelevant000000", "modelId": ""},
			http.StatusBadRequest, "MODEL_ID_REQUIRED",
		},

		{
			"CONVERSATION_NOT_FOUND",
			"PATCH", "/api/v1/conversations/cv_doesnotexist000000",
			map[string]any{"title": "x"},
			http.StatusNotFound, "CONVERSATION_NOT_FOUND",
		},

		{
			"STREAM_NOT_FOUND",
			"DELETE", "/api/v1/conversations/" + convID + "/stream",
			nil, http.StatusNotFound, "STREAM_NOT_FOUND",
		},
	}

	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			var errResp th.ErrEnvelope
			status := th.DoRequest(t, h, tc.method, tc.path, tc.body, &errResp)
			if status != tc.want {
				t.Errorf("status=%d, want %d; body=%+v", status, tc.want, errResp)
			}
			if errResp.Error.Code != tc.code {
				t.Errorf("error.code=%q, want %q", errResp.Error.Code, tc.code)
			}
		})
	}
}

// covers: errcode:FUNCTION_NAME_DUPLICATE
// covers: errcode:FUNCTION_NOT_FOUND
// covers: errcode:FUNCTION_PENDING_NOT_FOUND
func TestErrCodes_FunctionDomain(t *testing.T) {
	h := th.New(t)

	h.NewFunction(t, "errcodes_fn_a", th.SimpleFunctionCode)

	t.Run("FUNCTION_NAME_DUPLICATE", func(t *testing.T) {
		var errResp th.ErrEnvelope
		status := th.PostFunction(t, h, "errcodes_fn_a", th.SimpleFunctionCode, &errResp)
		if status != http.StatusConflict {
			t.Errorf("status=%d, want 409", status)
		}
		if errResp.Error.Code != "FUNCTION_NAME_DUPLICATE" {
			t.Errorf("error.code=%q, want FUNCTION_NAME_DUPLICATE", errResp.Error.Code)
		}
	})

	t.Run("FUNCTION_NOT_FOUND_on_get", func(t *testing.T) {
		var errResp th.ErrEnvelope
		status := th.DoRequest(t, h, "GET", "/api/v1/functions/fn_doesnotexist0000", nil, &errResp)
		if status != http.StatusNotFound {
			t.Errorf("status=%d, want 404", status)
		}
		if errResp.Error.Code != "FUNCTION_NOT_FOUND" {
			t.Errorf("error.code=%q, want FUNCTION_NOT_FOUND", errResp.Error.Code)
		}
	})

	t.Run("FUNCTION_PENDING_NOT_FOUND_on_accept", func(t *testing.T) {
		var createResp struct {
			Data struct {
				Function struct {
					ID string `json:"id"`
				} `json:"function"`
			} `json:"data"`
		}
		th.PostFunction(t, h, "errcodes_fn_b", th.SimpleFunctionCode, &createResp)
		fnID := createResp.Data.Function.ID

		var errResp th.ErrEnvelope
		status := th.DoRequest(t, h, "POST",
			"/api/v1/functions/"+fnID+"/pending:accept", nil, &errResp)
		if status != http.StatusNotFound {
			t.Errorf("status=%d, want 404", status)
		}
		if errResp.Error.Code != "FUNCTION_PENDING_NOT_FOUND" {
			t.Errorf("error.code=%q, want FUNCTION_PENDING_NOT_FOUND", errResp.Error.Code)
		}
	})
}

// covers: errcode:API_KEY_IN_USE
//
// SeedDeepSeek already binds the api_key to 3 model_configs, so DELETE via
// the service is refused (422) — exercises the RefScanner RESTRICT path
// wired in main.go and mirrored in harness.New (Task 0b §0).
//
// SeedDeepSeek 已把 api_key 绑到 3 个 model_config,DELETE 触发 RefScanner
// RESTRICT 路径 → 422。
func TestErrcodes_APIKeyInUse(t *testing.T) {
	h := th.New(t)
	apiKeyID := h.SeedDeepSeek(t, "test-key")

	var errResp th.ErrEnvelope
	status := th.DoRequest(t, h, "DELETE", "/api/v1/api-keys/"+apiKeyID, nil, &errResp)
	if status != http.StatusUnprocessableEntity {
		t.Fatalf("status=%d, want 422; body=%+v", status, errResp)
	}
	if errResp.Error.Code != "API_KEY_IN_USE" {
		t.Fatalf("error.code=%q, want API_KEY_IN_USE", errResp.Error.Code)
	}
}

// covers: errcode:INVALID_NODE_MODEL_OVERRIDE
//
// Exercises the workflow F1 validator via POST /api/v1/workflows with a
// set_node_model_override op missing apiKeyId. The unit-level coverage
// lives in app/workflow/apply_test.go (Task 9); this sweep case asserts
// the HTTP envelope + status code wiring.
//
// 通过 POST /api/v1/workflows 触发 workflow F1 校验;set_node_model_override
// 缺 apiKeyId → 400 INVALID_NODE_MODEL_OVERRIDE。
func TestErrcodes_InvalidNodeModelOverride(t *testing.T) {
	h := th.New(t)

	var errResp th.ErrEnvelope
	status := th.DoRequest(t, h, "POST", "/api/v1/workflows", map[string]any{
		"ops": []map[string]any{
			{"op": "set_meta", "name": "bad-override-wf", "description": "errcode test"},
			{"op": "add_node", "node": map[string]any{
				"id":     "trig",
				"type":   "trigger",
				"name":   "manual",
				"config": map[string]any{"triggerType": "manual"},
			}},
			{"op": "add_node", "node": map[string]any{
				"id":     "agent_node",
				"type":   "agent",
				"name":   "agent",
				"config": map[string]any{"scenario": "agent"},
			}},
			{
				"op":            "set_node_model_override",
				"nodeId":        "agent_node",
				"modelOverride": map[string]any{"modelId": "deepseek-chat"},
			},
		},
	}, &errResp)
	if status != http.StatusBadRequest {
		t.Fatalf("status=%d, want 400; body=%+v", status, errResp)
	}
	if errResp.Error.Code != "INVALID_NODE_MODEL_OVERRIDE" {
		t.Fatalf("error.code=%q, want INVALID_NODE_MODEL_OVERRIDE", errResp.Error.Code)
	}
}
