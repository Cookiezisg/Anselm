package conversation

import (
	"context"
	"database/sql"
	"errors"
	"testing"

	_ "github.com/glebarez/go-sqlite"
	"go.uber.org/zap"

	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	documentdomain "github.com/sunweilin/anselm/backend/internal/domain/document"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
	conversationstore "github.com/sunweilin/anselm/backend/internal/infra/store/conversation"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// fakeEmitter records every event so tests assert the action without a real bus. events
// holds both tiers (what fired); persisted / broadcast split them so a test can prove a
// conversation event took the frame-only tier (no inbox row).
//
// fakeEmitter 记录每次事件，使测试断言动作而无需真 bus。events 含两档（何事发生）；persisted /
// broadcast 分档，使测试能证明 conversation 事件走了仅帧径（不落收件箱行）。
type fakeEmitter struct {
	events    []string
	persisted []string
	broadcast []string
}

func (f *fakeEmitter) Emit(_ context.Context, eventType string, _ map[string]any) error {
	f.events = append(f.events, eventType)
	f.persisted = append(f.persisted, eventType)
	return nil
}

func (f *fakeEmitter) Broadcast(_ context.Context, eventType string, _ map[string]any) error {
	f.events = append(f.events, eventType)
	f.broadcast = append(f.broadcast, eventType)
	return nil
}

func (f *fakeEmitter) last() string {
	if len(f.events) == 0 {
		return ""
	}
	return f.events[len(f.events)-1]
}

// fakeRelations records PurgeEntity and SyncIncoming calls.
//
// fakeRelations 记录 PurgeEntity 与 SyncIncoming 调用。
type fakeRelations struct {
	purged   []string
	incoming []syncCall
}

// syncCall is one recorded SyncIncoming: fixed endpoint + kind scope + edges — the three things the
// fork lineage edge must get exactly right (writing it from the SOURCE's outgoing side instead
// would wipe every entity that conversation ever built).
//
// syncCall 是一次记录下来的 SyncIncoming：固定端 + kind 范围 + 边——分叉血缘边必须分毫不差的三件事
// （改从**源**的出向侧写会抹掉该对话曾建过的所有实体）。
type syncCall struct {
	toKind, toID string
	kindScope    []string
	edges        []relationdomain.SyncEdge
}

func (f *fakeRelations) PurgeEntity(_ context.Context, kind, id string) error {
	f.purged = append(f.purged, kind+":"+id)
	return nil
}

func (f *fakeRelations) SyncIncoming(_ context.Context, toKind, toID string, kindScope []string, edges []relationdomain.SyncEdge) error {
	f.incoming = append(f.incoming, syncCall{toKind: toKind, toID: toID, kindScope: kindScope, edges: edges})
	return nil
}

// fakeTouchpoints records the ledger cascade. fakeTouchpoints 记录台账级联调用。
type fakeTouchpoints struct{ purged []string }

func (f *fakeTouchpoints) PurgeConversation(_ context.Context, id string) error {
	f.purged = append(f.purged, id)
	return nil
}

// newSvc wires the Service over a real in-memory store + fakes, so the tests exercise the full
// app→store→orm stack offline (JSON round-trip, soft-delete, isolation).
//
// newSvc 把 Service 接在真 in-memory store + fake 上，使测试离线走全栈 app→store→orm。
func newSvc(t *testing.T) (*Service, *fakeEmitter, *fakeRelations, context.Context) {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range conversationstore.Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	em := &fakeEmitter{}
	svc := NewService(conversationstore.New(ormpkg.Open(sqlDB)), em, zap.NewNop())
	rel := &fakeRelations{}
	svc.SetRelationSyncer(rel)
	svc.SetTouchpointPurger(&fakeTouchpoints{})
	return svc, em, rel, reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")
}

func TestCreate_TrimsTitle_EmitsCreated(t *testing.T) {
	svc, em, _, ctx := newSvc(t)
	c, err := svc.Create(ctx, "  Hi  ")
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if c.Title != "Hi" {
		t.Errorf("title not trimmed: %q", c.Title)
	}
	if len(c.ID) < 3 || c.ID[:3] != "cv_" {
		t.Errorf("id prefix: %s", c.ID)
	}
	if len(em.events) != 1 || em.events[0] != "conversation.created" {
		t.Errorf("events = %v", em.events)
	}
	// N0 fork: every conversation lifecycle event is a rail reconciliation echo — it takes
	// the frame-only tier (a live signal) and leaves NO inbox row. N0 分径:对话事件仅帧、不落行。
	if len(em.broadcast) != 1 || em.broadcast[0] != "conversation.created" {
		t.Errorf("conversation.created must broadcast (frame-only), got broadcast=%v", em.broadcast)
	}
	if len(em.persisted) != 0 {
		t.Errorf("conversation events must NOT persist an inbox row, got persisted=%v", em.persisted)
	}
}

type fakeQuerier struct{ generating map[string]bool }

func (f fakeQuerier) IsGenerating(id string) bool { return f.generating[id] }

// TestDerivesIsGenerating: Get/List fill the derived IsGenerating from the injected querier; with
// no querier wired it stays false (never crashes, never invents state).
func TestDerivesIsGenerating(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	a, _ := svc.Create(ctx, "a")
	b, _ := svc.Create(ctx, "b")
	svc.SetGeneratingQuerier(fakeQuerier{generating: map[string]bool{a.ID: true}})

	ga, _ := svc.Get(ctx, a.ID)
	gb, _ := svc.Get(ctx, b.ID)
	if !ga.IsGenerating || gb.IsGenerating {
		t.Errorf("Get: a=%v b=%v, want a=true b=false", ga.IsGenerating, gb.IsGenerating)
	}
	rows, _, err := svc.List(ctx, ListFilter{})
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	for _, c := range rows {
		if want := c.ID == a.ID; c.IsGenerating != want {
			t.Errorf("List: %s isGenerating=%v want %v", c.ID, c.IsGenerating, want)
		}
	}

	// PATCH must also return the accurate derived flag — pinning a generating conversation must not
	// return a stale isGenerating=false.
	pin := true
	if up, err := svc.Update(ctx, a.ID, UpdateInput{Pinned: &pin}); err != nil {
		t.Fatalf("update: %v", err)
	} else if !up.IsGenerating {
		t.Error("Update: PATCH on a generating conversation must return isGenerating=true")
	}

	// No querier wired (default) → derived flag stays false, no panic.
	svc2, _, _, ctx2 := newSvc(t)
	c, _ := svc2.Create(ctx2, "c")
	if gc, _ := svc2.Get(ctx2, c.ID); gc.IsGenerating {
		t.Error("nil querier → IsGenerating must be false")
	}
}

func TestCreateWithSystemPrompt(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	c, err := svc.CreateWithSystemPrompt(ctx, "", "You are helpful")
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if c.SystemPrompt != "You are helpful" {
		t.Errorf("sysprompt = %q", c.SystemPrompt)
	}
}

func TestUpdate_ModelOverride_SetThenClear(t *testing.T) {
	svc, em, _, ctx := newSvc(t)
	c, _ := svc.Create(ctx, "t")

	set := &modeldomain.ModelRef{APIKeyID: "aki_1", ModelID: "m1"}
	got, err := svc.Update(ctx, c.ID, UpdateInput{ModelOverride: &set})
	if err != nil {
		t.Fatalf("set: %v", err)
	}
	if got.ModelOverride == nil || got.ModelOverride.ModelID != "m1" {
		t.Errorf("set: %+v", got.ModelOverride)
	}
	if em.last() != "conversation.model_override" {
		t.Errorf("set event = %v", em.events)
	}

	var none *modeldomain.ModelRef // &nil = explicit clear
	got, err = svc.Update(ctx, c.ID, UpdateInput{ModelOverride: &none})
	if err != nil {
		t.Fatalf("clear: %v", err)
	}
	if got.ModelOverride != nil {
		t.Errorf("clear: %+v", got.ModelOverride)
	}
}

func TestUpdate_InvalidModelOverride(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	c, _ := svc.Create(ctx, "t")
	bad := &modeldomain.ModelRef{APIKeyID: "aki_1"} // missing modelId
	if _, err := svc.Update(ctx, c.ID, UpdateInput{ModelOverride: &bad}); !errors.Is(err, conversationdomain.ErrInvalidModelOverride) {
		t.Errorf("err = %v, want ErrInvalidModelOverride", err)
	}
}

func TestUpdate_PinThenArchive_EmitActions(t *testing.T) {
	svc, em, _, ctx := newSvc(t)
	c, _ := svc.Create(ctx, "t")
	yes := true
	if _, err := svc.Update(ctx, c.ID, UpdateInput{Pinned: &yes}); err != nil {
		t.Fatal(err)
	}
	if em.last() != "conversation.pinned" {
		t.Errorf("pin event = %v", em.events)
	}
	if _, err := svc.Update(ctx, c.ID, UpdateInput{Archived: &yes}); err != nil {
		t.Fatal(err)
	}
	if em.last() != "conversation.archived" {
		t.Errorf("archive event = %v", em.events)
	}
}

func TestUpdate_NotFound(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	title := "x"
	if _, err := svc.Update(ctx, "cv_missing", UpdateInput{Title: &title}); !errors.Is(err, conversationdomain.ErrNotFound) {
		t.Errorf("err = %v, want ErrNotFound", err)
	}
}

func TestDelete_EmitsAndPurges(t *testing.T) {
	svc, em, rel, ctx := newSvc(t)
	c, _ := svc.Create(ctx, "t")
	if err := svc.Delete(ctx, c.ID); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if em.last() != "conversation.deleted" {
		t.Errorf("delete event = %v", em.events)
	}
	if len(rel.purged) != 1 || rel.purged[0] != "conversation:"+c.ID {
		t.Errorf("purged = %v", rel.purged)
	}
	if tpp, ok := svc.touchpoints.(*fakeTouchpoints); !ok || len(tpp.purged) != 1 || tpp.purged[0] != c.ID {
		t.Errorf("touchpoint cascade = %+v", svc.touchpoints)
	}
	if _, err := svc.Get(ctx, c.ID); !errors.Is(err, conversationdomain.ErrNotFound) {
		t.Errorf("get after delete = %v, want ErrNotFound", err)
	}
}

func TestNamesByIDs_LabelFallback(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	titled, _ := svc.Create(ctx, "My Thread")
	untitled, _ := svc.Create(ctx, "")
	names, err := svc.NamesByIDs(ctx, []string{titled.ID, untitled.ID})
	if err != nil {
		t.Fatalf("names: %v", err)
	}
	if names[titled.ID] != "My Thread" {
		t.Errorf("titled label = %q", names[titled.ID])
	}
	if names[untitled.ID] != "(未命名对话)" {
		t.Errorf("untitled label = %q", names[untitled.ID])
	}
}

func TestSetSummary_PersistsAndEmits(t *testing.T) {
	svc, em, _, ctx := newSvc(t)
	c, _ := svc.Create(ctx, "Thread")

	if err := svc.SetSummary(ctx, c.ID, "the running summary", 42); err != nil {
		t.Fatalf("SetSummary: %v", err)
	}

	got, err := svc.Get(ctx, c.ID)
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if got.Summary != "the running summary" || got.SummaryCoversUpToSeq != 42 {
		t.Fatalf("summary/watermark not persisted: %q / %d", got.Summary, got.SummaryCoversUpToSeq)
	}
	if em.last() != "conversation.compacted" {
		t.Fatalf("expected conversation.compacted emit, got %q", em.last())
	}
}

type fakeDocResolver struct{ known map[string]bool }

func (f fakeDocResolver) ResolveAttached(_ context.Context, atts []documentdomain.AttachedDocument) ([]*documentdomain.Document, error) {
	var out []*documentdomain.Document
	for _, a := range atts {
		if f.known[a.DocumentID] {
			out = append(out, &documentdomain.Document{ID: a.DocumentID})
		}
	}
	return out, nil
}

// TestUpdate_AttachedDocuments_RejectsDangling pins F168-M5: attaching a doc id that does not exist is
// rejected 422 at attach time (not silently accepted); a known id and an empty (clearing) list succeed.
func TestUpdate_AttachedDocuments_RejectsDangling(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	svc.SetDocumentResolver(fakeDocResolver{known: map[string]bool{"doc_ok": true}})
	c, _ := svc.Create(ctx, "t")

	bad := []documentdomain.AttachedDocument{{DocumentID: "doc_missing"}}
	if _, err := svc.Update(ctx, c.ID, UpdateInput{AttachedDocuments: &bad}); !errors.Is(err, conversationdomain.ErrAttachedDocumentNotFound) {
		t.Fatalf("dangling attach must be rejected (F168-M5), got %v", err)
	}
	good := []documentdomain.AttachedDocument{{DocumentID: "doc_ok"}}
	if got, err := svc.Update(ctx, c.ID, UpdateInput{AttachedDocuments: &good}); err != nil || len(got.AttachedDocuments) != 1 {
		t.Fatalf("known attach must succeed: %v %+v", err, got)
	}
	empty := []documentdomain.AttachedDocument{}
	if _, err := svc.Update(ctx, c.ID, UpdateInput{AttachedDocuments: &empty}); err != nil {
		t.Fatalf("clearing attachments must succeed, got %v", err)
	}
}

// TestUpdate_AttachedDocuments_NilResolverSkips: without a resolver wired, no attach-time check runs
// (the F167 render-time warning backstops); the attach is accepted unchecked.
func TestUpdate_AttachedDocuments_NilResolverSkips(t *testing.T) {
	svc, _, _, ctx := newSvc(t) // no SetDocumentResolver
	c, _ := svc.Create(ctx, "t")
	any := []documentdomain.AttachedDocument{{DocumentID: "doc_unchecked"}}
	if _, err := svc.Update(ctx, c.ID, UpdateInput{AttachedDocuments: &any}); err != nil {
		t.Fatalf("nil resolver must skip validation, got %v", err)
	}
}

type fakeKeyChecker struct{ known map[string]bool }

func (f fakeKeyChecker) KeyExists(_ context.Context, id string) error {
	if f.known[id] {
		return nil
	}
	return apikeydomain.ErrNotFound
}

// TestUpdate_RejectsDanglingModelOverrideKey pins F153 for the conversation override write path: a
// modelOverride PATCH pointing at a non-existent apiKeyId is rejected at WRITE (API_KEY_NOT_FOUND, was
// only at chat time); a real key passes; clearing (&nil) skips existence.
func TestUpdate_RejectsDanglingModelOverrideKey(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	svc.SetKeyChecker(fakeKeyChecker{known: map[string]bool{"aki_real": true}})
	c, _ := svc.Create(ctx, "t")

	bad := &modeldomain.ModelRef{APIKeyID: "aki_deadbeef", ModelID: "m"}
	if _, err := svc.Update(ctx, c.ID, UpdateInput{ModelOverride: &bad}); !errors.Is(err, apikeydomain.ErrNotFound) {
		t.Fatalf("dangling apiKeyId must reject at write with API_KEY_NOT_FOUND, got %v", err)
	}
	good := &modeldomain.ModelRef{APIKeyID: "aki_real", ModelID: "deepseek-typo"}
	if _, err := svc.Update(ctx, c.ID, UpdateInput{ModelOverride: &good}); err != nil {
		t.Fatalf("a real apiKeyId must pass even with a typo'd modelId: %v", err)
	}
	var clear *modeldomain.ModelRef // &nil = clear
	if _, err := svc.Update(ctx, c.ID, UpdateInput{ModelOverride: &clear}); err != nil {
		t.Fatalf("clearing (&nil) must skip existence, got %v", err)
	}
}

// TestFork_HeadCopiesConfigStampsLineageAndCarriesSummary: the head half of a fork. Config the fork
// runtime needs (systemPrompt / attachedDocuments / modelOverride) is copied verbatim; the shelf
// state (archived / pinned) is NOT (a fork is a thread you just opened); the title gets the fixed
// suffix with AutoTitled left false so chat's auto-titler is not fooled into thinking the name is
// its own; the lineage pair is stamped; and the caller's summary-carry decision is applied as given
// (the branch itself is chat's — it owns the message rows the watermark indexes).
func TestFork_HeadCopiesConfigStampsLineageAndCarriesSummary(t *testing.T) {
	svc, em, rel, ctx := newSvc(t)
	svc.SetDocumentResolver(fakeDocResolver{known: map[string]bool{"doc_ok": true}})
	src, _ := svc.Create(ctx, "Original")
	atts := []documentdomain.AttachedDocument{{DocumentID: "doc_ok"}}
	ref := &modeldomain.ModelRef{APIKeyID: "aki_1", ModelID: "m"}
	prompt := "be concise"
	pinned, archived := true, true
	src, err := svc.Update(ctx, src.ID, UpdateInput{
		SystemPrompt: &prompt, AttachedDocuments: &atts, ModelOverride: &ref,
		Pinned: &pinned, Archived: &archived,
	})
	if err != nil {
		t.Fatalf("seed source: %v", err)
	}

	fork, err := svc.Fork(ctx, conversationdomain.ForkInput{
		Source: src, AtMessageID: "msg_cut", Summary: "older turns", SummaryCoversUpToSeq: 4,
	})
	if err != nil {
		t.Fatalf("fork: %v", err)
	}
	if fork.ID == src.ID || fork.ID[:3] != "cv_" {
		t.Fatalf("fork must be a NEW cv_ row, got %q (source %q)", fork.ID, src.ID)
	}
	if fork.Title != "Original (fork)" || fork.AutoTitled {
		t.Errorf("title/autoTitled = %q/%v, want %q/false", fork.Title, fork.AutoTitled, "Original (fork)")
	}
	if fork.SystemPrompt != prompt || len(fork.AttachedDocuments) != 1 || fork.ModelOverride == nil ||
		fork.ModelOverride.APIKeyID != "aki_1" {
		t.Errorf("runtime config not copied: %+v", fork)
	}
	if fork.Pinned || fork.Archived {
		t.Errorf("shelf state must NOT travel: pinned=%v archived=%v", fork.Pinned, fork.Archived)
	}
	if fork.ForkedFromConversationID != src.ID || fork.ForkedFromMessageID != "msg_cut" {
		t.Errorf("lineage = %q/%q, want %q/%q",
			fork.ForkedFromConversationID, fork.ForkedFromMessageID, src.ID, "msg_cut")
	}
	if fork.Summary != "older turns" || fork.SummaryCoversUpToSeq != 4 {
		t.Errorf("summary carry not applied as given: %q/%d", fork.Summary, fork.SummaryCoversUpToSeq)
	}
	// The row must READ BACK the same (the two columns are real, not just struct fields).
	back, err := svc.Get(ctx, fork.ID)
	if err != nil || back.ForkedFromConversationID != src.ID || back.ForkedFromMessageID != "msg_cut" {
		t.Fatalf("lineage must round-trip through the columns: %v %+v", err, back)
	}
	// The source is untouched — a fork is pure append.
	if again, _ := svc.Get(ctx, src.ID); again.Title != "Original" || again.ForkedFromConversationID != "" {
		t.Errorf("source must be untouched: %+v", again)
	}
	if em.last() != "conversation.created" {
		t.Errorf("fork must emit conversation.created so the rail grows the row, got %q", em.last())
	}
	// Lineage edge: `create`, from the SOURCE into the FORK, keyed on the FORK's incoming side.
	if len(rel.incoming) != 1 {
		t.Fatalf("want exactly one SyncIncoming, got %+v", rel.incoming)
	}
	got := rel.incoming[0]
	if got.toKind != relationdomain.EntityKindConversation || got.toID != fork.ID {
		t.Errorf("edge must be keyed on the FORK's incoming side, got %s:%s", got.toKind, got.toID)
	}
	if len(got.kindScope) != 1 || got.kindScope[0] != relationdomain.KindCreate {
		t.Errorf("kindScope = %v, want [create]", got.kindScope)
	}
	if len(got.edges) != 1 || got.edges[0].OtherID != src.ID ||
		got.edges[0].OtherKind != relationdomain.EntityKindConversation ||
		got.edges[0].Kind != relationdomain.KindCreate {
		t.Errorf("edge = %+v, want create from conversation %s", got.edges, src.ID)
	}
}

// TestFork_UntitledSourceStaysUntitled: a bare "(fork)" would be a name that says nothing, so an
// untitled source yields an untitled fork and chat's auto-titler still gets its turn.
func TestFork_UntitledSourceStaysUntitled(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	src, _ := svc.Create(ctx, "   ")
	fork, err := svc.Fork(ctx, conversationdomain.ForkInput{Source: src})
	if err != nil {
		t.Fatalf("fork: %v", err)
	}
	if fork.Title != "" || fork.AutoTitled {
		t.Errorf("title/autoTitled = %q/%v, want empty/false", fork.Title, fork.AutoTitled)
	}
}
