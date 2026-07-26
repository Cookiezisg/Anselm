package llm

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// restoreVendored re-parses the embedded snapshot into the active slot after a test that swapped
// it — the catalog is package-global state, so every mutating test must restore.
//
// restoreVendored 在换过目录的测试后把内嵌快照重新装回活动位——目录是包级全局态,凡改动的测试
// 必须还原。
func restoreVendored(t *testing.T) {
	t.Helper()
	t.Cleanup(func() {
		cat, err := ParseCatalog(vendoredCatalogJSON)
		if err != nil {
			t.Fatalf("restore vendored: %v", err)
		}
		currentCatalog.Store(cat)
	})
}

// TestVendoredCatalog_ShapeGuard pins the facts the whole 批A rests on: six followed providers,
// doubao gone (P2), no realtime ids, the omni/qwen-long lines absent upstream, and the modality
// arrays present where the projection needs them.
//
// TestVendoredCatalog_ShapeGuard 钉死批A 依赖的事实:六家在位、豆包撤(P2)、无 realtime id、
// omni/qwen-long 线上游缺席、投影所需模态数组在位。
func TestVendoredCatalog_ShapeGuard(t *testing.T) {
	cat, err := ParseCatalog(vendoredCatalogJSON)
	if err != nil {
		t.Fatalf("vendored snapshot invalid: %v", err)
	}
	if len(cat.Providers) != 6 {
		t.Fatalf("providers = %d, want exactly the six followed", len(cat.Providers))
	}
	if _, ok := cat.Providers["doubao"]; ok {
		t.Errorf("doubao present in catalog — P2 removed the provider entirely")
	}
	for _, ours := range []string{"openai", "anthropic", "deepseek", "qwen", "moonshot", "zhipu"} {
		models := cat.Providers[ours]
		if len(models) == 0 {
			t.Errorf("provider %q empty", ours)
		}
		for id := range models {
			if strings.Contains(id, "realtime") {
				t.Errorf("%s/%s: realtime models must be trimmed (they do not speak /chat/completions)", ours, id)
			}
		}
	}
	for _, gone := range []string{"qwen3.5-omni-plus", "qwen3.5-omni-flash", "qwen-long"} {
		if _, ok := cat.Providers["qwen"][gone]; ok {
			t.Errorf("qwen/%s present — absent upstream, must stay absent here (P1/P2)", gone)
		}
	}
	if m := cat.Providers["anthropic"]["claude-opus-4-8"]; !hasModality(m.In, "pdf") || !hasModality(m.In, "image") {
		t.Errorf("claude-opus-4-8 in=%v, want image+pdf per models.dev", m.In)
	}
	if m := cat.Providers["qwen"]["qwen3.7-plus"]; !hasModality(m.In, "video") || m.Ctx != 1_000_000 {
		t.Errorf("qwen3.7-plus = %+v, want video input + 1M ctx per models.dev", m)
	}
}

