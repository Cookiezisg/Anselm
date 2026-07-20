package workspace

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"go.uber.org/zap"

	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	workspacedomain "github.com/sunweilin/anselm/backend/internal/domain/workspace"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// fakeRepo is an in-memory workspacedomain.Repository. It mirrors the store's
// unique-name behavior so conflict paths are covered without a real DB.
//
// fakeRepo 是内存版 workspacedomain.Repository。镜像 store 的唯一名行为，使冲突路径无需真 DB。
type fakeRepo struct {
	items map[string]*workspacedomain.Workspace
}

func newFakeRepo() *fakeRepo { return &fakeRepo{items: map[string]*workspacedomain.Workspace{}} }

func (f *fakeRepo) Save(_ context.Context, w *workspacedomain.Workspace) error {
	for id, existing := range f.items {
		if id != w.ID && existing.Name == w.Name {
			return workspacedomain.ErrNameConflict
		}
	}
	cp := *w
	f.items[w.ID] = &cp
	return nil
}

func (f *fakeRepo) Get(_ context.Context, id string) (*workspacedomain.Workspace, error) {
	w, ok := f.items[id]
	if !ok {
		return nil, workspacedomain.ErrNotFound
	}
	cp := *w
	return &cp, nil
}

func (f *fakeRepo) List(_ context.Context) ([]*workspacedomain.Workspace, error) {
	out := make([]*workspacedomain.Workspace, 0, len(f.items))
	for _, w := range f.items {
		cp := *w
		out = append(out, &cp)
	}
	return out, nil
}

func (f *fakeRepo) Delete(_ context.Context, id string) error {
	if _, ok := f.items[id]; !ok {
		return workspacedomain.ErrNotFound
	}
	delete(f.items, id)
	return nil
}

func (f *fakeRepo) Count(_ context.Context) (int, error) { return len(f.items), nil }

func (f *fakeRepo) TouchLastUsed(_ context.Context, id string) error {
	w, ok := f.items[id]
	if !ok {
		return workspacedomain.ErrNotFound
	}
	now := time.Now().UTC()
	w.LastUsedAt = &now
	return nil
}

func (f *fakeRepo) Stats(_ context.Context, id string, generatingIDs []string) (*workspacedomain.Stats, error) {
	if _, ok := f.items[id]; !ok {
		return nil, workspacedomain.ErrNotFound
	}
	return &workspacedomain.Stats{Conversations: 3, RunningFlowruns: 1,
		GeneratingConversations: len(generatingIDs)}, nil
}

func newService() *Service { return NewService(newFakeRepo(), zap.NewNop()) }

func TestCreate_TrimsName_DefaultsLanguageAndID(t *testing.T) {
	w, err := newService().Create(context.Background(), CreateInput{Name: "  My Space  "})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if w.Name != "My Space" {
		t.Errorf("name = %q, want trimmed 'My Space'", w.Name)
	}
	if w.Language != workspacedomain.LanguageZhCN {
		t.Errorf("language = %q, want default zh-CN", w.Language)
	}
	if !strings.HasPrefix(w.ID, "ws_") {
		t.Errorf("id = %q, want ws_ prefix", w.ID)
	}
}

