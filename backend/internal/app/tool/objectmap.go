package tool

import (
	"encoding/json"
	"fmt"

	jsonrepairpkg "github.com/sunweilin/anselm/backend/internal/pkg/jsonrepair"
)

// ObjectMap is an object-typed tool parameter that also accepts the SAME object sent as a JSON
// string. Real models stringify nested objects routinely — a live qwen call arrived as
//
//	{"functionId": "fn_…", "args": "{\"points\": 6}"}
//
// where the schema says `args` is an object. A plain map[string]any rejects that with
// "cannot unmarshal string into Go struct field", which reaches the model as a hard tool error; the
// model then flails (the live run went off to re-read the function's definition instead of retrying
// the call). Nothing about the intent was ambiguous — only the encoding was.
//
// It applies to a FAMILY, not one tool: run_function's `args`, call_handler's `args`, and
// invoke_agent's `input` (twice) are all object parameters filled by a model. Fixing them one at a
// time would be the same repair written four times — the framework already owns arg decoding
// (StripStandardFields runs jsonrepair on every call), so the tolerance belongs here.
//
// **Only a string that decodes to an object is accepted.** A string that is not JSON, or that
// decodes to an array/number, is still an error — the point is to accept a different ENCODING of the
// right value, not to guess at a wrong one.
//
// ObjectMap 是一个 object 型工具参数,同时接受**同一个对象**以 JSON **字符串**形式送来。真模型经常把
// 嵌套对象字符串化——一次真实的 qwen 调用就是:
//
//	{"functionId": "fn_…", "args": "{\"points\": 6}"}
//
// 而 schema 里 `args` 是 object。裸 map[string]any 会以「cannot unmarshal string into Go struct
// field」拒掉它,这个错以工具硬失败的形式抵达模型;模型随即乱套(真跑那次它跑去重读函数定义,而不是
// 重试调用)。意图没有任何歧义——**只有编码不同**。
//
// 这是**一族**、不是一个工具:run_function 的 `args`、call_handler 的 `args`、invoke_agent 的 `input`
// (两处)全是由模型填的 object 参数。逐个修等于把同一段修复写四遍——而框架本来就管着入参解码
// (StripStandardFields 对每次调用都跑 jsonrepair),故这份容忍应该住在这里。
//
// **只接受「解出来是对象」的字符串。** 不是 JSON 的字符串、或解出数组/数字的字符串,仍然是错——要点是
// 接受**正确的值的另一种编码**,不是去猜一个错误的值。
type ObjectMap map[string]any

// UnmarshalJSON accepts both the object form and the stringified-object form.
func (m *ObjectMap) UnmarshalJSON(b []byte) error {
	// Object form — the schema-correct shape, tried first and unchanged.
	// 对象形——schema 规定的那一形,先试,不做任何加工。
	var direct map[string]any
	if err := json.Unmarshal(b, &direct); err == nil {
		*m = direct
		return nil
	}

	var s string
	if err := json.Unmarshal(b, &s); err != nil {
		// Neither an object nor a string: report the ORIGINAL object-decode failure, because that is
		// what the caller asked for and what the model must fix.
		// 既不是对象也不是字符串:报**原本**那个对象解码失败——那才是调用方要的东西、也是模型该修的。
		return json.Unmarshal(b, &direct)
	}
	var inner map[string]any
	if err := json.Unmarshal([]byte(jsonrepairpkg.Repair(s)), &inner); err != nil {
		return fmt.Errorf("expected an object (or a JSON string holding one), got %q", truncateArg(s))
	}
	*m = inner
	return nil
}

func truncateArg(s string) string {
	if len(s) > 120 {
		return s[:120] + "…"
	}
	return s
}
