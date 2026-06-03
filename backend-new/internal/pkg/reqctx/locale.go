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
