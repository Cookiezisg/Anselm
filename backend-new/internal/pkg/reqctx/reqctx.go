// Package reqctx carries request-scoped values through context.Context.
//
// Layout: generic attributes that belong to no business entity (locale, …) live in this
// file; a named identity that owns a full domain (workspace) gets its own file
// (workspace.go). Both stay in this base pkg package rather than the workspace business
// module — writing the workspace id into ctx is a cross-cutting concern done by HTTP
// middleware, wired before any business package exists; putting it in the workspace module
// would invert the layer order.
//
// Keys are private empty structs to avoid collisions. Pure stdlib — no upstream deps.
//
// Package reqctx 通过 context.Context 传递请求作用域的值。
//
// 布局：不属于任何业务实体的通用属性（locale 等）放本文件；拥有完整业务域的具名身份（workspace）
// 单独成文件（workspace.go）。两者都留在本地基 pkg 包、而非 workspace 业务模块——把 workspace id
// 写入 ctx 是横切关注点，由 HTTP 中间件完成、在任何业务包存在前就接线；放进 workspace 模块会倒置层级。
// 私有 empty-struct key 防冲突。纯 stdlib，无上层依赖。
package reqctx

import "context"

// Locale is the workspace's preferred language for AI-generated content; not for backend error messages.
//
// Locale 是工作区偏好的 AI 生成内容语言；不用于后端错误消息。
type Locale string

const (
	LocaleZhCN    Locale = "zh-CN"
	LocaleEn      Locale = "en"
	DefaultLocale        = LocaleZhCN
)

// IsSupported reports whether the locale is one this backend handles.
//
// IsSupported 报告该 locale 是否被后端支持。
func (l Locale) IsSupported() bool {
	return l == LocaleZhCN || l == LocaleEn
}

type localeKey struct{}

// SetLocale returns a copy of ctx carrying l.
//
// SetLocale 返回携带 l 的 ctx 拷贝。
func SetLocale(ctx context.Context, l Locale) context.Context {
	return context.WithValue(ctx, localeKey{}, l)
}

// GetLocale returns the carried locale, or DefaultLocale when unset/unsupported; always usable.
//
// GetLocale 返回携带的 locale，未设/不支持时返 DefaultLocale；总返回可用值。
func GetLocale(ctx context.Context) Locale {
	if l, ok := ctx.Value(localeKey{}).(Locale); ok && l.IsSupported() {
		return l
	}
	return DefaultLocale
}
