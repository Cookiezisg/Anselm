//go:build pipeline

// http_test.go — end-to-end HTTP contract tests for the
// 22 /api/v1/forges/* endpoints. All tests require FORGIFY_DEV_RESOURCES
// and will t.Skip when the sandbox is not bootstrapped.
//
// http_test.go — /api/v1/forges/* 22 端点的 HTTP 契约端到端测试。
// 全部需要 FORGIFY_DEV_RESOURCES，沙箱未 Bootstrap 时 t.Skip。
package forge

import (
	"encoding/json"
	"fmt"
	"net/http"
	"testing"

	th "github.com/sunweilin/forgify/backend/test/harness"
)

// ── 1. Create + List round-trip ──────────────────────────────────────────────

func TestForge_CreateAndList_Roundtrip(t *testing.T) {
	h := th.New(t)
	th.RequireForgeResources(t, h)

	var createResp struct {
		Data struct {
			ID           string `json:"id"`
			Name         string `json:"name"`
			VersionCount int    `json:"versionCount"`
		} `json:"data"`
	}
	if s := th.PostForge(t, h, "hello_forge", th.SimpleForgeCode, &createResp); s != http.StatusCreated {
		t.Fatalf("POST /forges status=%d, want 201", s)
	}
	if createResp.Data.ID == "" {
		t.Fatal("create: empty id")
	}
	if createResp.Data.Name != "hello_forge" {
		t.Errorf("name=%q, want hello_forge", createResp.Data.Name)
	}
	if createResp.Data.VersionCount != 1 {
		t.Errorf("versionCount=%d, want 1", createResp.Data.VersionCount)
	}
	forgeID := createResp.Data.ID

	var listResp struct {
		Data    []struct{ ID string `json:"id"` } `json:"data"`
		HasMore *bool                              `json:"hasMore"`
	}
	h.GetJSON("/api/v1/forges", &listResp)
	if len(listResp.Data) != 1 {
		t.Fatalf("list: got %d items, want 1", len(listResp.Data))
	}
	if listResp.Data[0].ID != forgeID {
		t.Errorf("list[0].id=%q, want %q", listResp.Data[0].ID, forgeID)
	}
}

// ── 2. GET /forges/{id} contains envStatus ────────────────────────────────────

func TestForge_Get_ContainsActiveVersionID(t *testing.T) {
	h := th.New(t)
	th.RequireForgeResources(t, h)

	var createResp struct {
		Data struct{ ID string `json:"id"` } `json:"data"`
	}
	th.PostForge(t, h, "get_test", th.SimpleForgeCode, &createResp)
	forgeID := createResp.Data.ID

	var getResp struct {
		Data struct {
			ID              string `json:"id"`
			ActiveVersionID string `json:"activeVersionId"`
			EnvStatus       string `json:"envStatus"`
		} `json:"data"`
	}
	h.GetJSON("/api/v1/forges/"+forgeID, &getResp)
	if getResp.Data.ActiveVersionID == "" {
		t.Error("activeVersionId is empty; forge should have v1 after create")
	}
	if getResp.Data.EnvStatus == "" {
		t.Error("envStatus is empty; should be set after sync attempt")
	}
}

// ── 3. PATCH updates metadata ─────────────────────────────────────────────────

func TestForge_Update_Metadata(t *testing.T) {
	h := th.New(t)
	th.RequireForgeResources(t, h)

	var createResp struct {
		Data struct{ ID string `json:"id"` } `json:"data"`
	}
	th.PostForge(t, h, "patch_test", th.SimpleForgeCode, &createResp)
	forgeID := createResp.Data.ID

	newName := "patch_test_renamed"
	var patchResp struct {
		Data struct {
			Name        string `json:"name"`
			Description string `json:"description"`
		} `json:"data"`
	}
	h.PatchJSON("/api/v1/forges/"+forgeID, map[string]any{
		"name":        newName,
		"description": "a nice tool",
	}, &patchResp)
	if patchResp.Data.Name != newName {
		t.Errorf("name=%q, want %q", patchResp.Data.Name, newName)
	}
	if patchResp.Data.Description != "a nice tool" {
		t.Errorf("description=%q, want 'a nice tool'", patchResp.Data.Description)
	}
}

// ── 4. DELETE soft-deletes; list no longer shows the forge ────────────────────

func TestForge_Delete_SoftDelete_HidesFromList(t *testing.T) {
	h := th.New(t)
	th.RequireForgeResources(t, h)

	var createResp struct {
		Data struct{ ID string `json:"id"` } `json:"data"`
	}
	th.PostForge(t, h, "delete_test", th.SimpleForgeCode, &createResp)
	forgeID := createResp.Data.ID

	h.Delete("/api/v1/forges/" + forgeID)

	var listResp struct {
		Data []struct{ ID string `json:"id"` } `json:"data"`
	}
	h.GetJSON("/api/v1/forges", &listResp)
	for _, item := range listResp.Data {
		if item.ID == forgeID {
			t.Errorf("deleted forge %q still appears in list", forgeID)
		}
	}
}

