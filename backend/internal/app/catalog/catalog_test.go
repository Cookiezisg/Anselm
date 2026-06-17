package catalog

import (
	"context"
	"errors"
	"strings"
	"testing"

	"go.uber.org/zap"

	catalogdomain "github.com/sunweilin/anselm/backend/internal/domain/catalog"
)

// fakeSource is an in-memory CatalogSource: canned items, or a forced error.
//
// fakeSource 是内存版 CatalogSource：预设 items，或强制 error。
type fakeSource struct {
	name  string
	items []catalogdomain.Item
	err   error
}

func (f fakeSource) Name() string { return f.name }
func (f fakeSource) ListItems(_ context.Context) ([]catalogdomain.Item, error) {
	return f.items, f.err
}

func item(source, id, name, desc string) catalogdomain.Item {
	return catalogdomain.Item{Source: source, ID: id, Name: name, Description: desc}
}

func newSvc(srcs ...catalogdomain.CatalogSource) *Service {
	s := NewService(zap.NewNop())
	for _, src := range srcs {
		s.RegisterSource(src)
	}
	return s
}

func TestBuild_AggregatesAndGroups(t *testing.T) {
	svc := newSvc(
		fakeSource{name: "function", items: []catalogdomain.Item{
			item("function", "fn_b", "beta", "second fn"),
			item("function", "fn_a", "alpha", "first fn"),
		}},
		fakeSource{name: "workflow", items: []catalogdomain.Item{
			item("workflow", "wf_1", "deploy", "auto deploy"),
		}},
	)
	cat, err := svc.Get(context.Background())
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if !strings.Contains(cat.Summary, "### function") || !strings.Contains(cat.Summary, "### workflow") {
		t.Errorf("missing kind headers:\n%s", cat.Summary)
	}
	// alpha before beta (name-sorted within a group)
	if strings.Index(cat.Summary, "alpha") > strings.Index(cat.Summary, "beta") {
		t.Errorf("entities not name-sorted:\n%s", cat.Summary)
	}
	// ids must NOT leak into the LLM-facing text
	if strings.Contains(cat.Summary, "fn_a") || strings.Contains(cat.Summary, "wf_1") {
		t.Errorf("ids must not appear in summary:\n%s", cat.Summary)
	}
	// ids DO appear in the structured coverage map
	if len(cat.Coverage["function"]) != 2 || cat.Coverage["workflow"][0] != "wf_1" {
		t.Errorf("coverage wrong: %+v", cat.Coverage)
	}
}

func TestBuild_AllSourcesFailed(t *testing.T) {
	svc := newSvc(
		fakeSource{name: "function", err: errors.New("db down")},
		fakeSource{name: "workflow", err: errors.New("db down")},
	)
	if _, err := svc.Get(context.Background()); !errors.Is(err, catalogdomain.ErrAllSourcesFailed) {
		t.Errorf("want ErrAllSourcesFailed, got %v", err)
	}
}

func TestBuild_PartialFailureUsesSucceeded(t *testing.T) {
	svc := newSvc(
		fakeSource{name: "function", items: []catalogdomain.Item{item("function", "fn_a", "alpha", "ok")}},
		fakeSource{name: "workflow", err: errors.New("db down")},
	)
	cat, err := svc.Get(context.Background())
	if err != nil {
		t.Fatalf("partial failure should not error: %v", err)
	}
	if !strings.Contains(cat.Summary, "alpha") || strings.Contains(cat.Summary, "### workflow") {
		t.Errorf("expected only the function group:\n%s", cat.Summary)
	}
}

func TestBuild_EmptyLibrary(t *testing.T) {
	svc := newSvc(fakeSource{name: "function", items: nil})
	cat, err := svc.Get(context.Background())
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if cat.Summary != "" {
		t.Errorf("empty library should yield empty summary, got:\n%q", cat.Summary)
	}
}

func TestBuild_NoSources(t *testing.T) {
	// No sources registered → empty, not an error.
	cat, err := newSvc().Get(context.Background())
	if err != nil {
		t.Fatalf("no sources should not error: %v", err)
	}
	if cat.Summary != "" || len(cat.Coverage) != 0 {
		t.Errorf("want empty catalog, got %+v", cat)
	}
}

func TestGetForSystemPrompt_OmitsOnAllFailure(t *testing.T) {
	svc := newSvc(fakeSource{name: "function", err: errors.New("db down")})
	if got := svc.GetForSystemPrompt(context.Background()); got != "" {
		t.Errorf("want empty string on failure, got %q", got)
	}
}
