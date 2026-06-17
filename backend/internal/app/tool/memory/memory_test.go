package memory

import (
	"context"
	"strings"
	"sync"
	"testing"

	"go.uber.org/zap"

	memoryapp "github.com/sunweilin/anselm/backend/internal/app/memory"
	memorydomain "github.com/sunweilin/anselm/backend/internal/domain/memory"
)

// fakeMemoryRepo is an in-memory memorydomain.Repository for offline tool tests.
//
// fakeMemoryRepo 是离线 tool 测试用的内存版 memorydomain.Repository。
type fakeMemoryRepo struct {
	mu    sync.Mutex
	store map[string]*memorydomain.Memory
}

func newFakeRepo() *fakeMemoryRepo {
	return &fakeMemoryRepo{store: make(map[string]*memorydomain.Memory)}
}

func (r *fakeMemoryRepo) List(_ context.Context, filter memorydomain.ListFilter) ([]*memorydomain.Memory, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := make([]*memorydomain.Memory, 0, len(r.store))
	for _, m := range r.store {
		if filter.Pinned != nil && *filter.Pinned != m.Pinned {
			continue
		}
		cp := *m
		out = append(out, &cp)
	}
	return out, nil
}

func (r *fakeMemoryRepo) Get(_ context.Context, name string) (*memorydomain.Memory, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	m, ok := r.store[name]
	if !ok {
		return nil, memorydomain.ErrNotFound
	}
	cp := *m
	return &cp, nil
}

func (r *fakeMemoryRepo) Save(_ context.Context, m *memorydomain.Memory) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	cp := *m
	r.store[m.Name] = &cp
	return nil
}

func (r *fakeMemoryRepo) Delete(_ context.Context, name string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.store[name]; !ok {
		return memorydomain.ErrNotFound
	}
	delete(r.store, name)
	return nil
}

func newTestSvc() (*memoryapp.Service, *fakeMemoryRepo) {
	repo := newFakeRepo()
	return memoryapp.NewService(repo, nil, zap.NewNop()), repo
}

func TestMemoryTools_NamesAndCount(t *testing.T) {
	svc, _ := newTestSvc()
	tools := MemoryTools(svc)
	if len(tools) != 3 {
		t.Fatalf("want 3 tools, got %d", len(tools))
	}
	names := map[string]bool{}
	for _, tl := range tools {
		names[tl.Name()] = true
	}
	for _, want := range []string{"read_memory", "write_memory", "forget_memory"} {
		if !names[want] {
			t.Fatalf("missing tool %s", want)
		}
	}
}

func TestWriteMemory_SavesAsAIUnpinned(t *testing.T) {
	svc, repo := newTestSvc()
	out, err := (&WriteMemory{svc: svc}).Execute(context.Background(),
		`{"name":"no_python38","description":"py version preference","content":"use 3.11+"}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	if !strings.Contains(out, "Saved memory") {
		t.Fatalf("got %q", out)
	}
	m, ok := repo.store["no_python38"]
	if !ok {
		t.Fatal("memory not stored")
	}
	if m.Source != memorydomain.SourceAI {
		t.Fatalf("source = %q, want ai", m.Source)
	}
	if m.Pinned {
		t.Fatal("write must land unpinned (pinning is user-only)")
	}
}

func TestWriteMemory_InvalidNameSoftFails(t *testing.T) {
	svc, _ := newTestSvc()
	out, err := (&WriteMemory{svc: svc}).Execute(context.Background(),
		`{"name":"BAD NAME","description":"d","content":"c"}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	if !strings.Contains(out, "invalid") {
		t.Fatalf("expected invalid-name soft failure, got %q", out)
	}
}

func TestReadMemory_RoundTrip(t *testing.T) {
	svc, _ := newTestSvc()
	if _, err := (&WriteMemory{svc: svc}).Execute(context.Background(),
		`{"name":"api_base","description":"backend url","content":"https://x"}`); err != nil {
		t.Fatalf("seed write: %v", err)
	}
	out, err := (&ReadMemory{svc: svc}).Execute(context.Background(), `{"name":"api_base"}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	if !strings.Contains(out, "https://x") || !strings.Contains(out, "source: ai") {
		t.Fatalf("rendered memory missing content/source: %q", out)
	}
}

func TestReadMemory_NotFoundSoftFails(t *testing.T) {
	svc, _ := newTestSvc()
	out, err := (&ReadMemory{svc: svc}).Execute(context.Background(), `{"name":"ghost"}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	if !strings.Contains(out, "not found") {
		t.Fatalf("got %q", out)
	}
}

func TestForgetMemory_DeletesThenSoftFails(t *testing.T) {
	svc, repo := newTestSvc()
	if _, err := (&WriteMemory{svc: svc}).Execute(context.Background(),
		`{"name":"temp_fact","description":"d","content":"c"}`); err != nil {
		t.Fatalf("seed write: %v", err)
	}
	out, err := (&ForgetMemory{svc: svc}).Execute(context.Background(), `{"name":"temp_fact"}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	if !strings.Contains(out, "Forgot") {
		t.Fatalf("got %q", out)
	}
	if _, ok := repo.store["temp_fact"]; ok {
		t.Fatal("memory still present after forget")
	}
	// Second forget hits the not-found soft-failure branch.
	again, err := (&ForgetMemory{svc: svc}).Execute(context.Background(), `{"name":"temp_fact"}`)
	if err != nil {
		t.Fatalf("Execute(again): %v", err)
	}
	if !strings.Contains(again, "not found") {
		t.Fatalf("got %q", again)
	}
}

func TestValidateInput(t *testing.T) {
	if err := (&WriteMemory{}).ValidateInput([]byte(`{"name":"x","description":"d"}`)); err == nil {
		t.Fatal("write: missing content should fail")
	}
	if err := (&ReadMemory{}).ValidateInput([]byte(`{"name":""}`)); err == nil {
		t.Fatal("read: empty name should fail")
	}
	if err := (&ForgetMemory{}).ValidateInput([]byte(`{}`)); err == nil {
		t.Fatal("forget: missing name should fail")
	}
}
