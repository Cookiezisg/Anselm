//go:build pipeline

// Package agent_test runs end-to-end pipeline tests for the Agent domain (quadrinity 4th member).
// Mirrors backend/test/api/function — same harness, same envelope/errcode assertion style.
//
// Package agent_test 跑 Agent 域端到端 pipeline 测试（quadrinity 第四元）。
// 镜像 backend/test/api/function —— 同 harness、同 envelope/errcode 断言风格。
package agent_test

import (
	"strings"
	"testing"
	"time"

	th "github.com/sunweilin/forgify/backend/test/harness"
)

// agentCreateBody is the minimal valid Create payload (name + prompt are the only required fields).
//
// agentCreateBody 是最小合法 Create 载荷（只有 name + prompt 必填）。
func agentCreateBody(name, prompt string) map[string]any {
	return map[string]any{"name": name, "prompt": prompt}
}

// createAgent POSTs /api/v1/agents and returns the new agent id; fatals on non-201.
//
// createAgent POST /api/v1/agents 返新 agent id；非 201 直接 fatal。
func createAgent(t *testing.T, h *th.Harness, body map[string]any) string {
	t.Helper()
	var resp struct {
		Data struct {
			ID            string `json:"id"`
			ActiveVersion struct {
				ID      string `json:"id"`
				Version *int   `json:"version"`
			} `json:"activeVersion"`
		} `json:"data"`
	}
	if status := th.DoRequest(t, h, "POST", "/api/v1/agents", body, &resp); status != 201 {
		t.Fatalf("create agent status=%d, want 201", status)
	}
	if resp.Data.ID == "" || !strings.HasPrefix(resp.Data.ID, "ag_") {
		t.Fatalf("bad agent id: %q", resp.Data.ID)
	}
	return resp.Data.ID
}

// covers: POST /api/v1/agents (happy)
// covers: GET /api/v1/agents/{id}
// covers: GET /api/v1/agents (list)
// covers: PATCH /api/v1/agents/{id} (UpdateMeta — name/desc/tags, no version bump)
// covers: DELETE /api/v1/agents/{id}
// covers: GET /api/v1/agents/{id} (not_found_404)
// covers: errcode:AGENT_NAME_DUPLICATE
// covers: errcode:AGENT_NOT_FOUND
func TestAgent_HTTP_CRUDLifecycle(t *testing.T) {
	h := th.New(t)

	// Create — response embeds an auto-accepted activeVersion (v1).
	var createResp struct {
		Data struct {
			ID            string   `json:"id"`
			Name          string   `json:"name"`
			Tags          []string `json:"tags"`
			ActiveVersion struct {
				ID      string `json:"id"`
				Version *int   `json:"version"`
				Status  string `json:"status"`
				Prompt  string `json:"prompt"`
			} `json:"activeVersion"`
		} `json:"data"`
	}
	status := th.DoRequest(t, h, "POST", "/api/v1/agents",
		agentCreateBody("classifier", "Classify the input sentiment."), &createResp)
	if status != 201 {
		t.Fatalf("POST status=%d, want 201", status)
	}
	agID := createResp.Data.ID
	if agID == "" || !strings.HasPrefix(agID, "ag_") {
		t.Fatalf("bad agent id: %q", agID)
	}
	if createResp.Data.ActiveVersion.ID == "" {
		t.Fatal("create did not embed activeVersion")
	}
	if v := createResp.Data.ActiveVersion.Version; v == nil || *v != 1 {
		t.Errorf("activeVersion.version = %v, want 1", v)
	}
	if createResp.Data.ActiveVersion.Status != "accepted" {
		t.Errorf("activeVersion.status = %q, want accepted", createResp.Data.ActiveVersion.Status)
	}

	// Get — returns the agent with its activeVersion attached.
	var getResp struct {
		Data struct {
			Name          string `json:"name"`
			ActiveVersion struct {
				Prompt string `json:"prompt"`
			} `json:"activeVersion"`
		} `json:"data"`
	}
	resp := h.GetJSON("/api/v1/agents/"+agID, &getResp)
	_ = resp.Body.Close()
	if getResp.Data.Name != "classifier" {
		t.Errorf("GET name=%q, want classifier", getResp.Data.Name)
	}
	if getResp.Data.ActiveVersion.Prompt != "Classify the input sentiment." {
		t.Errorf("GET activeVersion.prompt=%q, want the seeded prompt", getResp.Data.ActiveVersion.Prompt)
	}

	// Duplicate name → 409 AGENT_NAME_DUPLICATE.
	var dupErr th.ErrEnvelope
	dupStatus := th.DoRequest(t, h, "POST", "/api/v1/agents",
		agentCreateBody("classifier", "another prompt"), &dupErr)
	th.AssertErrCode(t, dupStatus, 409, dupErr, "AGENT_NAME_DUPLICATE")

	// List — the created agent shows up. Paged envelope (mirrors function): {"data":[...],"hasMore":...}.
	var listResp struct {
		Data    []map[string]any `json:"data"`
		HasMore bool             `json:"hasMore"`
	}
	lr := h.GetJSON("/api/v1/agents?limit=10", &listResp)
	_ = lr.Body.Close()
	if len(listResp.Data) != 1 {
		t.Errorf("List returned %d, want 1", len(listResp.Data))
	}

	// Delete → 204, then GET → 404 AGENT_NOT_FOUND.
	delResp := h.Delete("/api/v1/agents/" + agID)
	_ = delResp.Body.Close()
	if delResp.StatusCode != 204 {
		t.Errorf("DELETE status=%d, want 204", delResp.StatusCode)
	}
	var notFound th.ErrEnvelope
	gone := th.DoRequest(t, h, "GET", "/api/v1/agents/"+agID, nil, &notFound)
	th.AssertErrCode(t, gone, 404, notFound, "AGENT_NOT_FOUND")
}

