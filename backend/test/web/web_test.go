//go:build pipeline

// web_test.go — pipeline tests for the web system tools (WebFetch /
// WebSearch) driving the full chat ReAct loop with a fake LLM. The
// scenarios deliberately short-circuit BEFORE any real network call so
// the tests stay deterministic and fast (no internet needed):
//
//  1. WebFetchBlocksLoopback — fake LLM scripts WebFetch with a
//     loopback URL; the SSRF guard rejects it before any HTTP request,
//     and the rejection string surfaces in tool_result.
//  2. WebSearchRejectsEmptyQuery — fake LLM scripts WebSearch with an
//     empty query; ValidateInput rejects it pre-Execute and the chat
//     layer surfaces the error in the tool_result.
//
// Live network round-trips (Jina / SearXNG / Bing) are covered by the
// in-package httptest unit tests; pipeline coverage here focuses on the
// LLM ↔ tool wiring.
//
// web_test.go — web 系统工具（WebFetch / WebSearch）pipeline 测试。两个
// 场景故意在任何真实网络调用前 short-circuit，让测试确定且快（无需联网）。
// 真实网络往返由包内 httptest 单测覆盖；pipeline 这里只验 LLM ↔ tool 接线。
package web_test

import (
	"fmt"
	"strings"
	"testing"
	"time"

	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	th "github.com/sunweilin/forgify/backend/test/harness"
)

// ── 1. WebFetch SSRF guard short-circuits before any network call ─────────────

func TestWeb_WebFetchBlocksLoopback(t *testing.T) {
	fake := th.NewFakeLLMServer(t)
	fake.PushScript(th.ScriptSingleToolCall(
		"WebFetch", "call_fake_fetch_001",
		`{"summary":"snooping localhost","url":"http://127.0.0.1/admin","prompt":"What's on this page?"}`,
	))
	fake.PushScript(th.ScriptText("I cannot fetch loopback addresses."))

	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	h.SeedDeepSeek(t, "fake-test-key")
	conv := h.NewConversation(t, "web-ssrf")
	sub := h.SubscribeSSE(t, conv.ID)

	th.PostMessage(t, h, conv.ID, "Try fetching http://127.0.0.1/admin.")

	final := sub.WaitForAssistantTerminal(30 * time.Second)
	if final.Status != chatdomain.StatusCompleted {
		t.Fatalf("status=%q errCode=%q errMsg=%q\nraw:\n%s",
			final.Status, final.ErrorCode, final.ErrorMessage, sub.FormatRawEvents())
	}

	fetchID, ok := th.ExtractToolCallByName(final.Blocks, "WebFetch")
	if !ok {
		t.Fatalf("no WebFetch tool_call in final blocks\nraw:\n%s", sub.FormatRawEvents())
	}
	res, ok := th.ExtractToolResultByCallID(final.Blocks, fetchID)
	if !ok {
		t.Fatalf("no WebFetch tool_result for call %q", fetchID)
	}
	// Framework-level ok must remain true — the SSRF rejection is a friendly
	// string, not a Go error.
	// framework 层 ok 仍是 true——SSRF 拒绝是友好字符串，非 Go err。
	if v, _ := res["ok"].(bool); !v {
		t.Errorf("WebFetch tool_result.ok = false; expected true. data: %v", res)
	}
	resultText, _ := res["result"].(string)
	if !strings.Contains(resultText, "loopback") {
		t.Errorf("expected loopback rejection in tool_result, got: %q", resultText)
	}
}

// ── 2. WebSearch ValidateInput rejects empty query pre-Execute ────────────────

func TestWeb_WebSearchRejectsEmptyQuery(t *testing.T) {
	fake := th.NewFakeLLMServer(t)
	fake.PushScript(th.ScriptSingleToolCall(
		"WebSearch", "call_fake_search_001",
		`{"summary":"empty search","query":""}`,
	))
	fake.PushScript(th.ScriptText("I cannot search with an empty query."))

	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	h.SeedDeepSeek(t, "fake-test-key")
	conv := h.NewConversation(t, "web-validate")
	sub := h.SubscribeSSE(t, conv.ID)

	th.PostMessage(t, h, conv.ID, "Search the web.")

	final := sub.WaitForAssistantTerminal(30 * time.Second)
	if final.Status != chatdomain.StatusCompleted {
		t.Fatalf("status=%q\nraw:\n%s", final.Status, sub.FormatRawEvents())
	}

	searchID, ok := th.ExtractToolCallByName(final.Blocks, "WebSearch")
	if !ok {
		t.Fatalf("no WebSearch tool_call in final blocks")
	}
	res, ok := th.ExtractToolResultByCallID(final.Blocks, searchID)
	if !ok {
		t.Fatal("no WebSearch tool_result")
	}
	// ValidateInput failures are surfaced as tool failures — the chat layer
	// stamps ok=false and copies the error message into the result text.
	// ValidateInput 失败被当作 tool failure 处理；chat 层置 ok=false 并把
	// 错误消息写进 result 文本。
	if v, _ := res["ok"].(bool); v {
		t.Errorf("WebSearch tool_result.ok = true; expected false on validation failure. data: %v", res)
	}
	resultText := fmt.Sprintf("%v", res["result"])
	if !strings.Contains(resultText, "query is required") {
		t.Errorf("expected ErrEmptyQuery message in result, got: %q", resultText)
	}
}
