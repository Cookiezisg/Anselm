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

// TestTrimUpstreamCatalog_ChatPredicate exercises the trim axes that remain EXCLUSIONS on a
// synthetic upstream: no-text-output dropped, realtime dropped, and a missing followed provider is
// a loud error (never a silently thinner catalog).
//
// `tool_call=false` used to be a fourth axis here and is no longer one — a tool-less model now
// survives carrying `tools:false` (H12-b). That half moved to
// [TestTrimUpstreamCatalog_ToolCallIsCarriedNotFiltered], which asserts the new law rather than
// the old one; the axis was rewritten, not deleted, because「一个模型能不能装下一次 chat」与
// 「它能不能当 agent」始终是两个问题,只是从前被同一个 continue 回答了。
//
// TestTrimUpstreamCatalog_ChatPredicate 用合成上游走**仍然是排除**的那几条裁剪轴:输出无 text 落选、
// realtime 落选、follow 家缺席大声报错(绝不静默变薄)。
//
// `tool_call=false` 曾是这里的第四条轴、现在不是了——没有工具的模型如今带着 `tools:false` 活下来
// (H12-b)。那一半搬去了 [TestTrimUpstreamCatalog_ToolCallIsCarriedNotFiltered],断言的是**新律**
// 而非旧律;这条轴是被**改写**、不是被删掉的。
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
		"image-only-out":{"tool_call":true,"modalities":{"input":["text"],"output":["image"]},"limit":{"context":1000,"output":100}},
		"gpt-realtime-x":{"tool_call":true,"modalities":{"input":["text","audio"],"output":["text","audio"]},"limit":{"context":1000,"output":100}}`))
	if err != nil {
		t.Fatalf("trim: %v", err)
	}
	oa := cat.Providers["openai"]
	if _, ok := oa["chat-ok"]; !ok {
		t.Errorf("chat-ok missing: %v", oa)
	}
	for _, dropped := range []string{"image-only-out", "gpt-realtime-x"} {
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

// TestTrimUpstreamCatalog_ToolCallIsCarriedNotFiltered is the H12-b decision written as a test: a
// model that cannot call tools STAYS in the catalog carrying `tools:false`, and one that cannot
// answer in text (or declares no window) does not.
//
// The distinction is the whole point. "No tools" is a limit on what the model can DO for you — a
// user may still want to chat with it, and the picker labels it. "No text output" and "no context
// window" are limits on whether a chat can happen at all: one cannot answer, the other cannot be
// sized. Filtering the first was throwing away usable models on the user's behalf, invisibly.
//
// TestTrimUpstreamCatalog_ToolCallIsCarriedNotFiltered 把 H12-b 的裁决写成测试:不会调工具的模型
// **留在**目录里、带着 `tools:false`;不会用文本作答(或没有声明窗口)的**不留**。
//
// 这个区分就是全部要点。「没有工具」限制的是模型能为你**做**什么——用户仍然可能想跟它聊天,而选择器
// 会标注它。「输出没有文本」与「没有上下文窗口」限制的是**一场聊天到底能不能发生**:一个答不了,
// 一个量不出信封。过滤掉前者,是**替用户**扔掉可用的模型,而且扔得看不见。
func TestTrimUpstreamCatalog_ToolCallIsCarriedNotFiltered(t *testing.T) {
	raw := []byte(`{
      "openai":{"models":{
        "chatty-no-tools":{"tool_call":false,"modalities":{"input":["text"],"output":["text"]},"limit":{"context":8000,"output":1000}},
        "agentic":{"tool_call":true,"modalities":{"input":["text"],"output":["text"]},"limit":{"context":8000,"output":1000}},
        "image-only":{"tool_call":true,"modalities":{"input":["text"],"output":["image"]},"limit":{"context":8000,"output":1000}},
        "no-window":{"tool_call":true,"modalities":{"input":["text"],"output":["text"]},"limit":{"context":0,"output":1000}},
        "gpt-realtime":{"tool_call":true,"modalities":{"input":["text"],"output":["text"]},"limit":{"context":8000,"output":1000}}}},
      "anthropic":{"models":{"c":{"tool_call":true,"modalities":{"input":["text"],"output":["text"]},"limit":{"context":8000,"output":1000}}}},
      "deepseek":{"models":{"d":{"tool_call":true,"modalities":{"input":["text"],"output":["text"]},"limit":{"context":8000,"output":1000}}}},
      "alibaba":{"models":{"q":{"tool_call":true,"modalities":{"input":["text"],"output":["text"]},"limit":{"context":8000,"output":1000}}}},
      "moonshotai":{"models":{"k":{"tool_call":true,"modalities":{"input":["text"],"output":["text"]},"limit":{"context":8000,"output":1000}}}},
      "zhipuai":{"models":{"g":{"tool_call":true,"modalities":{"input":["text"],"output":["text"]},"limit":{"context":8000,"output":1000}}}}}`)

	cat, err := TrimUpstreamCatalog(raw)
	if err != nil {
		t.Fatal(err)
	}
	got := cat.Providers["openai"]
	if m, ok := got["chatty-no-tools"]; !ok {
		t.Error("a tool-less model must SURVIVE the trim — hiding it is deciding for the user, invisibly")
	} else if m.Tools {
		t.Error("chatty-no-tools must carry tools:false so the picker can say 能聊天、不能当 agent")
	}
	if m, ok := got["agentic"]; !ok || !m.Tools {
		t.Errorf("a tool-calling model must survive carrying tools:true, got %+v ok=%v", m, ok)
	}
	for _, id := range []string{"image-only", "no-window", "gpt-realtime"} {
		if _, ok := got[id]; ok {
			t.Errorf("%q must NOT survive: it cannot hold a chat completion at all", id)
		}
	}
}
