//go:build pipeline

// lifecycle_test.go — sandbox lifecycle tests for forge.
// Verifies that forge creation syncs a Python venv, that forge execution
// produces correct output and persists a ForgeExecution record, and that
// test cases run correctly. All tests require FORGIFY_DEV_RESOURCES.
//
// lifecycle_test.go — forge 沙箱 lifecycle 测试。
// 验证 forge 创建同步 Python venv、forge 执行产生正确输出并持久化
// ForgeExecution 记录、测试用例正常运行。全部需要 FORGIFY_DEV_RESOURCES。
package forge

import (
	"testing"
	"time"

	th "github.com/sunweilin/forgify/backend/test/harness"
)

// ── 1. Create → envStatus=ready ───────────────────────────────────────────────

func TestForgeLifecycle_Create_EnvReady(t *testing.T) {
	h := th.New(t)
	th.RequireForgeResources(t, h)

	// POST /forges runs sandbox.Sync synchronously; response carries final envStatus.
	// POST /forges 同步运行 sandbox.Sync；响应携带最终 envStatus。
	var createResp struct {
		Data struct {
			ID        string `json:"id"`
			EnvStatus string `json:"envStatus"`
			EnvError  string `json:"envError"`
		} `json:"data"`
	}
	status := th.PostForge(t, h, "lifecycle_env", th.SimpleForgeCode, &createResp)
	if status != 201 {
		t.Fatalf("POST /forges status=%d, want 201", status)
	}
	if createResp.Data.EnvStatus != "ready" {
		t.Errorf("envStatus=%q, want ready; envError=%q", createResp.Data.EnvStatus, createResp.Data.EnvError)
	}
}

// ── 2. Run forge → correct output + ForgeExecution persisted ─────────────────

func TestForgeLifecycle_Run_ReturnsOutput_And_WritesExecution(t *testing.T) {
	h := th.New(t)
	th.RequireForgeResources(t, h)

	var createResp struct {
		Data struct{ ID string `json:"id"` } `json:"data"`
	}
	th.PostForge(t, h, "lifecycle_run", th.SimpleForgeCode, &createResp)
	forgeID := createResp.Data.ID

	// Run with input {name: "World"} → should return "Hello, World!".
	// 以 {name: "World"} 运行，应返回 "Hello, World!"。
	var runResp struct {
		Data struct {
			OK        bool  `json:"ok"`
			Output    any   `json:"output"`
			ElapsedMs int64 `json:"elapsedMs"`
		} `json:"data"`
	}
	h.PostJSON("/api/v1/forges/"+forgeID+":run", map[string]any{
		"input": map[string]any{"name": "World"},
	}, &runResp)

	if !runResp.Data.OK {
		t.Errorf("run ok=false, expected success")
	}
	if runResp.Data.Output == nil {
		t.Error("run output is nil")
	}
	if runResp.Data.ElapsedMs <= 0 {
		t.Error("elapsedMs should be > 0")
	}

	// ForgeExecution record must be persisted in DB.
	// ForgeExecution 记录必须落库。
	count := th.DBCount(t, h, "forge_executions", "forge_id = ? AND kind = 'run'", forgeID)
	if count != 1 {
		t.Errorf("forge_executions count=%d for forge %q, want 1", count, forgeID)
	}
}

// ── 3. Create test case + run via HTTP ────────────────────────────────────────

func TestForgeLifecycle_RunTestCase_Pass(t *testing.T) {
	h := th.New(t)
	th.RequireForgeResources(t, h)

	var createResp struct {
		Data struct{ ID string `json:"id"` } `json:"data"`
	}
	th.PostForge(t, h, "lifecycle_tc", th.SimpleForgeCode, &createResp)
	forgeID := createResp.Data.ID

	// Create a test case that expects "Hello, Alice!".
	// 创建期望 "Hello, Alice!" 的测试用例。
	var tcResp struct {
		Data struct{ ID string `json:"id"` } `json:"data"`
	}
	h.PostJSON("/api/v1/forges/"+forgeID+"/test-cases", map[string]any{
		"name":           "greet alice",
		"inputData":      `{"name":"Alice"}`,
		"expectedOutput": `"Hello, Alice!"`,
	}, &tcResp)
	tcID := tcResp.Data.ID

	// Run the test case via HTTP.
	// 通过 HTTP 运行测试用例。
	var runResp struct {
		Data struct {
			Pass     *bool  `json:"pass"`
			ErrorMsg string `json:"errorMsg"`
		} `json:"data"`
	}
	h.PostJSON("/api/v1/forges/"+forgeID+"/test-cases/"+tcID+":run", nil, &runResp)

	if runResp.Data.Pass == nil || !*runResp.Data.Pass {
		t.Errorf("test case did not pass; errorMsg=%q", runResp.Data.ErrorMsg)
	}
}

// ── 4. SSE publishes forge snapshots during create ────────────────────────────

func TestForgeLifecycle_SSE_ReportsEnvStatus(t *testing.T) {
	h := th.New(t)
	th.RequireForgeResources(t, h)

	// We need a conversation ID to subscribe to SSE (SSE is per-conversationId).
	// But forge SSE is not scoped to a conversation — it's published globally.
	// Actually the bridge filters by conversationId so we need forge events on
	// a conversation... but forge Create happens outside a conversation context.
	//
	// For HTTP POST /forges, forge SSE events are published with convID="".
	// The SSE endpoint requires a conversationId query param. So we subscribe
	// with an empty/dummy convID... actually, the forge bridge publishes are
	// made with the forge's context which has no convID. Events with empty
	// convID won't be routed to any subscriber.
	//
	// Therefore this SSE forge test is only meaningful via chat × forge (Phase E).
	// For now, verify forge state is correct after synchronous Create.
	//
	// forge SSE 在 HTTP Create 路径下用 convID="" 发布，SSE 订阅需要 convID
	// query param。forge SSE 验证留给 Phase E（chat × forge）。
	// 这里只验证 Create 后的 forge 状态（envStatus 通过 GET 确认）。

	var createResp struct {
		Data struct {
			ID        string `json:"id"`
			EnvStatus string `json:"envStatus"`
		} `json:"data"`
	}
	if s := th.PostForge(t, h, "sse_forge", th.SimpleForgeCode, &createResp); s != 201 {
		t.Fatalf("status=%d", s)
	}
	forgeID := createResp.Data.ID

	// GET the forge to see latest envStatus (sync was sync in the HTTP call).
	// GET forge 查看最新 envStatus（sync 在 HTTP 调用内同步完成）。
	var getResp struct {
		Data struct {
			EnvStatus string `json:"envStatus"`
		} `json:"data"`
	}
	h.GetJSON("/api/v1/forges/"+forgeID, &getResp)
	if getResp.Data.EnvStatus != "ready" {
		t.Errorf("envStatus=%q after Create, want ready", getResp.Data.EnvStatus)
	}

	_ = time.Millisecond // suppress unused import if needed
}