// covers: PATCH /api/v1/agents/{id} (UpdateMeta)
// Verifies metadata patches (name/description/tags) do NOT bump the version and keep activeVersion fixed.
//
// 验证改 name/description/tags 不动版本号、active version 不变。
func TestAgent_HTTP_UpdateMetaNoVersionBump(t *testing.T) {
	h := th.New(t)
	agID := createAgent(t, h, agentCreateBody("router", "Route the request."))

	// Snapshot the active version id + number before the patch.
	var before struct {
		Data struct {
			ActiveVersionID string `json:"activeVersionId"`
			ActiveVersion   struct {
				Version *int `json:"version"`
			} `json:"activeVersion"`
		} `json:"data"`
	}
	br := h.GetJSON("/api/v1/agents/"+agID, &before)
	_ = br.Body.Close()
	beforeVID := before.Data.ActiveVersionID
	if beforeVID == "" {
		t.Fatal("precondition: agent has no active version id")
	}

	newName := "router-v2"
	newDesc := "Routes inbound requests to the right worker."
	patch := map[string]any{
		"name":        newName,
		"description": newDesc,
		"tags":        []string{"prod", "routing"},
	}
	pr := h.PatchJSON("/api/v1/agents/"+agID, patch, nil)
	_ = pr.Body.Close()
	if pr.StatusCode != 200 {
		t.Fatalf("PATCH status=%d, want 200", pr.StatusCode)
	}

	var after struct {
		Data struct {
			Name            string   `json:"name"`
			Description     string   `json:"description"`
			Tags            []string `json:"tags"`
			ActiveVersionID string   `json:"activeVersionId"`
			ActiveVersion   struct {
				Version *int `json:"version"`
			} `json:"activeVersion"`
		} `json:"data"`
	}
	ar := h.GetJSON("/api/v1/agents/"+agID, &after)
	_ = ar.Body.Close()
	if after.Data.Name != newName {
		t.Errorf("name=%q, want %q", after.Data.Name, newName)
	}
	if after.Data.Description != newDesc {
		t.Errorf("description=%q, want %q", after.Data.Description, newDesc)
	}
	if len(after.Data.Tags) != 2 || after.Data.Tags[0] != "prod" {
		t.Errorf("tags=%v, want [prod routing]", after.Data.Tags)
	}
	if after.Data.ActiveVersionID != beforeVID {
		t.Errorf("active version id changed: before=%q after=%q (UpdateMeta must not bump version)",
			beforeVID, after.Data.ActiveVersionID)
	}
	if v := after.Data.ActiveVersion.Version; v == nil || *v != 1 {
		t.Errorf("active version number = %v, want still 1", v)
	}
}

