//go:build pipeline

// forge_test.go — chat × forge intersection pipeline tests.
// Tests that the five forge LLM tools (search/get/create/edit/run) function
// end-to-end in a real chat turn with a fake LLM driving tool calls.
//
// All tests that need forge operations (get/create/run) require
// FORGIFY_DEV_RESOURCES because creating a forge needs the Python AST parser.
//
// forge_test.go — chat × forge 交集 pipeline 测试。
// 验证五个 forge LLM tool 在真实 chat turn 中端到端工作（fake LLM 驱动 tool call）。
// 需要 forge 操作的测试（get/create/run）都需 FORGIFY_DEV_RESOURCES（Python AST）。
package chat

import (
	"fmt"
	"testing"
	"time"

	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	th "github.com/sunweilin/forgify/backend/test/harness"
)

// ── 1. get_forge: LLM calls get_forge and receives full forge detail ──────────

func TestChatForge_GetForge_ReturnsDetail(t *testing.T) {
	fake := th.NewFakeLLMServer(t)
	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	th.RequireForgeResources(t, h)
	h.SeedDeepSeek(t, "fake-key")

	// Create a real forge (needs Python for AST parse).
	// 创建真实 forge（需要 Python 做 AST 解析）。
	forge := h.NewForge(t, "get_detail_forge", th.SimpleForgeCode)

	// Script 1: LLM calls get_forge with the forge's ID.
	// Script 2: LLM responds after receiving forge detail.
	//
	// Script 1：LLM 调 get_forge 传入 forge ID。
	// Script 2：LLM 收到 forge detail 后响应。
	fake.PushScript(th.ScriptSingleToolCall(
		"get_forge", "call_getforge_001",
		fmt.Sprintf(`{"forge_id":%q,"summary":"getting forge details"}`, forge.ID),
	))
	fake.PushScript(th.ScriptText("The forge is a greeting tool that uppercases a name."))

	conv := h.NewConversation(t, "chat-get-forge")
	sub := h.SubscribeSSE(t, conv.ID)

	th.PostMessage(t, h, conv.ID, "Tell me about the get_detail_forge.")

	final := sub.WaitForAssistantTerminal(60 * time.Second)
	if final.Status != chatdomain.StatusCompleted {
		t.Fatalf("status=%q errorCode=%q\nraw:\n%s",
			final.Status, final.ErrorCode, sub.FormatRawEvents())
	}

	// Verify get_forge tool call + result blocks.
	// 验证 get_forge tool call + result block。
	callID, found := th.ExtractToolCallByName(final.Blocks, "get_forge")
	if !found {
		t.Error("no get_forge tool_call block in final message")
	}
	result, foundResult := th.ExtractToolResultByCallID(final.Blocks, callID)
	if !foundResult {
		t.Error("no tool_result paired with get_forge call")
	}
	if ok, _ := result["ok"].(bool); !ok {
		t.Errorf("get_forge tool_result ok=false; result=%v", result)
	}
}

// ── 2. run_forge: LLM calls run_forge → ForgeExecution with TriggeredBy=chat ─

