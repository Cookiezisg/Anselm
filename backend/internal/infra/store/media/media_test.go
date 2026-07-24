package media

import (
	"context"
	"database/sql"
	"testing"

	_ "github.com/glebarez/go-sqlite"

	mediadomain "github.com/sunweilin/anselm/backend/internal/domain/media"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func newStore(t *testing.T) *Store {
	t.Helper()
	db, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	db.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = db.Close() })
	for _, statement := range Schema {
		if _, err := db.Exec(statement); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	return New(ormpkg.Open(db))
}

func mediaCtx() context.Context { return reqctxpkg.SetWorkspaceID(context.Background(), "ws_1") }

func derivative(id, source, params string) *mediadomain.Derivative {
	return &mediadomain.Derivative{ID: id, AttachmentID: "att_1", Kind: "model-default", SourceSHA256: source, ParamsHash: params, Status: mediadomain.StatusPending}
}

func TestClaimDerivative_ExactIdentityReusesButChangesInvalidate(t *testing.T) {
	s := newStore(t)
	ctx := mediaCtx()
	first, created, err := s.ClaimDerivative(ctx, derivative("mdr_1", "source-a", "params-a"))
	if err != nil || !created {
		t.Fatalf("first claim = (%+v, %v, %v), want created", first, created, err)
	}
	again, created, err := s.ClaimDerivative(ctx, derivative("mdr_2", "source-a", "params-a"))
	if err != nil || created || again.ID != first.ID {
		t.Fatalf("same identity must reuse first: (%+v, %v, %v)", again, created, err)
	}
	byParams, created, err := s.ClaimDerivative(ctx, derivative("mdr_3", "source-a", "params-b"))
	if err != nil || !created || byParams.ID == first.ID {
		t.Fatalf("changed params must create new work: (%+v, %v, %v)", byParams, created, err)
	}
	bySource, created, err := s.ClaimDerivative(ctx, derivative("mdr_4", "source-b", "params-a"))
	if err != nil || !created || bySource.ID == first.ID {
		t.Fatalf("changed source must create new work: (%+v, %v, %v)", bySource, created, err)
	}
}

func TestClaimPerception_TaskAndModelScopeCache(t *testing.T) {
	s := newStore(t)
	ctx := mediaCtx()
	makePerception := func(id, task, model string) *mediadomain.Perception {
		return &mediadomain.Perception{ID: id, AttachmentID: "att_1", Kind: "audio-evidence", SourceSHA256: "source-a", TaskHash: task, Provider: "qwen", Model: model, ParamsHash: "params", Status: mediadomain.StatusPending}
	}
	first, created, err := s.ClaimPerception(ctx, makePerception("mpr_1", "task-a", "qwen3.5-omni-plus"))
	if err != nil || !created {
		t.Fatalf("first claim = (%+v, %v, %v), want created", first, created, err)
	}
	again, created, err := s.ClaimPerception(ctx, makePerception("mpr_2", "task-a", "qwen3.5-omni-plus"))
	if err != nil || created || again.ID != first.ID {
		t.Fatalf("same perception must reuse: (%+v, %v, %v)", again, created, err)
	}
	if _, created, err = s.ClaimPerception(ctx, makePerception("mpr_3", "task-b", "qwen3.5-omni-plus")); err != nil || !created {
		t.Fatalf("changed task must create work: created=%v err=%v", created, err)
	}
	if _, created, err = s.ClaimPerception(ctx, makePerception("mpr_4", "task-a", "new-model")); err != nil || !created {
		t.Fatalf("changed model must create work: created=%v err=%v", created, err)
	}
}

func TestClaimDerivative_WorkspaceIsolation(t *testing.T) {
	s := newStore(t)
	if _, created, err := s.ClaimDerivative(mediaCtx(), derivative("mdr_1", "source-a", "params-a")); err != nil || !created {
		t.Fatalf("ws_1 create: created=%v err=%v", created, err)
	}
	ctx2 := reqctxpkg.SetWorkspaceID(context.Background(), "ws_2")
	if _, created, err := s.ClaimDerivative(ctx2, derivative("mdr_2", "source-a", "params-a")); err != nil || !created {
		t.Fatalf("same identity in another workspace must be independent: created=%v err=%v", created, err)
	}
}
