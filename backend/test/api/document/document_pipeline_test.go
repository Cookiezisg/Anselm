//go:build pipeline

// Package document_test runs pipeline tests for the Notion-style document tree.
//
// Package document_test 跑 Notion-style 文档树 pipeline 测试。
package document_test

import (
	"strings"
	"testing"
	"time"

	documentapp "github.com/sunweilin/forgify/backend/internal/app/document"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	th "github.com/sunweilin/forgify/backend/test/harness"
)

// TestDocument_AgentCreatesViaToolCall — fake LLM emits create_document, agent
// loop runs the tool, doc lands in DB.
//
// TestDocument_AgentCreatesViaToolCall —— fake LLM 发 create_document tool_call,
// agent loop 跑该工具,doc 真落库。
// covers: POST /api/v1/conversations/{id}/messages
// covers: GET /api/v1/eventlog
func TestDocument_AgentCreatesViaToolCall(t *testing.T) {
	fake := th.NewFakeLLMServer(t)
	// After capability-disclosure refactor, document tools are lazy: the agent
	// must call activate_tools(category="document") first before create_document
	// becomes available. We model the production flow with 3 sequential scripts.
	//
	// 能力披露重构后,document tool 是 lazy:agent 必须先调
	// activate_tools(category="document") 才能用 create_document。3 步脚本模拟。
	fake.PushScript(th.ScriptSingleToolCall(
		"activate_tools", "tc_activate_doc",
		`{"summary":"activating document tools","category":"document"}`,
	))
	fake.PushScript(th.ScriptSingleToolCall(
		"create_document", "tc_create_1",
		`{"summary":"creating root doc","name":"Project Alpha","description":"the main project"}`,
	))
	fake.PushScript(th.ScriptText("Done — Project Alpha is created."))
	fake.PushDefault(th.ScriptText("Title"))

	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	h.SeedDeepSeek(t, "fake-test-key")

	conv := h.NewConversation(t, "doc-agent-create")
	sub := h.SubscribeSSE(t, conv.ID)
	th.PostMessage(t, h, conv.ID, "Create a Project Alpha doc for me.")
	final := sub.WaitForAssistantTerminal(60 * time.Second)
	if final.Status != chatdomain.StatusCompleted {
		t.Fatalf("status=%q errMsg=%q\nraw:\n%s", final.Status, final.ErrorMessage, sub.FormatRawEvents())
	}

	ctx := th.CtxAs(th.DefaultUserID)
	docs, err := h.Document.ListAll(ctx)
	if err != nil {
		t.Fatalf("ListAll: %v", err)
	}
	if len(docs) != 1 {
		t.Fatalf("expected 1 doc in DB after tool call; got %d", len(docs))
	}
	got := docs[0]
	if got.Name != "Project Alpha" {
		t.Errorf("doc name = %q, want %q", got.Name, "Project Alpha")
	}
	if got.Path != "/Project Alpha" {
		t.Errorf("doc path = %q, want %q", got.Path, "/Project Alpha")
	}
	if got.Description != "the main project" {
		t.Errorf("description = %q", got.Description)
	}
}

// TestDocument_AgentReadsAndEdits — seed a doc via service, agent fetches via
// read_document then edits content via edit_document, verify DB updated.
//
// TestDocument_AgentReadsAndEdits —— 先用 service 种一篇 doc,
// agent 经 read_document 读 + edit_document 改,验证 DB 更新。
// covers: POST /api/v1/conversations/{id}/messages
// covers: GET /api/v1/eventlog
func TestDocument_AgentReadsAndEdits(t *testing.T) {
	fake := th.NewFakeLLMServer(t)

	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	h.SeedDeepSeek(t, "fake-test-key")

	ctx := th.CtxAs(th.DefaultUserID)
	seeded, err := h.Document.Create(ctx, documentapp.CreateInput{
		Name:        "API Spec",
		Description: "REST contract",
		Content:     "# API v1\n\nendpoints TBD",
	})
	if err != nil {
		t.Fatalf("seed doc: %v", err)
	}

	// Turn 0: activate document tools (lazy category — capability disclosure).
	//
	// Turn 0: 激活 document 工具(lazy 类别 — 能力披露重构后)。
	fake.PushScript(th.ScriptSingleToolCall(
		"activate_tools", "tc_activate_doc",
		`{"summary":"activating document tools","category":"document"}`,
	))
	// Turn 1: read the doc
	fake.PushScript(th.ScriptSingleToolCall(
		"read_document", "tc_read_1",
		`{"summary":"reading the spec","id":"`+seeded.ID+`"}`,
	))
	// Turn 2: append a v2 section
	fake.PushScript(th.ScriptSingleToolCall(
		"edit_document", "tc_edit_1",
		`{"summary":"adding v2 endpoints","id":"`+seeded.ID+`","content":"# API v1\n\nendpoints TBD\n\n# API v2\n\n- GET /foo"}`,
	))
	// Turn 3: text close-out
	fake.PushScript(th.ScriptText("Updated the spec with v2."))
	fake.PushDefault(th.ScriptText("Title"))

	conv := h.NewConversation(t, "doc-agent-edit")
	sub := h.SubscribeSSE(t, conv.ID)
	th.PostMessage(t, h, conv.ID, "Add a v2 section to the API spec.")
	final := sub.WaitForAssistantTerminal(60 * time.Second)
	if final.Status != chatdomain.StatusCompleted {
		t.Fatalf("status=%q errMsg=%q\nraw:\n%s", final.Status, final.ErrorMessage, sub.FormatRawEvents())
	}

	got, err := h.Document.Get(ctx, seeded.ID)
	if err != nil {
		t.Fatalf("post-edit Get: %v", err)
	}
	if !strings.Contains(got.Content, "API v2") {
		t.Errorf("edit_document did not persist v2 section; got content: %s", got.Content)
	}
}
