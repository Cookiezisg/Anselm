//go:build pipeline

package catalog

import (
	"strings"
	"testing"

	documentapp "github.com/sunweilin/forgify/backend/internal/app/document"
	th "github.com/sunweilin/forgify/backend/test/harness"
)

// TestCatalog_DocumentsExcluded_E2E — documents must NOT appear in the catalog;
// they enter context via @-mention (separate feature), not auto-injection.
//
// TestCatalog_DocumentsExcluded_E2E —— 文档不进 catalog；走 @ 引用进上下文。
func TestCatalog_DocumentsExcluded_E2E(t *testing.T) {
	h := th.New(t)
	ctx := h.LocalCtx()

	if _, err := h.Document.Create(ctx, documentapp.CreateInput{
		Name: "Projects", Description: "Top-level project folder",
	}); err != nil {
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
	if ids := cat.Coverage["document"]; len(ids) != 0 {
		t.Errorf("Coverage[document]=%v, want empty (documents excluded)", ids)
	}
	if strings.Contains(cat.Summary, "Projects") || strings.Contains(cat.Summary, "scratchpad") {
		t.Errorf("Summary should not contain document names: %q", cat.Summary)
	}
}