// ── 5. Duplicate name → 409 TOOL_NAME_DUPLICATE ───────────────────────────────

func TestForge_DuplicateName_Returns409(t *testing.T) {
	h := th.New(t)
	th.RequireForgeResources(t, h)

	th.PostForge(t, h, "dup_name", th.SimpleForgeCode, nil)

	var errResp th.ErrEnvelope
	status := th.PostForge(t, h, "dup_name", th.SimpleForgeCode, &errResp)
	if status != http.StatusConflict {
		t.Errorf("status=%d, want 409", status)
	}
	if errResp.Error.Code != "TOOL_NAME_DUPLICATE" {
		t.Errorf("error.code=%q, want TOOL_NAME_DUPLICATE", errResp.Error.Code)
	}
}

// ── 6. GET non-existent → 404 ─────────────────────────────────────────────────

func TestForge_Get_NotFound_Returns404(t *testing.T) {
	h := th.New(t)
	th.RequireForgeResources(t, h)

	var errResp th.ErrEnvelope
	status := th.DoRequest(t, h, "GET", "/api/v1/forges/f_doesnotexist", nil, &errResp)
	if status != http.StatusNotFound {
		t.Errorf("status=%d, want 404", status)
	}
	if errResp.Error.Code != "TOOL_NOT_FOUND" {
		t.Errorf("error.code=%q, want TOOL_NOT_FOUND", errResp.Error.Code)
	}
}

// ── 7. ListVersions after create shows v1 ─────────────────────────────────────

func TestForge_ListVersions_ShowsV1(t *testing.T) {
	h := th.New(t)
	th.RequireForgeResources(t, h)

	var createResp struct {
		Data struct{ ID string `json:"id"` } `json:"data"`
	}
	th.PostForge(t, h, "versions_test", th.SimpleForgeCode, &createResp)
	forgeID := createResp.Data.ID

	var versionsResp struct {
		Data []struct {
			Version *int   `json:"version"`
			Status  string `json:"status"`
		} `json:"data"`
	}
	h.GetJSON("/api/v1/forges/"+forgeID+"/versions", &versionsResp)
	if len(versionsResp.Data) != 1 {
		t.Fatalf("versions count=%d, want 1", len(versionsResp.Data))
	}
	if versionsResp.Data[0].Version == nil || *versionsResp.Data[0].Version != 1 {
		t.Errorf("version=%v, want 1", versionsResp.Data[0].Version)
	}
	if versionsResp.Data[0].Status != "accepted" {
		t.Errorf("status=%q, want accepted", versionsResp.Data[0].Status)
	}
}

// ── 8. TestCase CRUD ──────────────────────────────────────────────────────────

func TestForge_TestCase_CRUD(t *testing.T) {
	h := th.New(t)
	th.RequireForgeResources(t, h)

	var createResp struct {
		Data struct{ ID string `json:"id"` } `json:"data"`
	}
	th.PostForge(t, h, "tc_test", th.SimpleForgeCode, &createResp)
	forgeID := createResp.Data.ID

	// Create test case.
	// 创建测试用例。
	var tcResp struct {
		Data struct {
			ID   string `json:"id"`
			Name string `json:"name"`
		} `json:"data"`
	}
	h.PostJSON("/api/v1/forges/"+forgeID+"/test-cases", map[string]any{
		"name":           "basic greeting",
		"inputData":      `{"name":"Alice"}`,
		"expectedOutput": `"Hello, Alice!"`,
	}, &tcResp)
	if tcResp.Data.ID == "" {
		t.Fatal("create test case: empty id")
	}
	tcID := tcResp.Data.ID

	// List — should contain the test case.
	var listResp struct {
		Data []struct{ ID string `json:"id"` } `json:"data"`
	}
	h.GetJSON("/api/v1/forges/"+forgeID+"/test-cases", &listResp)
	if len(listResp.Data) != 1 {
		t.Fatalf("test cases count=%d, want 1", len(listResp.Data))
	}
	if listResp.Data[0].ID != tcID {
		t.Errorf("list[0].id=%q, want %q", listResp.Data[0].ID, tcID)
	}

	// Delete.
	h.Delete("/api/v1/forges/" + forgeID + "/test-cases/" + tcID)

	// List again — empty.
	h.GetJSON("/api/v1/forges/"+forgeID+"/test-cases", &listResp)
	if len(listResp.Data) != 0 {
		t.Errorf("test cases after delete=%d, want 0", len(listResp.Data))
	}
}

// ── 9. ListExecutions empty on new forge ──────────────────────────────────────