// TestTrimUpstreamCatalog_ChatPredicate exercises all three trim axes on a synthetic upstream:
// tool_call=false dropped, no-text-output dropped, realtime dropped; a missing followed provider
// is a loud error (never a silently thinner catalog).
//
// TestTrimUpstreamCatalog_ChatPredicate 用合成上游走全三条裁剪轴:tool_call=false 落选、输出无
// text 落选、realtime 落选;follow 家缺席大声报错(绝不静默变薄)。
func TestTrimUpstreamCatalog_ChatPredicate(t *testing.T) {
	mk := func(models string) []byte {
		base := `{
			"anthropic":{"models":{"claude-x":{"tool_call":true,"modalities":{"input":["text"],"output":["text"]},"limit":{"context":100,"output":10}}}},
			"deepseek":{"models":{"ds-x":{"tool_call":true,"modalities":{"input":["text"],"output":["text"]},"limit":{"context":100,"output":10}}}},
			"alibaba":{"models":{"qw-x":{"tool_call":true,"modalities":{"input":["text"],"output":["text"]},"limit":{"context":100,"output":10}}}},
			"moonshotai":{"models":{"kimi-x":{"tool_call":true,"modalities":{"input":["text"],"output":["text"]},"limit":{"context":100,"output":10}}}},
			"zhipuai":{"models":{"glm-x":{"tool_call":true,"modalities":{"input":["text"],"output":["text"]},"limit":{"context":100,"output":10}}}},
			"openai":{"models":{` + models + `}}}`
		return []byte(base)
	}
	cat, err := TrimUpstreamCatalog(mk(`
		"chat-ok":{"tool_call":true,"modalities":{"input":["text","image"],"output":["text"]},"limit":{"context":1000,"output":100}},
		"embed-no-tools":{"tool_call":false,"modalities":{"input":["text"],"output":["text"]},"limit":{"context":1000,"output":100}},
		"image-only-out":{"tool_call":true,"modalities":{"input":["text"],"output":["image"]},"limit":{"context":1000,"output":100}},
		"gpt-realtime-x":{"tool_call":true,"modalities":{"input":["text","audio"],"output":["text","audio"]},"limit":{"context":1000,"output":100}}`))
	if err != nil {
		t.Fatalf("trim: %v", err)
	}
	oa := cat.Providers["openai"]
	if _, ok := oa["chat-ok"]; !ok {
		t.Errorf("chat-ok missing: %v", oa)
	}
	for _, dropped := range []string{"embed-no-tools", "image-only-out", "gpt-realtime-x"} {
		if _, ok := oa[dropped]; ok {
			t.Errorf("%s survived the trim, want dropped", dropped)
		}
	}
	// A followed provider absent upstream must fail loudly, not produce a thinner catalog.
	if _, err := TrimUpstreamCatalog([]byte(`{"openai":{"models":{}}}`)); err == nil {
		t.Errorf("trim with five providers absent: want error, got nil")
	}
}

