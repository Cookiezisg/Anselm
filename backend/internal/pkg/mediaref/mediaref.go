// Package mediaref is the MediaRef grammar's pure half (WRK-082 批B'): recognizing attachment
// references inside arbitrary JSON-shaped values. A MediaRef is any object carrying an
// `attachmentId` whose value is an `att_<16hex>` id — the exact receipt shape the generation
// tools emit and the ONE currency media uses to flow through tool_result / frn rows / agent
// payloads (不变量①). Pure: no I/O, no imports beyond stdlib — every layer may use it.
//
// Package mediaref 是 MediaRef 文法的纯半(批B'):在任意 JSON 形值里识别附件引用。MediaRef =
// 任何携 `attachmentId`(值为 `att_<16hex>` id)的对象——恰是生成工具产出的 receipt 形,也是媒体
// 流经 tool_result / frn 行 / agent payload 的唯一货币(不变量①)。纯函数:零 I/O、仅标准库,
// 任何层可用。
package mediaref

import (
	"encoding/json"
	"regexp"
	"strings"
)

// Key is the grammar's one field name. A closed vocabulary: producers write it, the consumption
// chokepoint reads it — never a second spelling.
//
// Key 是文法唯一字段名。封闭词表:产出侧写它、消费咽喉读它——绝无第二种拼法。
const Key = "attachmentId"

// MaxRefs bounds how many refs one payload may expand (defense against a hostile/degenerate
// payload turning one agent turn into hundreds of media parts).
//
// MaxRefs 界一个 payload 可展开的引用数(防恶意/退化 payload 把一轮 agent 变成上百媒体 part)。
const MaxRefs = 8

var idShape = regexp.MustCompile(`^att_[0-9a-f]{16}$`)

// IsAttachmentID reports whether s is a well-formed attachment id.
//
// IsAttachmentID 报告 s 是否合法附件 id 形。
func IsAttachmentID(s string) bool { return idShape.MatchString(s) }

// Collect walks a decoded JSON value (maps / slices / scalars) and returns every well-formed
// attachment id found under the grammar Key, deduplicated in first-seen order, capped at MaxRefs.
// A STRING scalar that contains the grammar Key gets one JSON-decode attempt and its decoded
// value walked too — receipts routinely travel as text between workflow nodes (an agent's
// free-text answer becomes `node.text`, the downstream input receives that string), and the
// chokepoint must recognize them there or the pipeline half of 不变量③ silently dies. The
// substring gate keeps arbitrary large texts from paying a decode.
//
// Collect 走一个已解码 JSON 值(map/slice/标量),按文法 Key 收集所有合法附件 id,按首见序去重、
// MaxRefs 封顶。含文法 Key 的**字符串**标量会得到一次 JSON 解码并继续走其值——receipt 在
// workflow 节点间常以文本流动(agent 自由文本答案成 `node.text`,下游 input 拿到的是字符串),
// 咽喉认不出这一形,不变量③的流水线半就静默死掉。子串闸免去任意大文本的解码开销。
func Collect(v any) []string { return CollectExcept(v, nil) }

// SourceKey names the receipt field every producer stamps with its own identity.
//
// SourceKey 是每个产地盖在 receipt 上的产地字段名。
const SourceKey = "source"

// SelfAuthored reports whether a receipt came from the GENERATION family — an artifact the model
// asked for by writing its own prompt.
//
// It exists because "should this artifact be fed back to the model as input" is decided by its
// PRODUCER, not by its size or its modality. A picture the model itself ordered adds nothing to
// that model's next turn: it authored the description, so it already knows what is in there.
// A chart a function computed is the opposite — that is evidence the model has never seen, and it
// is the whole point of asking. Size only decides how to DEGRADE when an artifact does need to go;
// it must never be the thing that decides whether it goes.
//
// This is also what the mature implementations do: OpenAI's image_generation tool carries a
// previous image into the next turn by ID (the model sees `revised_prompt` and call metadata, not
// the pixels), and a model that genuinely needs to look calls an inspection tool — pull, not push.
//
// SelfAuthored 报告一份 receipt 是否出自**生成族**——模型自己写 prompt 要来的产物。
//
// 它存在,是因为「这份产物该不该回喂给模型当输入」由它的**产地**决定,不由大小、也不由模态决定。
// 模型自己点的那张图,对它的下一轮毫无增益:描述是它写的,它**已经知道**里面是什么。而 function 算出来的
// 那张图表恰恰相反——那是模型**从未见过**的证据,也正是它开口要的理由。大小只决定该走时**怎么降级**,
// 绝不能成为决定走不走的那个判据。
//
// 这也是成熟实现的做法:OpenAI 的 image_generation 工具把上一张图带进下一轮靠的是 **ID**(模型看到的是
// `revised_prompt` 与调用元数据、不是像素);而真需要看的模型去调一个检视工具——**拉,不是推**。
func SelfAuthored(source string) bool {
	switch source {
	case "generate_image", "generate_speech", "generate_video":
		return true
	}
	return false
}

