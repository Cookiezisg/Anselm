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
	conversationstore "github.com/sunweilin/anselm/backend/internal/infra/store/conversation"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// fakeEmitter records every Emit so tests assert the broadcast action without a real bus.
//
// fakeEmitter 记录每次 Emit，使测试断言广播动作而无需真 bus。
type fakeEmitter struct{ events []string }

func (f *fakeEmitter) Emit(_ context.Context, eventType string, _ map[string]any) error {
	f.events = append(f.events, eventType)
	return nil
}

func (f *fakeEmitter) last() string {
	if len(f.events) == 0 {
		return ""
	}
	return f.events[len(f.events)-1]
}

// fakeRelations records PurgeEntity calls.
//
// fakeRelations 记录 PurgeEntity 调用。
type fakeRelations struct{ purged []string }

func (f *fakeRelations) PurgeEntity(_ context.Context, kind, id string) error {
	f.purged = append(f.purged, kind+":"+id)
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
