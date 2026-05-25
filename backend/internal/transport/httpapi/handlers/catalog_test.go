package handlers

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"go.uber.org/zap/zaptest"

	catalogapp "github.com/sunweilin/forgify/backend/internal/app/catalog"
	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
	middlewarehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/middleware"
)

type stubCatalogSource struct {
	name  string
	gran  catalogdomain.Granularity
	items []catalogdomain.Item
}

func (s *stubCatalogSource) Name() string                           { return s.name }
func (s *stubCatalogSource) Granularity() catalogdomain.Granularity { return s.gran }
func (s *stubCatalogSource) ListItems(_ context.Context) ([]catalogdomain.Item, error) {
	return append([]catalogdomain.Item(nil), s.items...), nil
}

type catalogHandlerHarness struct {
	srv *httptest.Server
	svc *catalogapp.Service
}

func newCatalogTestServer(t *testing.T) *catalogHandlerHarness {
	t.Helper()
	log := zaptest.NewLogger(t)
	svc := catalogapp.New(log)
	hd := NewCatalogHandler(svc, log)
	mux := http.NewServeMux()
	hd.Register(mux)
	srv := httptest.NewServer(middlewarehttpapi.InjectUserID(mux))
	t.Cleanup(srv.Close)
	return &catalogHandlerHarness{srv: srv, svc: svc}
}

func TestCatalog_Get_EmptyLibrary_ReturnsEmptyCatalog(t *testing.T) {
	h := newCatalogTestServer(t)
	resp, err := http.Get(h.srv.URL + "/api/v1/catalog")
	if err != nil {
		t.Fatalf("GET: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200", resp.StatusCode)
	}
	got := envOf[*catalogdomain.Catalog](t, resp.Body)
	if got == nil {
		t.Fatal("expected a Catalog object, got null")
	}
	if got.GeneratedBy != "mechanical" {
		t.Errorf("GeneratedBy = %q, want mechanical", got.GeneratedBy)
	}
	if got.Summary != "" {
		t.Errorf("empty library Summary = %q, want empty", got.Summary)
	}
}

func TestCatalog_Get_BuildsFromSources(t *testing.T) {
	h := newCatalogTestServer(t)
	h.svc.RegisterSource(&stubCatalogSource{
		name: "forge",
		gran: catalogdomain.PerItem,
		items: []catalogdomain.Item{
			{Source: "forge", ID: "f_a", Name: "csv-clean", Description: "Strip BOMs"},
			{Source: "forge", ID: "f_b", Name: "csv-merge", Description: "Concat CSVs"},
		},
	})

	resp, err := http.Get(h.srv.URL + "/api/v1/catalog")
	if err != nil {
		t.Fatalf("GET: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200", resp.StatusCode)
	}
	got := envOf[*catalogdomain.Catalog](t, resp.Body)
	if got == nil {
		t.Fatal("GET returned nil Catalog")
	}
	if got.GeneratedBy != "mechanical" {
		t.Errorf("GeneratedBy = %q, want mechanical", got.GeneratedBy)
	}
	if len(got.Coverage["forge"]) != 2 {
		t.Errorf("Coverage[forge] = %v, want 2 items", got.Coverage["forge"])
	}
	if !strings.Contains(got.Summary, "csv-clean") || !strings.Contains(got.Summary, "csv-merge") {
		t.Errorf("Summary missing item names: %q", got.Summary)
	}
}
