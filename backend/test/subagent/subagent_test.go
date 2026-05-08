//go:build pipeline

// subagent_test.go — pipeline tests for the Subagent system tool.
// Three offline scenarios using FakeLLMServer + Script queues:
//
//  1. Spawn_EndToEnd
//     Parent → Subagent("general-purpose", "summarize") → sub-runner emits
//     text → parent receives sub-runner's text as tool_result → parent
//     finishes. Asserts: a sub-run Message row exists in `messages` with
//     attrs.kind=subagent_run + status=completed; sub blocks persisted in
//     `message_blocks`; parent's final assistant message contains a
//     tool_call(Subagent) + paired tool_result.
//
//  2. EventLog_CarriesSubagentRunMetadata
//     Same scenario as #1, plus walks the SSE eventlog raw events to
//     assert that at least one message_start during the sub-run window
//     carries attrs.kind=subagent_run + type=general-purpose.
//
//  3. MaxTurns_Triggered
//     Parent calls Subagent with max_turns=1; sub-LLM keeps emitting
//     tool_calls. Asserts the sub-run Message status=max_turns and
//     parent's tool_result text contains the "max turns" marker.
//
// subagent_test.go ——Subagent 工具 pipeline 测试。新数据模型：sub-run 是
// 统一 messages 表里的一行（attrs.kind=subagent_run），sub blocks 在
// message_blocks。无独立 subagent_runs / subagent_messages 表。
package subagent

import (
	"encoding/json"
	"strings"
	"testing"
	"time"

	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	th "github.com/sunweilin/forgify/backend/test/harness"
)

// findSubagentRuns returns the messages rows in convID flagged as
// subagent runs (attrs.kind=subagent_run). Each row is decoded as a map
// so tests can inspect both columns and parsed Attrs JSON fields.
//
// findSubagentRuns 返 convID 中标记为 subagent run（attrs.kind=
// subagent_run）的 messages 行，每行解码为 map 让测试同时看列与 Attrs JSON。
func findSubagentRuns(t *testing.T, h *th.Harness, convID string) []map[string]any {
	t.Helper()
	type row struct {
		ID     string `gorm:"column:id"`
		Status string `gorm:"column:status"`
		Attrs  string `gorm:"column:attrs"`
	}
	var rows []row
	if err := h.DB.Raw(
		`SELECT id, status, attrs FROM messages
		 WHERE conversation_id = ? AND attrs != ''
		   AND json_extract(attrs, '$.kind') = 'subagent_run'`,
		convID,
	).Scan(&rows).Error; err != nil {
		t.Fatalf("query subagent runs: %v", err)
	}
	out := make([]map[string]any, 0, len(rows))
	for _, r := range rows {
		var a map[string]any
		_ = json.Unmarshal([]byte(r.Attrs), &a)
		if a == nil {
			a = map[string]any{}
		}
		a["id"] = r.ID
		a["status"] = r.Status
		out = append(out, a)
	}
	return out
}

// ── 1. Spawn end-to-end ──────────────────────────────────────────────