// covers: POST /api/v1/agents/{id}:edit (→ pending)
// covers: GET /api/v1/agents/{id}/pending
// covers: POST /api/v1/agents/{id}/pending:accept
// covers: GET /api/v1/agents/{id}/versions (ListVersions)
// covers: POST /api/v1/agents/{id}:revert (targetVersion)
// Exercises the full forge lifecycle: edit creates a pending v2, accept promotes it, revert flips active back to v1.
//
// 全锻造生命周期：edit 建 pending v2 → accept 升 active → revert 切回 v1。
func TestAgent_HTTP_EditPendingAcceptRevert(t *testing.T) {
	h := th.New(t)
	agID := createAgent(t, h, agentCreateBody("editor", "v1 prompt"))

	// Edit → a pending version (no number yet).
	newPrompt := "v2 prompt"
	var editResp struct {
		Data struct {
			ID     string `json:"id"`
			Status string `json:"status"`
			Prompt string `json:"prompt"`
		} `json:"data"`
	}
	es := th.DoRequest(t, h, "POST", "/api/v1/agents/"+agID+":edit",
		map[string]any{"prompt": newPrompt, "changeReason": "tighten prompt"}, &editResp)
	if es != 200 {
		t.Fatalf("edit status=%d, want 200", es)
	}
	if editResp.Data.Status != "pending" {
		t.Errorf("edited version status=%q, want pending", editResp.Data.Status)
	}
	if editResp.Data.Prompt != newPrompt {
		t.Errorf("pending prompt=%q, want %q", editResp.Data.Prompt, newPrompt)
	}

	// GetPending reflects the same pending version.
	var pendResp struct {
		Data struct {
			ID     string `json:"id"`
			Status string `json:"status"`
		} `json:"data"`
	}
	pr := h.GetJSON("/api/v1/agents/"+agID+"/pending", &pendResp)
	_ = pr.Body.Close()
	if pendResp.Data.Status != "pending" {
		t.Errorf("GetPending status=%q, want pending", pendResp.Data.Status)
	}

	// Accept → pending becomes active v2.
	var acceptResp struct {
		Data struct {
			VersionID string `json:"versionId"`
			Accepted  bool   `json:"accepted"`
		} `json:"data"`
	}
	as := th.DoRequest(t, h, "POST", "/api/v1/agents/"+agID+"/pending:accept", nil, &acceptResp)
	if as != 200 {
		t.Fatalf("accept status=%d, want 200", as)
	}
	if !acceptResp.Data.Accepted {
		t.Errorf("accept returned accepted=false")
	}

	// After accept, active prompt is the v2 prompt and version number is 2.
	var afterAccept struct {
		Data struct {
			ActiveVersion struct {
				Version *int   `json:"version"`
				Prompt  string `json:"prompt"`
			} `json:"activeVersion"`
		} `json:"data"`
	}
	aa := h.GetJSON("/api/v1/agents/"+agID, &afterAccept)
	_ = aa.Body.Close()
	if v := afterAccept.Data.ActiveVersion.Version; v == nil || *v != 2 {
		t.Fatalf("active version after accept = %v, want 2", v)
	}
	if afterAccept.Data.ActiveVersion.Prompt != newPrompt {
		t.Errorf("active prompt after accept=%q, want %q", afterAccept.Data.ActiveVersion.Prompt, newPrompt)
	}

	// ListVersions returns both accepted versions (v1 + v2). Paged envelope: {"data":[...]}.
	var versionsResp struct {
		Data []struct {
			Version *int   `json:"version"`
			Status  string `json:"status"`
		} `json:"data"`
	}
	vr := h.GetJSON("/api/v1/agents/"+agID+"/versions", &versionsResp)
	_ = vr.Body.Close()
	accepted := 0
	for _, v := range versionsResp.Data {
		if v.Status == "accepted" {
			accepted++
		}
	}
	if accepted < 2 {
		t.Errorf("ListVersions accepted count=%d, want >=2", accepted)
	}

	// Revert to v1 → active version number flips back to 1, prompt is the v1 prompt.
	var revertResp struct {
		Data struct {
			Version *int   `json:"version"`
			Prompt  string `json:"prompt"`
		} `json:"data"`
	}
	rs := th.DoRequest(t, h, "POST", "/api/v1/agents/"+agID+":revert",
		map[string]any{"targetVersion": 1}, &revertResp)
	if rs != 200 {
		t.Fatalf("revert status=%d, want 200", rs)
	}
	if v := revertResp.Data.Version; v == nil || *v != 1 {
		t.Errorf("revert returned version=%v, want 1", v)
	}

	var afterRevert struct {
		Data struct {
			ActiveVersion struct {
				Version *int   `json:"version"`
				Prompt  string `json:"prompt"`
			} `json:"activeVersion"`
		} `json:"data"`
	}
	ar := h.GetJSON("/api/v1/agents/"+agID, &afterRevert)
	_ = ar.Body.Close()
	if v := afterRevert.Data.ActiveVersion.Version; v == nil || *v != 1 {
		t.Errorf("active version after revert=%v, want 1", v)
	}
	if afterRevert.Data.ActiveVersion.Prompt != "v1 prompt" {
		t.Errorf("active prompt after revert=%q, want v1 prompt", afterRevert.Data.ActiveVersion.Prompt)
	}
}

