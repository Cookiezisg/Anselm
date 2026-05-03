//go:build pipeline

// conversation_test.go — end-to-end tests for the 4
// /api/v1/conversations/* endpoints. Covers CRUD, soft-delete behaviour, 404
// on missing IDs, and cursor pagination. All tests run offline.
//
// conversation_test.go — /api/v1/conversations/* 4 个端点的端到端测试。
// 覆盖 CRUD、软删行为、404、cursor 分页，全部离线。
package conversation

import (
	"fmt"
	"net/http"
	"testing"

	th "github.com/sunweilin/forgify/backend/test/harness"
)

// ── 1. CRUD round-trip ───────────────────────────────────────────────────────

func TestConversation_CRUD_Roundtrip(t *testing.T) {
	h := th.New(t)

	// Create
	var createResp struct {
		Data struct {
			ID         string `json:"id"`
			Title      string `json:"title"`
			AutoTitled bool   `json:"autoTitled"`
		} `json:"data"`
	}
	h.PostJSON("/api/v1/conversations", map[string]any{"title": "hello"}, &createResp)
	if createResp.Data.ID == "" {
		t.Fatal("create: empty id")
	}
	if createResp.Data.Title != "hello" {
		t.Errorf("title=%q, want hello", createResp.Data.Title)
	}
	if createResp.Data.AutoTitled {
		t.Error("autoTitled should be false on explicit create")
	}
	convID := createResp.Data.ID

	// List — one item
	var listResp struct {
		Data    []struct{ ID string `json:"id"` } `json:"data"`
		HasMore *bool                              `json:"hasMore"`
	}
	h.GetJSON("/api/v1/conversations", &listResp)
	if len(listResp.Data) != 1 {
		t.Fatalf("list: got %d, want 1", len(listResp.Data))
	}

	// Rename (PATCH)
	var renameResp struct {
		Data struct {
			Title string `json:"title"`
		} `json:"data"`
	}
	h.PatchJSON("/api/v1/conversations/"+convID, map[string]any{"title": "renamed"}, &renameResp)
	if renameResp.Data.Title != "renamed" {
		t.Errorf("title after rename=%q, want renamed", renameResp.Data.Title)
	}

	// Delete → 204
	h.Delete("/api/v1/conversations/" + convID)

	// List again → empty (soft-delete hides the row)
	// 再 list → 空（软删隐藏行）
	h.GetJSON("/api/v1/conversations", &listResp)
	if len(listResp.Data) != 0 {
		t.Errorf("list after delete: got %d items, want 0", len(listResp.Data))
	}
}

// ── 2. Soft-delete hides the deleted conversation but leaves others ──────────

func TestConversation_SoftDelete_HidesFromList(t *testing.T) {
	h := th.New(t)

	// Create three conversations.
	// 创建三个对话。
	var ids [3]string
	for i := range 3 {
		var resp struct {
			Data struct{ ID string `json:"id"` } `json:"data"`
		}
		h.PostJSON("/api/v1/conversations", map[string]any{"title": fmt.Sprintf("conv-%d", i)}, &resp)
		ids[i] = resp.Data.ID
	}

	// Delete the middle one.
	// 删除中间那个。
	h.Delete("/api/v1/conversations/" + ids[1])

	var listResp struct {
		Data []struct{ ID string `json:"id"` } `json:"data"`
	}
	h.GetJSON("/api/v1/conversations", &listResp)

	if len(listResp.Data) != 2 {
		t.Fatalf("list after soft-delete: got %d items, want 2", len(listResp.Data))
	}
	for _, item := range listResp.Data {
		if item.ID == ids[1] {
			t.Errorf("deleted conversation %q still appears in list", ids[1])
		}
	}
}

// ── 3. Delete non-existent → 404 ─────────────────────────────────────────────

func TestConversation_Delete_NotFound_Returns404(t *testing.T) {
	h := th.New(t)
	var errResp th.ErrEnvelope
	status := th.DoRequest(t, h, "DELETE", "/api/v1/conversations/cv_doesnotexist", nil, &errResp)
	if status != http.StatusNotFound {
		t.Errorf("status=%d, want 404", status)
	}
	if errResp.Error.Code != "CONVERSATION_NOT_FOUND" {
		t.Errorf("error.code=%q, want CONVERSATION_NOT_FOUND", errResp.Error.Code)
	}
}

// ── 4. Cursor pagination exhausts all pages ──────────────────────────────────

func TestConversation_CursorPagination_ExhaustPages(t *testing.T) {
	h := th.New(t)

	// Seed 7 conversations; with limit=3 expect pages: 3 + 3 + 1.
	// 插入 7 个对话；limit=3 预期 3 + 3 + 1 三页。
	for i := range 7 {
		h.PostJSON("/api/v1/conversations", map[string]any{
			"title": fmt.Sprintf("conv-%02d", i),
		}, nil)
	}

	type pagedResp struct {
		Data []struct {
			ID string `json:"id"`
		} `json:"data"`
		NextCursor *string `json:"nextCursor"`
		HasMore    *bool   `json:"hasMore"`
	}

	var cursor string
	totalSeen := 0
	for page := 0; ; page++ {
		url := "/api/v1/conversations?limit=3"
		if cursor != "" {
			url += "&cursor=" + cursor
		}
		var resp pagedResp
		h.GetJSON(url, &resp)

		if len(resp.Data) == 0 {
			t.Fatalf("page %d: empty data (seen %d so far)", page, totalSeen)
		}
		totalSeen += len(resp.Data)

		hasMore := resp.HasMore != nil && *resp.HasMore
		if hasMore {
			if resp.NextCursor == nil || *resp.NextCursor == "" {
				t.Fatalf("page %d: hasMore=true but nextCursor empty", page)
			}
			cursor = *resp.NextCursor
		} else {
			break
		}
		if page > 5 {
			t.Fatal("pagination did not terminate after 5 pages")
		}
	}
	if totalSeen != 7 {
		t.Errorf("total across pages=%d, want 7", totalSeen)
	}
}
