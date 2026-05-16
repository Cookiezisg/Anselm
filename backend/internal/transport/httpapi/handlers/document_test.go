package handlers

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"go.uber.org/zap/zaptest"
	gormlogger "gorm.io/gorm/logger"

	documentapp "github.com/sunweilin/forgify/backend/internal/app/document"
	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"
	documentstore "github.com/sunweilin/forgify/backend/internal/infra/store/document"
	middlewarehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/middleware"
)

func newDocTestServer(t *testing.T) *httptest.Server {
	t.Helper()
	gdb, err := dbinfra.Open(dbinfra.Config{LogLevel: gormlogger.Silent})
	if err != nil {
		t.Fatalf("dbinfra.Open: %v", err)
	}
	t.Cleanup(func() { _ = dbinfra.Close(gdb) })
	if err := dbinfra.Migrate(gdb, documentstore.AutoMigrateModels()...); err != nil {
		t.Fatalf("Migrate: %v", err)
	}
	log := zaptest.NewLogger(t)
	svc := documentapp.New(documentstore.New(gdb), nil, log)
	h := NewDocumentHandler(svc, log)
	mux := http.NewServeMux()
	h.Register(mux)
	return httptest.NewServer(middlewarehttpapi.InjectUserID(mux))
}

func TestDocHandler_Create_Root(t *testing.T) {
	srv := newDocTestServer(t)
	defer srv.Close()

	status, env := do(t, srv, "POST", "/api/v1/documents", map[string]any{
		"name":        "Project Alpha",
		"description": "Root project",
	})
	if status != http.StatusCreated {
		t.Fatalf("status = %d, env=%+v", status, env)
	}
	d := dataMap(t, env)
	if d["path"].(string) != "/Project Alpha" {
		t.Errorf("path = %q", d["path"])
	}
	if d["parentId"] != nil {
		t.Errorf("root should have null parentId; got %v", d["parentId"])
	}
}

func TestDocHandler_Create_Child(t *testing.T) {
	srv := newDocTestServer(t)
	defer srv.Close()

	_, env := do(t, srv, "POST", "/api/v1/documents", map[string]any{"name": "ProjA"})
	parentID := dataMap(t, env)["id"].(string)
	status, env := do(t, srv, "POST", "/api/v1/documents", map[string]any{
		"name":     "spec",
		"parentId": parentID,
	})
	if status != http.StatusCreated {
		t.Fatalf("status = %d", status)
	}
	d := dataMap(t, env)
	if d["path"].(string) != "/ProjA/spec" {
		t.Errorf("child path = %q", d["path"])
	}
}

func TestDocHandler_Create_BadParent_422(t *testing.T) {
	srv := newDocTestServer(t)
	defer srv.Close()
	status, env := do(t, srv, "POST", "/api/v1/documents", map[string]any{
		"name":     "x",
		"parentId": "doc_missing",
	})
	if status != http.StatusUnprocessableEntity {
		t.Errorf("status = %d, want 422: %+v", status, env)
	}
	if e := env["error"].(map[string]any); e["code"].(string) != "DOCUMENT_PARENT_NOT_FOUND" {
		t.Errorf("code = %q", e["code"])
	}
}

func TestDocHandler_Create_InvalidName_400(t *testing.T) {
	srv := newDocTestServer(t)
	defer srv.Close()
	status, env := do(t, srv, "POST", "/api/v1/documents", map[string]any{"name": ""})
	if status != http.StatusBadRequest {
		t.Errorf("empty name status = %d, want 400: %+v", status, env)
	}
}

func TestDocHandler_Create_DuplicateName_409(t *testing.T) {
	srv := newDocTestServer(t)
	defer srv.Close()
	do(t, srv, "POST", "/api/v1/documents", map[string]any{"name": "Notes"})
	status, env := do(t, srv, "POST", "/api/v1/documents", map[string]any{"name": "Notes"})
	if status != http.StatusConflict {
		t.Errorf("status = %d, want 409: %+v", status, env)
	}
}

func TestDocHandler_Create_ContentTooLarge_413(t *testing.T) {
	srv := newDocTestServer(t)
	defer srv.Close()
	big := strings.Repeat("x", 2*1024*1024) // 2 MB
	status, env := do(t, srv, "POST", "/api/v1/documents", map[string]any{
		"name":    "huge",
		"content": big,
	})
	if status != http.StatusRequestEntityTooLarge {
		t.Errorf("status = %d, want 413: %+v", status, env)
	}
}

func TestDocHandler_Get_NotFound_404(t *testing.T) {
	srv := newDocTestServer(t)
	defer srv.Close()
	status, _ := do(t, srv, "GET", "/api/v1/documents/doc_missing", nil)
	if status != http.StatusNotFound {
		t.Errorf("status = %d, want 404", status)
	}
}

func TestDocHandler_Update_PartialPatch(t *testing.T) {
	srv := newDocTestServer(t)
	defer srv.Close()
	_, env := do(t, srv, "POST", "/api/v1/documents", map[string]any{"name": "Orig", "description": "old"})
	id := dataMap(t, env)["id"].(string)

	newDesc := "fresh"
	status, env := do(t, srv, "PATCH", "/api/v1/documents/"+id, map[string]any{
		"description": newDesc,
	})
	if status != http.StatusOK {
		t.Fatalf("status = %d", status)
	}
	d := dataMap(t, env)
	if d["description"].(string) != "fresh" {
		t.Errorf("description = %q", d["description"])
	}
	if d["name"].(string) != "Orig" {
		t.Errorf("name should be untouched; got %q", d["name"])
	}
}