// covers: POST /api/v1/agents/{id}:edit
// covers: POST /api/v1/agents/{id}/pending:reject
// covers: GET /api/v1/agents/{id}/pending (not_found after reject)
// Reject discards the pending version and leaves active untouched.
//
// reject 丢弃 pending，active 不变。
func TestAgent_HTTP_RejectPending(t *testing.T) {
	h := th.New(t)
	agID := createAgent(t, h, agentCreateBody("rejecter", "v1 prompt"))

	es := th.DoRequest(t, h, "POST", "/api/v1/agents/"+agID+":edit",
		map[string]any{"prompt": "throwaway"}, nil)
	if es != 200 {
		t.Fatalf("edit status=%d, want 200", es)
	}

	rs := th.DoRequest(t, h, "POST", "/api/v1/agents/"+agID+"/pending:reject", nil, nil)
	if rs != 200 {
		t.Fatalf("reject status=%d, want 200", rs)
	}

	// Active stays at v1.
	var after struct {
		Data struct {
			ActiveVersion struct {
				Version *int   `json:"version"`
				Prompt  string `json:"prompt"`
			} `json:"activeVersion"`
		} `json:"data"`
	}
	ar := h.GetJSON("/api/v1/agents/"+agID, &after)
	_ = ar.Body.Close()
	if v := after.Data.ActiveVersion.Version; v == nil || *v != 1 {
		t.Errorf("active version after reject=%v, want 1", v)
	}
	if after.Data.ActiveVersion.Prompt != "v1 prompt" {
		t.Errorf("active prompt after reject=%q, want v1 prompt", after.Data.ActiveVersion.Prompt)
	}
}

