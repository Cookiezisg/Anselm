package relation

import (
	"context"
	"errors"
	"testing"

	"go.uber.org/zap"

	relationdomain "github.com/sunweilin/forgify/backend/internal/domain/relation"
	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"
	relationstore "github.com/sunweilin/forgify/backend/internal/infra/store/relation"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

const testUserID = "user_local"

func newTestService(t *testing.T, opts ...func(*Config)) *Service {
	t.Helper()
	db, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	if err := dbinfra.Migrate(db, &relationdomain.Relation{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	cfg := Config{
		Repo: relationstore.New(db),
		Log:  zap.NewNop(),
	}
	for _, o := range opts {
		o(&cfg)
	}
	return NewService(cfg)
}

func testCtx() context.Context {
	return reqctxpkg.SetUserID(context.Background(), testUserID)
}

// --- SyncOutgoing diff-sync semantics ---

func TestSyncOutgoing_InsertsNewEdges(t *testing.T) {
	s := newTestService(t)
	ctx := testCtx()
	err := s.SyncOutgoing(ctx, "workflow", "wf_x",
		[]string{relationdomain.KindWorkflowUsesFunction},
		[]relationdomain.SyncEdge{
			{OtherKind: "function", OtherID: "fn_y", Kind: relationdomain.KindWorkflowUsesFunction, Attrs: map[string]any{"nodeIds": []string{"n_1"}}},
		})
	if err != nil {
		t.Fatalf("SyncOutgoing: %v", err)
	}
	rows, _, _, err := s.List(ctx, relationdomain.Filter{FromKind: "workflow", FromID: "wf_x"}, "", 100)
	if err != nil {
		t.Fatalf("List: %v", err)
	}
	if len(rows) != 1 || rows[0].ToID != "fn_y" {
		t.Errorf("expected 1 edge to fn_y, got %+v", rows)
	}
}

func TestSyncOutgoing_IdempotentOnIdenticalInput(t *testing.T) {
	s := newTestService(t)
	ctx := testCtx()
	edges := []relationdomain.SyncEdge{
		{OtherKind: "function", OtherID: "fn_y", Kind: relationdomain.KindWorkflowUsesFunction, Attrs: map[string]any{"nodeIds": []string{"n_1"}}},
	}
	if err := s.SyncOutgoing(ctx, "workflow", "wf_x", []string{relationdomain.KindWorkflowUsesFunction}, edges); err != nil {
		t.Fatalf("SyncOutgoing 1: %v", err)
	}
	rowsBefore, _, _, _ := s.List(ctx, relationdomain.Filter{FromKind: "workflow", FromID: "wf_x"}, "", 100)

	// Same edges again — should produce no DB-level change
	if err := s.SyncOutgoing(ctx, "workflow", "wf_x", []string{relationdomain.KindWorkflowUsesFunction}, edges); err != nil {
		t.Fatalf("SyncOutgoing 2: %v", err)
	}
	rowsAfter, _, _, _ := s.List(ctx, relationdomain.Filter{FromKind: "workflow", FromID: "wf_x"}, "", 100)

	if len(rowsAfter) != 1 || rowsAfter[0].ID != rowsBefore[0].ID {
		t.Errorf("expected same single row (id preserved); before=%+v after=%+v", rowsBefore, rowsAfter)
	}
}

func TestSyncOutgoing_DeletesMissingEdges(t *testing.T) {
	s := newTestService(t)
	ctx := testCtx()
	// Insert 2 edges
	if err := s.SyncOutgoing(ctx, "workflow", "wf_x",
		[]string{relationdomain.KindWorkflowUsesFunction},
		[]relationdomain.SyncEdge{
			{OtherKind: "function", OtherID: "fn_a", Kind: relationdomain.KindWorkflowUsesFunction},
			{OtherKind: "function", OtherID: "fn_b", Kind: relationdomain.KindWorkflowUsesFunction},
		}); err != nil {
		t.Fatalf("SyncOutgoing 1: %v", err)
	}
	// Re-sync with just fn_a — fn_b should disappear
	if err := s.SyncOutgoing(ctx, "workflow", "wf_x",
		[]string{relationdomain.KindWorkflowUsesFunction},
		[]relationdomain.SyncEdge{
			{OtherKind: "function", OtherID: "fn_a", Kind: relationdomain.KindWorkflowUsesFunction},
		}); err != nil {
		t.Fatalf("SyncOutgoing 2: %v", err)
	}
	rows, _, _, _ := s.List(ctx, relationdomain.Filter{FromKind: "workflow", FromID: "wf_x"}, "", 100)
	if len(rows) != 1 || rows[0].ToID != "fn_a" {
		t.Errorf("expected only fn_a remaining, got %+v", rows)
	}
}

func TestSyncOutgoing_UpdatesChangedAttrs(t *testing.T) {
	s := newTestService(t)
	ctx := testCtx()
	if err := s.SyncOutgoing(ctx, "workflow", "wf_x",
		[]string{relationdomain.KindWorkflowUsesFunction},
		[]relationdomain.SyncEdge{
			{OtherKind: "function", OtherID: "fn_y", Kind: relationdomain.KindWorkflowUsesFunction, Attrs: map[string]any{"nodeIds": []string{"n_1"}}},
		}); err != nil {
		t.Fatalf("SyncOutgoing 1: %v", err)
	}
	// Re-sync with same edge but different attrs (nodeIds now [n_1, n_5])
	if err := s.SyncOutgoing(ctx, "workflow", "wf_x",
		[]string{relationdomain.KindWorkflowUsesFunction},
		[]relationdomain.SyncEdge{
			{OtherKind: "function", OtherID: "fn_y", Kind: relationdomain.KindWorkflowUsesFunction, Attrs: map[string]any{"nodeIds": []string{"n_1", "n_5"}}},
		}); err != nil {
		t.Fatalf("SyncOutgoing 2: %v", err)
	}
	rows, _, _, _ := s.List(ctx, relationdomain.Filter{FromKind: "workflow", FromID: "wf_x"}, "", 100)
	if len(rows) != 1 {
		t.Fatalf("expected 1 row, got %d", len(rows))
	}
	got, _ := rows[0].Attrs["nodeIds"].([]any)
	if len(got) != 2 {
		t.Errorf("expected updated nodeIds=[n_1, n_5], got %v", rows[0].Attrs)
	}
}

// --- SyncIncoming ---

func TestSyncIncoming_EmptyEdgesRemovesExisting(t *testing.T) {
	s := newTestService(t)
	ctx := testCtx()
	// Write a forged edge to fn_x
	if err := s.SyncIncoming(ctx, "function", "fn_x",
		[]string{relationdomain.KindConversationEditedEntity},
		[]relationdomain.SyncEdge{
			{OtherKind: "conversation", OtherID: "cv_a", Kind: relationdomain.KindConversationEditedEntity},
		}); err != nil {
		t.Fatalf("SyncIncoming 1: %v", err)
	}
	// Re-sync with empty edges (suppress scenario: editor==origin)
	if err := s.SyncIncoming(ctx, "function", "fn_x",
		[]string{relationdomain.KindConversationEditedEntity},
		nil); err != nil {
		t.Fatalf("SyncIncoming 2: %v", err)
	}
	rows, _, _, _ := s.List(ctx, relationdomain.Filter{ToKind: "function", ToID: "fn_x"}, "", 100)
	if len(rows) != 0 {
		t.Errorf("expected 0 rows after empty re-sync, got %+v", rows)
	}
}

func TestSyncIncoming_RewriteOnDifferentFrom(t *testing.T) {
	s := newTestService(t)
	ctx := testCtx()
	// cv_a was the editor
	if err := s.SyncIncoming(ctx, "function", "fn_x",
		[]string{relationdomain.KindConversationEditedEntity},
		[]relationdomain.SyncEdge{
			{OtherKind: "conversation", OtherID: "cv_a", Kind: relationdomain.KindConversationEditedEntity},
		}); err != nil {
		t.Fatalf("SyncIncoming 1: %v", err)
	}
	// Now cv_b is the editor (revert scenario or new accept)
	if err := s.SyncIncoming(ctx, "function", "fn_x",
		[]string{relationdomain.KindConversationEditedEntity},
		[]relationdomain.SyncEdge{
			{OtherKind: "conversation", OtherID: "cv_b", Kind: relationdomain.KindConversationEditedEntity},
		}); err != nil {
		t.Fatalf("SyncIncoming 2: %v", err)
	}
	rows, _, _, _ := s.List(ctx, relationdomain.Filter{ToKind: "function", ToID: "fn_x"}, "", 100)
	if len(rows) != 1 || rows[0].FromID != "cv_b" {
		t.Errorf("expected sole edge from cv_b, got %+v", rows)
	}
}

// --- PurgeEntity ---

func TestPurgeEntity_CascadesAllDirections(t *testing.T) {
	s := newTestService(t)
	ctx := testCtx()
	// fn_x has: incoming forged from cv_a, incoming uses from wf_y
	_ = s.SyncIncoming(ctx, "function", "fn_x",
		[]string{relationdomain.KindConversationForgedEntity},
		[]relationdomain.SyncEdge{
			{OtherKind: "conversation", OtherID: "cv_a", Kind: relationdomain.KindConversationForgedEntity},
		})
	_ = s.SyncOutgoing(ctx, "workflow", "wf_y",
		[]string{relationdomain.KindWorkflowUsesFunction},
		[]relationdomain.SyncEdge{
			{OtherKind: "function", OtherID: "fn_x", Kind: relationdomain.KindWorkflowUsesFunction},
		})
	// Unrelated edge: wf_y → hd_y (should survive)
	_ = s.SyncOutgoing(ctx, "workflow", "wf_y",
		[]string{relationdomain.KindWorkflowUsesHandler},
		[]relationdomain.SyncEdge{
			{OtherKind: "handler", OtherID: "hd_y", Kind: relationdomain.KindWorkflowUsesHandler},
		})

	if err := s.PurgeEntity(ctx, "function", "fn_x"); err != nil {
		t.Fatalf("PurgeEntity: %v", err)
	}

	// fn_x should have no edges
	rowsIn, _, _, _ := s.List(ctx, relationdomain.Filter{ToKind: "function", ToID: "fn_x"}, "", 100)
	if len(rowsIn) != 0 {
		t.Errorf("expected 0 incoming to fn_x, got %d", len(rowsIn))
	}
	// wf_y → hd_y should survive
	rowsWf, _, _, _ := s.List(ctx, relationdomain.Filter{FromKind: "workflow", FromID: "wf_y"}, "", 100)
	if len(rowsWf) != 1 || rowsWf[0].ToID != "hd_y" {
		t.Errorf("expected wf_y → hd_y survives, got %+v", rowsWf)
	}
}

// --- Validation ---

func TestSyncOutgoing_RejectsSelfLoop(t *testing.T) {
	s := newTestService(t)
	ctx := testCtx()
	err := s.SyncOutgoing(ctx, "function", "fn_x",
		[]string{relationdomain.KindDocumentLinksEntity},
		[]relationdomain.SyncEdge{
			{OtherKind: "function", OtherID: "fn_x", Kind: relationdomain.KindDocumentLinksEntity},
		})
	if !errors.Is(err, relationdomain.ErrSelfLoop) {
		t.Errorf("expected ErrSelfLoop, got %v", err)
	}
}

func TestSyncOutgoing_RejectsInvalidKind(t *testing.T) {
	s := newTestService(t)
	ctx := testCtx()
	err := s.SyncOutgoing(ctx, "workflow", "wf_x",
		[]string{"not_a_kind"},
		nil)
	if !errors.Is(err, relationdomain.ErrInvalidKind) {
		t.Errorf("expected ErrInvalidKind, got %v", err)
	}
}

func TestList_RejectsIncompleteFilter(t *testing.T) {
	s := newTestService(t)
	ctx := testCtx()
	// fromKind given but no fromId
	_, _, _, err := s.List(ctx, relationdomain.Filter{FromKind: "workflow"}, "", 100)
	if !errors.Is(err, relationdomain.ErrIncompleteFilter) {
		t.Errorf("expected ErrIncompleteFilter, got %v", err)
	}
}

func TestNeighborhood_RejectsBadDepth(t *testing.T) {
	s := newTestService(t)
	ctx := testCtx()
	if _, err := s.Neighborhood(ctx, "workflow", "wf_x", 0); !errors.Is(err, relationdomain.ErrDepthOutOfRange) {
		t.Errorf("depth=0: expected ErrDepthOutOfRange, got %v", err)
	}
	if _, err := s.Neighborhood(ctx, "workflow", "wf_x", 4); !errors.Is(err, relationdomain.ErrDepthOutOfRange) {
		t.Errorf("depth=4: expected ErrDepthOutOfRange, got %v", err)
	}
}

// --- Neighborhood BFS ---

func TestNeighborhood_RespectsDepthLimit(t *testing.T) {
	s := newTestService(t)
	ctx := testCtx()
	// Build chain: doc_a → fn_b → wf_c (via doc_links + workflow_uses)
	// Hop 1: doc_a → fn_b (out)  AND  fn_b → doc_a (in)
	// Hop 2: wf_c → fn_b (in from wf_c)
	_ = s.SyncOutgoing(ctx, "document", "doc_a",
		[]string{relationdomain.KindDocumentLinksEntity},
		[]relationdomain.SyncEdge{
			{OtherKind: "function", OtherID: "fn_b", Kind: relationdomain.KindDocumentLinksEntity},
		})
	_ = s.SyncOutgoing(ctx, "workflow", "wf_c",
		[]string{relationdomain.KindWorkflowUsesFunction},
		[]relationdomain.SyncEdge{
			{OtherKind: "function", OtherID: "fn_b", Kind: relationdomain.KindWorkflowUsesFunction},
		})

	// Depth 1 from doc_a: just doc_a → fn_b
	rows1, err := s.Neighborhood(ctx, "document", "doc_a", 1)
	if err != nil {
		t.Fatalf("Neighborhood d=1: %v", err)
	}
	if len(rows1) != 1 {
		t.Errorf("d=1: expected 1 edge, got %d", len(rows1))
	}

	// Depth 2 from doc_a: doc_a → fn_b + fn_b ← wf_c (via incoming on fn_b)
	rows2, err := s.Neighborhood(ctx, "document", "doc_a", 2)
	if err != nil {
		t.Fatalf("Neighborhood d=2: %v", err)
	}
	if len(rows2) != 2 {
		t.Errorf("d=2: expected 2 edges, got %d: %+v", len(rows2), rows2)
	}
}

// --- GetRelgraph ---

type stubReader struct{ metas []EntityMeta }

func (s *stubReader) ListAllMeta(ctx context.Context, userID string) ([]EntityMeta, error) {
	return s.metas, nil
}

type stubConvReader struct{ metas map[string]EntityMeta }

func (s *stubConvReader) GetMetaBatch(ctx context.Context, userID string, ids []string) ([]EntityMeta, error) {
	out := make([]EntityMeta, 0, len(ids))
	for _, id := range ids {
		if m, ok := s.metas[id]; ok {
			out = append(out, m)
		}
	}
	return out, nil
}

func TestRelgraph_OmitsOrphanConversations(t *testing.T) {
	functionStub := &stubReader{metas: []EntityMeta{{ID: "fn_x", Label: "do thing"}}}
	convStub := &stubConvReader{metas: map[string]EntityMeta{
		"cv_referenced": {ID: "cv_referenced", Label: "Conv A"},
		"cv_orphan":     {ID: "cv_orphan", Label: "Conv B"},
	}}
	s := newTestService(t, func(c *Config) {
		c.FunctionReader = functionStub
		c.ConversationReader = convStub
	})
	ctx := testCtx()

	// Only cv_referenced has an edge to fn_x
	_ = s.SyncIncoming(ctx, "function", "fn_x",
		[]string{relationdomain.KindConversationForgedEntity},
		[]relationdomain.SyncEdge{
			{OtherKind: "conversation", OtherID: "cv_referenced", Kind: relationdomain.KindConversationForgedEntity},
		})

	snap, err := s.GetRelgraph(ctx)
	if err != nil {
		t.Fatalf("GetRelgraph: %v", err)
	}

	convNodes := []relationdomain.GraphNode{}
	fnNodes := []relationdomain.GraphNode{}
	for _, n := range snap.Nodes {
		if n.Kind == "conversation" {
			convNodes = append(convNodes, n)
		}
		if n.Kind == "function" {
			fnNodes = append(fnNodes, n)
		}
	}
	if len(convNodes) != 1 || convNodes[0].ID != "cv_referenced" {
		t.Errorf("expected only cv_referenced (orphan dropped), got %+v", convNodes)
	}
	if len(fnNodes) != 1 || fnNodes[0].ID != "fn_x" {
		t.Errorf("expected fn_x as orphan-included function node, got %+v", fnNodes)
	}
	if len(snap.Edges) != 1 {
		t.Errorf("expected 1 edge in snapshot, got %d", len(snap.Edges))
	}
}

func TestRelgraph_IncludesNonConversationOrphans(t *testing.T) {
	functionStub := &stubReader{metas: []EntityMeta{
		{ID: "fn_used", Label: "used one"},
		{ID: "fn_orphan", Label: "orphan one"},
	}}
	s := newTestService(t, func(c *Config) {
		c.FunctionReader = functionStub
	})
	ctx := testCtx()

	// Only fn_used has any edge (none here actually, but the contract is functions
	// always appear; let's verify no edges and 2 fn nodes)
	snap, err := s.GetRelgraph(ctx)
	if err != nil {
		t.Fatalf("GetRelgraph: %v", err)
	}
	fnNodes := 0
	for _, n := range snap.Nodes {
		if n.Kind == "function" {
			fnNodes++
		}
	}
	if fnNodes != 2 {
		t.Errorf("expected both function nodes (orphans included), got %d", fnNodes)
	}
}