func TestDocHandler_Update_Rename_CascadesPaths(t *testing.T) {
	srv := newDocTestServer(t)
	defer srv.Close()
	_, env := do(t, srv, "POST", "/api/v1/documents", map[string]any{"name": "Orig"})
	rootID := dataMap(t, env)["id"].(string)
	_, env = do(t, srv, "POST", "/api/v1/documents", map[string]any{"name": "child", "parentId": rootID})
	childID := dataMap(t, env)["id"].(string)

	newName := "Renamed"
	if status, _ := do(t, srv, "PATCH", "/api/v1/documents/"+rootID, map[string]any{
		"name": newName,
	}); status != http.StatusOK {
		t.Fatalf("rename status = %d", status)
	}
	_, env = do(t, srv, "GET", "/api/v1/documents/"+childID, nil)
	if dataMap(t, env)["path"].(string) != "/Renamed/child" {
		t.Errorf("child path not cascaded: %v", dataMap(t, env)["path"])
	}
}

func TestDocHandler_Move(t *testing.T) {
	srv := newDocTestServer(t)
	defer srv.Close()
	_, env := do(t, srv, "POST", "/api/v1/documents", map[string]any{"name": "A"})
	aID := dataMap(t, env)["id"].(string)
	_, env = do(t, srv, "POST", "/api/v1/documents", map[string]any{"name": "B"})
	bID := dataMap(t, env)["id"].(string)
	_, env = do(t, srv, "POST", "/api/v1/documents", map[string]any{"name": "child", "parentId": aID})
	childID := dataMap(t, env)["id"].(string)

	status, env := do(t, srv, "POST", "/api/v1/documents/"+childID+":move", map[string]any{
		"parentId": bID,
	})
	if status != http.StatusOK {
		t.Fatalf("move status = %d", status)
	}
	if dataMap(t, env)["path"].(string) != "/B/child" {
		t.Errorf("post-move path = %v", dataMap(t, env)["path"])
	}
}

func TestDocHandler_Move_ToDescendant_422(t *testing.T) {
	srv := newDocTestServer(t)
	defer srv.Close()
	_, env := do(t, srv, "POST", "/api/v1/documents", map[string]any{"name": "root"})
	rootID := dataMap(t, env)["id"].(string)
	_, env = do(t, srv, "POST", "/api/v1/documents", map[string]any{"name": "leaf", "parentId": rootID})
	leafID := dataMap(t, env)["id"].(string)

	status, env := do(t, srv, "POST", "/api/v1/documents/"+rootID+":move", map[string]any{
		"parentId": leafID,
	})
	if status != http.StatusUnprocessableEntity {
		t.Errorf("status = %d, want 422", status)
	}
	if env["error"].(map[string]any)["code"].(string) != "DOCUMENT_INVALID_PARENT" {
		t.Errorf("code = %v", env["error"])
	}
}

func TestDocHandler_Delete_Recursive(t *testing.T) {
	srv := newDocTestServer(t)
	defer srv.Close()
	_, env := do(t, srv, "POST", "/api/v1/documents", map[string]any{"name": "root"})
	rootID := dataMap(t, env)["id"].(string)
	_, env = do(t, srv, "POST", "/api/v1/documents", map[string]any{"name": "mid", "parentId": rootID})
	midID := dataMap(t, env)["id"].(string)
	do(t, srv, "POST", "/api/v1/documents", map[string]any{"name": "leaf", "parentId": midID})

	status, env := do(t, srv, "DELETE", "/api/v1/documents/"+rootID, nil)
	if status != http.StatusOK {
		t.Fatalf("status = %d", status)
	}
	if n := dataMap(t, env)["deletedCount"].(float64); n != 3 {
		t.Errorf("deletedCount = %v, want 3", n)
	}
	if s, _ := do(t, srv, "GET", "/api/v1/documents/"+rootID, nil); s != http.StatusNotFound {
		t.Errorf("post-delete GET = %d, want 404", s)
	}
}

func TestDocHandler_ListByParent(t *testing.T) {
	srv := newDocTestServer(t)
	defer srv.Close()
	_, env := do(t, srv, "POST", "/api/v1/documents", map[string]any{"name": "root"})
	rootID := dataMap(t, env)["id"].(string)
	do(t, srv, "POST", "/api/v1/documents", map[string]any{"name": "a", "parentId": rootID})
	do(t, srv, "POST", "/api/v1/documents", map[string]any{"name": "b", "parentId": rootID})

	status, env := do(t, srv, "GET", "/api/v1/documents?parentId="+rootID, nil)
	if status != http.StatusOK {
		t.Fatalf("status = %d", status)
	}
	items := dataSlice(t, env)
	if len(items) != 2 {
		t.Errorf("items = %d, want 2", len(items))
	}
}

func TestDocHandler_Tree(t *testing.T) {
	srv := newDocTestServer(t)
	defer srv.Close()
	_, env := do(t, srv, "POST", "/api/v1/documents", map[string]any{"name": "root"})
	rootID := dataMap(t, env)["id"].(string)
	do(t, srv, "POST", "/api/v1/documents", map[string]any{"name": "child", "parentId": rootID})

	status, env := do(t, srv, "GET", "/api/v1/documents/tree", nil)
	if status != http.StatusOK {
		t.Fatalf("status = %d, env=%+v", status, env)
	}
	items := dataSlice(t, env)
	if len(items) != 2 {
		t.Errorf("tree items = %d, want 2", len(items))
	}
	// content should be omitted from tree response (lightweight)
	for _, it := range items {
		m := it.(map[string]any)
		if _, has := m["content"]; has {
			t.Errorf("tree row should not include content; got %v", m["content"])
		}
	}
}