// covers: GET /api/v1/agents/{id}/versions/{version} (by integer number)
// covers: GET /api/v1/agents/{id}/versions/{version} (by versionId)
// GetVersion must resolve both an integer version number and a raw version id (two handler branches).
//
// GetVersion 两条解析路径：数字版本号 与 原始 versionId。
func TestAgent_HTTP_GetVersionByNumberAndID(t *testing.T) {
	h := th.New(t)

	var createResp struct {
		Data struct {
			ID            string `json:"id"`
			ActiveVersion struct {
				ID string `json:"id"`
			} `json:"activeVersion"`
		} `json:"data"`
	}
	if status := th.DoRequest(t, h, "POST", "/api/v1/agents",
		agentCreateBody("versioned", "do the thing"), &createResp); status != 201 {
		t.Fatalf("create status=%d", status)
	}
	agID := createResp.Data.ID
	versionID := createResp.Data.ActiveVersion.ID
	if versionID == "" {
		t.Fatal("create did not return activeVersion.id")
	}

	// Path A: by integer number "1".
	var byNum struct {
		Data struct {
			ID     string `json:"id"`
			Prompt string `json:"prompt"`
		} `json:"data"`
	}
	an := h.GetJSON("/api/v1/agents/"+agID+"/versions/1", &byNum)
	_ = an.Body.Close()
	if byNum.Data.ID != versionID {
		t.Errorf("GetVersion by number id=%q, want %q", byNum.Data.ID, versionID)
	}
	if byNum.Data.Prompt != "do the thing" {
		t.Errorf("GetVersion by number prompt=%q", byNum.Data.Prompt)
	}

	// Path B: by raw versionId.
	var byID struct {
		Data struct {
			ID     string `json:"id"`
			Prompt string `json:"prompt"`
		} `json:"data"`
	}
	ai := h.GetJSON("/api/v1/agents/"+agID+"/versions/"+versionID, &byID)
	_ = ai.Body.Close()
	if byID.Data.ID != versionID {
		t.Errorf("GetVersion by id id=%q, want %q", byID.Data.ID, versionID)
	}
	if byID.Data.Prompt != "do the thing" {
		t.Errorf("GetVersion by id prompt=%q", byID.Data.Prompt)
	}
}

// covers: POST /api/v1/agents (outputSchema round-trips through storage)
// An enum outputSchema set at create must come back verbatim on GET.
//
// create 传 enum outputSchema，GET 原样取回。
func TestAgent_HTTP_OutputSchemaRoundTrip(t *testing.T) {
	h := th.New(t)

	body := map[string]any{
		"name":   "yesno",
		"prompt": "Answer yes or no.",
		"outputSchema": map[string]any{
			"kind":  "enum",
			"enums": []string{"yes", "no"},
		},
	}
	agID := createAgent(t, h, body)

	var getResp struct {
		Data struct {
			ActiveVersion struct {
				OutputSchema struct {
					Kind  string   `json:"kind"`
					Enums []string `json:"enums"`
				} `json:"outputSchema"`
			} `json:"activeVersion"`
		} `json:"data"`
	}
	gr := h.GetJSON("/api/v1/agents/"+agID, &getResp)
	_ = gr.Body.Close()
	os := getResp.Data.ActiveVersion.OutputSchema
	if os.Kind != "enum" {
		t.Errorf("outputSchema.kind=%q, want enum", os.Kind)
	}
	if len(os.Enums) != 2 || os.Enums[0] != "yes" || os.Enums[1] != "no" {
		t.Errorf("outputSchema.enums=%v, want [yes no]", os.Enums)
	}
}

