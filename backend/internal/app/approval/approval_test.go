package approval

import (
	"context"
	"database/sql"
	"errors"
	"testing"

	_ "github.com/glebarez/go-sqlite"
	"go.uber.org/zap"

	approvaldomain "github.com/sunweilin/anselm/backend/internal/domain/approval"
	approvalstore "github.com/sunweilin/anselm/backend/internal/infra/store/approval"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func newSvc(t *testing.T) (*Service, context.Context) {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range approvalstore.Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	svc := NewService(approvalstore.New(ormpkg.Open(sqlDB)), nil, zap.NewNop())
	return svc, reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")
}

type recordingNotifier struct {
	events []string
}

func (n *recordingNotifier) Emit(_ context.Context, eventType string, _ map[string]any) error {
	n.events = append(n.events, eventType)
	return nil
}

func (n *recordingNotifier) Broadcast(_ context.Context, eventType string, _ map[string]any) error {
	n.events = append(n.events, eventType)
	return nil
}

func TestCreate_WritesV1Active(t *testing.T) {
	svc, ctx := newSvc(t)
	f, v, err := svc.Create(ctx, CreateInput{
		Name: "email-send", Description: "approve email",
		Template: "发送给 {{ input.to }}?", AllowReason: true, Timeout: "30d", TimeoutBehavior: "reject",
	})
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	if v.Version != 1 || f.ActiveVersionID != v.ID {
		t.Fatalf("v1 active: f=%+v v=%+v", f, v)
	}
	got, err := svc.Get(ctx, f.ID)
	if err != nil || got.ActiveVersion == nil {
		t.Fatalf("Get: %+v err=%v", got, err)
	}
	av := got.ActiveVersion
	if av.Template != "发送给 {{ input.to }}?" || !av.AllowReason || av.Timeout != "30d" || av.TimeoutBehavior != "reject" {
		t.Fatalf("rules not round-tripped: %+v", av)
	}
}

func TestCreate_EmptyTemplate(t *testing.T) {
	svc, ctx := newSvc(t)
	_, _, err := svc.Create(ctx, CreateInput{Name: "x", Template: "  "})
	if !errors.Is(err, approvaldomain.ErrInvalidTemplate) {
		t.Fatalf("want ErrInvalidTemplate, got %v", err)
	}
}

func TestCreate_BadTemplateCEL(t *testing.T) {
	svc, ctx := newSvc(t)
	_, _, err := svc.Create(ctx, CreateInput{Name: "x", Template: "bad {{ input.( }}"})
	if !errors.Is(err, approvaldomain.ErrInvalidTemplate) {
		t.Fatalf("want ErrInvalidTemplate (CEL), got %v", err)
	}
}

func TestCreate_TimeoutNoBehavior(t *testing.T) {
	svc, ctx := newSvc(t)
	_, _, err := svc.Create(ctx, CreateInput{Name: "x", Template: "ok?", Timeout: "30d"})
	if !errors.Is(err, approvaldomain.ErrInvalidTimeout) {
		t.Fatalf("want ErrInvalidTimeout, got %v", err)
	}
}

func TestCreate_BadDuration(t *testing.T) {
	svc, ctx := newSvc(t)
	_, _, err := svc.Create(ctx, CreateInput{Name: "x", Template: "ok?", Timeout: "30x", TimeoutBehavior: "reject"})
	if !errors.Is(err, approvaldomain.ErrInvalidTimeout) {
		t.Fatalf("want ErrInvalidTimeout (duration), got %v", err)
	}
}

func TestCreate_EmptyName(t *testing.T) {
	svc, ctx := newSvc(t)
	_, _, err := svc.Create(ctx, CreateInput{Name: "  ", Template: "ok?"})
	if !errors.Is(err, approvaldomain.ErrInvalidName) {
		t.Fatalf("want ErrInvalidName, got %v", err)
	}
}

func TestCreate_DuplicateName(t *testing.T) {
	svc, ctx := newSvc(t)
	mk := func() error {
		_, _, err := svc.Create(ctx, CreateInput{Name: "dup", Template: "ok?"})
		return err
	}
	if err := mk(); err != nil {
		t.Fatalf("first create: %v", err)
	}
	if err := mk(); !errors.Is(err, approvaldomain.ErrDuplicateName) {
		t.Fatalf("want ErrDuplicateName, got %v", err)
	}
}

func TestEdit_NewVersionPointerMoves(t *testing.T) {
	svc, ctx := newSvc(t)
	f, _, _ := svc.Create(ctx, CreateInput{Name: "e", Template: "v1?"})
	v2, err := svc.Edit(ctx, EditInput{ID: f.ID, Template: "v2 {{ input.x }}?"})
	if err != nil {
		t.Fatalf("Edit: %v", err)
	}
	if v2.Version != 2 {
		t.Fatalf("want v2, got %d", v2.Version)
	}
	got, _ := svc.Get(ctx, f.ID)
	if got.ActiveVersionID != v2.ID {
		t.Fatal("active should be v2")
	}
	if _, err := svc.GetVersionByNumber(ctx, f.ID, 1); err != nil {
		t.Fatalf("v1 should be retained: %v", err)
	}
}

func TestListVersionsRequiresParentAndRetainsDeletedHistory(t *testing.T) {
	svc, ctx := newSvc(t)
	f, _, err := svc.Create(ctx, CreateInput{Name: "history", Template: "ok?"})
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	rows, _, err := svc.ListVersions(ctx, f.ID, approvaldomain.VersionListFilter{})
	if err != nil || len(rows) != 1 {
		t.Fatalf("existing approval history: rows=%d err=%v", len(rows), err)
	}
	if err := svc.Delete(ctx, f.ID); err != nil {
		t.Fatalf("soft-delete approval: %v", err)
	}
	if _, err := svc.Get(ctx, f.ID); !errors.Is(err, approvaldomain.ErrNotFound) {
		t.Fatalf("deleted approval must remain absent from normal reads, got %v", err)
	}
	rows, _, err = svc.ListVersions(ctx, f.ID, approvaldomain.VersionListFilter{})
	if err != nil || len(rows) != 1 {
		t.Fatalf("soft-deleted approval history must remain auditable: rows=%d err=%v", len(rows), err)
	}
	if _, _, err := svc.ListVersions(ctx, "apf_missing_versions", approvaldomain.VersionListFilter{}); !errors.Is(err, approvaldomain.ErrNotFound) {
		t.Fatalf("missing approval history must be ErrNotFound, got %v", err)
	}
}

func TestGetVersionForApprovalScopesOpaqueID(t *testing.T) {
	svc, ctx := newSvc(t)
	a, av, err := svc.Create(ctx, CreateInput{Name: "a", Template: "a?"})
	if err != nil {
		t.Fatalf("create a: %v", err)
	}
	b, bv, err := svc.Create(ctx, CreateInput{Name: "b", Template: "b?"})
	if err != nil {
		t.Fatalf("create b: %v", err)
	}
	if got, err := svc.GetVersionForApproval(ctx, a.ID, av.ID); err != nil || got.ApprovalID != a.ID {
		t.Fatalf("same-parent opaque read: got=%+v err=%v", got, err)
	}
	if _, err := svc.GetVersionForApproval(ctx, a.ID, bv.ID); !errors.Is(err, approvaldomain.ErrVersionNotFound) {
		t.Fatalf("cross-approval opaque version must be hidden, got %v", err)
	}
	if _, err := svc.GetVersionForApproval(ctx, "apf_missing_version_owner", av.ID); !errors.Is(err, approvaldomain.ErrVersionNotFound) {
		t.Fatalf("missing approval must not expose an opaque version, got %v", err)
	}
	_ = b
}

func TestRevert_MovesPointer(t *testing.T) {
	svc, ctx := newSvc(t)
	f, v1, _ := svc.Create(ctx, CreateInput{Name: "r", Template: "v1?"})
	if _, err := svc.Edit(ctx, EditInput{ID: f.ID, Template: "v2?"}); err != nil {
		t.Fatalf("Edit: %v", err)
	}
	if _, err := svc.Revert(ctx, f.ID, 1); err != nil {
		t.Fatalf("Revert: %v", err)
	}
	got, _ := svc.Get(ctx, f.ID)
	if got.ActiveVersionID != v1.ID {
		t.Fatal("active should be v1 after revert")
	}
}

func TestUpdateMeta_NoVersionBump(t *testing.T) {
	svc, ctx := newSvc(t)
	f, _, _ := svc.Create(ctx, CreateInput{Name: "m", Template: "ok?"})
	name := "renamed"
	if _, err := svc.UpdateMeta(ctx, UpdateMetaInput{ID: f.ID, Name: &name}); err != nil {
		t.Fatalf("UpdateMeta: %v", err)
	}
	got, _ := svc.Get(ctx, f.ID)
	if got.Name != "renamed" {
		t.Fatalf("name not updated: %q", got.Name)
	}
	if n, _ := svc.repo.MaxVersionNumber(ctx, f.ID); n != 1 {
		t.Fatalf("UpdateMeta must not bump version, max=%d", n)
	}
}

func TestUpdateMeta_NoOpDoesNotTouchUpdatedAt(t *testing.T) {
	svc, ctx := newSvc(t)
	f, _, _ := svc.Create(ctx, CreateInput{Name: "m", Description: "same", Template: "ok?"})
	notifier := &recordingNotifier{}
	svc.notif = notifier
	before, err := svc.Get(ctx, f.ID)
	if err != nil {
		t.Fatalf("Get before: %v", err)
	}
	got, err := svc.UpdateMeta(ctx, UpdateMetaInput{ID: f.ID})
	if err != nil {
		t.Fatalf("UpdateMeta no-op: %v", err)
	}
	if !got.UpdatedAt.Equal(before.UpdatedAt) {
		t.Fatalf("no-op must not touch updatedAt: before=%s after=%s", before.UpdatedAt, got.UpdatedAt)
	}
	after, err := svc.Get(ctx, f.ID)
	if err != nil {
		t.Fatalf("Get after: %v", err)
	}
	if !after.UpdatedAt.Equal(before.UpdatedAt) {
		t.Fatalf("no-op must not persist an updatedAt change: before=%s after=%s", before.UpdatedAt, after.UpdatedAt)
	}
	name, description := before.Name, before.Description
	if _, err := svc.UpdateMeta(ctx, UpdateMetaInput{ID: f.ID, Name: &name, Description: &description}); err != nil {
		t.Fatalf("UpdateMeta equal no-op: %v", err)
	}
	if len(notifier.events) != 0 {
		t.Fatalf("no-op must not publish notifications, got %v", notifier.events)
	}
}

func TestSearch_Substring(t *testing.T) {
	svc, ctx := newSvc(t)
	svc.Create(ctx, CreateInput{Name: "email-approval", Template: "ok?"})
	svc.Create(ctx, CreateInput{Name: "refund-gate", Template: "ok?"})
	hits, err := svc.Search(ctx, "email")
	if err != nil || len(hits) != 1 || hits[0].Name != "email-approval" {
		t.Fatalf("search email: %v hits=%v", err, hits)
	}
	all, _ := svc.Search(ctx, "")
	if len(all) != 2 {
		t.Fatalf("empty query should list all, got %d", len(all))
	}
}

func TestDelete_SoftDeleted(t *testing.T) {
	svc, ctx := newSvc(t)
	f, _, _ := svc.Create(ctx, CreateInput{Name: "d", Template: "ok?"})
	if err := svc.Delete(ctx, f.ID); err != nil {
		t.Fatalf("Delete: %v", err)
	}
	if _, err := svc.Get(ctx, f.ID); !errors.Is(err, approvaldomain.ErrNotFound) {
		t.Fatalf("deleted should be NotFound, got %v", err)
	}
}

func TestResolve_ActiveAndPinned(t *testing.T) {
	svc, ctx := newSvc(t)
	f, v1, _ := svc.Create(ctx, CreateInput{Name: "rs", Template: "v1?"})
	if _, err := svc.Edit(ctx, EditInput{ID: f.ID, Template: "v2 {{ input.x }}?"}); err != nil {
		t.Fatalf("Edit: %v", err)
	}
	act, err := svc.Resolve(ctx, f.ID, "")
	if err != nil || act.Template != "v2 {{ input.x }}?" {
		t.Fatalf("resolve active: %v %+v", err, act)
	}
	pin, err := svc.Resolve(ctx, f.ID, v1.ID)
	if err != nil || pin.Template != "v1?" {
		t.Fatalf("resolve pinned v1: %v %+v", err, pin)
	}
}
