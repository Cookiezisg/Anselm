package catalog

import (
	"context"
	"strings"
	"sync"
	"testing"

	"go.uber.org/zap/zaptest"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

func ctxWithUser() context.Context {
	return reqctxpkg.SetUserID(context.Background(), "test-user")
}

type fakeSource struct {
	name    string
	gran    catalogdomain.Granularity
	items   []catalogdomain.Item
	listErr error
}

func (f *fakeSource) Name() string                           { return f.name }
func (f *fakeSource) Granularity() catalogdomain.Granularity { return f.gran }
func (f *fakeSource) InvokeTool() string                     { return "fake_tool" }
func (f *fakeSource) ListItems(_ context.Context) ([]catalogdomain.Item, error) {
	if f.listErr != nil {
		return nil, f.listErr
	}
	return f.items, nil
}

func newServiceForTest(t *testing.T) *Service {
	t.Helper()
	return New(zaptest.NewLogger(t))
}

func TestGetForSystemPrompt_NoSources_Empty(t *testing.T) {
	s := newServiceForTest(t)
	if got := s.GetForSystemPrompt(ctxWithUser()); got != "" {
		t.Errorf("GetForSystemPrompt with no sources = %q, want empty", got)
	}
}

func TestGetForSystemPrompt_MissingUserID_Empty(t *testing.T) {
	s := newServiceForTest(t)
	s.RegisterSource(&fakeSource{name: "function", gran: catalogdomain.PerItem, items: []catalogdomain.Item{
		{Source: "function", ID: "f_a", Name: "csv-clean", Description: "Strip BOMs"},
	}})
	if got := s.GetForSystemPrompt(context.Background()); got != "" {
		t.Errorf("GetForSystemPrompt without userID = %q, want empty", got)
	}
}

func TestGet_MissingUserID_Errors(t *testing.T) {
	s := newServiceForTest(t)
	if _, err := s.Get(context.Background()); err == nil {
		t.Fatal("Get without userID should error")
	}
}

func TestBuild_MechanicalListsAllSources(t *testing.T) {
	s := newServiceForTest(t)
	s.RegisterSource(&fakeSource{name: "function", gran: catalogdomain.PerItem, items: []catalogdomain.Item{
		{Source: "function", ID: "f_a", Name: "csv-clean", Description: "Strip BOMs"},
	}})
	s.RegisterSource(&fakeSource{name: "skill", gran: catalogdomain.PerItem, items: []catalogdomain.Item{
		{Source: "skill", ID: "deploy", Name: "deploy", Description: "Deploy via CI"},
	}})
	cat, err := s.Get(ctxWithUser())
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if cat.GeneratedBy != "mechanical" {
		t.Errorf("GeneratedBy = %q, want mechanical", cat.GeneratedBy)
	}
	if !strings.Contains(cat.Summary, "## Available capabilities") {
		t.Errorf("Summary missing header: %q", cat.Summary)
	}
	if !strings.Contains(cat.Summary, "csv-clean") || !strings.Contains(cat.Summary, "deploy") {
		t.Errorf("Summary missing an item name: %q", cat.Summary)
	}
	if !contains(cat.Coverage["function"], "f_a") {
		t.Errorf("Coverage[function] = %v, missing f_a", cat.Coverage["function"])
	}
	if cat.GeneratedAt.IsZero() {
		t.Error("GeneratedAt should be set")
	}
}

func TestBuild_EmptyLibrary_SkipsSection(t *testing.T) {
	s := newServiceForTest(t)
	s.RegisterSource(&fakeSource{name: "function", gran: catalogdomain.PerItem, items: nil})
	cat, err := s.Get(ctxWithUser())
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if strings.Contains(cat.Summary, "## Available capabilities") {
		t.Errorf("empty library should skip the section; got %q", cat.Summary)
	}
}

func TestBuild_AllSourcesFail_Errors(t *testing.T) {
	s := newServiceForTest(t)
	s.RegisterSource(&fakeSource{name: "function", gran: catalogdomain.PerItem, listErr: errBoom})
	if _, err := s.Get(ctxWithUser()); err == nil {
		t.Fatal("all-sources-failed Get should error")
	}
}

func TestBuild_PartialFailure_UsesSucceeded(t *testing.T) {
	s := newServiceForTest(t)
	s.RegisterSource(&fakeSource{name: "bad", gran: catalogdomain.PerItem, listErr: errBoom})
	s.RegisterSource(&fakeSource{name: "good", gran: catalogdomain.PerItem, items: []catalogdomain.Item{
		{Source: "good", ID: "g_1", Name: "good-item", Description: "still here"},
	}})
	cat, err := s.Get(ctxWithUser())
	if err != nil {
		t.Fatalf("partial-failure Get should not error; got %v", err)
	}
	if !strings.Contains(cat.Summary, "good-item") {
		t.Errorf("good source dropped: %q", cat.Summary)
	}
}

func TestRegisterSource_Concurrent(t *testing.T) {
	s := newServiceForTest(t)
	var wg sync.WaitGroup
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			s.RegisterSource(&fakeSource{name: "src", gran: catalogdomain.PerItem})
		}()
	}
	wg.Wait()
	if got := len(s.snapshotSources()); got != 10 {
		t.Errorf("registered = %d, want 10", got)
	}
}

var errBoom = boomErr("kaboom")

type boomErr string

func (e boomErr) Error() string { return string(e) }

func contains(xs []string, want string) bool {
	for _, x := range xs {
		if x == want {
			return true
		}
	}
	return false
}
