package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"go.uber.org/zap"

	sandboxapp "github.com/sunweilin/anselm/backend/internal/app/sandbox"
	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	sandboxdomain "github.com/sunweilin/anselm/backend/internal/domain/sandbox"
	dbinfra "github.com/sunweilin/anselm/backend/internal/infra/db"
	sandboxstore "github.com/sunweilin/anselm/backend/internal/infra/store/sandbox"
)

type fakeConversationResolver struct {
	conversations map[string]*conversationdomain.Conversation
}

func (f fakeConversationResolver) Get(_ context.Context, id string) (*conversationdomain.Conversation, error) {
	if c := f.conversations[id]; c != nil {
		return c, nil
	}
	return nil, conversationdomain.ErrNotFound
}

func TestBootstrapStatusDoesNotExposeFilesystemDetails(t *testing.T) {
	db, err := dbinfra.Open(dbinfra.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })
	if err := dbinfra.Migrate(db, sandboxstore.Schema...); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	dataDir := t.TempDir()
	root := filepath.Join(dataDir, "sandbox")
	if err := os.WriteFile(root, []byte("not a directory"), 0o600); err != nil {
		t.Fatalf("create sabotage: %v", err)
	}
	svc := sandboxapp.NewService(sandboxstore.New(db), dataDir, nil, zap.NewNop())
	if err := svc.Bootstrap(context.Background()); err == nil {
		t.Fatal("Bootstrap should fail when sandbox root is a regular file")
	}

	req := httptest.NewRequest(http.MethodGet, "/api/v1/sandbox/bootstrap-status", nil)
	rec := httptest.NewRecorder()
	NewSandboxHandler(svc, nil, zap.NewNop()).BootstrapStatus(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	var envelope struct {
		Data struct {
			OK    bool   `json:"ok"`
			Error string `json:"error"`
		} `json:"data"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &envelope); err != nil {
		t.Fatalf("decode response: %v; body=%s", err, rec.Body.String())
	}
	if envelope.Data.OK {
		t.Fatal("bootstrap status should be degraded")
	}
	if envelope.Data.Error != bootstrapFailureSummary {
		t.Fatalf("error summary = %q, want %q", envelope.Data.Error, bootstrapFailureSummary)
	}
	if got := rec.Body.String(); got == "" || containsAny(got, root, "sandboxapp.Bootstrap", "not a directory") {
		t.Fatalf("response leaked implementation detail: %s", got)
	}

	retryRec := httptest.NewRecorder()
	NewSandboxHandler(svc, nil, zap.NewNop()).RetryBootstrap(retryRec, req)
	if retryRec.Code != http.StatusOK {
		t.Fatalf("retry status = %d, want 200", retryRec.Code)
	}
	var retryEnvelope struct {
		Data struct {
			OK    bool   `json:"ok"`
			Error string `json:"error"`
		} `json:"data"`
	}
	if err := json.Unmarshal(retryRec.Body.Bytes(), &retryEnvelope); err != nil {
		t.Fatalf("decode retry response: %v; body=%s", err, retryRec.Body.String())
	}
	if retryEnvelope.Data.OK || retryEnvelope.Data.Error != bootstrapFailureSummary {
		t.Fatalf("retry response = %s, want degraded safe summary", retryRec.Body.String())
	}
	if got := retryRec.Body.String(); containsAny(got, root, "sandboxapp.Bootstrap", "not a directory") {
		t.Fatalf("retry response leaked implementation detail: %s", got)
	}
}

func containsAny(value string, needles ...string) bool {
	for _, needle := range needles {
		if strings.Contains(value, needle) {
			return true
		}
	}
	return false
}

func TestConversationSandboxRoutesAuthorizeConversationBeforeManifestAccess(t *testing.T) {
	db, err := dbinfra.Open(dbinfra.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })
	if err := dbinfra.Migrate(db, sandboxstore.Schema...); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	dataDir := t.TempDir()
	svc := sandboxapp.NewService(sandboxstore.New(db), dataDir, nil, zap.NewNop())
	if err := svc.Bootstrap(context.Background()); err != nil {
		t.Fatalf("bootstrap: %v", err)
	}
	store := sandboxstore.New(db)
	now := time.Now().UTC()
	if err := store.CreateEnv(context.Background(), &sandboxdomain.Env{
		ID:         "se_foreign_scratch",
		OwnerKind:  sandboxdomain.OwnerKindConversation,
		OwnerID:    "cv_foreign_python",
		RuntimeID:  "sr_python",
		Path:       "envs/conversation/cv_foreign_python",
		Status:     sandboxdomain.EnvStatusReady,
		CreatedAt:  now,
		LastUsedAt: now,
		UpdatedAt:  now,
	}); err != nil {
		t.Fatalf("create env fixture: %v", err)
	}

	resolver := fakeConversationResolver{conversations: map[string]*conversationdomain.Conversation{
		"cv_local":   {ID: "cv_local"},
		"cv_foreign": {ID: "cv_foreign"},
	}}
	mux := http.NewServeMux()
	NewSandboxHandler(svc, resolver, zap.NewNop()).Register(mux)

	for _, path := range []string{
		"/api/v1/conversations/cv_missing/sandbox-envs",
		"/api/v1/conversations/cv_missing/sandbox-envs/python:reset",
		"/api/v1/conversations/cv_missing/sandbox-envs:reset-all",
	} {
		req := httptest.NewRequest(http.MethodPost, path, nil)
		if strings.HasSuffix(path, "/sandbox-envs") {
			req = httptest.NewRequest(http.MethodGet, path, nil)
		}
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)
		if rec.Code != http.StatusNotFound || !strings.Contains(rec.Body.String(), "CONVERSATION_NOT_FOUND") {
			t.Fatalf("unknown conversation route %s = %d %s, want 404 CONVERSATION_NOT_FOUND", path, rec.Code, rec.Body.String())
		}
		if strings.Contains(rec.Body.String(), "se_foreign_scratch") {
			t.Fatalf("unknown conversation route %s leaked sandbox manifest: %s", path, rec.Body.String())
		}
	}

	localReq := httptest.NewRequest(http.MethodGet, "/api/v1/conversations/cv_local/sandbox-envs", nil)
	localRec := httptest.NewRecorder()
	mux.ServeHTTP(localRec, localReq)
	if localRec.Code != http.StatusOK || strings.TrimSpace(localRec.Body.String()) != `{"data":[]}` {
		t.Fatalf("known scratchless conversation = %d %s, want 200 empty list", localRec.Code, localRec.Body.String())
	}

	ownedReq := httptest.NewRequest(http.MethodGet, "/api/v1/conversations/cv_foreign/sandbox-envs", nil)
	ownedRec := httptest.NewRecorder()
	mux.ServeHTTP(ownedRec, ownedReq)
	if ownedRec.Code != http.StatusOK || !strings.Contains(ownedRec.Body.String(), "se_foreign_scratch") {
		t.Fatalf("known conversation with scratch env = %d %s, want its owner row", ownedRec.Code, ownedRec.Body.String())
	}
}

// TestGCOlderThanDays — F-sandbox-gc-zero (round-8 revertchurn): an explicit olderThanDays=0 must be
// honored as "reclaim all idle now" (the manual remedy for freshly-orphaned venvs), NOT silently
// coerced to the 30-day default. Empty / negative / garbage still fall back to 30.
func TestGCOlderThanDays(t *testing.T) {
	cases := []struct {
		raw  string
		want int
	}{
		{"0", 0},    // honored: force-reclaim all idle (was silently coerced to 30)
		{"7", 7},    // explicit positive
		{"30", 30},  // explicit default
		{"", 30},    // unset → default
		{"-5", 30},  // negative ignored → default
		{"abc", 30}, // non-numeric ignored → default
	}
	for _, c := range cases {
		if got := gcOlderThanDays(c.raw); got != c.want {
			t.Errorf("gcOlderThanDays(%q) = %d, want %d", c.raw, got, c.want)
		}
	}
}
