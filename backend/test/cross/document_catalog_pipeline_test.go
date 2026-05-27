//go:build pipeline

package cross

import (
	"strings"
	"testing"

	documentapp "github.com/sunweilin/forgify/backend/internal/app/document"
	th "github.com/sunweilin/forgify/backend/test/harness"
)

// TestCatalog_DocumentsIncluded_E2E — documents now appear in the catalog as
// read_document entries so the LLM knows they exist and how to retrieve them.
//
// TestCatalog_DocumentsIncluded_E2E —— 文档现进 catalog（read_document），LLM 可查。
func TestCatalog_DocumentsIncluded_E2E(t *testing.T) {
	h := th.New(t)
	ctx := h.LocalCtx()

	d1, err := h.Document.Create(ctx, documentapp.CreateInput{
		Name: "Projects", Description: "Top-level project folder",
	})
	if err != nil {
		t.Fatalf("seed Projects: %v", err)
	}
	if _, err := h.Document.Create(ctx, documentapp.CreateInput{
		Name: "scratchpad", Description: "Loose ideas",
	}); err != nil {
		t.Fatalf("seed scratchpad: %v", err)
	}

	cat, err := h.Catalog.Get(h.LocalCtx())
	if err != nil {
		t.Fatalf("Catalog.Get: %v", err)
	}

	ids := cat.Coverage["document"]
	if !contains(ids, d1.ID) {
		t.Errorf("Coverage[document]=%v missing Projects id %q", ids, d1.ID)
	}
	if !strings.Contains(cat.Summary, "Projects") {
		t.Errorf("Summary should contain document name 'Projects': %q", cat.Summary)
	}
	if !strings.Contains(cat.Summary, "[read_document]") {
		t.Errorf("Summary should contain invoke tool 'read_document': %q", cat.Summary)
	}
}