// CollectExcept is Collect with a per-receipt veto keyed on its SourceKey. A nil skip collects
// everything (the plain Collect).
//
// The veto is applied at the RECEIPT, not to the id afterwards: the same attachment can legitimately
// be self-authored in one place and evidence in another (an upstream node generates a chart, a
// downstream agent must look at it), so the decision belongs where the producer is still named.
//
// CollectExcept 是带**逐 receipt 否决**的 Collect,否决依据是它的 SourceKey。skip 为 nil 即全收(即
// 普通 Collect)。
//
// 否决施加在 **receipt** 上、而不是事后施加在 id 上:同一份附件完全可以在一处是「自己点的」、在另一处是
// 「证据」(上游节点生成一张图表、下游 agent 必须看它),故这个决定必须留在**产地还叫得出名字**的地方。
func CollectExcept(v any, skip func(source string) bool) []string {
	var out []string
	seen := map[string]bool{}
	var walk func(v any)
	walk = func(v any) {
		if len(out) >= MaxRefs {
			return
		}
		switch x := v.(type) {
		case map[string]any:
			if id, ok := x[Key].(string); ok && IsAttachmentID(id) && !seen[id] {
				src, _ := x[SourceKey].(string)
				if skip == nil || !skip(src) {
					seen[id] = true
					out = append(out, id)
				}
			}
			for _, val := range x {
				walk(val)
			}
		case []any:
			for _, val := range x {
				walk(val)
			}
		case string:
			// Gate on the bare Key, not `"Key"` — a receipt nested one level deep arrives with its
			// quotes backslash-escaped, and a quote-anchored gate would miss exactly that case.
			// 闸只看裸 Key、不看 `"Key"`——嵌一层的 receipt 引号是转义的,带引号的闸恰好漏掉这一形。
			if !strings.Contains(x, Key) {
				return
			}
			// Whole-string JSON first: the cheap, exact case (a tool_result body, a nested receipt).
			// 先试整串 JSON:便宜且精确的那一类(tool_result 体、嵌套的 receipt)。
			var decoded any
			if json.Unmarshal([]byte(x), &decoded) == nil {
				walk(decoded)
				return
			}
			// Otherwise scan for receipts EMBEDDED in prose. An agent's final answer is written by a
			// model, and a model writes "已绘制…receipt 如下:" and then fences the JSON — a string
			// that is not itself JSON. Requiring the whole answer to parse meant the reference was
			// dropped and the downstream node received no media at all. That passed every mocked
			// test, because a scripted turn echoes the receipt VERBATIM and nothing else; the first
			// real model never did (WRK-082 H7).
			//
			// Embedded objects are walked rather than bare ids being regex-scraped, so each receipt
			// keeps its `source` — which is what ADR 0017's producer filter reads. A bare id carries
			// no producer, so scraping ids would silently disable that decision.
			//
			// 否则扫描**嵌在散文里**的 receipt。agent 的终答是**模型**写的,而模型会写「已绘制…receipt
			// 如下:」再把 JSON 放进围栏——那是一个**本身不是 JSON** 的字符串。要求整段答案可解析,等于把
			// 引用整个丢掉、下游节点一点媒体也收不到。这在**每一个** mock 测试里都是绿的,因为脚本化的
			// 回合会**一字不差**地回显 receipt、别的什么都不写;而第一个真模型从没这么干过(H7)。
			//
			// 走的是**解析嵌入对象**而非正则刮裸 id,故每份 receipt 都留着自己的 `source`——那正是
			// ADR 0017 的产地过滤要读的东西。裸 id 不带产地,刮 id 等于把那个决定静默地关掉。
			for i := 0; i < len(x) && len(out) < MaxRefs; i++ {
				if x[i] != '{' {
					continue
				}
				dec := json.NewDecoder(strings.NewReader(x[i:]))
				var obj any
				if dec.Decode(&obj) != nil {
					continue
				}
				walk(obj)
				i += int(dec.InputOffset()) - 1
			}
		}
	}
	walk(v)
	return out
}

// URIPrefix is the document-text form's prefix: a media reference inside markdown is an image
// link, `![alt](anselm://media/<id>)`. The front end owns the same grammar (core/media/media_uri).
//
// URIPrefix 是文档正文形的前缀:markdown 里的媒体引用是一个图像链接。前端持有同一份文法。
const URIPrefix = "anselm://media/"

// CollectURIs scans free text for `anselm://media/<id>` references and returns the well-formed
// ids, first-seen and capped at MaxRefs. It is a scan rather than a parse because the reference
// lives inside prose — a document body is markdown, and the id is in a link, not a field.
//
// CollectURIs 扫自由文本里的 `anselm://media/<id>` 引用,返回合法 id(首见序、MaxRefs 封顶)。它是
// **扫描**而非解析,因为引用住在散文里——文档正文是 markdown,id 在一个链接里、不在某个字段上。
func CollectURIs(text string) []string {
	var out []string
	seen := map[string]bool{}
	for i := 0; i < len(text) && len(out) < MaxRefs; {
		j := strings.Index(text[i:], URIPrefix)
		if j < 0 {
			break
		}
		start := i + j + len(URIPrefix)
		end := start
		for end < len(text) && isIDRune(text[end]) {
			end++
		}
		id := text[start:end]
		if IsAttachmentID(id) && !seen[id] {
			seen[id] = true
			out = append(out, id)
		}
		// Always advance past what was just examined. A prefix at the very END of the text leaves
		// start == end == len(text); stepping "one past" from there walks off the string, which is
		// exactly the crash a document ending in the bare scheme would have caused.
		// 恒推进过刚检视的部分。前缀出现在文本**末尾**时 start == end == len(text),从那里再「往前一步」
		// 会走出字符串——那正是一份以裸 scheme 结尾的文档会引发的崩溃。
		if end > start {
			i = end
		} else {
			i = start + 1
		}
	}
	return out
}

func isIDRune(b byte) bool {
	return b == '_' || (b >= '0' && b <= '9') || (b >= 'a' && b <= 'z') || (b >= 'A' && b <= 'Z')
}
