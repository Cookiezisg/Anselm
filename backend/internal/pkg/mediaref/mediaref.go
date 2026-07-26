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
	"regexp"
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
//
// Collect 走一个已解码 JSON 值(map/slice/标量),按文法 Key 收集所有合法附件 id,按首见序去重、
// MaxRefs 封顶。
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
		}
	}
	walk(v)
	return out
}