func TestCreate_InvokesOnCreatedHookOnSuccess(t *testing.T) {
	s := newService()
	var gotWS string
	var calls int
	s.SetOnCreated(func(_ context.Context, wsID string) {
		calls++
		gotWS = wsID
	})
	w, err := s.Create(context.Background(), CreateInput{Name: "Free"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if calls != 1 {
		t.Errorf("onCreated fired %d times, want 1 (load-bearing first-run free-tier path)", calls)
	}
	if gotWS != w.ID {
		t.Errorf("hook got workspace %q, want the created %q", gotWS, w.ID)
	}

	// A FAILED create must NOT fire the hook (no provisioning for a workspace that wasn't saved).
	calls = 0
	if _, err := s.Create(context.Background(), CreateInput{Name: "Free"}); err == nil {
		t.Fatal("duplicate name should conflict")
	}
	if calls != 0 {
		t.Error("onCreated must not fire when Create fails")
	}
}

func TestCreate_EmptyName_ErrNameRequired(t *testing.T) {
	_, err := newService().Create(context.Background(), CreateInput{Name: "   "})
	if !errors.Is(err, workspacedomain.ErrNameRequired) {
		t.Errorf("err = %v, want ErrNameRequired", err)
	}
}

func TestCreate_TooLong_ErrNameTooLong(t *testing.T) {
	long := strings.Repeat("a", workspacedomain.MaxNameLen+1)
	_, err := newService().Create(context.Background(), CreateInput{Name: long})
	if !errors.Is(err, workspacedomain.ErrNameTooLong) {
		t.Errorf("err = %v, want ErrNameTooLong", err)
	}
}

func TestCreate_InvalidLanguage_ErrLanguageInvalid(t *testing.T) {
	_, err := newService().Create(context.Background(), CreateInput{Name: "X", Language: "fr"})
	if !errors.Is(err, workspacedomain.ErrLanguageInvalid) {
		t.Errorf("err = %v, want ErrLanguageInvalid", err)
	}
}

func TestCreate_DuplicateName_ErrNameConflict(t *testing.T) {
	s := newService()
	if _, err := s.Create(context.Background(), CreateInput{Name: "Dup"}); err != nil {
		t.Fatalf("first: %v", err)
	}
	_, err := s.Create(context.Background(), CreateInput{Name: "Dup"})
	if !errors.Is(err, workspacedomain.ErrNameConflict) {
		t.Errorf("err = %v, want ErrNameConflict", err)
	}
}

func TestUpdate_PartialRename(t *testing.T) {
	s := newService()
	w, _ := s.Create(context.Background(), CreateInput{Name: "Orig"})
	newName := "Renamed"
	got, err := s.Update(context.Background(), w.ID, UpdateInput{Name: &newName})
	if err != nil {
		t.Fatalf("update: %v", err)
	}
	if got.Name != "Renamed" {
		t.Errorf("name = %q, want Renamed", got.Name)
	}
}

func TestUpdate_InvalidLanguage(t *testing.T) {
	s := newService()
	w, _ := s.Create(context.Background(), CreateInput{Name: "X"})
	bad := "de"
	_, err := s.Update(context.Background(), w.ID, UpdateInput{Language: &bad})
	if !errors.Is(err, workspacedomain.ErrLanguageInvalid) {
		t.Errorf("err = %v, want ErrLanguageInvalid", err)
	}
}

// Web-fetch mode is a workspace preference — set/validate via PATCH, read
// (already defaulted to local) by the WebFetch tool.
//
// 抓取模式是 workspace 偏好——经 PATCH 设置/校验，由 WebFetch 工具读（已兜底 local）。
func TestUpdate_WebFetchMode_SetAndValidate(t *testing.T) {
	s := newService()
	w, _ := s.Create(context.Background(), CreateInput{Name: "X"})

	jina := workspacedomain.WebFetchModeJina
	got, err := s.Update(context.Background(), w.ID, UpdateInput{WebFetchMode: &jina})
	if err != nil || got.WebFetchMode != workspacedomain.WebFetchModeJina {
		t.Fatalf("set jina: mode=%q err=%v", got.WebFetchMode, err)
	}
	bad := "proxy"
	if _, err := s.Update(context.Background(), w.ID, UpdateInput{WebFetchMode: &bad}); !errors.Is(err, workspacedomain.ErrWebFetchModeInvalid) {
		t.Fatalf("err = %v, want ErrWebFetchModeInvalid", err)
	}
}

func TestWebFetchMode_DefaultsAndResolution(t *testing.T) {
	s := newService()
	w, _ := s.Create(context.Background(), CreateInput{Name: "X"})
	ctx := reqctxpkg.Detached(w.ID)

	if m := s.WebFetchMode(ctx); m != workspacedomain.WebFetchModeLocal {
		t.Fatalf("unset must default to local, got %q", m)
	}
	jina := workspacedomain.WebFetchModeJina
	if _, err := s.Update(context.Background(), w.ID, UpdateInput{WebFetchMode: &jina}); err != nil {
		t.Fatal(err)
	}
	if m := s.WebFetchMode(ctx); m != workspacedomain.WebFetchModeJina {
		t.Fatalf("configured jina not resolved, got %q", m)
	}
	if m := s.WebFetchMode(context.Background()); m != workspacedomain.WebFetchModeLocal {
		t.Fatalf("no-workspace ctx must fail closed to local, got %q", m)
	}
}

func TestDelete_LastRefused(t *testing.T) {
	s := newService()
	w, _ := s.Create(context.Background(), CreateInput{Name: "Only"})
	if err := s.Delete(context.Background(), w.ID); !errors.Is(err, workspacedomain.ErrCannotDeleteLast) {
		t.Errorf("err = %v, want ErrCannotDeleteLast", err)
	}
}

func TestDelete_OKWhenMoreThanOne(t *testing.T) {
	s := newService()
	_, _ = s.Create(context.Background(), CreateInput{Name: "A"})
	b, _ := s.Create(context.Background(), CreateInput{Name: "B"})
	if err := s.Delete(context.Background(), b.ID); err != nil {
		t.Errorf("delete with >1 workspace: %v", err)
	}
}

func TestResolve_ExistingAndMissing(t *testing.T) {
	s := newService()
	w, _ := s.Create(context.Background(), CreateInput{Name: "V", Language: "en"})
	loc, err := s.Resolve(context.Background(), w.ID)
	if err != nil {
		t.Errorf("resolve existing: %v", err)
	}
	if string(loc) != "en" {
		t.Errorf("resolve locale = %q, want en (from workspace.language)", loc)
	}
	if _, err := s.Resolve(context.Background(), "ws_missing"); !errors.Is(err, workspacedomain.ErrNotFound) {
		t.Errorf("resolve missing: err = %v, want ErrNotFound", err)
	}
}

func TestSetDefault_AndPick(t *testing.T) {
	s := newService()
	w, _ := s.Create(context.Background(), CreateInput{Name: "WS"})
	ref := &modeldomain.ModelRef{APIKeyID: "aki_1", ModelID: "gpt-5.5", Options: map[string]string{"reasoning_effort": "high"}}
	if _, err := s.SetDefault(context.Background(), w.ID, modeldomain.ScenarioDialogue, ref); err != nil {
		t.Fatalf("set default: %v", err)
	}
	// Pick reads the current workspace (id from ctx) — the picker contract LLM callers use.
	// Pick 读当前 workspace（id 取自 ctx）——LLM caller 用的 picker 契约。
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), w.ID)
	got, err := s.Pick(ctx, modeldomain.ScenarioDialogue)
	if err != nil {
		t.Fatalf("pick: %v", err)
	}
	if got.APIKeyID != "aki_1" || got.ModelID != "gpt-5.5" || got.Options["reasoning_effort"] != "high" {
		t.Errorf("pick = %+v, want the set default", got)
	}
}

