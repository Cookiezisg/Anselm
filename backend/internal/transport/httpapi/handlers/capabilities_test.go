package handlers

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"go.uber.org/zap/zaptest"
	gormlogger "gorm.io/gorm/logger"

	apikeyapp "github.com/sunweilin/forgify/backend/internal/app/apikey"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	cryptoinfra "github.com/sunweilin/forgify/backend/internal/infra/crypto"
	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"
	apikeystore "github.com/sunweilin/forgify/backend/internal/infra/store/apikey"
	modelcapoverridestore "github.com/sunweilin/forgify/backend/internal/infra/store/modelcapoverride"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
	middlewarehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/middleware"
)

// capsTestEnv wires a test server with real in-memory SQLite for capabilities tests.
//
// capsTestEnv 装配使用真实内存 SQLite 的测试服务。
type capsTestEnv struct {
	srv       *httptest.Server
	apikeySvc *apikeyapp.Service
	capSvc    *apikeyapp.CapabilityService
	store     *apikeystore.Store
}

func newCapsTestEnv(t *testing.T) *capsTestEnv {
	t.Helper()
	gdb, err := dbinfra.Open(dbinfra.Config{LogLevel: gormlogger.Silent})
	if err != nil {
		t.Fatalf("dbinfra.Open: %v", err)
	}
	t.Cleanup(func() { _ = dbinfra.Close(gdb) })
	if err := dbinfra.Migrate(gdb, &apikeydomain.APIKey{}, &modeldomain.ModelCapOverride{}); err != nil {
		t.Fatalf("dbinfra.Migrate: %v", err)
	}
	log := zaptest.NewLogger(t)
	enc, err := cryptoinfra.NewAESGCMEncryptor(cryptoinfra.DeriveKey("caps-handler-test"))
	if err != nil {
		t.Fatalf("NewAESGCMEncryptor: %v", err)
	}
	st := apikeystore.New(gdb)
	apikeySvc := apikeyapp.NewService(st, enc, &fakeTester{}, log)
	capSvc := apikeyapp.NewCapabilityService(modelcapoverridestore.New(gdb))
	h := NewCapabilitiesHandler(capSvc, apikeySvc, log)
	mux := http.NewServeMux()
	h.Register(mux)
	return &capsTestEnv{
		srv:       httptest.NewServer(middlewarehttpapi.InjectUserID(mux)),
		apikeySvc: apikeySvc,
		capSvc:    capSvc,
		store:     st,
	}
}

// seedVerifiedKey creates a key with test_status=ok and specific modelsFound.
//
// seedVerifiedKey 种一把 test_status=ok、带指定 modelsFound 的 key。
func (e *capsTestEnv) seedVerifiedKey(t *testing.T, provider string, modelsFound []string) string {
	t.Helper()
	ctx := reqctxpkg.SetUserID(context.Background(), "test-user")
	k, err := e.apikeySvc.Create(ctx, apikeyapp.CreateInput{
		Provider: provider, Key: "sk-test-" + provider, DisplayName: provider + "-key",
	})
	if err != nil {
		t.Fatalf("seed key %s: %v", provider, err)
	}
	if err := e.store.UpdateTestResult(ctx, k.ID, apikeydomain.TestStatusOK, "", modelsFound); err != nil {
		t.Fatalf("UpdateTestResult %s: %v", provider, err)
	}
	return k.ID
}

func TestCapabilitiesHandler_List_ReturnsModelsForVerifiedKey(t *testing.T) {
	env := newCapsTestEnv(t)
	defer env.srv.Close()

	// deepseek-v4 prefix → ShapeEffort, contextWindow 1_000_000 per static catalog.
	env.seedVerifiedKey(t, "deepseek", []string{"deepseek-v4-0324"})

	status, envBody := do(t, env.srv, "GET", "/api/v1/model-capabilities", nil)
	if status != http.StatusOK {
		t.Fatalf("status = %d, want 200: %+v", status, envBody)
	}
	items, ok := envBody["data"].([]any)
	if !ok {
		t.Fatalf("data is not an array: %+v", envBody["data"])
	}
	if len(items) != 1 {
		t.Fatalf("len(items) = %d, want 1", len(items))
	}
	item := items[0].(map[string]any)
	if got := item["provider"].(string); got != "deepseek" {
		t.Errorf("provider = %q, want deepseek", got)
	}
	if got := item["modelId"].(string); got != "deepseek-v4-0324" {
		t.Errorf("modelId = %q, want deepseek-v4-0324", got)
	}
	if got := item["thinkingShape"].(string); got != "effort" {
		t.Errorf("thinkingShape = %q, want effort", got)
	}
	if got := int(item["contextWindow"].(float64)); got != 1_000_000 {
		t.Errorf("contextWindow = %d, want 1000000", got)
	}
}

