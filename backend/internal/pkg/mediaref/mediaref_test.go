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

// TestCollect_JSONStringForm: receipts embedded in STRING scalars — how they travel between
// workflow nodes (an agent's free-text answer becomes node.text, the downstream input receives
// that string) — are recognized via one Key-gated decode. Prose mentioning the key collects
// nothing, and a key-free string never pays a decode.
//
// TestCollect_JSONStringForm:嵌在**字符串**标量里的 receipt——它在 workflow 节点间就是这么走的
// (agent 自由文本答案成 node.text、下游 input 拿到字符串)——经一次 Key 闸控的解码被认出。提到
// key 的散文收集不到,无 key 的字符串根本不付解码。
func TestCollect_JSONStringForm(t *testing.T) {
	receipt := `{"attachmentId":"att_00112233445566aa","mime":"image/png","source":"generate_image"}`
	if got := Collect(map[string]any{"picture": receipt}); len(got) != 1 || got[0] != "att_00112233445566aa" {
		t.Fatalf("string-embedded receipt must collect, got %v", got)
	}
	// Nested: a JSON string inside a decoded string's object. 嵌套:解码后对象里再嵌 JSON 字符串。
	outer := `{"wrapped":"{\"attachmentId\":\"att_00112233445566bb\"}"}`
	if got := Collect(outer); len(got) != 1 || got[0] != "att_00112233445566bb" {
		t.Fatalf("nested string form must collect, got %v", got)
	}
	if got := Collect(`the "attachmentId" field is documented here: att_00112233445566cc`); len(got) != 0 {
		t.Fatalf("prose must not collect, got %v", got)
	}
	if got := Collect(`{"other":"att_00112233445566dd"}`); len(got) != 0 {
		t.Fatalf("key-free JSON must not collect, got %v", got)
	}
}
