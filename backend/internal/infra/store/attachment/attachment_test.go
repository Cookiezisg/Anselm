package attachment

import (
	"context"
	"database/sql"
	"errors"
	"sort"
	"testing"

	_ "github.com/glebarez/go-sqlite"

	attachmentdomain "github.com/sunweilin/forgify/backend/internal/domain/attachment"
	ormpkg "github.com/sunweilin/forgify/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

func newStore(t *testing.T) *Store {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	return New(ormpkg.Open(sqlDB))
}

func ctxWS(id string) context.Context {
	return reqctxpkg.SetWorkspaceID(context.Background(), id)
}

func ins(t *testing.T, s *Store, ctx context.Context, id, sha, kind string) {
	t.Helper()
	a := &attachmentdomain.Attachment{ID: id, SHA256: sha, Filename: id + ".bin", MimeType: "application/octet-stream", SizeBytes: 3, Kind: kind}
	if err := s.Insert(ctx, a); err != nil {
		t.Fatalf("insert %s: %v", id, err)
	}
}

func TestInsertGet_RoundTrip(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	ins(t, s, ctx, "att_1", "abc123", attachmentdomain.KindImage)
	got, err := s.Get(ctx, "att_1")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if got.SHA256 != "abc123" || got.Kind != attachmentdomain.KindImage || got.WorkspaceID != "ws_1" {
		t.Errorf("round-trip: %+v", got)
	}
	if got.CreatedAt.IsZero() {
		t.Error("created_at not auto-stamped")
	}
}

func TestGet_NotFound(t *testing.T) {
	s := newStore(t)
	if _, err := s.Get(ctxWS("ws_1"), "att_x"); !errors.Is(err, attachmentdomain.ErrNotFound) {
		t.Errorf("err = %v, want ErrNotFound", err)
	}
}

func TestGetBatch(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	ins(t, s, ctx, "att_1", "h1", attachmentdomain.KindText)
	ins(t, s, ctx, "att_2", "h2", attachmentdomain.KindText)
	rows, err := s.GetBatch(ctx, []string{"att_1", "att_2", "att_missing"})
	if err != nil {
		t.Fatalf("batch: %v", err)
	}
	if len(rows) != 2 {
		t.Errorf("batch len = %d, want 2", len(rows))
	}
	if r, err := s.GetBatch(ctx, nil); err != nil || r != nil {
		t.Errorf("empty batch = %v, %v", r, err)
	}
}

func TestSoftDelete(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	ins(t, s, ctx, "att_1", "h1", attachmentdomain.KindText)
	if err := s.SoftDelete(ctx, "att_1"); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if _, err := s.Get(ctx, "att_1"); !errors.Is(err, attachmentdomain.ErrNotFound) {
		t.Errorf("get after delete = %v, want ErrNotFound", err)
	}
	if err := s.SoftDelete(ctx, "att_1"); !errors.Is(err, attachmentdomain.ErrNotFound) {
		t.Errorf("re-delete = %v, want ErrNotFound", err)
	}
}

func TestListLiveSHAs_DistinctAndSoftDeleteAware(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	// Two rows share sha "hA" (dedup), one row "hB".
	ins(t, s, ctx, "att_1", "hA", attachmentdomain.KindImage)
	ins(t, s, ctx, "att_2", "hA", attachmentdomain.KindImage)
	ins(t, s, ctx, "att_3", "hB", attachmentdomain.KindText)

	shas, err := s.ListLiveSHAs(ctx)
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	sort.Strings(shas)
	if len(shas) != 2 || shas[0] != "hA" || shas[1] != "hB" {
		t.Errorf("distinct shas = %v, want [hA hB]", shas)
	}

	// Deleting one of the two hA rows keeps hA live (the other row still references it).
	_ = s.SoftDelete(ctx, "att_1")
	if shas, _ := s.ListLiveSHAs(ctx); len(shas) != 2 {
		t.Errorf("after deleting 1 hA row, shas = %v, want still 2 (hA kept)", shas)
	}
	// Deleting the second hA row drops hA.
	_ = s.SoftDelete(ctx, "att_2")
	shas, _ = s.ListLiveSHAs(ctx)
	if len(shas) != 1 || shas[0] != "hB" {
		t.Errorf("after deleting both hA rows, shas = %v, want [hB]", shas)
	}
}

func TestWorkspaceIsolation(t *testing.T) {
	s := newStore(t)
	ins(t, s, ctxWS("ws_1"), "att_1", "h1", attachmentdomain.KindText)
	if _, err := s.Get(ctxWS("ws_2"), "att_1"); !errors.Is(err, attachmentdomain.ErrNotFound) {
		t.Errorf("cross-ws get = %v, want ErrNotFound", err)
	}
	if shas, _ := s.ListLiveSHAs(ctxWS("ws_2")); len(shas) != 0 {
		t.Errorf("ws_2 shas = %v, want empty", shas)
	}
}
