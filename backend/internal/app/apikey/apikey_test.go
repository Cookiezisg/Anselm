package apikey

import (
	"context"
	"errors"
	"strings"
	"testing"

	"go.uber.org/zap"

	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// --- fakes ---

type fakeRepo struct {
	items map[string]*apikeydomain.APIKey
}

func newFakeRepo() *fakeRepo { return &fakeRepo{items: map[string]*apikeydomain.APIKey{}} }

func (f *fakeRepo) Get(_ context.Context, id string) (*apikeydomain.APIKey, error) {
	k, ok := f.items[id]
	if !ok {
		return nil, apikeydomain.ErrNotFound
	}
	cp := *k
	return &cp, nil
}

func (f *fakeRepo) List(_ context.Context, filter apikeydomain.ListFilter) ([]*apikeydomain.APIKey, string, error) {
	out := []*apikeydomain.APIKey{}
	for _, k := range f.items {
		if filter.Provider != "" && k.Provider != filter.Provider {
			continue
		}
		cp := *k
		out = append(out, &cp)
	}
	return out, "", nil
}

func (f *fakeRepo) Save(_ context.Context, k *apikeydomain.APIKey) error {
	for id, ex := range f.items {
		if id != k.ID && ex.DisplayName == k.DisplayName {
			return apikeydomain.ErrDisplayNameConflict
		}
	}
	cp := *k
	f.items[k.ID] = &cp
	return nil
}

func (f *fakeRepo) Delete(_ context.Context, id string) error {
	if _, ok := f.items[id]; !ok {
		return apikeydomain.ErrNotFound
	}
	delete(f.items, id)
	return nil
}

func (f *fakeRepo) UpdateTestResult(_ context.Context, id, status, errMsg, response string) error {
	k, ok := f.items[id]
	if !ok {
		return apikeydomain.ErrNotFound
	}
	k.TestStatus, k.TestError, k.TestResponse = status, errMsg, response
	return nil
}

func (f *fakeRepo) ListProbed(_ context.Context) ([]apikeydomain.ProbedKey, error) {
	out := []apikeydomain.ProbedKey{}
	for _, k := range f.items {
		out = append(out, apikeydomain.ProbedKey{Provider: k.Provider, TestStatus: k.TestStatus, TestResponse: k.TestResponse})
	}
	return out, nil
}

// fakeEncryptor is a reversible non-crypto stand-in proving the boundary is exercised.
type fakeEncryptor struct{}

func (fakeEncryptor) Encrypt(_ context.Context, plain []byte) ([]byte, error) {
	return []byte("ENC:" + string(plain)), nil
}
func (fakeEncryptor) Decrypt(_ context.Context, ct []byte) ([]byte, error) {
	return []byte(strings.TrimPrefix(string(ct), "ENC:")), nil
}

type fakeTester struct {
	result *TestResult
	err    error
}

func (f fakeTester) Test(context.Context, string, string, string, string) (*TestResult, error) {
	return f.result, f.err
}

type fakeScanner struct{ used bool }

func (f fakeScanner) ReferencesAPIKey(context.Context, string) ([]apikeydomain.APIKeyRef, error) {
	if f.used {
		return []apikeydomain.APIKeyRef{{Kind: "scenario_default", ID: "dialogue", Name: "dialogue"}}, nil
	}
	return nil, nil
}

func newSvc(tester ConnectivityTester) (*Service, *fakeRepo) {
	repo := newFakeRepo()
	return NewService(repo, fakeEncryptor{}, tester, zap.NewNop()), repo
}

func ctxWS() context.Context { return reqctxpkg.SetWorkspaceID(context.Background(), "ws_1") }

// --- tests ---

func TestCreate_EncryptsAndMasks(t *testing.T) {
	s, _ := newSvc(nil)
	k, err := s.Create(ctxWS(), CreateInput{Provider: "openai", DisplayName: "main", Key: "sk-abcdefghijklmnop"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if k.KeyEncrypted != "ENC:sk-abcdefghijklmnop" {
		t.Errorf("not encrypted: %q", k.KeyEncrypted)
	}
	if k.KeyMasked == "" || strings.Contains(k.KeyMasked, "efghij") {
		t.Errorf("not masked: %q", k.KeyMasked)
	}
	if k.TestStatus != apikeydomain.TestStatusPending || !strings.HasPrefix(k.ID, "aki_") {
		t.Errorf("got %+v", k)
	}
}

func TestCreate_Validation(t *testing.T) {
	s, _ := newSvc(nil)
	cases := []struct {
		name string
		in   CreateInput
		want error
	}{
		{"unknown provider", CreateInput{Provider: "nope", Key: "k"}, apikeydomain.ErrInvalidProvider},
		{"empty key", CreateInput{Provider: "openai", Key: "  "}, apikeydomain.ErrKeyRequired},
		{"ollama needs baseURL", CreateInput{Provider: "ollama", Key: "k"}, apikeydomain.ErrBaseURLRequired},
		{"custom needs apiFormat", CreateInput{Provider: "custom", Key: "k", BaseURL: "http://x"}, apikeydomain.ErrAPIFormatRequired},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if _, err := s.Create(ctxWS(), c.in); !errors.Is(err, c.want) {
				t.Errorf("err = %v, want %v", err, c.want)
			}
		})
	}
}

// TestValidateCreate_APIFormatWhitelist pins G9: a custom key's apiFormat is a closed
// set — empty is missing, anything outside the whitelist is rejected (would otherwise
// silently fall through to the OpenAI-compat dialect at dispatch/probe).
//
// TestValidateCreate_APIFormatWhitelist 锁 G9:custom key 的 apiFormat 是封闭集——空=缺,
// 白名单外的串被拒(否则会在派发/探测时静默落 OpenAI-compat 方言)。
func TestValidateCreate_APIFormatWhitelist(t *testing.T) {
	custom := func(f string) CreateInput {
		return CreateInput{Provider: "custom", Key: "k", BaseURL: "http://x", APIFormat: f}
	}
	cases := []struct {
		name string
		in   CreateInput
		want error
	}{
		{"empty rejected", custom(""), apikeydomain.ErrAPIFormatRequired},
		{"junk rejected", custom("gpt-ish"), apikeydomain.ErrAPIFormatInvalid},
		{"openai-compatible accepted", custom("openai-compatible"), nil},
		{"anthropic-compatible accepted", custom("anthropic-compatible"), nil},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if err := validateCreate(c.in); !errors.Is(err, c.want) {
				t.Errorf("validateCreate = %v, want %v", err, c.want)
			}
		})
	}
}

