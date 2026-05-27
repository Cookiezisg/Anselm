//go:build pipeline

package document_test

import (
	"context"
	"strings"
	"testing"
	"time"

	documentapp "github.com/sunweilin/forgify/backend/internal/app/document"
	workflowapp "github.com/sunweilin/forgify/backend/internal/app/workflow"
	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
	th "github.com/sunweilin/forgify/backend/test/harness"
)

// TestWorkflow_AgentNode_CreatesDoc_E2E — fake LLM scripts an `agent` node
// that calls create_document; verify the doc lands in DB after run completes.
//
// TestWorkflow_AgentNode_CreatesDoc_E2E —— fake LLM 让 `agent` 节点调
// create_document;run 完成后验证 doc 真落库。
func TestWorkflow_AgentNode_CreatesDoc_E2E(t *testing.T) {
	fake := th.NewFakeLLMServer(t)
	fake.PushScript(th.ScriptSingleToolCall(
		"create_document", "tc_agent_doc_1",
		`{"summary":"workflow agent creates output doc","name":"Workflow Output","description":"agent-generated"}`,
	))
	fake.PushScript(th.ScriptText("Workflow Output doc created."))

	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	h.SeedDeepSeek(t, "fake-test-key")

	ctx := th.CtxAs("test-user")
	wf, _, err := h.Workflow.Create(ctx, workflowapp.CreateInput{
		Ops: []workflowapp.Op{
			{Type: "set_meta", Raw: []byte(`{"op":"set_meta","name":"agent_writes_doc","description":"agent creates a doc"}`)},
			{Type: "add_node", Raw: []byte(`{"op":"add_node","node":{"id":"trig","type":"trigger","config":{"triggerType":"manual"}}}`)},
			{Type: "add_node", Raw: []byte(`{"op":"add_node","node":{"id":"agent1","type":"agent","config":{"prompt":"Create a doc named 'Workflow Output'.","maxTurns":3}}}`)},
			{Type: "add_edge", Raw: []byte(`{"op":"add_edge","edge":{"id":"e1","from":"trig","to":"agent1"}}`)},
		},
	})
	if err != nil {
		t.Fatalf("Create workflow: %v", err)
	}

	var trigResp struct {
		Data struct {
			RunID string `json:"runId"`
		} `json:"data"`
	}
	if status := th.DoRequest(t, h, "POST", "/api/v1/workflows/"+wf.ID+":trigger",
		map[string]any{}, &trigResp); status != 201 {
		t.Fatalf("trigger: %d", status)
	}
	runID := trigResp.Data.RunID

	deadline := time.Now().Add(15 * time.Second)
	var final *flowrundomain.FlowRun
	for time.Now().Before(deadline) {
		run, _ := h.FlowRunRepo.Get(ctx, runID)
		if run != nil && (run.Status == flowrundomain.StatusCompleted || run.Status == flowrundomain.StatusFailed) {
			final = run
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if final == nil {
		t.Fatalf("flowrun did not terminate within 15s")
	}
	if final.Status != flowrundomain.StatusCompleted {
		t.Fatalf("expected completed, got %q: %+v", final.Status, final)
	}

	docs, err := h.Document.ListAll(ctx)
	if err != nil {
		t.Fatalf("ListAll: %v", err)
	}
	if len(docs) != 1 {
		t.Fatalf("expected 1 doc; got %d (the agent should have created via create_document tool)", len(docs))
	}
	if docs[0].Name != "Workflow Output" {
		t.Errorf("doc name = %q, want %q", docs[0].Name, "Workflow Output")
	}
}

// TestWorkflow_LLMNode_AttachedDocsInPrompt_E2E — workflow `llm` node with
// AttachedDocuments; verify fake LLM sees the document content in its prompt.
//
// TestWorkflow_LLMNode_AttachedDocsInPrompt_E2E —— `llm` 节点挂 doc,
// 验证 fake LLM 收到的 prompt 含 doc 内容。
func TestWorkflow_LLMNode_AttachedDocsInPrompt_E2E(t *testing.T) {
	fake := th.NewFakeLLMServer(t)
	fake.PushScript(th.ScriptText("ok-acknowledged-llm-node"))

	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	h.SeedDeepSeek(t, "fake-test-key")

	ctx := th.CtxAs("test-user")
	doc, err := h.Document.Create(ctx, documentapp.CreateInput{
		Name:        "Refspec",
		Description: "API ref",
		Content:     "## Spec body — uniqueMARKER123 — endpoints here",
	})
	if err != nil {
		t.Fatalf("seed doc: %v", err)
	}

	// Build raw ops with the attached doc id substituted in.
	//
	// 在 ops 模板里注入实际 doc id。
	addNode := []byte(`{"op":"add_node","node":{"id":"l1","type":"llm","config":{"prompt":"summarise","attachedDocuments":[{"documentId":"` + doc.ID + `"}]}}}`)
	wf, _, err := h.Workflow.Create(ctx, workflowapp.CreateInput{
		Ops: []workflowapp.Op{
			{Type: "set_meta", Raw: []byte(`{"op":"set_meta","name":"llm_attach_doc","description":"llm reads doc"}`)},
			{Type: "add_node", Raw: []byte(`{"op":"add_node","node":{"id":"trig","type":"trigger","config":{"triggerType":"manual"}}}`)},
			{Type: "add_node", Raw: addNode},
			{Type: "add_edge", Raw: []byte(`{"op":"add_edge","edge":{"id":"e1","from":"trig","to":"l1"}}`)},
		},
	})
	if err != nil {
		t.Fatalf("Create workflow: %v", err)
	}

	var trigResp struct {
		Data struct {
			RunID string `json:"runId"`
		} `json:"data"`
	}
	if status := th.DoRequest(t, h, "POST", "/api/v1/workflows/"+wf.ID+":trigger",
		map[string]any{}, &trigResp); status != 201 {
		t.Fatalf("trigger: %d", status)
	}
	runID := trigResp.Data.RunID

	deadline := time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) {
		run, _ := h.FlowRunRepo.Get(ctx, runID)
		if run != nil && (run.Status == flowrundomain.StatusCompleted || run.Status == flowrundomain.StatusFailed) {
			if run.Status != flowrundomain.StatusCompleted {
				t.Fatalf("run failed: %+v", run)
			}
			break
		}
		time.Sleep(20 * time.Millisecond)
	}

	// Inspect fake LLM's last user message — should contain the doc body.
	//
	// 检查 fake LLM 最近一次的 user 消息——应含 doc 正文。
	var userMsg string
	for _, m := range fake.LastMessages() {
		if m.Role == "user" {
			userMsg = m.Content
		}
	}
	if !strings.Contains(userMsg, "uniqueMARKER123") {
		t.Errorf("fake LLM user message missing doc body marker:\n%s", userMsg)
	}
	if !strings.Contains(userMsg, "<documents>") {
		t.Errorf("fake LLM user message missing <documents> wrapper:\n%s", userMsg)
	}
}

// TestWorkflow_LLM_AttachedDocMissing_ValidationRejects — capability check
// catches stale doc reference at workflow validate time.
//
// TestWorkflow_LLM_AttachedDocMissing_ValidationRejects —— validate 期
// 抓未存在的 doc 引用。
func TestWorkflow_LLM_AttachedDocMissing_ValidationRejects(t *testing.T) {
	h := th.New(t)
	ctx := th.CtxAs("test-user")

	_, _, err := h.Workflow.Create(ctx, workflowapp.CreateInput{
		Ops: []workflowapp.Op{
			{Type: "set_meta", Raw: []byte(`{"op":"set_meta","name":"llm_missing_doc","description":"x"}`)},
			{Type: "add_node", Raw: []byte(`{"op":"add_node","node":{"id":"trig","type":"trigger","config":{"triggerType":"manual"}}}`)},
			{Type: "add_node", Raw: []byte(`{"op":"add_node","node":{"id":"l1","type":"llm","config":{"prompt":"x","attachedDocuments":[{"documentId":"doc_does_not_exist"}]}}}`)},
			{Type: "add_edge", Raw: []byte(`{"op":"add_edge","edge":{"id":"e1","from":"trig","to":"l1"}}`)},
		},
	})
	if err == nil {
		t.Fatal("expected validation error for missing doc reference")
	}
	if !strings.Contains(err.Error(), "doc_does_not_exist") {
		t.Errorf("error should mention the missing id: %v", err)
	}
	_ = context.Background()
}
