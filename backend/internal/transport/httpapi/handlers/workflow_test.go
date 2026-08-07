package handlers

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	_ "github.com/glebarez/go-sqlite"
	"go.uber.org/zap"

	workflowapp "github.com/sunweilin/anselm/backend/internal/app/workflow"
	workflowdomain "github.com/sunweilin/anselm/backend/internal/domain/workflow"
	workflowstore "github.com/sunweilin/anselm/backend/internal/infra/store/workflow"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func TestWorkflowGetVersion_OpaqueIDIsParentScoped(t *testing.T) {
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range workflowstore.Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")
	svc := workflowapp.NewService(workflowstore.New(ormpkg.Open(sqlDB)), nil, nil, zap.NewNop())
	create := func(name, ref string) (*workflowdomain.Workflow, *workflowdomain.Version) {
		t.Helper()
		ops, err := workflowdomain.ParseOps(json.RawMessage(fmt.Sprintf(`[{"op":"add_node","node":{"id":"start","kind":"trigger","ref":"%s"}}]`, ref)))
		if err != nil {
			t.Fatalf("parse ops %s: %v", name, err)
		}
		w, v, err := svc.Create(ctx, workflowapp.CreateInput{
			Name: name,
			Ops:  ops,
		})
		if err != nil {
			t.Fatalf("create %s: %v", name, err)
		}
		return w, v
	}
	a, av := create("http-version-a", "trg_a")
	b, _ := create("http-version-b", "trg_b")

	h := NewWorkflowHandler(svc, nil, zap.NewNop())
	request := func(parent, versionID string) *httptest.ResponseRecorder {
		t.Helper()
		r := httptest.NewRequest(http.MethodGet, "/api/v1/workflows/"+parent+"/versions/"+versionID, nil).WithContext(ctx)
		r.SetPathValue("id", parent)
		r.SetPathValue("version", versionID)
		rec := httptest.NewRecorder()
		h.GetVersion(rec, r)
		return rec
	}

	good := request(a.ID, av.ID)
	if good.Code != http.StatusOK {
		t.Fatalf("same-parent opaque read status = %d, body=%s", good.Code, good.Body)
	}
	var goodBody struct {
		Data workflowdomain.Version `json:"data"`
	}
	if err := json.Unmarshal(good.Body.Bytes(), &goodBody); err != nil {
		t.Fatalf("decode same-parent response: %v", err)
	}
	if goodBody.Data.WorkflowID != a.ID || goodBody.Data.GraphParsed == nil {
		t.Fatalf("same-parent response = %+v", goodBody.Data)
	}

	cross := request(b.ID, av.ID)
	if cross.Code != http.StatusNotFound {
		t.Fatalf("cross-parent opaque read status = %d, body=%s", cross.Code, cross.Body)
	}
	var crossBody struct {
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	if err := json.Unmarshal(cross.Body.Bytes(), &crossBody); err != nil {
		t.Fatalf("decode cross-parent response: %v", err)
	}
	if crossBody.Error.Code != "WORKFLOW_VERSION_NOT_FOUND" {
		t.Fatalf("cross-parent error code = %q", crossBody.Error.Code)
	}
}
