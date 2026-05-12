// method.go — MethodSpec / ArgSpec / InitArgSpec value types embedded in
// Version via serializer:json.
//
// method.go —— MethodSpec / ArgSpec / InitArgSpec 值类型,经 serializer:json
// 嵌在 Version 行里。

package handler

// MethodSpec is one Python method's full description (schema + body). Private
// methods (Name 以 `_` 开头) 通过 add_method 同样写入但不暴露给 LLM 调用
// (call_handler 拒绝 `_`-prefix method)。
//
// MethodSpec 是一个 Python method 的完整描述(schema + body)。带 _ 前缀的
// 私有 method 同样存,但 call_handler 拒绝调用。
type MethodSpec struct {
	Name         string         `json:"name"`
	Description  string         `json:"description,omitempty"`
	Args         []ArgSpec      `json:"args"`
	ReturnSchema map[string]any `json:"returnSchema,omitempty"`

	// Body is the Python method body WITHOUT the def header. System composes
	// the full def line + indentation when building the class.
	//
	// Body 是 method body 字符串(不含 def 头);系统拼装时加 def 行 + 缩进。
	Body string `json:"body"`

	// Streaming = true means body uses `yield` → driver translates each yield
	// into a progress block delta; the final return is the tool_result.
	//
	// Streaming = true 表 body 用 yield → driver 翻为 progress delta;
	// 最终 return 是 tool_result。
	Streaming bool `json:"streaming"`

	// Timeout in milliseconds for this method call (0 = use driver default 30s).
	// Per-method timeout is the SAME knob whether called from chat / workflow /
	// test / session — caller ctx cancel still wins.
	//
	// 单个 method 的 timeout(ms,0 = driver 默认 30s)。caller ctx cancel 优先。
	Timeout int `json:"timeout,omitempty"`
}

// ArgSpec describes one positional / keyword method argument's JSON-schema
// shape.
//
// ArgSpec 是一个 method 参数的 JSON-schema 形状。
type ArgSpec struct {
	Name        string `json:"name"`
	Type        string `json:"type"` // string / number / integer / boolean / object / array (whitelist)
	Description string `json:"description,omitempty"`
	Required    bool   `json:"required"`
	Default     any    `json:"default,omitempty"`
}

// InitArgSpec describes one __init__ one-time parameter (D-handler config
// system). Sensitive=true → encrypted at rest, masked in GET / list, never
// echoed in LLM tool results.
//
// InitArgSpec 是 __init__ 一次性参数的 schema(D-handler config 系统)。
// Sensitive=true → 加密存,GET 返掩码,LLM 工具结果永不回显明文。
type InitArgSpec struct {
	Name        string `json:"name"`
	Type        string `json:"type"`
	Description string `json:"description,omitempty"`
	Required    bool   `json:"required"`
	Sensitive   bool   `json:"sensitive"`
	Default     any    `json:"default,omitempty"`
}