// TestSetDefault_Clear pins G3: a nil ref clears a scenario default (the DELETE
// default-models/{scenario} path), after which Pick reports the scenario unconfigured.
//
// TestSetDefault_Clear 锁 G3:nil ref 清除某 scenario 默认（DELETE default-models/{scenario}
// 路径）,此后 Pick 报该 scenario 未配。
func TestSetDefault_Clear(t *testing.T) {
	s := newService()
	w, _ := s.Create(context.Background(), CreateInput{Name: "WS"})
	ref := &modeldomain.ModelRef{APIKeyID: "aki_1", ModelID: "gpt-5.5"}
	if _, err := s.SetDefault(context.Background(), w.ID, modeldomain.ScenarioDialogue, ref); err != nil {
		t.Fatalf("set: %v", err)
	}
	if _, err := s.SetDefault(context.Background(), w.ID, modeldomain.ScenarioDialogue, nil); err != nil {
		t.Fatalf("clear: %v", err)
	}
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), w.ID)
	if _, err := s.Pick(ctx, modeldomain.ScenarioDialogue); !errors.Is(err, modeldomain.ErrNotConfigured) {
		t.Errorf("after clear Pick err = %v, want ErrNotConfigured", err)
	}
}

// TestSeedDefaultsIfUnset: free-tier seeding fills ONLY the unset scenarios and never clobbers a
// default the user already picked (dialogue here); a second seed is a no-op.
func TestSeedDefaultsIfUnset(t *testing.T) {
	s := newService()
	w, _ := s.Create(context.Background(), CreateInput{Name: "WS"})
	user := &modeldomain.ModelRef{APIKeyID: "aki_user", ModelID: "gpt-5.5"}
	if _, err := s.SetDefault(context.Background(), w.ID, modeldomain.ScenarioDialogue, user); err != nil {
		t.Fatalf("set dialogue: %v", err)
	}
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), w.ID)
	managed := modeldomain.ModelRef{APIKeyID: "aki_managed", ModelID: "anselm-auto"}
	if err := s.SeedDefaultsIfUnset(ctx, managed); err != nil {
		t.Fatalf("seed: %v", err)
	}
	if dlg, _ := s.Pick(ctx, modeldomain.ScenarioDialogue); dlg.APIKeyID != "aki_user" {
		t.Errorf("dialogue must keep the user's pick, got %+v", dlg)
	}
	for _, sc := range []string{modeldomain.ScenarioUtility, modeldomain.ScenarioAgent} {
		got, err := s.Pick(ctx, sc)
		if err != nil {
			t.Fatalf("pick %s: %v", sc, err)
		}
		if got.APIKeyID != "aki_managed" || got.ModelID != "anselm-auto" {
			t.Errorf("%s = %+v, want the seeded managed ref", sc, got)
		}
	}
	// Idempotent: re-seeding with a different ref changes nothing (all three are now set).
	if err := s.SeedDefaultsIfUnset(ctx, modeldomain.ModelRef{APIKeyID: "aki_other", ModelID: "x"}); err != nil {
		t.Fatalf("re-seed: %v", err)
	}
	if u, _ := s.Pick(ctx, modeldomain.ScenarioUtility); u.APIKeyID != "aki_managed" {
		t.Errorf("re-seed clobbered a set default, got %+v", u)
	}
}

