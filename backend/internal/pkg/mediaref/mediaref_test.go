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

// TestCollectURIs pins the DOCUMENT-TEXT half of the grammar. A document body is markdown, so the
// reference lives inside prose — which means the scan must end an id at the right character, and
// must not claim a url that merely looks similar. Getting the boundary wrong would send a
// nonsense lookup down the attachment pipeline for every document that mentions the scheme.
//
// TestCollectURIs 钉文法的**文档正文**半。文档正文是 markdown,故引用住在散文里——这意味着扫描必须在
// 正确的字符处结束一个 id,且不得认领仅仅长得像的 url。边界弄错,会让每一份提到这个 scheme 的文档都往
// 附件管线送一次无意义的查询。
func TestCollectURIs(t *testing.T) {
	const id = "att_00112233445566aa"
	body := "# 报告\n\n看这张图:\n\n![chart](anselm://media/" + id + ")\n\n结论如上。"
	if got := CollectURIs(body); len(got) != 1 || got[0] != id {
		t.Fatalf("collect = %v, want the one id", got)
	}

	// The id ends at the closing paren — not at the end of the line, and not swallowing it.
	// id 在右括号处结束——不到行尾、也不把括号吞进去。
	if got := CollectURIs("![a](anselm://media/" + id + ") 和 ![b](anselm://media/" + id + ")"); len(got) != 1 {
		t.Fatalf("the same id twice must dedupe: %v", got)
	}

	// Look-alikes must not be claimed.
	for _, foreign := range []string{
		"https://example.com/anselm/media/" + id,
		"anselm://document/" + id,
		"anselm://media/not-an-id",
		"anselm://media/",
		"just prose about anselm://media/ with nothing after it",
	} {
		if got := CollectURIs(foreign); len(got) != 0 {
			t.Fatalf("claimed %q → %v", foreign, got)
		}
	}
}

// TestCollectURIs_Capped: a degenerate document cannot expand past what the chokepoint will show.
func TestCollectURIs_Capped(t *testing.T) {
	hex := "0123456789abcdef"
	var b []byte
	for i := 0; i < 20; i++ {
		b = append(b, []byte("![x](anselm://media/att_00112233445566"+string(hex[i%16])+string(hex[(i/16)%16])+")\n")...)
	}
	if got := CollectURIs(string(b)); len(got) != MaxRefs {
		t.Fatalf("collect = %d, want the %d cap", len(got), MaxRefs)
	}
}

// TestCollectExcept_VetoesBySourceNotById: the veto reads the receipt's own producer, so the SAME
// attachment id is skipped when self-authored and kept when it is evidence. Keying on the id
// instead would make one artifact's fate depend on whichever receipt happened to be seen first.
//
// TestCollectExcept_VetoesBySourceNotById:否决读的是 receipt 自己的产地,故**同一个** id 在「自己点的」
// 那份里被跳过、在「证据」那份里被保留。改成按 id 判定,会让一份产物的命运取决于**先看到哪份 receipt**。
func TestCollectExcept_VetoesBySourceNotById(t *testing.T) {
	const id = "att_00aa00aa00aa00aa"
	generated := map[string]any{Key: id, "source": "generate_video"}
	evidence := map[string]any{Key: id, "source": "function_artifact"}

	if got := CollectExcept(generated, SelfAuthored); len(got) != 0 {
		t.Fatalf("self-authored receipt collected: %v", got)
	}
	if got := CollectExcept(evidence, SelfAuthored); len(got) != 1 || got[0] != id {
		t.Fatalf("evidence receipt = %v, want the id", got)
	}
	// A nil veto is the plain Collect — the other consumption entries (agent invoke payload) must
	// keep seeing everything, because a DOWNSTREAM model did not author the upstream's prompt.
	// nil 否决即普通 Collect——其余消费入口(agent invoke payload)必须照旧全见,因为**下游**模型并没有
	// 写过上游那条 prompt。
	if got := Collect(generated); len(got) != 1 {
		t.Fatalf("plain Collect must not veto: %v", got)
	}
}

func TestSelfAuthored_IsTheGenerationFamilyOnly(t *testing.T) {
	for _, src := range []string{"generate_image", "generate_speech", "generate_video"} {
		if !SelfAuthored(src) {
			t.Fatalf("%s must be self-authored", src)
		}
	}
	for _, src := range []string{"function_artifact", "handler_artifact", "mcp", "", "read_aloud"} {
		if SelfAuthored(src) {
			t.Fatalf("%s must NOT be self-authored — the model has not seen it", src)
		}
	}
}

// TestCollect_ReceiptEmbeddedInProse pins the shape a REAL agent answer has: a sentence, a fenced
// code block, and the receipt inside it. The whole string is not JSON, and requiring it to be meant
// media silently stopped crossing workflow nodes — invisible to every mocked test, because a
// scripted turn echoes the receipt verbatim and nothing else (WRK-082 H7).
//
// TestCollect_ReceiptEmbeddedInProse 钉住**真** agent 答案的形状:一句话、一个围栏代码块、receipt 在
// 里面。整个字符串不是 JSON,而要求它是,曾让媒体静默地不再跨 workflow 节点——对每个 mock 测试都不可见,
// 因为脚本化的回合一字不差地回显 receipt、别的什么都不写(H7)。
func TestCollect_ReceiptEmbeddedInProse(t *testing.T) {
	answer := "已绘制黄昏的红色灯塔，工具返回的 receipt 如下：\n\n```json\n" +
		`{"attachmentId":"att_0a2009405c5f2a0c","mime":"image/png","source":"generate_image"}` +
		"\n```\n希望符合你的要求。"
	got := Collect(answer)
	if len(got) != 1 || got[0] != "att_0a2009405c5f2a0c" {
		t.Fatalf("receipt embedded in prose must be found, got %v", got)
	}

	// The producer survives the trip: ADR 0017's filter reads `source`, and it can only do that if
	// the whole receipt object was parsed rather than the id scraped out of the text.
	// 产地要活着到达:ADR 0017 的过滤读 `source`,而它只有在整份 receipt **被解析**、而非 id 被从文本里
	// 刮出来时才读得到。
	if skipped := CollectExcept(answer, SelfAuthored); len(skipped) != 0 {
		t.Fatalf("a self-authored receipt must be filterable through prose too, got %v", skipped)
	}

	// Two receipts in one answer, and prose that merely mentions the key without an object.
	// 一段答案里两份 receipt;以及只提到键名却没有对象的散文。
	two := "first {\"attachmentId\":\"att_1111111111111111\"} then {\"attachmentId\":\"att_2222222222222222\"}"
	if got := Collect(two); len(got) != 2 {
		t.Fatalf("both embedded receipts must be found, got %v", got)
	}
	if got := Collect("the attachmentId was lost"); len(got) != 0 {
		t.Fatalf("prose with no object must yield nothing, got %v", got)
	}
}