func TestChatForge_RunForge_WritesExecution_TriggeredByChat(t *testing.T) {
	fake := th.NewFakeLLMServer(t)
	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	th.RequireForgeResources(t, h)
	h.SeedDeepSeek(t, "fake-key")

	forge := h.NewForge(t, "run_chat_forge", th.SimpleForgeCode)

	// Script 1: LLM calls run_forge with input.
	// Script 2: LLM responds after receiving execution result.
	fake.PushScript(th.ScriptSingleToolCall(
		"run_forge", "call_runforge_001",
		fmt.Sprintf(`{"forge_id":%q,"input":{"name":"World"},"summary":"running the forge"}`, forge.ID),
	))
	fake.PushScript(th.ScriptText("The forge ran successfully and greeted World."))

	conv := h.NewConversation(t, "chat-run-forge")
	sub := h.SubscribeSSE(t, conv.ID)

	th.PostMessage(t, h, conv.ID, "Run the run_chat_forge with name World.")

	final := sub.WaitForAssistantTerminal(60 * time.Second)
	if final.Status != chatdomain.StatusCompleted {
		t.Fatalf("status=%q errorCode=%q\nraw:\n%s",
			final.Status, final.ErrorCode, sub.FormatRawEvents())
	}

	// Verify run_forge tool call + result.
	callID, found := th.ExtractToolCallByName(final.Blocks, "run_forge")
	if !found {
		t.Fatalf("no run_forge tool_call block")
	}
	result, _ := th.ExtractToolResultByCallID(final.Blocks, callID)
	if ok, _ := result["ok"].(bool); !ok {
		t.Errorf("run_forge tool_result ok=false; result=%v", result)
	}

	// ForgeExecution must be in DB with TriggeredBy=chat and ConversationID set.
	// ForgeExecution 必须落库，TriggeredBy=chat，ConversationID 已填。
	var triggeredBy, convIDInDB string
	if err := h.DB.Raw(
		"SELECT triggered_by, conversation_id FROM forge_executions WHERE forge_id = ? AND kind = 'run' LIMIT 1",
		forge.ID,
	).Row().Scan(&triggeredBy, &convIDInDB); err != nil {
		t.Fatalf("query forge_executions: %v", err)
	}
	if triggeredBy != "chat" {
		t.Errorf("triggered_by=%q, want chat", triggeredBy)
	}
	if convIDInDB != conv.ID {
		t.Errorf("conversation_id=%q, want %q", convIDInDB, conv.ID)
	}
}

// ── 3. create_forge: LLM triggers code gen → pending version in DB ────────────

func TestChatForge_CreateForge_PendingCreated(t *testing.T) {
	fake := th.NewFakeLLMServer(t)
	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	th.RequireForgeResources(t, h)
	h.SeedDeepSeek(t, "fake-key")

	// 3 scripts:
	//   1. Chat LLM → create_forge tool_call
	//   2. create_forge internal LLM → Python code stream
	//   3. Chat LLM → text response after tool result
	//
	// 3 条脚本：
	//   1. Chat LLM → create_forge tool call
	//   2. create_forge 内部 LLM → 流出 Python 代码
	//   3. Chat LLM → tool result 后响应
	fake.PushScript(th.ScriptSingleToolCall(
		"create_forge", "call_createforge_001",
		`{"name":"chat_created_forge","description":"Greet someone","instruction":"Write a greeting function","summary":"creating a forge"}`,
	))
	fake.PushScript(th.ScriptText(th.SimpleForgeCode)) // internal code gen call
	fake.PushScript(th.ScriptText("I created a new forge called chat_created_forge for you."))

	conv := h.NewConversation(t, "chat-create-forge")
	sub := h.SubscribeSSE(t, conv.ID)

	th.PostMessage(t, h, conv.ID, "Create a forge that greets someone by name.")

	final := sub.WaitForAssistantTerminal(120 * time.Second)
	if final.Status != chatdomain.StatusCompleted {
		t.Fatalf("status=%q errorCode=%q\nraw:\n%s",
			final.Status, final.ErrorCode, sub.FormatRawEvents())
	}

	// Verify create_forge tool_call block.
	_, found := th.ExtractToolCallByName(final.Blocks, "create_forge")
	if !found {
		t.Error("no create_forge tool_call block in final message")
	}

	// Forge must have been persisted (draft + pending version).
	// Forge 必须已落库（draft + pending version）。
	n := th.DBCount(t, h, "forges", "name = 'chat_created_forge'")
	if n != 1 {
		t.Errorf("forges with name=chat_created_forge: %d, want 1", n)
	}
	n = th.DBCount(t, h, "forge_versions",
		"forge_id = (SELECT id FROM forges WHERE name = 'chat_created_forge') AND status = 'pending'")
	if n != 1 {
		t.Errorf("pending forge_versions: %d, want 1", n)
	}
}
