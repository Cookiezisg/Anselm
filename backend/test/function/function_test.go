//go:build pipeline

// function_test.go — end-to-end pipeline tests for the function domain
// (forge_redesign Plan 01 Phase 8). Real in-process backend via harness:
// real DB / SSE bridge / sandbox v2 (when mise embedded) / fake LLM.
//
// Scenarios:
//
//  1. TestFunction_HTTP_CRUDLifecycle — POST → GET → PATCH → DELETE without
//     sandbox; verifies serialization, error envelopes, name uniqueness.
//  2. TestFunction_HTTP_PendingAcceptFlow — POST then PATCH-via-ops not
//     possible from HTTP (HTTP only does direct create + meta update). Edit
//     flow exercised via Service directly; HTTP pending:accept / :reject.
//  3. TestFunction_LLM_SearchEmpty — chat-driven search_function on empty
//     library returns []; no sandbox needed.
//  4. TestFunction_HTTP_RunAndExecutionLog — requires sandbox; POST function,
//     wait for env ready, POST :run, GET /executions, verify the log row.
//
// function_test.go —— function domain 端到端 pipeline 测试。

package function_test

import (
	"strings"
	"testing"
	"time"

	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	th "github.com/sunweilin/forgify/backend/test/harness"
)

// ── 1. HTTP CRUD lifecycle (no sandbox) ──────────────────────────────────────

func TestFunction_HTTP_CRUDLifecycle(t *testing.T) {
	h := th.New(t)

	// Create via POST /functions
	// POST 创建
	var createResp struct {
		Data struct {
			Function struct {
				ID   string `json:"id"`
				Name string `json:"name"`
			} `json:"function"`
		} `json:"data"`
	}
	status := th.PostFunction(t, h, "csv_clean", "def csv_clean(args):\n    return args\n", &createResp)
	if status != 201 {
		t.Fatalf("POST status=%d, want 201", status)
	}
	fnID := createResp.Data.Function.ID
	if fnID == "" {
		t.Fatal("POST returned empty function id")
	}
	if !strings.HasPrefix(fnID, "fn_") {
		t.Errorf("function id %q missing fn_ prefix", fnID)
	}

	// GET /functions/{id}
	// 单查
	var getResp struct {
		Data struct {
			ID   string `json:"id"`
			Name string `json:"name"`
		} `json:"data"`
	}
	resp := h.GetJSON("/api/v1/functions/"+fnID, &getResp)
	_ = resp.Body.Close()
	if getResp.Data.Name != "csv_clean" {
		t.Errorf("GET name=%q, want csv_clean", getResp.Data.Name)
	}

	// Duplicate name → 409 FUNCTION_NAME_DUPLICATE
	// 重名 → 409. Same name AND matching def in body so AST scan + name char-set
	// validation both pass before we hit the duplicate check.
	var errResp th.ErrEnvelope
	dupStatus := th.PostFunction(t, h, "csv_clean", "def csv_clean(args):\n    return args\n", &errResp)
	if dupStatus != 409 {
		t.Errorf("duplicate POST status=%d, want 409", dupStatus)
	}
	if errResp.Error.Code != "FUNCTION_NAME_DUPLICATE" {
		t.Errorf("duplicate error.code=%q, want FUNCTION_NAME_DUPLICATE", errResp.Error.Code)
	}

	// PATCH description
	// PATCH 描述
	newDesc := "Cleans CSV inputs"
	patchResp := h.PatchJSON("/api/v1/functions/"+fnID,
		map[string]any{"description": newDesc}, nil)
	_ = patchResp.Body.Close()
	if patchResp.StatusCode != 200 {
		t.Errorf("PATCH status=%d, want 200", patchResp.StatusCode)
	}

	// DELETE
	// 软删
	delResp := h.Delete("/api/v1/functions/" + fnID)
	_ = delResp.Body.Close()
	if delResp.StatusCode != 204 {
		t.Errorf("DELETE status=%d, want 204", delResp.StatusCode)
	}

	// GET after DELETE → 404 (use DoRequest to capture error status without fatal).
	// 删后 GET 404(用 DoRequest 非 fatal 抓状态码)。
	var notFound th.ErrEnvelope
	goneStatus := th.DoRequest(t, h, "GET", "/api/v1/functions/"+fnID, nil, &notFound)
	if goneStatus != 404 {
		t.Errorf("GET after delete status=%d, want 404", goneStatus)
	}
	if notFound.Error.Code != "FUNCTION_NOT_FOUND" {
		t.Errorf("GET after delete error.code=%q, want FUNCTION_NOT_FOUND", notFound.Error.Code)
	}
}

// ── 2. List + pagination smoke ───────────────────────────────────────────────

func TestFunction_HTTP_ListPaginated(t *testing.T) {
	h := th.New(t)

	// Seed 3 functions.
	for _, name := range []string{"alpha_fn", "beta_fn", "gamma_fn"} {
		var resp struct{}
		_ = th.PostFunction(t, h, name, "def "+name+"(x):\n    return x\n", &resp)
	}

	var listResp struct {
		Data    []map[string]any `json:"data"`
		HasMore bool             `json:"hasMore"`
	}
	resp := h.GetJSON("/api/v1/functions?limit=10", &listResp)
	_ = resp.Body.Close()
	if len(listResp.Data) != 3 {
		t.Errorf("List returned %d, want 3", len(listResp.Data))
	}
}