// TestCatalog_CacheOverVendored proves the load priority (P11): a runtime-cached trim wins over
// the vendored snapshot, and a corrupt cache is rejected while the vendored snapshot stays active.
//
// TestCatalog_CacheOverVendored 证载入优先级(P11):运行时缓存赢过 vendored;损坏缓存被拒且
// vendored 继续生效。
func TestCatalog_CacheOverVendored(t *testing.T) {
	restoreVendored(t)
	dir := t.TempDir()
	cat, err := ParseCatalog(vendoredCatalogJSON)
	if err != nil {
		t.Fatal(err)
	}
	// Mark the cache by giving qwen3.7-plus a sentinel context window.
	m := cat.Providers["qwen"]["qwen3.7-plus"]
	m.Ctx = 777_777
	cat.Providers["qwen"]["qwen3.7-plus"] = m
	data, err := MarshalCatalog(cat)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, catalogCacheFile), data, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := LoadCatalogCache(dir); err != nil {
		t.Fatalf("LoadCatalogCache: %v", err)
	}
	models, err := newQwenProvider().DescribeModels(`{"data":[{"id":"qwen3.7-plus"}]}`)
	if err != nil || len(models) != 1 {
		t.Fatalf("describe after cache load: %v %v", models, err)
	}
	if models[0].ContextWindow != 777_777 {
		t.Errorf("ctx = %d, want the cached 777777 to beat the vendored value", models[0].ContextWindow)
	}
	// Corrupt cache: rejected, active catalog untouched.
	bad := t.TempDir()
	if err := os.WriteFile(filepath.Join(bad, catalogCacheFile), []byte(`{"providers":{}}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := LoadCatalogCache(bad); err == nil {
		t.Errorf("corrupt cache load: want error, got nil")
	}
	if got, _ := newQwenProvider().DescribeModels(`{"data":[{"id":"qwen3.7-plus"}]}`); len(got) != 1 || got[0].ContextWindow != 777_777 {
		t.Errorf("active catalog changed by a rejected cache: %+v", got)
	}
}

// TestCatalogRefresh_FailSilent points the refresher at a dead port: the previous catalog stays
// active and nothing panics — the refresh path must never blank the picker.
//
// TestCatalogRefresh_FailSilent 把刷新器指向死端口:旧目录继续生效、零 panic——刷新路径绝不
// 清空选择器。
func TestCatalogRefresh_FailSilent(t *testing.T) {
	restoreVendored(t)
	old := catalogUpstreamURL
	catalogUpstreamURL = "http://127.0.0.1:1/api.json"
	t.Cleanup(func() { catalogUpstreamURL = old })
	refreshCatalogOnce(t.Context(), t.TempDir(), nil)
	if models, err := newQwenProvider().DescribeModels(`{"data":[{"id":"qwen3.7-plus"}]}`); err != nil || len(models) != 1 {
		t.Errorf("catalog degraded after failed refresh: %v %v", models, err)
	}
}

// TestDescribe_MaskGatesProjection pins capability advertising = catalog modality ∧ dialect mask:
// kimi-k2.6 lists video input upstream but the Moonshot dialect cannot carry a video part, so
// Video must stay false; gpt-5.5 lists pdf and the OpenAI dialect renders file parts, so
// NativeDocs must be true.
//
// TestDescribe_MaskGatesProjection 钉死能力宣称 = 目录模态 ∧ 方言掩码:kimi-k2.6 上游列 video
// 输入而 Moonshot 方言载不动 video part,故 Video 必须 false;gpt-5.5 列 pdf 且 OpenAI 方言渲
// file part,故 NativeDocs 必须 true。
func TestDescribe_MaskGatesProjection(t *testing.T) {
	kimi, err := newMoonshotProvider().DescribeModels(`{"data":[{"id":"kimi-k2.6"}]}`)
	if err != nil || len(kimi) != 1 {
		t.Fatalf("moonshot describe: %v %v", kimi, err)
	}
	if !kimi[0].Vision || kimi[0].Video {
		t.Errorf("kimi-k2.6 = vision:%v video:%v, want vision-only (dialect mask gates video)", kimi[0].Vision, kimi[0].Video)
	}
	oai, err := newOpenAIProvider().DescribeModels(`{"data":[{"id":"gpt-5.5"}]}`)
	if err != nil || len(oai) != 1 {
		t.Fatalf("openai describe: %v %v", oai, err)
	}
	if !oai[0].NativeDocs || !oai[0].Vision {
		t.Errorf("gpt-5.5 = vision:%v nativeDocs:%v, want both (pdf ∧ file-part wire)", oai[0].Vision, oai[0].NativeDocs)
	}
}

// TestKnobsByPrefix_MostSpecificWins guards the rule-order convention the hand-written knob
// tables rely on.
//
// TestKnobsByPrefix_MostSpecificWins 守卫手写旋钮表依赖的规则顺序惯例。
func TestKnobsByPrefix_MostSpecificWins(t *testing.T) {
	rules := []knobRule{
		{"gpt-5.5", []Knob{boolKnob("specific", "S", "true")}},
		{"gpt-5", []Knob{boolKnob("generic", "G", "true")}},
	}
	f := knobsByPrefix(rules)
	if ks := f("gpt-5.5-pro"); len(ks) != 1 || ks[0].Key != "specific" {
		t.Errorf("gpt-5.5-pro knobs = %v, want the most specific rule", ks)
	}
	if ks := f("gpt-5.1"); len(ks) != 1 || ks[0].Key != "generic" {
		t.Errorf("gpt-5.1 knobs = %v, want the generic rule", ks)
	}
	if ks := f("unrelated"); ks != nil {
		t.Errorf("unmatched id knobs = %v, want nil", ks)
	}
}
