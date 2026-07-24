package logger

import (
	"strings"

	"go.uber.org/zap/zapcore"
)

// WRK-078 §3.3 #10 — "content never enters the observability surface": logs, metrics labels, audit
// rows and errors must carry no media, prompt, transcript or signed URL. The gateway has enforced
// this with a runtime redaction floor since day one; this backend had NONE — any
// `zap.String("prompt", p)` went verbatim to stderr AND to the rotating file at <logDir>/anselm.log,
// which is the artifact users are asked to send in when reporting a problem.
//
// A redaction floor is deliberately a CORE wrapper rather than a review rule: it applies to every
// field of every entry from every call site, including ones written after this comment. It is a
// key-name denylist, so it is a floor and not a proof — a brand-new key name still leaks. Pair it
// with the call-site scan that §3.3 #10 still lacks; do not treat this file as closing that gap.
//
// WRK-078 §3.3 #10「内容不进观测面」:日志/metrics label/审计/错误均不得含媒体、prompt、转写或签名 URL。
// 网关一开始就有运行时脱敏底座,而本后端**一处都没有**——任何 `zap.String("prompt", p)` 会原样写进 stderr
// **以及** `<logDir>/anselm.log` 轮转文件,而那正是我们请用户报障时发来的东西。
//
// 脱敏刻意做成 **core 包装**而非评审规则:它作用于每条记录的每个字段、每个调用点,包括本注释之后新写的。
// 它是**按键名的黑名单**,故是**底线而非证明**——全新的键名仍会漏。§3.3 #10 仍缺的调用点扫描要另外补,
// 不要把本文件当作那道缺口已被堵上。

const redactedValue = "[REDACTED]"

// redactKeys are field names whose VALUE is content or a credential. Matching is exact,
// case-insensitive. 值为内容或凭证的字段名(精确匹配、大小写不敏感)。
var redactKeys = map[string]struct{}{
	// Model-facing content. 面向模型的内容。
	"prompt": {}, "prompts": {}, "completion": {}, "content": {}, "messages": {},
	"system_prompt": {}, "history": {}, "text": {}, "summary": {}, "transcript": {},
	"reasoning": {}, "capsule": {},
	// Tool I/O — arguments and results routinely carry user data. 工具 I/O 常带用户数据。
	"args": {}, "arguments": {}, "tool_args": {}, "tool_result": {}, "result": {}, "output": {},
	// Media and its capability-bearing URLs. 媒体与带能力的 URL。
	"image_url": {}, "video_url": {}, "input_audio": {}, "audio": {}, "media": {},
	"data_url": {}, "signed_url": {}, "lease_url": {}, "fetch_url": {}, "fetch_path": {},
	// Raw upstream/HTTP bodies. 上游/HTTP 原始体。
	"body": {}, "request_body": {}, "response_body": {}, "upstream_body": {},
	// Credentials. 凭证。
	"api_key": {}, "apikey": {}, "key": {}, "secret": {}, "password": {}, "token": {},
	"authorization": {}, "bearer": {},
	// User-supplied identifiers that are content by nature. 本质即内容的用户标识。
	"filename": {}, "query": {}, "question": {},
}

// redactSuffixes catch the common compound forms (`gateway_api_key`, `refresh_token`, …) so a new
// field does not leak merely because it prefixed an existing sensitive name.
// 复合形后缀,免得新字段仅因加了前缀就绕过。
var redactSuffixes = []string{"_api_key", "_key", "_secret", "_password", "_token", "_prompt", "_body", "_url"}

// isSensitiveKey reports whether a field's value must never be written.
func isSensitiveKey(key string) bool {
	k := strings.ToLower(key)
	if _, ok := redactKeys[k]; ok {
		return true
	}
	for _, suffix := range redactSuffixes {
		if strings.HasSuffix(k, suffix) {
			return true
		}
	}
	return false
}

// redactFields returns fields with every sensitive value replaced. The slice is copied only when a
// replacement is actually needed, so the common (clean) path allocates nothing.
//
// 返回替换过敏感值的字段;仅在真需替换时才拷贝切片,故干净路径零分配。
func redactFields(fields []zapcore.Field) []zapcore.Field {
	idx := -1
	for i, f := range fields {
		if isSensitiveKey(f.Key) {
			idx = i
			break
		}
	}
	if idx < 0 {
		return fields
	}
	out := make([]zapcore.Field, len(fields))
	copy(out, fields)
	for i := idx; i < len(out); i++ {
		if isSensitiveKey(out[i].Key) {
			// Replace the whole field, not just its string member: a sensitive key may carry an
			// arbitrary struct/map via zap.Any, whose contents an encoder would happily walk.
			// 整字段替换而非只换字符串成员:敏感键可能经 zap.Any 携带任意结构,编码器会照样展开它。
			out[i] = zapcore.Field{Key: out[i].Key, Type: zapcore.StringType, String: redactedValue}
		}
	}
	return out
}

// redactCore wraps a core so redaction happens once, below every call site and above every sink.
//
// redactCore 包住 core,使脱敏只发生一次——在所有调用点之下、所有 sink 之上。
type redactCore struct{ zapcore.Core }

func (c redactCore) With(fields []zapcore.Field) zapcore.Core {
	return redactCore{Core: c.Core.With(redactFields(fields))}
}

func (c redactCore) Check(e zapcore.Entry, ce *zapcore.CheckedEntry) *zapcore.CheckedEntry {
	if c.Enabled(e.Level) {
		return ce.AddCore(e, c)
	}
	return ce
}

func (c redactCore) Write(e zapcore.Entry, fields []zapcore.Field) error {
	return c.Core.Write(e, redactFields(fields))
}