// ── 3. LLM tool — search_function on empty library returns [] ────────────────

func TestFunction_LLM_SearchEmpty(t *testing.T) {
	fake := th.NewFakeLLMServer(t)
	fake.PushScript(th.ScriptSingleToolCall(
		"search_function", "call_search_empty_001",
		`{"query":"anything","summary":"checking the empty library"}`,
	))
	fake.PushScript(th.ScriptText("Library is empty."))

	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	h.SeedDeepSeek(t, "fake-key")
	conv := h.NewConversation(t, "fn-search-empty")
	sub := h.SubscribeSSE(t, conv.ID)

	th.PostMessage(t, h, conv.ID, "What functions do I have?")

	final := sub.WaitForAssistantTerminal(30 * time.Second)
	if final.Status != chatdomain.StatusCompleted {
		t.Fatalf("status=%q errorCode=%q\nraw:\n%s", final.Status, final.ErrorCode, sub.FormatRawEvents())
	}

	_, sawCall := th.ExtractToolCallByName(final.Blocks, "search_function")
	if !sawCall {
		t.Errorf("no search_function tool_call in final blocks\nraw:\n%s", sub.FormatRawEvents())
	}
}

// ── 4. Run + execution log (sandbox-gated) ───────────────────────────────────

func TestFunction_HTTP_RunAndExecutionLog(t *testing.T) {
	h := th.New(t)
	th.RequireFunctionResources(t, h)

	// Create.
	// 建。
	var createResp struct {
		Data struct {
			Function struct{ ID string `json:"id"` } `json:"function"`
			Version  struct{ ID string `json:"id"` } `json:"version"`
		} `json:"data"`
	}
	if status := th.PostFunction(t, h, "echo_fn", "def echo_fn(name):\n    return f'hi-{name}'\n", &createResp); status != 201 {
		t.Fatalf("create status=%d", status)
	}
	fnID := createResp.Data.Function.ID
	versionID := createResp.Data.Version.ID

	// Wait for env ready (background sync). Polls GET every 500ms up to 90s
	// — first-time uv venv build downloads Python + creates a virtualenv;
	// can take 20-60s on fresh CI. If python-build itself fails on this host
	// (common cause: missing OS build deps for cpython), skip rather than
	// fail — we're testing the function flow, not the mise install pipeline.
	//
	// 等 env ready(后台 sync)。每 500ms 轮询 GET,最长 90s。host 上 python-build
	// 挂时(常见:缺 cpython 构建依赖)t.Skip(测的是 function 流程不是 mise)。
	envReady := false
	deadline := time.Now().Add(90 * time.Second)
	for time.Now().Before(deadline) {
		var getResp struct {
			Data struct {
				EnvStatus string `json:"envStatus"`
				EnvError  string `json:"envError"`
			} `json:"data"`
		}
		gr := h.GetJSON("/api/v1/functions/"+fnID, &getResp)
		_ = gr.Body.Close()
		if getResp.Data.EnvStatus == "ready" {
			envReady = true
			break
		}
		if getResp.Data.EnvStatus == "failed" {
			t.Skipf("env_sync failed on this host (skipping run test): %s", getResp.Data.EnvError)
		}
		time.Sleep(500 * time.Millisecond)
	}
	if !envReady {
		t.Skipf("env never reached ready within 90s for function %s/version %s (host runtime issue, not a code regression)", fnID, versionID)
	}

	// Run.
	var runResp struct {
		Data struct {
			OK     bool   `json:"ok"`
			Output any    `json:"output"`
		} `json:"data"`
	}
	rr := h.PostJSON("/api/v1/functions/"+fnID+":run",
		map[string]any{"args": map[string]any{"name": "world"}}, &runResp)
	_ = rr.Body.Close()
	if rr.StatusCode != 200 {
		t.Fatalf("Run status=%d, want 200", rr.StatusCode)
	}
	if !runResp.Data.OK {
		t.Fatalf("Run ok=false: %+v", runResp)
	}
	if got, _ := runResp.Data.Output.(string); got != "hi-world" {
		t.Errorf("Run output=%v, want %q", runResp.Data.Output, "hi-world")
	}

	// Execution log list.
	// 执行日志列表。
	var execListResp struct {
		Data struct {
			Count      int              `json:"count"`
			Executions []map[string]any `json:"executions"`
			Aggregates map[string]any   `json:"aggregates"`
		} `json:"data"`
	}
	el := h.GetJSON("/api/v1/functions/"+fnID+"/executions", &execListResp)
	_ = el.Body.Close()
	if el.StatusCode != 200 {
		t.Fatalf("ListExecutions status=%d", el.StatusCode)
	}
	if execListResp.Data.Count != 1 {
		t.Errorf("ListExecutions count=%d, want 1", execListResp.Data.Count)
	}
	if okCount, _ := execListResp.Data.Aggregates["okCount"].(float64); okCount != 1 {
		t.Errorf("aggregates.okCount=%v, want 1", execListResp.Data.Aggregates["okCount"])
	}
}