func TestForge_ListExecutions_EmptyOnNew(t *testing.T) {
	h := th.New(t)
	th.RequireForgeResources(t, h)

	var createResp struct {
		Data struct{ ID string `json:"id"` } `json:"data"`
	}
	th.PostForge(t, h, "exec_test", th.SimpleForgeCode, &createResp)
	forgeID := createResp.Data.ID

	var listResp struct {
		Data    []json.RawMessage `json:"data"`
		HasMore *bool             `json:"hasMore"`
	}
	h.GetJSON("/api/v1/forges/"+forgeID+"/executions", &listResp)
	if len(listResp.Data) != 0 {
		t.Errorf("executions count=%d, want 0 for new forge", len(listResp.Data))
	}
}

// ── 10. Cursor pagination ─────────────────────────────────────────────────────

func TestForge_CursorPagination_ExhaustPages(t *testing.T) {
	h := th.New(t)
	th.RequireForgeResources(t, h)

	// Seed 5 forges with unique names; limit=2 → pages: 2 + 2 + 1.
	// 插入 5 个 forge；limit=2 → 预期 3 页。
	for i := range 5 {
		th.PostForge(t, h, fmt.Sprintf("page_forge_%02d", i), th.SimpleForgeCode, nil)
	}

	type pagedResp struct {
		Data []struct {
			ID string `json:"id"`
		} `json:"data"`
		NextCursor *string `json:"nextCursor"`
		HasMore    *bool   `json:"hasMore"`
	}

	var cursor string
	total := 0
	for page := 0; ; page++ {
		url := "/api/v1/forges?limit=2"
		if cursor != "" {
			url += "&cursor=" + cursor
		}
		var resp pagedResp
		h.GetJSON(url, &resp)
		if len(resp.Data) == 0 {
			t.Fatalf("page %d: empty data (seen %d so far)", page, total)
		}
		total += len(resp.Data)
		if resp.HasMore != nil && *resp.HasMore {
			if resp.NextCursor == nil || *resp.NextCursor == "" {
				t.Fatalf("page %d: hasMore but empty nextCursor", page)
			}
			cursor = *resp.NextCursor
		} else {
			break
		}
		if page > 5 {
			t.Fatal("pagination did not terminate")
		}
	}
	if total != 5 {
		t.Errorf("total across pages=%d, want 5", total)
	}
}

// ── 11. Export produces valid JSON ────────────────────────────────────────────

func TestForge_Export_ProducesValidJSON(t *testing.T) {
	h := th.New(t)
	th.RequireForgeResources(t, h)

	var createResp struct {
		Data struct{ ID string `json:"id"` } `json:"data"`
	}
	th.PostForge(t, h, "export_test", th.SimpleForgeCode, &createResp)
	forgeID := createResp.Data.ID

	// Export returns raw JSON (not wrapped in envelope).
	// Export 直接返回原始 JSON（不包在 envelope 里）。
	var exportData json.RawMessage
	status := th.DoRequest(t, h, "POST", "/api/v1/forges/"+forgeID+":export", nil, &exportData)
	if status != http.StatusOK {
		t.Fatalf("export status=%d, want 200", status)
	}
	if len(exportData) == 0 {
		t.Fatal("export: empty response body")
	}

	// The export data should be valid JSON with at least "name" field.
	// 导出数据应是包含 "name" 字段的合法 JSON。
	var exported map[string]any
	if err := json.Unmarshal(exportData, &exported); err != nil {
		t.Fatalf("export: unmarshal failed: %v", err)
	}
	if _, ok := exported["name"]; !ok {
		t.Error("export JSON missing 'name' field")
	}
}

// ── 12. Export → Import round-trip ────────────────────────────────────────────

func TestForge_Export_Import_RoundTrip(t *testing.T) {
	h := th.New(t)
	th.RequireForgeResources(t, h)

	var createResp struct {
		Data struct{ ID string `json:"id"` } `json:"data"`
	}
	th.PostForge(t, h, "roundtrip_original", th.SimpleForgeCode, &createResp)
	forgeID := createResp.Data.ID

	// Export.
	var exportData json.RawMessage
	th.DoRequest(t, h, "POST", "/api/v1/forges/"+forgeID+":export", nil, &exportData)

	// Mutate the name so we don't hit TOOL_NAME_DUPLICATE.
	var exportMap map[string]any
	_ = json.Unmarshal(exportData, &exportMap)
	exportMap["name"] = "roundtrip_imported"
	mutated, _ := json.Marshal(exportMap)

	// Import.
	var importResp struct {
		Data struct {
			ID   string `json:"id"`
			Name string `json:"name"`
		} `json:"data"`
	}
	status := th.DoRequest(t, h, "POST", "/api/v1/forges:import", json.RawMessage(mutated), &importResp)
	if status != http.StatusCreated {
		t.Fatalf("import status=%d, want 201", status)
	}
	if importResp.Data.Name != "roundtrip_imported" {
		t.Errorf("imported name=%q, want roundtrip_imported", importResp.Data.Name)
	}
}
