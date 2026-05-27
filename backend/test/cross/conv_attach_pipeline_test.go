//go:build pipeline

package cross

import (
	"strings"
	"testing"
	"time"

	convapp "github.com/sunweilin/forgify/backend/internal/app/conversation"
	documentapp "github.com/sunweilin/forgify/backend/internal/app/document"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	documentdomain "github.com/sunweilin/forgify/backend/internal/domain/document"
	th "github.com/sunweilin/forgify/backend/test/harness"
)

// TestDocument_ConversationAttach_SingleDoc — attach one doc to a conv;
// chat system prompt should contain the doc's content (no subtree expansion).
//
// TestDocument_ConversationAttach_SingleDoc —— 把单篇 doc 挂到对话上,
// chat system prompt 应含该 doc 内容(不展开子树)。
func TestDocument_ConversationAttach_SingleDoc(t *testing.T) {
	fake := th.NewFakeLLMServer(t)
	fake.PushScript(th.ScriptText("Read the spec."))
	fake.PushDefault(th.ScriptText("Title"))

	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	h.SeedDeepSeek(t, "fake-test-key")

	ctx := h.LocalCtx()
	doc, err := h.Document.Create(ctx, documentapp.CreateInput{
		Name:        "API spec",
		Description: "REST API endpoints",
		Content:     "# v2 endpoints\n\nGET /widgets — list widgets.",
	})
	if err != nil {
		t.Fatalf("seed doc: %v", err)
	}

	conv := h.NewConversation(t, "conv-attach-single")
	atts := []documentdomain.AttachedDocument{{DocumentID: doc.ID}}
	if _, err := h.Conversation.Update(ctx, conv.ID, convapp.UpdateInput{
		AttachedDocuments: &atts,
	}); err != nil {
		t.Fatalf("attach doc to conv: %v", err)
	}

	sub := h.SubscribeSSE(t, conv.ID)
	th.PostMessage(t, h, conv.ID, "What does the API spec say?")
	final := sub.WaitForAssistantTerminal(60 * time.Second)
	if final.Status != chatdomain.StatusCompleted {
		t.Fatalf("status=%q errMsg=%q\nraw:\n%s", final.Status, final.ErrorMessage, sub.FormatRawEvents())
	}

	prompt := fake.LastSystemPrompt()
	for _, want := range []string{
		"<documents>",
		`<document path="/API spec"`,
		"GET /widgets",
	} {
		if !strings.Contains(prompt, want) {
			t.Errorf("system prompt missing %q\nfull prompt:\n%s", want, prompt)
		}
	}
}

// TestDocument_ConversationAttach_Subtree — attach a tree root with
// IncludeSubtree=true; system prompt should contain ALL descendants live-resolved.
//
// TestDocument_ConversationAttach_Subtree —— 挂载根并标 IncludeSubtree=true;
// system prompt 应含全部 descendants(live-resolved)。
func TestDocument_ConversationAttach_Subtree(t *testing.T) {
	fake := th.NewFakeLLMServer(t)
	fake.PushScript(th.ScriptText("Reviewed."))
	fake.PushDefault(th.ScriptText("Title"))

	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	h.SeedDeepSeek(t, "fake-test-key")

	ctx := h.LocalCtx()
	root, err := h.Document.Create(ctx, documentapp.CreateInput{
		Name:        "Project Alpha",
		Description: "root folder",
		Content:     "## Alpha root",
	})
	if err != nil {
		t.Fatalf("seed root: %v", err)
	}
	if _, err := h.Document.Create(ctx, documentapp.CreateInput{
		Name:     "spec",
		ParentID: &root.ID,
		Content:  "## spec content unique-A",
	}); err != nil {
		t.Fatalf("seed spec: %v", err)
	}
	if _, err := h.Document.Create(ctx, documentapp.CreateInput{
		Name:     "tasks",
		ParentID: &root.ID,
		Content:  "## tasks content unique-B",
	}); err != nil {
		t.Fatalf("seed tasks: %v", err)
	}

	conv := h.NewConversation(t, "conv-attach-subtree")
	atts := []documentdomain.AttachedDocument{{DocumentID: root.ID, IncludeSubtree: true}}
	if _, err := h.Conversation.Update(ctx, conv.ID, convapp.UpdateInput{
		AttachedDocuments: &atts,
	}); err != nil {
		t.Fatalf("attach subtree: %v", err)
	}

	sub := h.SubscribeSSE(t, conv.ID)
	th.PostMessage(t, h, conv.ID, "Review Project Alpha.")
	final := sub.WaitForAssistantTerminal(60 * time.Second)
	if final.Status != chatdomain.StatusCompleted {
		t.Fatalf("status=%q errMsg=%q\nraw:\n%s", final.Status, final.ErrorMessage, sub.FormatRawEvents())
	}

	prompt := fake.LastSystemPrompt()
	for _, want := range []string{
		"unique-A",
		"unique-B",
		"Alpha root",
		"/Project Alpha/spec",
		"/Project Alpha/tasks",
	} {
		if !strings.Contains(prompt, want) {
			t.Errorf("system prompt missing %q\nfull prompt:\n%s", want, prompt)
		}
	}
}

// TestDocument_ConversationAttach_Empty — no AttachedDocuments → no docs section.
//
// TestDocument_ConversationAttach_Empty —— 未挂载时 system prompt 不出现 docs 段。
func TestDocument_ConversationAttach_Empty(t *testing.T) {
	fake := th.NewFakeLLMServer(t)
	fake.PushScript(th.ScriptText("Hi."))
	fake.PushDefault(th.ScriptText("Title"))

	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	h.SeedDeepSeek(t, "fake-test-key")

	conv := h.NewConversation(t, "conv-attach-empty")
	sub := h.SubscribeSSE(t, conv.ID)
	th.PostMessage(t, h, conv.ID, "Hi.")
	final := sub.WaitForAssistantTerminal(60 * time.Second)
	if final.Status != chatdomain.StatusCompleted {
		t.Fatalf("status=%q errMsg=%q", final.Status, final.ErrorMessage)
	}

	prompt := fake.LastSystemPrompt()
	if strings.Contains(prompt, "──── Attached documents ────") {
		t.Errorf("system prompt should NOT have attached docs section:\n%s", prompt)
	}
}