// covers: POST /api/v1/agents (modelOverride validation, table-driven)
// covers: errcode:AGENT_INVALID_MODEL_OVERRIDE
//
// modelOverride 校验（表驱动）：
//   - 缺 apiKeyId 的 override 必须被拒 → 400 AGENT_INVALID_MODEL_OVERRIDE
//     (domain ErrInvalidModelOverride，镜像 workflow 节点 override 校验)。
//   - 完整 {apiKeyId,modelId} 的 override 必须建成（apiKeyId 指向已 seed 的 key）。
func TestAgent_HTTP_ModelOverrideValidation(t *testing.T) {
	h := th.New(t)
	// Seed a real apikey so the "complete override" case resolves to an existing key id.
	keyID := h.SeedDeepSeek(t, "fake-key")

	t.Run("incomplete_override_rejected", func(t *testing.T) {
		body := map[string]any{
			"name":   "bad_override",
			"prompt": "x",
			"modelOverride": map[string]any{
				"apiKeyId": "", // missing → invalid (a set override needs both ids)
				"modelId":  "deepseek-chat",
			},
		}
		var errResp th.ErrEnvelope
		status := th.DoRequest(t, h, "POST", "/api/v1/agents", body, &errResp)
		th.AssertErrCode(t, status, 400, errResp, "AGENT_INVALID_MODEL_OVERRIDE")
	})

	t.Run("complete_override_accepted", func(t *testing.T) {
		body := map[string]any{
			"name":   "good_override",
			"prompt": "x",
			"modelOverride": map[string]any{
				"apiKeyId": keyID,
				"modelId":  "deepseek-chat",
			},
		}
		var resp struct {
			Data struct {
				ID            string `json:"id"`
				ActiveVersion struct {
					ModelOverride struct {
						APIKeyID string `json:"apiKeyId"`
						ModelID  string `json:"modelId"`
					} `json:"modelOverride"`
				} `json:"activeVersion"`
			} `json:"data"`
		}
		status := th.DoRequest(t, h, "POST", "/api/v1/agents", body, &resp)
		if status != 201 {
			t.Fatalf("complete override status=%d, want 201", status)
		}
		if resp.Data.ActiveVersion.ModelOverride.APIKeyID != keyID {
			t.Errorf("stored modelOverride.apiKeyId=%q, want %q",
				resp.Data.ActiveVersion.ModelOverride.APIKeyID, keyID)
		}
		if resp.Data.ActiveVersion.ModelOverride.ModelID != "deepseek-chat" {
			t.Errorf("stored modelOverride.modelId=%q, want deepseek-chat",
				resp.Data.ActiveVersion.ModelOverride.ModelID)
		}
	})
}

// covers: POST /api/v1/agents (tools validation — ag_ ref forbidden)
// Agents cannot list another agent as a tool (员工不调员工) → 400 AGENT_TOOLS_AGENT_REF_FORBIDDEN.
//
// agent 不能把另一个 agent 当工具 → 400。
func TestAgent_HTTP_ToolsAgentRefForbidden(t *testing.T) {
	h := th.New(t)
	body := map[string]any{
		"name":   "recursive",
		"prompt": "x",
		"tools": []map[string]any{
			{"ref": "ag_deadbeefdeadbeef", "name": "another agent"},
		},
	}
	var errResp th.ErrEnvelope
	status := th.DoRequest(t, h, "POST", "/api/v1/agents", body, &errResp)
	th.AssertErrCode(t, status, 400, errResp, "AGENT_TOOLS_AGENT_REF_FORBIDDEN")
}

