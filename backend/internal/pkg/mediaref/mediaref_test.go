package mediaref

import (
	"encoding/json"
	"testing"
)

// TestCollect pins the grammar: attachmentId keys at ANY depth, well-formed ids only,
// first-seen dedupe, MaxRefs cap — and nothing else ever matches (receipts never guess的 pure 半).
func TestCollect(t *testing.T) {
	var v any
	payload := `{
		"image": {"attachmentId": "att_00112233445566aa", "mime": "image/png"},
		"items": [
			{"nested": {"attachmentId": "att_00112233445566bb"}},
			{"attachmentId": "att_00112233445566aa"},
			{"attachmentId": "not-an-id"},
			{"attachment_id": "att_00112233445566cc"},
			{"attachmentId": 42}
		]
	}`
	if err := json.Unmarshal([]byte(payload), &v); err != nil {
		t.Fatal(err)
	}
	got := Collect(v)
	if len(got) != 2 {
		t.Fatalf("collect = %v, want the two well-formed ids (deduped, wrong key/shape ignored)", got)
	}
	seen := map[string]bool{}
	for _, id := range got {
		seen[id] = true
	}
	if !seen["att_00112233445566aa"] || !seen["att_00112233445566bb"] {
		t.Fatalf("collect = %v", got)
	}
}

// TestCollect_Cap: a degenerate payload cannot expand beyond MaxRefs.
func TestCollect_Cap(t *testing.T) {
	items := make([]any, 0, 20)
	for i := 0; i < 20; i++ {
		items = append(items, map[string]any{Key: "att_001122334455" + string(rune('a'+i%6)) + string(rune('a'+i/6)) + "0a"})
	}
	// build genuinely distinct valid ids / 造真不同的合法 id
	items = items[:0]
	hex := "0123456789abcdef"
	for i := 0; i < 20; i++ {
		id := "att_00112233445566" + string(hex[i%16]) + string(hex[(i/16)%16])
		items = append(items, map[string]any{Key: id})
	}
	got := Collect(map[string]any{"items": items})
	if len(got) != MaxRefs {
		t.Fatalf("collect = %d refs, want the %d cap", len(got), MaxRefs)
	}
}