func TestSubagent_Spawn_EndToEnd(t *testing.T) {
	fake := th.NewFakeLLMServer(t)
	// Script queue plays back in order across the parent run + sub-runner.
	// Script 队列按顺序在父 run + sub-runner 之间回放。
	//
	// 1. Parent LLM: emit a Subagent tool_call.
	// 1. 父 LLM：emit Subagent tool_call。
	fake.PushScript(th.ScriptSingleToolCall(
		"Subagent", "call_sub_1",
		`{"subagent_type":"general-purpose","prompt":"summarize the project","summary":"delegating to subagent"}`,
	))
	// 2. Sub-runner LLM: emit a final text answer (no tool calls → loop ends).
	// 2. Sub-runner LLM：emit 最终 text 答案（无 tool call → loop 结束）。
	fake.PushScript(th.ScriptText("Forgify is a local-first agentic workflow platform built around a Go backend with sub-domains for chat, forge, and sandbox."))
	// 3. Parent LLM (after sub returns): wrap up with a final answer.
	// 3. 父 LLM（sub 返回后）：用 final answer 收尾。
	fake.PushScript(th.ScriptText("I delegated the question to a subagent — see its summary above."))

	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	h.SeedDeepSeek(t, "fake-test-key")
	conv := h.NewConversation(t, "subagent-end-to-end")
	sub := h.SubscribeSSE(t, conv.ID)

	th.PostMessage(t, h, conv.ID, "What is this project?")

	final := sub.WaitForAssistantTerminal(60 * time.Second)
	if final.Status != chatdomain.StatusCompleted {
		t.Fatalf("parent status=%q errCode=%q errMsg=%q\nraw:\n%s",
			final.Status, final.ErrorCode, final.ErrorMessage, sub.FormatRawEvents())
	}

	// Parent's final blocks must contain the Subagent tool_call + a paired
	// tool_result whose `result` text matches the sub-runner's last message.
	//
	// 父 final blocks 必含 Subagent tool_call + 配对 tool_result，其
	// `result` 文本 = sub-runner 最后一条 message。
	tcID, ok := th.ExtractToolCallByName(final.Blocks, "Subagent")
	if !ok {
		t.Fatalf("no Subagent tool_call block in parent final\nraw:\n%s", sub.FormatRawEvents())
	}
	resultData, ok := th.ExtractToolResultByCallID(final.Blocks, tcID)
	if !ok {
		t.Fatalf("no paired tool_result for Subagent call %q", tcID)
	}
	if okFlag, _ := resultData["ok"].(bool); !okFlag {
		t.Errorf("Subagent tool_result.ok=false; data=%v", resultData)
	}
	resultText, _ := resultData["result"].(string)
	if !strings.Contains(resultText, "Forgify") {
		t.Errorf("Subagent tool_result text doesn't echo sub-runner's message: %q", resultText)
	}

	// Sub-run Message row persisted with status=completed.
	// sub-run Message 行落库，status=completed。
	runs := findSubagentRuns(t, h, conv.ID)
	if len(runs) != 1 {
		t.Fatalf("subagent run count = %d, want 1", len(runs))
	}
	if runs[0]["status"] != "completed" {
		t.Errorf("subagent run status = %v, want completed", runs[0]["status"])
	}
	if runs[0]["type"] != "general-purpose" {
		t.Errorf("subagent run type = %v, want general-purpose", runs[0]["type"])
	}

	// Sub-run blocks persisted in message_blocks (at least one — the
	// final text block from the sub-runner).
	// sub-run blocks 落库（至少一条 sub-runner 最终 text block）。
	runID, _ := runs[0]["id"].(string)
	var blockCount int64
	if err := h.DB.Raw(
		`SELECT COUNT(*) FROM message_blocks WHERE message_id = ?`, runID,
	).Scan(&blockCount).Error; err != nil {
		t.Fatalf("count message_blocks for sub-run: %v", err)
	}
	if blockCount < 1 {
		t.Errorf("message_blocks for sub-run = %d, want ≥ 1", blockCount)
	}
}

// ── 2. EventLog carries subagent_run metadata ────────────────────────

func TestSubagent_EventLog_CarriesSubagentRunMetadata(t *testing.T) {
	fake := th.NewFakeLLMServer(t)
	fake.PushScript(th.ScriptSingleToolCall(
		"Subagent", "call_sub_2",
		`{"subagent_type":"general-purpose","prompt":"give me a one-line description","summary":"checking eventlog"}`,
	))
	fake.PushScript(th.ScriptText("A focused subagent that streams its work back through the eventlog."))
	fake.PushScript(th.ScriptText("Done."))

	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	h.SeedDeepSeek(t, "fake-test-key")
	conv := h.NewConversation(t, "subagent-eventlog")
	sub := h.SubscribeSSE(t, conv.ID)

	th.PostMessage(t, h, conv.ID, "Describe yourself.")

	final := sub.WaitForAssistantTerminal(60 * time.Second)
	if final.Status != chatdomain.StatusCompleted {
		t.Fatalf("parent status=%q\nraw:\n%s", final.Status, sub.FormatRawEvents())
	}

	// Walk the raw eventlog: at least one message_start during the sub-run
	// window must carry attrs.kind=subagent_run + type=general-purpose.
	//
	// 遍历 raw eventlog：sub-run 窗口内至少一条 message_start 必带
	// attrs.kind=subagent_run + type=general-purpose。
	var sawSubagentStart bool
	for _, ev := range sub.RawEvents() {
		if ev.Source != "eventlog" || ev.Type != "message_start" {
			continue
		}
		var payload struct {
			ConversationID string         `json:"conversationId"`
			Attrs          map[string]any `json:"attrs"`
		}
		if err := json.Unmarshal(ev.Data, &payload); err != nil {
			continue
		}
		if payload.Attrs["kind"] != "subagent_run" {
			continue
		}
		sawSubagentStart = true
		if payload.ConversationID != conv.ID {
			t.Errorf("subagent message_start conversationId = %q, want %s", payload.ConversationID, conv.ID)
		}
		if payload.Attrs["type"] != "general-purpose" {
			t.Errorf("subagent message_start attrs.type = %v, want general-purpose", payload.Attrs["type"])
		}
	}
	if !sawSubagentStart {
		t.Errorf("no message_start with attrs.kind=subagent_run during the run\nraw:\n%s",
			sub.FormatRawEvents())
	}
}