func TestUpdate_KeyRotationResetsProbe(t *testing.T) {
	s, repo := newSvc(nil)
	k, _ := s.Create(ctxWS(), CreateInput{Provider: "openai", DisplayName: "m", Key: "sk-old1234567890"})
	repo.items[k.ID].TestStatus = apikeydomain.TestStatusOK
	repo.items[k.ID].TestResponse = `{"data":[]}`

	newKey := "sk-new1234567890"
	got, err := s.Update(ctxWS(), k.ID, UpdateInput{Key: &newKey})
	if err != nil {
		t.Fatalf("update: %v", err)
	}
	if got.KeyEncrypted != "ENC:sk-new1234567890" {
		t.Errorf("key not rotated: %q", got.KeyEncrypted)
	}
	if got.TestStatus != apikeydomain.TestStatusPending || got.TestResponse != "" {
		t.Errorf("probe archive not reset: status=%q response=%q", got.TestStatus, got.TestResponse)
	}
}

// TestUpdate_KeyRotationAutoReprobes pins G7: with a tester wired, rotating the key resets the
// probe to pending then auto-reprobes, so the returned row already carries the resolved status
// (not the silent pending that would drop the key's models from the selector).
//
// TestUpdate_KeyRotationAutoReprobes 锁 G7:接了 tester 时,旋转 key 先把探测重置为 pending 再自动
// 重探,故返回的行已带解析后的状态(而非会让该 key 模型从选择器消失的静默 pending)。
func TestUpdate_KeyRotationAutoReprobes(t *testing.T) {
	s, _ := newSvc(fakeTester{result: &TestResult{OK: true, RawResponse: `{"data":[{"id":"m"}]}`}})
	k, err := s.Create(ctxWS(), CreateInput{Provider: "openai", DisplayName: "k", Key: "sk-old1234567890"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if k.TestStatus != apikeydomain.TestStatusPending {
		t.Fatalf("precondition: create should leave status pending, got %q", k.TestStatus)
	}
	newKey := "sk-new1234567890"
	got, err := s.Update(ctxWS(), k.ID, UpdateInput{Key: &newKey})
	if err != nil {
		t.Fatalf("update: %v", err)
	}
	if got.TestStatus != apikeydomain.TestStatusOK {
		t.Errorf("after rotation TestStatus = %q, want ok (auto-reprobed)", got.TestStatus)
	}
}

// TestUpdate_KeyRotationProbeFailureStillSucceeds pins G7's guard: a failed post-rotation probe
// must NOT fail the PATCH — the rotation succeeded; the row just reflects the error status.
//
// TestUpdate_KeyRotationProbeFailureStillSucceeds 锁 G7 的守:旋转后探测失败不得让 PATCH 失败——
// 旋转成功了,行只是带上 error 状态。
func TestUpdate_KeyRotationProbeFailureStillSucceeds(t *testing.T) {
	s, _ := newSvc(fakeTester{err: errors.New("dial tcp: refused")})
	k, _ := s.Create(ctxWS(), CreateInput{Provider: "openai", DisplayName: "k", Key: "sk-old1234567890"})
	newKey := "sk-new1234567890"
	got, err := s.Update(ctxWS(), k.ID, UpdateInput{Key: &newKey})
	if err != nil {
		t.Fatalf("rotation must succeed even when the probe fails, got: %v", err)
	}
	if got.KeyEncrypted != "ENC:sk-new1234567890" {
		t.Errorf("key not rotated: %q", got.KeyEncrypted)
	}
	if got.TestStatus != apikeydomain.TestStatusError {
		t.Errorf("after failed reprobe TestStatus = %q, want error", got.TestStatus)
	}
}

func TestDelete_RefScannerBlocks(t *testing.T) {
	s, _ := newSvc(nil)
	k, _ := s.Create(ctxWS(), CreateInput{Provider: "openai", DisplayName: "m", Key: "sk-1234567890"})
	s.AddRefScanner(fakeScanner{used: true})
	if err := s.Delete(ctxWS(), k.ID); !errors.Is(err, apikeydomain.ErrInUse) {
		t.Errorf("err = %v, want ErrInUse", err)
	}
}

func TestDelete_OKWhenUnreferenced(t *testing.T) {
	s, _ := newSvc(nil)
	k, _ := s.Create(ctxWS(), CreateInput{Provider: "openai", DisplayName: "m", Key: "sk-1234567890"})
	s.AddRefScanner(fakeScanner{used: false})
	if err := s.Delete(ctxWS(), k.ID); err != nil {
		t.Errorf("delete: %v", err)
	}
}

// TestDelete_InUseCarriesReferences pins G4: a blocked delete's ErrInUse carries the
// referrers in details.references so the client can tell the user where to detach the key.
//
// TestDelete_InUseCarriesReferences 锁 G4:被拦删除的 ErrInUse 在 details.references 带上引用方,
// 使客户端能告诉用户去哪解引用。
func TestDelete_InUseCarriesReferences(t *testing.T) {
	s, _ := newSvc(nil)
	k, _ := s.Create(ctxWS(), CreateInput{Provider: "openai", DisplayName: "m", Key: "sk-1234567890"})
	s.AddRefScanner(fakeScanner{used: true})
	err := s.Delete(ctxWS(), k.ID)
	if !errors.Is(err, apikeydomain.ErrInUse) {
		t.Fatalf("err = %v, want ErrInUse", err)
	}
	var de *errorspkg.Error
	if !errors.As(err, &de) {
		t.Fatalf("err is not *errorspkg.Error: %v", err)
	}
	refs, ok := de.Details["references"].([]apikeydomain.APIKeyRef)
	if !ok || len(refs) == 0 {
		t.Fatalf("details.references missing/empty: %#v", de.Details)
	}
	if refs[0].Kind != "scenario_default" {
		t.Errorf("ref kind = %q, want scenario_default", refs[0].Kind)
	}
}

func TestTest_OKPersistsRawResponse(t *testing.T) {
	raw := `{"data":[{"id":"gpt-5"}]}`
	s, repo := newSvc(fakeTester{result: &TestResult{OK: true, Message: "connected", RawResponse: raw}})
	k, _ := s.Create(ctxWS(), CreateInput{Provider: "openai", DisplayName: "m", Key: "sk-1234567890"})

	res, err := s.Test(ctxWS(), k.ID)
	if err != nil || !res.OK {
		t.Fatalf("test: res=%+v err=%v", res, err)
	}
	stored := repo.items[k.ID]
	if stored.TestStatus != apikeydomain.TestStatusOK || stored.TestResponse != raw {
		t.Errorf("raw not archived: status=%q response=%q", stored.TestStatus, stored.TestResponse)
	}
}

func TestTest_FailPersistsError(t *testing.T) {
	s, repo := newSvc(fakeTester{result: &TestResult{OK: false, Message: "HTTP 401"}})
	k, _ := s.Create(ctxWS(), CreateInput{Provider: "openai", DisplayName: "m", Key: "sk-1234567890"})

	if _, err := s.Test(ctxWS(), k.ID); err != nil {
		t.Fatalf("test: %v", err)
	}
	stored := repo.items[k.ID]
	if stored.TestStatus != apikeydomain.TestStatusError || stored.TestError != "HTTP 401" || stored.TestResponse != "" {
		t.Errorf("failure not persisted right: %+v", stored)
	}
}

func TestResolveCredentialsByID_DecryptsAndFallsBackBaseURL(t *testing.T) {
	s, _ := newSvc(nil)
	k, _ := s.Create(ctxWS(), CreateInput{Provider: "openai", DisplayName: "m", Key: "sk-secret123456"})

	creds, err := s.ResolveCredentialsByID(ctxWS(), k.ID)
	if err != nil {
		t.Fatalf("resolve: %v", err)
	}
	if creds.Key != "sk-secret123456" {
		t.Errorf("not decrypted: %q", creds.Key)
	}
	if creds.BaseURL != "https://api.openai.com/v1" {
		t.Errorf("baseURL fallback failed: %q", creds.BaseURL)
	}
}

func TestMarkInvalidByID(t *testing.T) {
	s, repo := newSvc(nil)
	k, _ := s.Create(ctxWS(), CreateInput{Provider: "openai", DisplayName: "m", Key: "sk-1234567890"})
	if err := s.MarkInvalidByID(ctxWS(), k.ID, "401 from caller"); err != nil {
		t.Fatalf("mark: %v", err)
	}
	if repo.items[k.ID].TestStatus != apikeydomain.TestStatusError {
		t.Errorf("not marked invalid: %q", repo.items[k.ID].TestStatus)
	}
}