func TestSetDefaultSearch_AndPick(t *testing.T) {
	s := newService()
	w, _ := s.Create(context.Background(), CreateInput{Name: "WS"})
	if _, err := s.SetDefaultSearch(context.Background(), w.ID, "aki_search"); err != nil {
		t.Fatalf("set default search: %v", err)
	}
	// DefaultSearchKeyID reads the current workspace (id from ctx) — the SearchKeyPicker contract.
	// DefaultSearchKeyID 读当前 workspace（id 取自 ctx）——SearchKeyPicker 契约。
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), w.ID)
	id, ok := s.DefaultSearchKeyID(ctx)
	if !ok || id != "aki_search" {
		t.Fatalf("DefaultSearchKeyID = (%q,%v), want (aki_search,true)", id, ok)
	}
}

func TestDefaultSearchKeyID_Unconfigured(t *testing.T) {
	s := newService()
	w, _ := s.Create(context.Background(), CreateInput{Name: "WS"})
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), w.ID)
	if id, ok := s.DefaultSearchKeyID(ctx); ok || id != "" {
		t.Fatalf(`DefaultSearchKeyID = (%q,%v), want ("",false)`, id, ok)
	}
}

func TestSetDefaultSearch_Clear(t *testing.T) {
	s := newService()
	w, _ := s.Create(context.Background(), CreateInput{Name: "WS"})
	if _, err := s.SetDefaultSearch(context.Background(), w.ID, "aki_search"); err != nil {
		t.Fatalf("set: %v", err)
	}
	if _, err := s.SetDefaultSearch(context.Background(), w.ID, ""); err != nil {
		t.Fatalf("clear: %v", err)
	}
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), w.ID)
	if id, ok := s.DefaultSearchKeyID(ctx); ok || id != "" {
		t.Fatalf(`after clear = (%q,%v), want ("",false)`, id, ok)
	}
}

func TestDefaultSearchKeyID_NoWorkspaceInCtx(t *testing.T) {
	s := newService()
	if id, ok := s.DefaultSearchKeyID(context.Background()); ok || id != "" {
		t.Fatalf(`no ws in ctx = (%q,%v), want ("",false)`, id, ok)
	}
}

func TestPick_NotConfigured(t *testing.T) {
	s := newService()
	w, _ := s.Create(context.Background(), CreateInput{Name: "WS"})
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), w.ID)
	if _, err := s.Pick(ctx, modeldomain.ScenarioUtility); !errors.Is(err, modeldomain.ErrNotConfigured) {
		t.Errorf("err = %v, want ErrNotConfigured", err)
	}
}

func TestSetDefault_InvalidRef(t *testing.T) {
	s := newService()
	w, _ := s.Create(context.Background(), CreateInput{Name: "WS"})
	_, err := s.SetDefault(context.Background(), w.ID, modeldomain.ScenarioAgent, &modeldomain.ModelRef{APIKeyID: "aki_1"})
	if !errors.Is(err, modeldomain.ErrRefInvalid) {
		t.Errorf("err = %v, want ErrRefInvalid", err)
	}
}