// covers: POST /api/v1/agents/{id}:invoke (fake_llm; default active version)
// covers: GET /api/v1/agents/{id}/executions (the invoke is logged)
// covers: GET /api/v1/agent-executions/{execId} (detail + hints)
// One real ReAct run against the fake LLM: a plain-text reply terminates the loop; the run is
// recorded as one AgentExecution discoverable via both the list and detail endpoints.
//
// 一次真实 ReAct（fake LLM）：纯文本回复终止 loop；执行落表，列表 + 详情两端都能查到。
func TestAgent_HTTP_InvokeAndExecutionLog(t *testing.T) {
	fake := th.NewFakeLLMServer(t)
	// Plain-text answer → finish_reason=stop → loop ends with LastMessage="positive".
	fake.PushScript(th.ScriptText("positive"))
	// Default covers any extra resolve/probe call without exhausting the queue.
	fake.PushDefault(th.ScriptText("positive"))

	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	h.SeedDeepSeek(t, "fake-key")

	agID := createAgent(t, h, agentCreateBody("sentiment", "Classify sentiment of the input."))

	// Invoke against the active version (empty version → active).
	var invokeResp struct {
		Data struct {
			ExecutionID string `json:"executionId"`
			OK          bool   `json:"ok"`
			Output      any    `json:"output"`
			Status      string `json:"status"`
			Steps       int    `json:"steps"`
		} `json:"data"`
	}
	is := th.DoRequest(t, h, "POST", "/api/v1/agents/"+agID+":invoke",
		map[string]any{"input": map[string]any{"text": "I love this"}}, &invokeResp)
	if is != 200 {
		t.Fatalf("invoke status=%d, want 200", is)
	}
	if !invokeResp.Data.OK {
		t.Fatalf("invoke ok=false: %+v", invokeResp.Data)
	}
	if invokeResp.Data.ExecutionID == "" || !strings.HasPrefix(invokeResp.Data.ExecutionID, "agx_") {
		t.Errorf("bad executionId: %q", invokeResp.Data.ExecutionID)
	}
	if got, _ := invokeResp.Data.Output.(string); got != "positive" {
		t.Errorf("invoke output=%v, want %q", invokeResp.Data.Output, "positive")
	}
	execID := invokeResp.Data.ExecutionID

	// ListExecutions — handler returns SearchExecutionsResult (mirrors function): {"data":{"executions":[...],"hasMore":...,"aggregates":{...}}}.
	var execList struct {
		Data struct {
			Executions []map[string]any `json:"executions"`
			HasMore    bool             `json:"hasMore"`
			Aggregates struct {
				OKCount int `json:"okCount"`
			} `json:"aggregates"`
		} `json:"data"`
	}
	el := h.GetJSON("/api/v1/agents/"+agID+"/executions", &execList)
	_ = el.Body.Close()
	if len(execList.Data.Executions) != 1 {
		t.Fatalf("ListExecutions returned %d rows, want 1", len(execList.Data.Executions))
	}
	if execList.Data.Aggregates.OKCount != 1 {
		t.Errorf("aggregates.okCount=%d, want 1", execList.Data.Aggregates.OKCount)
	}
	if gotID, _ := execList.Data.Executions[0]["id"].(string); gotID != execID {
		t.Errorf("listed execution id=%q, want %q", gotID, execID)
	}

	// GetExecution — returns the row plus machine-computed hints.
	var execDetail struct {
		Data struct {
			ID      string `json:"id"`
			AgentID string `json:"agentId"`
			Status  string `json:"status"`
			Output  any    `json:"output"`
			Hints   struct {
				OutputEmpty bool `json:"outputEmpty"`
			} `json:"hints"`
		} `json:"data"`
	}
	gd := h.GetJSON("/api/v1/agent-executions/"+execID, &execDetail)
	_ = gd.Body.Close()
	if execDetail.Data.ID != execID {
		t.Errorf("GetExecution id=%q, want %q", execDetail.Data.ID, execID)
	}
	if execDetail.Data.AgentID != agID {
		t.Errorf("GetExecution agentId=%q, want %q", execDetail.Data.AgentID, agID)
	}
	if execDetail.Data.Status != "ok" {
		t.Errorf("GetExecution status=%q, want ok", execDetail.Data.Status)
	}
	if execDetail.Data.Hints.OutputEmpty {
		t.Errorf("hints.outputEmpty=true, want false (output was %q)", execDetail.Data.Output)
	}
}

// covers: GET /api/v1/agent-executions/{execId} (not_found_404)
// covers: errcode:AGENT_EXECUTION_NOT_FOUND
func TestAgent_HTTP_GetExecutionNotFound(t *testing.T) {
	h := th.New(t)
	var errResp th.ErrEnvelope
	status := th.DoRequest(t, h, "GET", "/api/v1/agent-executions/agx_deadbeefdeadbeef", nil, &errResp)
	th.AssertErrCode(t, status, 404, errResp, "AGENT_EXECUTION_NOT_FOUND")
}

