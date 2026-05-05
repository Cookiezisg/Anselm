//go:build pipeline

// subagent_test.go — pipeline tests for the Subagent system tool.
// Three offline scenarios using FakeLLMServer + Script queues:
//
//  1. Spawn_EndToEnd
//     Parent LLM → Subagent("general-purpose", "summarize") → sub-runner
//     emits text → parent receives sub-runner's text as tool_result →
//     parent finishes. Asserts: SubagentRun row in DB with status=completed,
//     SubagentMessage rows persisted, parent's final assistant message
//     contains a tool_call(Subagent) + paired tool_result with the
//     sub-runner's text.
//
//  2. SSE_CarriesSubagentRunSnapshot
//     Same scenario as #1, plus subscribes to the conversation's SSE
//     stream and asserts that at least one chat.message event during
//     the sub-run window carries SubagentRunID + a non-nil SubagentRun
//     snapshot (per subagent.md §10 — sub-runner publishes go through
//     the parent conversation's bridge with subagent context fields filled).
//
//  3. MaxTurns_Triggered
//     Parent calls Subagent with max_turns=1; sub-LLM keeps emitting
//     tool_calls (forcing > 1 ReAct step). Asserts: SubagentRun.Status
//     = max_turns, parent's tool_result text contains the
//     "[note: subagent hit max turns]" marker.
//
// V1 scope: structural recursion defense (filterTools dropping the
// SubagentTool from the sub-runner's registry) is unit-tested in
// app/subagent and app/tool/subagent. Spawning a nested Subagent inside
// a sub-run would degrade to "tool not found" (the layer-1 defense
// works), which is the expected and harmless behaviour — adding a
// pipeline test for this would only re-prove what unit tests cover.
//
// subagent_test.go ——Subagent 系统工具的 pipeline 测试。三个离线场景
// （FakeLLM Script 队列）：(1) 端到端 spawn；(2) SSE 携带 SubagentRun 快照；
// (3) max_turns 触发。结构性防递归（filterTools 剥 SubagentTool）已在
// app/subagent + app/tool/subagent 单测覆盖；嵌套尝试会降级为 "tool not
// found"——加 pipeline 重复证明无价值。
package subagent

import (
	"encoding/json"
	"strings"
	"testing"
	"time"

	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	subagentdomain "github.com/sunweilin/forgify/backend/internal/domain/subagent"
	th "github.com/sunweilin/forgify/backend/test/harness"
)

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

	// SubagentRun row persisted with status=completed.
	// SubagentRun 行落库，status=completed。
	var runs []subagentdomain.SubagentRun
	if err := h.DB.Raw(`SELECT * FROM subagent_runs WHERE parent_conversation_id = ?`, conv.ID).Scan(&runs).Error; err != nil {
		t.Fatalf("query subagent_runs: %v", err)
	}
	if len(runs) != 1 {
		t.Fatalf("subagent_runs count = %d, want 1", len(runs))
	}
	if runs[0].Status != subagentdomain.StatusCompleted {
		t.Errorf("subagent run status = %q, want completed", runs[0].Status)
	}
	if runs[0].Type != "general-purpose" {
		t.Errorf("subagent run type = %q, want general-purpose", runs[0].Type)
	}
	if runs[0].StepsUsed < 1 {
		t.Errorf("subagent run steps_used = %d, want ≥ 1", runs[0].StepsUsed)
	}

	// SubagentMessage rows persisted (at minimum the seeded user prompt
	// + the streaming assistant message).
	// SubagentMessage 行落库（至少种子 user prompt + 流式 assistant 消息）。
	var msgCount int64
	if err := h.DB.Raw(`SELECT COUNT(*) FROM subagent_messages WHERE subagent_run_id = ?`, runs[0].ID).Scan(&msgCount).Error; err != nil {
		t.Fatalf("count subagent_messages: %v", err)
	}
	if msgCount < 2 {
		t.Errorf("subagent_messages for run = %d, want ≥ 2 (user + assistant)", msgCount)
	}
}

// ── 2. SSE carries the SubagentRun snapshot ──────────────────────────

func TestSubagent_SSE_CarriesSubagentRunSnapshot(t *testing.T) {
	fake := th.NewFakeLLMServer(t)
	fake.PushScript(th.ScriptSingleToolCall(
		"Subagent", "call_sub_2",
		`{"subagent_type":"general-purpose","prompt":"give me a one-line description","summary":"checking SSE"}`,
	))
	fake.PushScript(th.ScriptText("A focused subagent that streams its work back through chat.message events."))
	fake.PushScript(th.ScriptText("Done."))

	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	h.SeedDeepSeek(t, "fake-test-key")
	conv := h.NewConversation(t, "subagent-sse")
	sub := h.SubscribeSSE(t, conv.ID)

	th.PostMessage(t, h, conv.ID, "Describe yourself.")

	final := sub.WaitForAssistantTerminal(60 * time.Second)
	if final.Status != chatdomain.StatusCompleted {
		t.Fatalf("parent status=%q\nraw:\n%s", final.Status, sub.FormatRawEvents())
	}

	// Walk the raw events: at least one chat.message during the run window
	// must carry subagentRunId + a non-nil subagentRun snapshot. Decode
	// the raw JSON to map[string]any so we read the wire field names per
	// subagent.md §10 (subagentRunId / parentConversationId / subagentRun).
	//
	// 遍历 raw events：run 窗口内至少一帧 chat.message 必带 subagentRunId
	// + 非空 subagentRun。解 JSON 到 map 以按 subagent.md §10 wire 字段名
	// 读取（subagentRunId / parentConversationId / subagentRun）。
	var (
		hasSubagentMsg     bool
		sawNonEmptyRunSnap bool
	)
	for _, ev := range sub.RawEvents() {
		if ev.Type != "chat.message" {
			continue
		}
		var payload map[string]any
		if err := json.Unmarshal(ev.Data, &payload); err != nil {
			continue
		}
		runID, _ := payload["subagentRunId"].(string)
		if runID == "" {
			continue
		}
		hasSubagentMsg = true
		if snap, ok := payload["subagentRun"].(map[string]any); ok && snap["id"] != nil {
			sawNonEmptyRunSnap = true
			// Snapshot fields per subagent.md §10 must include type +
			// parentConversationId — quick spot-check.
			// §10 快照字段必含 type + parentConversationId——抽检。
			if snap["type"] != "general-purpose" {
				t.Errorf("subagentRun.type = %v, want general-purpose", snap["type"])
			}
			if snap["parentConversationId"] != conv.ID {
				t.Errorf("subagentRun.parentConversationId = %v, want %s", snap["parentConversationId"], conv.ID)
			}
		}
	}
	if !hasSubagentMsg {
		t.Errorf("no chat.message event carried subagentRunId during the run\nraw:\n%s",
			sub.FormatRawEvents())
	}
	if !sawNonEmptyRunSnap {
		t.Errorf("no chat.message event carried a non-nil subagentRun snapshot")
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

	// SubagentRun row must record status=max_turns.
	// SubagentRun 行 status 必为 max_turns。
	var runs []subagentdomain.SubagentRun
	if err := h.DB.Raw(`SELECT * FROM subagent_runs WHERE parent_conversation_id = ?`, conv.ID).Scan(&runs).Error; err != nil {
		t.Fatalf("query subagent_runs: %v", err)
	}
	if len(runs) != 1 {
		t.Fatalf("subagent_runs count = %d, want 1", len(runs))
	}
	if runs[0].Status != subagentdomain.StatusMaxTurns {
		t.Errorf("subagent run status = %q, want max_turns", runs[0].Status)
	}
}