func TestSetDefault_InvalidScenario(t *testing.T) {
	s := newService()
	w, _ := s.Create(context.Background(), CreateInput{Name: "WS"})
	_, err := s.SetDefault(context.Background(), w.ID, "bogus", &modeldomain.ModelRef{APIKeyID: "a", ModelID: "m"})
	if !errors.Is(err, modeldomain.ErrScenarioInvalid) {
		t.Errorf("err = %v, want ErrScenarioInvalid", err)
	}
}

type fakeKeyChecker struct{ known map[string]bool }

func (f fakeKeyChecker) KeyExists(_ context.Context, id string) error {
	if f.known[id] {
		return nil
	}
	return apikeydomain.ErrNotFound
}

// TestSetDefault_RejectsDanglingKey pins F153 for the workspace scenario-default write path: a default
// pointing at a non-existent apiKeyId is rejected at WRITE (API_KEY_NOT_FOUND); a real key passes; clear
// (nil ref) skips existence. Symmetric with ReferencesAPIKey (which already blocks deleting a referenced key).
func TestSetDefault_RejectsDanglingKey(t *testing.T) {
	s := newService()
	s.SetKeyChecker(fakeKeyChecker{known: map[string]bool{"aki_1": true}})
	w, _ := s.Create(context.Background(), CreateInput{Name: "WS"})

	bad := &modeldomain.ModelRef{APIKeyID: "aki_deadbeef", ModelID: "m"}
	if _, err := s.SetDefault(context.Background(), w.ID, modeldomain.ScenarioDialogue, bad); !errors.Is(err, apikeydomain.ErrNotFound) {
		t.Fatalf("dangling apiKeyId must reject at write with API_KEY_NOT_FOUND, got %v", err)
	}
	good := &modeldomain.ModelRef{APIKeyID: "aki_1", ModelID: "deepseek-typo"}
	if _, err := s.SetDefault(context.Background(), w.ID, modeldomain.ScenarioDialogue, good); err != nil {
		t.Fatalf("a real apiKeyId must pass even with a typo'd modelId: %v", err)
	}
	if _, err := s.SetDefault(context.Background(), w.ID, modeldomain.ScenarioDialogue, nil); err != nil {
		t.Fatalf("clearing (nil ref) must skip existence, got %v", err)
	}
}

type fakeBlobSizer struct {
	n    int64
	err  error
	slow bool
}

func (b fakeBlobSizer) TotalBytes(ctx context.Context) (int64, error) {
	if b.slow {
		<-ctx.Done() // burn the whole budget 烧光预算
		return 0, ctx.Err()
	}
	return b.n, b.err
}

// TestStats_AssemblesPortsAndDegradesHonestly: counts come from the repo; blob bytes from the sizer;
// a blown budget or missing port reports -1 (never a fake 0); unknown id → ErrNotFound.
// 端口拼装与诚实退化:计数出 repo、字节出 sizer;超预算/缺端口=-1;未知 id=ErrNotFound。
func TestStats_AssemblesPortsAndDegradesHonestly(t *testing.T) {
	ctx := context.Background()
	repo := newFakeRepo()
	svc := NewService(repo, zap.NewNop())
	if _, err := svc.Create(ctx, CreateInput{Name: "one"}); err != nil {
		t.Fatalf("create: %v", err)
	}
	id := ""
	for k := range repo.items {
		id = k
	}

	// Full wiring. 全接线。
	svc.SetStatsPorts(fakeBlobSizer{n: 4096}, func() []string { return []string{"cv_a", "cv_b"} })
	st, err := svc.Stats(ctx, id)
	if err != nil {
		t.Fatalf("stats: %v", err)
	}
	if st.Conversations != 3 || st.BlobBytes != 4096 || st.GeneratingConversations != 2 {
		t.Errorf("assembled stats wrong: %+v", st)
	}

	// A blown walk budget is an honest -1. 超预算=-1。
	svc.SetStatsPorts(fakeBlobSizer{slow: true}, nil)
	if st, err = svc.Stats(ctx, id); err != nil {
		t.Fatalf("stats slow: %v", err)
	}
	if st.BlobBytes != -1 {
		t.Errorf("blob bytes on timeout = %d, want -1", st.BlobBytes)
	}

	// Unwired ports degrade, never panic. 缺端口退化不炸。
	svc2 := NewService(newFakeRepo(), zap.NewNop())
	if _, err := svc2.Stats(ctx, id); !errors.Is(err, workspacedomain.ErrNotFound) {
		t.Errorf("unknown id: got %v, want ErrNotFound", err)
	}
}