// covers: POST /api/v1/agents/{id}:invoke (modelOverride path resolves through fake LLM)
// Invoking a version whose modelOverride points at the seeded fake-LLM key must run successfully —
// proves ResolveAgentWithOverride honors the per-version override (not just the default agent scenario).
//
// 跑一个 modelOverride 指向 fake-LLM key 的版本 → 成功，证明 override 生效（非仅默认 agent scenario）。
func TestAgent_HTTP_InvokeWithModelOverride(t *testing.T) {
	fake := th.NewFakeLLMServer(t)
	fake.PushDefault(th.ScriptText("ok"))

	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	keyID := h.SeedDeepSeek(t, "fake-key")

	body := map[string]any{
		"name":   "override_runner",
		"prompt": "say ok",
		"modelOverride": map[string]any{
			"apiKeyId": keyID,
			"modelId":  "deepseek-chat",
		},
	}
	agID := createAgent(t, h, body)

	var invokeResp struct {
		Data struct {
			OK     bool `json:"ok"`
			Output any  `json:"output"`
		} `json:"data"`
	}
	is := th.DoRequest(t, h, "POST", "/api/v1/agents/"+agID+":invoke",
		map[string]any{"input": map[string]any{}}, &invokeResp)
	if is != 200 {
		t.Fatalf("invoke status=%d, want 200", is)
	}
	if !invokeResp.Data.OK {
		t.Errorf("invoke ok=false: %+v", invokeResp.Data)
	}
}

// covers: POST /api/v1/agents/{id}:iterate (spawns an AI editing conversation)
//
// :iterate spawns a user-visible conversation and returns its conversationId; chat.Send is fired
// async so the HTTP response does not block on the LLM. The harness DOES wire the askai Spawner
// (router.go SetSpawner + harness AskAISpawner), so the happy path is 200 with a conversationId —
// NOT the 503 ASKAI_NOT_AVAILABLE that would occur if the spawner were unwired. A fake LLM with a
// default script is seeded so the detached loop has something to consume; we assert only the
// synchronous contract (status + conversationId), since the async reasoning lands on eventlog.
//
// :iterate 起一个用户可见对话返 conversationId；chat.Send 异步发，HTTP 不阻塞 LLM。harness 接了
// askai Spawner，故 happy path 是 200 + conversationId（非 spawner 未接时的 503）。配 fake LLM
// 默认脚本喂异步 loop；只断言同步契约（状态 + conversationId），异步推理落 eventlog 不在此校。
func TestAgent_HTTP_Iterate(t *testing.T) {
	fake := th.NewFakeLLMServer(t)
	fake.PushDefault(th.ScriptText("Acknowledged. I'll tighten the prompt."))

	h := th.New(t, th.WithFakeLLMBaseURL(fake.URL()))
	h.SeedDeepSeek(t, "fake-key")

	agID := createAgent(t, h, agentCreateBody("iterating", "v1 prompt"))

	var iterResp struct {
		Data struct {
			ConversationID string `json:"conversationId"`
			UserMessageID  string `json:"userMessageId"`
		} `json:"data"`
	}
	status := th.DoRequest(t, h, "POST", "/api/v1/agents/"+agID+":iterate",
		map[string]any{"prompt": "Make the prompt stricter about output format."}, &iterResp)
	if status != 200 {
		t.Fatalf("iterate status=%d, want 200", status)
	}
	if iterResp.Data.ConversationID == "" {
		t.Errorf("iterate returned empty conversationId")
	}

	// Give the detached chat.Send loop a moment to drain so it doesn't race teardown
	// (the loop runs on a background goroutine; we don't assert on its output here).
	time.Sleep(200 * time.Millisecond)
}