func TestCapabilitiesHandler_List_ExcludesPendingKeys(t *testing.T) {
	env := newCapsTestEnv(t)
	defer env.srv.Close()

	// Create a key but do NOT mark it ok (stays pending).
	ctx := reqctxpkg.SetUserID(context.Background(), "test-user")
	_, err := env.apikeySvc.Create(ctx, apikeyapp.CreateInput{
		Provider: "openai", Key: "sk-pending", DisplayName: "pending-key",
	})
	if err != nil {
		t.Fatalf("create pending key: %v", err)
	}

	status, envBody := do(t, env.srv, "GET", "/api/v1/model-capabilities", nil)
	if status != http.StatusOK {
		t.Fatalf("status = %d, want 200", status)
	}
	items := envBody["data"].([]any)
	if len(items) != 0 {
		t.Errorf("want 0 items for pending key, got %d", len(items))
	}
}

func TestCapabilitiesHandler_SetOverride_ThenListReflectsIt(t *testing.T) {
	env := newCapsTestEnv(t)
	defer env.srv.Close()

	env.seedVerifiedKey(t, "deepseek", []string{"deepseek-v4-0324"})

	// Override deepseek-v4-0324 thinkingShape to "none".
	status, envBody := do(t, env.srv, "PUT", "/api/v1/model-capabilities/deepseek/deepseek-v4-0324", map[string]any{
		"thinkingShape": "none",
	})
	if status != http.StatusOK {
		t.Fatalf("PUT status = %d, want 200: %+v", status, envBody)
	}

	// GET must return "none" — override beats static catalog "effort".
	status, envBody = do(t, env.srv, "GET", "/api/v1/model-capabilities", nil)
	if status != http.StatusOK {
		t.Fatalf("GET status = %d, want 200", status)
	}
	items := envBody["data"].([]any)
	if len(items) != 1 {
		t.Fatalf("len(items) = %d, want 1", len(items))
	}
	item := items[0].(map[string]any)
	if got := item["thinkingShape"].(string); got != "none" {
		t.Errorf("thinkingShape = %q, want none (override)", got)
	}
}

func TestCapabilitiesHandler_DeleteOverride_RestoresToStatic(t *testing.T) {
	env := newCapsTestEnv(t)
	defer env.srv.Close()

	env.seedVerifiedKey(t, "deepseek", []string{"deepseek-v4-0324"})

	// Set then clear override.
	do(t, env.srv, "PUT", "/api/v1/model-capabilities/deepseek/deepseek-v4-0324", map[string]any{
		"thinkingShape": "none",
	})
	status, _ := do(t, env.srv, "DELETE", "/api/v1/model-capabilities/deepseek/deepseek-v4-0324", nil)
	if status != http.StatusNoContent {
		t.Fatalf("DELETE status = %d, want 204", status)
	}

	// GET must be back to static "effort".
	status, envBody := do(t, env.srv, "GET", "/api/v1/model-capabilities", nil)
	if status != http.StatusOK {
		t.Fatalf("GET status = %d, want 200", status)
	}
	items := envBody["data"].([]any)
	if len(items) != 1 {
		t.Fatalf("len(items) = %d, want 1", len(items))
	}
	item := items[0].(map[string]any)
	if got := item["thinkingShape"].(string); got != "effort" {
		t.Errorf("thinkingShape = %q, want effort (static restored)", got)
	}
}

func TestCapabilitiesHandler_SetOverride_BadThinkingShape_Returns400(t *testing.T) {
	env := newCapsTestEnv(t)
	defer env.srv.Close()

	status, envBody := do(t, env.srv, "PUT", "/api/v1/model-capabilities/deepseek/deepseek-v4", map[string]any{
		"thinkingShape": "turbo",
	})
	if status != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", status)
	}
	if code := errorCode(t, envBody); code != "INVALID_THINKING_SHAPE" {
		t.Errorf("code = %q, want INVALID_THINKING_SHAPE", code)
	}
}
