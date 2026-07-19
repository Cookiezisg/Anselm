package handlers

import (
	"testing"

	documentdomain "github.com/sunweilin/anselm/backend/internal/domain/document"
)

// TestDocumentTreeRows_HasContent — the /tree projection must drop the body but surface a
// hasContent bool (empty page vs written doc) so the sidebar picks the right icon without a
// content round-trip. hasContent tracks body presence, independent of description/tags.
//
// /tree 投影必须丢正文但浮出 hasContent bool（空页 vs 已写文档），让侧栏无需拉正文就选对 icon。
// hasContent 跟随正文有无，与 description/tags 无关。
func TestDocumentTreeRows_HasContent(t *testing.T) {
	empty := &documentdomain.Document{ID: "doc_empty", Name: "blank", Content: "", SizeBytes: 0}
	// A metadata-only doc (has description + tags but no body) still counts as empty content —
	// hasContent gates on the body, not on out-of-band metadata columns.
	// 仅 metadata 文档（有简介+标签但无正文）仍算空内容——hasContent 只看正文，不看带外 metadata 列。
	metaOnly := &documentdomain.Document{ID: "doc_meta", Name: "meta", Content: "", Description: "a note", Tags: []string{"x"}}
	written := &documentdomain.Document{ID: "doc_full", Name: "page", Content: "# hi", SizeBytes: 4}

	rows := documentTreeRows([]*documentdomain.Document{empty, metaOnly, written})
	if len(rows) != 3 {
		t.Fatalf("want 3 rows, got %d", len(rows))
	}

	want := map[string]bool{"doc_empty": false, "doc_meta": false, "doc_full": true}
	for _, row := range rows {
		id := row["id"].(string)
		if _, ok := row["content"]; ok {
			t.Fatalf("tree row must not carry content (metadata only), got %v", row)
		}
		hc, ok := row["hasContent"].(bool)
		if !ok {
			t.Fatalf("tree row %s must carry a hasContent bool, got %v", id, row["hasContent"])
		}
		if hc != want[id] {
			t.Fatalf("hasContent for %s: want %v got %v", id, want[id], hc)
		}
	}
}
