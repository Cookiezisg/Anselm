package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// TestParseAcceptLanguage — C-i18n-1: the parser is a two-outcome funnel — any header whose
// (lowercased, trimmed) value starts with "en" → LocaleEn; everything else (empty, garbage,
// zh, RTL, unsupported langs) → LocaleZhCN default. It supports exactly two AI-content
// locales, so a non-en header is never a 400 — it silently falls back to zh-CN.
//
// TestParseAcceptLanguage — C-i18n-1：解析器是二元漏斗——header（小写去空后）以 "en" 打头 → LocaleEn；
// 其余（空 / 垃圾 / zh / RTL / 不支持语言）→ LocaleZhCN 兜底。仅支持两种 AI 内容 locale，非 en 头绝不 400、静默降级 zh-CN。
func TestParseAcceptLanguage(t *testing.T) {
	cases := []struct {
		header string
		want   reqctxpkg.Locale
	}{
		// en* prefix → en
		{"en", reqctxpkg.LocaleEn},
		{"en-US", reqctxpkg.LocaleEn},
		{"EN-GB", reqctxpkg.LocaleEn},  // case-insensitive (lowercased before matching)
		{"  en  ", reqctxpkg.LocaleEn}, // trimmed
		{"en-US,en;q=0.9", reqctxpkg.LocaleEn},
		{"english", reqctxpkg.LocaleEn}, // prefix match, not exact

		// everything else → zh-CN default
		{"", reqctxpkg.LocaleZhCN},      // absent header
		{"   ", reqctxpkg.LocaleZhCN},   // whitespace only
		{"zh-CN", reqctxpkg.LocaleZhCN}, // the default language, explicit
		{"zh", reqctxpkg.LocaleZhCN},    //
		{"fr", reqctxpkg.LocaleZhCN},    // unsupported → fallback (not en)
		{"de-en", reqctxpkg.LocaleZhCN}, // "en" is not a PREFIX here
		{"ar", reqctxpkg.LocaleZhCN},    // RTL, unsupported
		{"he-IL", reqctxpkg.LocaleZhCN}, // RTL, unsupported
		{"*", reqctxpkg.LocaleZhCN},     // wildcard
		{"garbage-nonsense-value", reqctxpkg.LocaleZhCN},
		{"fr-FR,en;q=0.8", reqctxpkg.LocaleZhCN}, // first tag wins; French preferred → fallback
	}
	for _, c := range cases {
		if got := parseAcceptLanguage(c.header); got != c.want {
			t.Errorf("parseAcceptLanguage(%q) = %q, want %q", c.header, got, c.want)
		}
	}
}

// TestInjectLocale_SetsCtx — C-i18n-1: the middleware wires the parsed locale into the
// request ctx (where GetLocale reads it downstream), and defaults to zh-CN when the header
// is absent.
//
// TestInjectLocale_SetsCtx — C-i18n-1：中间件把解析出的 locale 注入 request ctx（下游 GetLocale 读它），
// header 缺失时兜底 zh-CN。
func TestInjectLocale_SetsCtx(t *testing.T) {
	cases := []struct {
		header string
		want   reqctxpkg.Locale
	}{
		{"en-US", reqctxpkg.LocaleEn},
		{"", reqctxpkg.LocaleZhCN},
		{"fr", reqctxpkg.LocaleZhCN},
	}
	for _, c := range cases {
		var got reqctxpkg.Locale
		h := InjectLocale(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
			got = reqctxpkg.GetLocale(r.Context())
		}))
		r := httptest.NewRequest(http.MethodGet, "/api/v1/functions", nil)
		if c.header != "" {
			r.Header.Set("Accept-Language", c.header)
		}
		h.ServeHTTP(httptest.NewRecorder(), r)
		if got != c.want {
			t.Errorf("InjectLocale with Accept-Language %q → ctx locale %q, want %q", c.header, got, c.want)
		}
	}
}
