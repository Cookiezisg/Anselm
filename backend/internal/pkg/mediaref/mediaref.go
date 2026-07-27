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

// SourceKey names the receipt field every producer stamps with its own identity. Nothing in this
// package reads it anymore — the producer VETO it once fed died with ADR 0017 (a paired live
// experiment showed the veto made the generating model re-draw until MAX_STEPS; ADR 0020). It
// stays because receipts still carry provenance for everyone else: tests assert on it, the
// attachment row mirrors it (H5.7), and the UI names the producer.
//
// SourceKey 是每个产地盖在 receipt 上的产地字段名。本包已不再读它——它曾喂养的产地**否决**随
// ADR 0017 一起死了(成对真钱实验证明那道否决让生成模型重画到 MAX_STEPS;ADR 0020)。它留着,
// 因为 receipt 仍为其他人携带产地:测试断言它、附件行镜像它(H5.7)、UI 用它称呼产地。
const SourceKey = "source"

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
func Collect(v any) []string {
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
				seen[id] = true
				out = append(out, id)
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
			// Embedded objects are walked rather than bare ids being regex-scraped: parsing keeps
			// every receipt intact as a value (its source, its dimensions), where a regex would
			// reduce it to an id and silently discard whatever the next consumer needs.
			//
			// 否则扫描**嵌在散文里**的 receipt。agent 的终答是**模型**写的,而模型会写「已绘制…receipt
			// 如下:」再把 JSON 放进围栏——那是一个**本身不是 JSON** 的字符串。要求整段答案可解析,等于把
			// 引用整个丢掉、下游节点一点媒体也收不到。这在**每一个** mock 测试里都是绿的,因为脚本化的
			// 回合会**一字不差**地回显 receipt、别的什么都不写;而第一个真模型从没这么干过(H7)。
			//
			// 走的是**解析嵌入对象**而非正则刮裸 id:解析让每份 receipt 作为**值**保持完整(它的
			// source、它的尺寸),正则会把它削成一个裸 id、把下一个消费者要的东西静默扔掉。
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