// ── 3. max_turns triggered ───────────────────────────────────────────

// Sub-LLM emits an unknown-tool call on every step so the loop keeps
// running tool batches. With max_turns=1 the second iteration must not
// happen — the run terminates with status=max_turns and the parent's
// tool_result carries the "[note: hit max turns]" marker.
//
// Sub-LLM 每步都 emit 未知工具 call，让 loop 持续 batch。max_turns=1 时
// 第二次迭代不发生——run 以 status=max_turns 终止，parent 的 tool_result
// 带 "[note: hit max turns]" 标记。
func TestSubagent_MaxTurns_Triggered(t *testing.T) {
	fake := th.NewFakeLLMServer(t)

	// Parent: emit Subagent with max_turns=1.
	// 父：emit Subagent，max_turns=1。
	fake.PushScript(th.ScriptSingleToolCall(
		"Subagent", "call_sub_max",
		`{"subagent_type":"general-purpose","prompt":"loop forever","max_turns":1,"summary":"max-turns test"}`,
	))
	// Sub-runner step 1: emit a tool_call to a nonexistent tool. The loop
	// runs the tool, gets "tool not found", and loops back. With max_turns=1
	// it should NOT enter step 2 — instead the run terminates as max_turns.
	//
	// Sub-runner step 1：emit 未知工具 call。loop 跑工具拿 "tool not found"
	// 后回环。max_turns=1 时不进 step 2——run 以 max_turns 终止。
	fake.PushScript(th.ScriptSingleToolCall(
		"NonexistentTool", "call_loop_x",
		`{"summary":"keep looping"}`,
	))
	// In case the loop somehow runs a second LLM step, guard with another
	// script — keeps the test from blocking on FakeLLMServer queue exhaustion.
	// 万一进入第二步，加一份兜底 script 防 FakeLLMServer 队列耗尽阻塞。
	fake.PushDefault(th.ScriptText("(should not be reached)"))

	// Parent: after sub returns, wrap up.
	// 父：sub 返回后收尾。
	fake.PushScript(th.ScriptText("Sub-run hit its max turns as expected."))

	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	h.SeedDeepSeek(t, "fake-test-key")
	conv := h.NewConversation(t, "subagent-max-turns")
	sub := h.SubscribeSSE(t, conv.ID)

	th.PostMessage(t, h, conv.ID, "Try a loopy task.")

	final := sub.WaitForAssistantTerminal(60 * time.Second)
	if final.Status != chatdomain.StatusCompleted {
		t.Fatalf("parent status=%q\nraw:\n%s", final.Status, sub.FormatRawEvents())
	}

	// Parent's tool_result for the Subagent call must carry the "max turns" note.
	// 父对 Subagent call 的 tool_result 必带 "max turns" 注脚。
	tcID, ok := th.ExtractToolCallByName(final.Blocks, "Subagent")
	if !ok {
		t.Fatalf("no Subagent tool_call in parent final")
	}
	resultData, ok := th.ExtractToolResultByCallID(final.Blocks, tcID)
	if !ok {
		t.Fatalf("no paired tool_result for Subagent call")
	}
	resultText, _ := resultData["result"].(string)
	if !strings.Contains(resultText, "max turns") {
		t.Errorf("tool_result text missing max-turns note: %q", resultText)
	}

	// Sub-run Message row status must be max_turns.
	// sub-run Message 行 status 必为 max_turns。
	runs := findSubagentRuns(t, h, conv.ID)
	if len(runs) != 1 {
		t.Fatalf("subagent run count = %d, want 1", len(runs))
	}
	if runs[0]["status"] != "max_turns" {
		t.Errorf("subagent run status = %v, want max_turns", runs[0]["status"])
	}
}
