package conversation

import (
	"context"
	"errors"
	"strings"
	"testing"

	"go.uber.org/zap"

	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	convdomain "github.com/sunweilin/forgify/backend/internal/domain/conversation"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// fakeKeys is a minimal KeyProvider stub; byID drives ResolveCredentialsByID
// so §12.3 F1 ModelOverride validation can match real existence checks.
//
// fakeKeys 是最小 KeyProvider 桩；byID 驱动 ResolveCredentialsByID,
// §12.3 F1 ModelOverride 校验依此匹配真实"key 是否存在"语义。
type fakeKeys struct {
	byID map[string]apikeydomain.Credentials
}

func (k *fakeKeys) ResolveCredentialsByID(_ context.Context, id string) (apikeydomain.Credentials, error) {
	if k.byID == nil {
		return apikeydomain.Credentials{}, apikeydomain.ErrNotFound
	}
	c, ok := k.byID[id]
	if !ok {
		return apikeydomain.Credentials{}, apikeydomain.ErrNotFound
	}
	return c, nil
}

func (k *fakeKeys) ResolveCredentials(_ context.Context, _ string) (apikeydomain.Credentials, error) {
	return apikeydomain.Credentials{}, nil
}

func (k *fakeKeys) MarkInvalid(_ context.Context, _, _ string) error           { return nil }
func (k *fakeKeys) HasKeyForProvider(_ context.Context, _ string) (bool, error) { return true, nil }
func (k *fakeKeys) DefaultSearchProvider(_ context.Context) string             { return "" }

type fakeRepo struct {
	rows map[string]*convdomain.Conversation
}

func newFakeRepo() *fakeRepo {
	return &fakeRepo{rows: make(map[string]*convdomain.Conversation)}
}

func (r *fakeRepo) Save(_ context.Context, c *convdomain.Conversation) error {
	cp := *c
	r.rows[c.ID] = &cp
	return nil
}

func (r *fakeRepo) Get(ctx context.Context, id string) (*convdomain.Conversation, error) {
	uid, _ := reqctxpkg.GetUserID(ctx)
	c, ok := r.rows[id]
	if !ok || c.UserID != uid {
		return nil, convdomain.ErrNotFound
	}
	cp := *c
	return &cp, nil
}

func (r *fakeRepo) List(ctx context.Context, _ convdomain.ListFilter) ([]*convdomain.Conversation, string, error) {
	uid, _ := reqctxpkg.GetUserID(ctx)
	var out []*convdomain.Conversation
	for _, c := range r.rows {
		if c.UserID == uid {
			cp := *c
			out = append(out, &cp)
		}
	}
	return out, "", nil
}

func (r *fakeRepo) Delete(ctx context.Context, id string) error {
	uid, _ := reqctxpkg.GetUserID(ctx)
	c, ok := r.rows[id]
	if !ok || c.UserID != uid {
		return convdomain.ErrNotFound
	}
	delete(r.rows, id)
	return nil
}

func ctxAlice() context.Context {
	return reqctxpkg.SetUserID(context.Background(), "u-alice")
}

func newSvc(t *testing.T) *Service {
	t.Helper()
	return NewService(newFakeRepo(), nil, zap.NewNop())
}

func TestNewService_NilLogger_Panics(t *testing.T) {
	defer func() {
		if r := recover(); r == nil {
			t.Error("expected panic, got none")
		}
	}()
	NewService(newFakeRepo(), nil, nil)
}

func TestCreate_Success(t *testing.T) {
	svc := newSvc(t)
	c, err := svc.Create(ctxAlice(), "My First Chat")
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	if !strings.HasPrefix(c.ID, "cv_") {
		t.Errorf("ID = %q, want cv_ prefix", c.ID)
	}
	if c.Title != "My First Chat" {
		t.Errorf("Title = %q, want My First Chat", c.Title)
	}
}

func TestCreate_EmptyTitleAllowed(t *testing.T) {
	svc := newSvc(t)
	c, err := svc.Create(ctxAlice(), "")
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	if c.Title != "" {
		t.Errorf("Title = %q, want empty", c.Title)
	}
}

func TestCreate_TrimsTitleWhitespace(t *testing.T) {
	svc := newSvc(t)
	c, _ := svc.Create(ctxAlice(), "  Hello  ")
	if c.Title != "Hello" {
		t.Errorf("Title = %q, want Hello", c.Title)
	}
}

func TestCreate_MissingUserID(t *testing.T) {
	svc := newSvc(t)
	_, err := svc.Create(context.Background(), "test")
	if err == nil {
		t.Fatal("want error, got nil")
	}
}

func TestRename_Success(t *testing.T) {
	svc := newSvc(t)
	ctx := ctxAlice()
	c, _ := svc.Create(ctx, "Old")
	updated, err := svc.Rename(ctx, c.ID, "New Title")
	if err != nil {
		t.Fatalf("Rename: %v", err)
	}
	if updated.Title != "New Title" {
		t.Errorf("Title = %q, want New Title", updated.Title)
	}
	// `After` (strict >) flakes on same-microsecond ticks; `!Before` is the real semantic.
	if updated.UpdatedAt.Before(c.UpdatedAt) {
		t.Error("UpdatedAt regressed")
	}
}

func TestRename_NotFound(t *testing.T) {
	svc := newSvc(t)
	_, err := svc.Rename(ctxAlice(), "nonexistent", "New")
	if !errors.Is(err, convdomain.ErrNotFound) {
		t.Errorf("got %v, want ErrNotFound", err)
	}
}

func TestDelete_Success(t *testing.T) {
	svc := newSvc(t)
	ctx := ctxAlice()
	c, _ := svc.Create(ctx, "test")
	if err := svc.Delete(ctx, c.ID); err != nil {
		t.Fatalf("Delete: %v", err)
	}
}

func TestDelete_NotFound(t *testing.T) {
	svc := newSvc(t)
	err := svc.Delete(ctxAlice(), "nope")
	if !errors.Is(err, convdomain.ErrNotFound) {
		t.Errorf("got %v, want ErrNotFound", err)
	}
}

func TestList_AfterCreate(t *testing.T) {
	svc := newSvc(t)
	ctx := ctxAlice()
	svc.Create(ctx, "A")
	svc.Create(ctx, "B")
	rows, _, err := svc.List(ctx, convdomain.ListFilter{Limit: 10})
	if err != nil {
		t.Fatalf("List: %v", err)
	}
	if len(rows) != 2 {
		t.Errorf("got %d rows, want 2", len(rows))
	}
}

// §12.3 ModelOverride tests.

func newSvcWithKeys(t *testing.T, byID map[string]apikeydomain.Credentials) *Service {
	t.Helper()
	svc := NewService(newFakeRepo(), nil, zap.NewNop())
	svc.SetKeyProvider(&fakeKeys{byID: byID})
	return svc
}

func validKeys() map[string]apikeydomain.Credentials {
	return map[string]apikeydomain.Credentials{
		"aki_test": {Provider: "deepseek", Key: "sk-test", BaseURL: ""},
	}
}

func TestUpdate_ModelOverride_SetSucceeds(t *testing.T) {
	svc := newSvcWithKeys(t, validKeys())
	ctx := ctxAlice()
	c, _ := svc.Create(ctx, "X")
	ref := &modeldomain.ModelRef{APIKeyID: "aki_test", ModelID: "deepseek-reasoner"}
	out, err := svc.Update(ctx, c.ID, UpdateInput{ModelOverride: &ref})
	if err != nil {
		t.Fatalf("Update: %v", err)
	}
	if out.ModelOverride == nil || out.ModelOverride.APIKeyID != "aki_test" || out.ModelOverride.ModelID != "deepseek-reasoner" {
		t.Errorf("ModelOverride wrong: %+v", out.ModelOverride)
	}
}

func TestUpdate_ModelOverride_NoKey_Returns404Sentinel(t *testing.T) {
	svc := newSvcWithKeys(t, validKeys())
	ctx := ctxAlice()
	c, _ := svc.Create(ctx, "X")
	ref := &modeldomain.ModelRef{APIKeyID: "aki_missing", ModelID: "claude-opus-4-7"}
	_, err := svc.Update(ctx, c.ID, UpdateInput{ModelOverride: &ref})
	if !errors.Is(err, apikeydomain.ErrNotFound) {
		t.Errorf("got %v, want apikeydomain.ErrNotFound", err)
	}
}

func TestUpdate_ModelOverride_Clear(t *testing.T) {
	svc := newSvcWithKeys(t, validKeys())
	ctx := ctxAlice()
	c, _ := svc.Create(ctx, "X")
	ref := &modeldomain.ModelRef{APIKeyID: "aki_test", ModelID: "deepseek-reasoner"}
	if _, err := svc.Update(ctx, c.ID, UpdateInput{ModelOverride: &ref}); err != nil {
		t.Fatalf("seed: %v", err)
	}
	var nilRef *modeldomain.ModelRef
	out, err := svc.Update(ctx, c.ID, UpdateInput{ModelOverride: &nilRef})
	if err != nil {
		t.Fatalf("Update: %v", err)
	}
	if out.ModelOverride != nil {
		t.Errorf("ModelOverride should be cleared, got %+v", out.ModelOverride)
	}
}

func TestUpdate_ModelOverride_MissingAPIKeyID(t *testing.T) {
	svc := newSvcWithKeys(t, validKeys())
	ctx := ctxAlice()
	c, _ := svc.Create(ctx, "X")
	ref := &modeldomain.ModelRef{APIKeyID: "", ModelID: "x"}
	_, err := svc.Update(ctx, c.ID, UpdateInput{ModelOverride: &ref})
	if !errors.Is(err, modeldomain.ErrAPIKeyIDRequired) {
		t.Errorf("got %v, want ErrAPIKeyIDRequired", err)
	}
}

func TestUpdate_ModelOverride_MissingModelID(t *testing.T) {
	svc := newSvcWithKeys(t, validKeys())
	ctx := ctxAlice()
	c, _ := svc.Create(ctx, "X")
	ref := &modeldomain.ModelRef{APIKeyID: "aki_test", ModelID: ""}
	_, err := svc.Update(ctx, c.ID, UpdateInput{ModelOverride: &ref})
	if !errors.Is(err, modeldomain.ErrModelIDRequired) {
		t.Errorf("got %v, want ErrModelIDRequired", err)
	}
}
