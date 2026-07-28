package apikey

import (
	"strings"
	"testing"

	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

// The provider CATALOG hides the mock fixture outside dev (WRK-062 S-5) while key creation keeps
// accepting it (T6 testend provisions mock keys without ANSELM_DEV — only the user-facing dropdown
// must not show it). 目录非 dev 藏 mock(S-5);建 key 白名单不动(T6 设施)。
func TestListProviders_MockIsDevOnly(t *testing.T) {
	has := func(list []ProviderMeta, name string) bool {
		for _, m := range list {
			if m.Name == name {
				return true
			}
		}
		return false
	}
	if has(ListProviders(false), "mock") {
		t.Error("mock must be filtered from the non-dev catalog")
	}
	if !has(ListProviders(true), "mock") {
		t.Error("mock must stay listed under dev")
	}
	// The creation whitelist is untouched — mock keys still validate. 建 key 白名单不动。
	if !isValidProvider("mock") {
		t.Error("mock must remain a VALID provider for key creation (testend fixture)")
	}
}

// TestProviderMeta_TemplateBaseURLIsAHintNotAValue pins a bug that would have shipped: four
// catalog providers publish an `api` containing `${ENV_VAR}` because their endpoint carries the
// customer's own account name. Prefilled verbatim, the user saves
// `https://${DATABRICKS_HOST}/…` and gets a connect failure whose message never mentions the
// literal `${…}` still sitting in the field.
//
// TestProviderMeta_TemplateBaseURLIsAHintNotAValue 钉住一个**本来会发出去**的 bug:四家目录
// provider 发布的 `api` 里带 `${ENV_VAR}`,因为它们的端点里含着客户自己的账号名。原样预填的话,
// 用户会保存 `https://${DATABRICKS_HOST}/…`,换来一次**只字不提**字段里那个字面 `${…}` 的连接失败。
func TestProviderMeta_TemplateBaseURLIsAHintNotAValue(t *testing.T) {
	m, ok := GetProviderMeta("databricks")
	if !ok {
		t.Skip("databricks absent from the vendored catalog")
	}
	if m.DefaultBaseURL != "" {
		t.Errorf("a ${…} template must not be prefilled as a value, got %q", m.DefaultBaseURL)
	}
	if !m.BaseURLRequired {
		t.Error("with no usable default the user must supply one")
	}
	if m.BaseURLHint == "" || !strings.Contains(m.BaseURLHint, "${") {
		t.Errorf("the template is the most useful thing on the form — keep it as a hint, got %q", m.BaseURLHint)
	}
}

// TestProviderMeta_ComesFromTheCatalog: the LLM whitelist is no longer hand-written. A provider
// nobody typed into this package must still resolve, carry its catalog display name, and be marked
// un-curated so the UI can say「这家我们没试过」rather than blaming the user's key.
//
// TestProviderMeta_ComesFromTheCatalog:LLM 白名单不再手写。一家**没人在本包里打过字**的 provider
// 仍须解析得出、带着它的目录显示名,并被标为未验证,好让 UI 说「这家我们没试过」、而不是去怪用户的 key。
func TestProviderMeta_ComesFromTheCatalog(t *testing.T) {
	m, ok := GetProviderMeta("groq")
	if !ok {
		t.Fatal("groq is in models.dev; the whitelist must reach it without a hand-written row")
	}
	if m.DisplayName == "" || m.DisplayName == "groq" {
		t.Errorf("display name should come from the catalog, got %q", m.DisplayName)
	}
	if m.Curated {
		t.Error("groq has no hand-written spec here; claiming otherwise would vouch for something we never ran")
	}
	if m.Category != CategoryLLM {
		t.Errorf("category = %q", m.Category)
	}
}

// TestProviderMeta_CredentialShapeIsDeclared: Vertex is the only provider whose「key」is not a
// pasted string but a service-account JSON FILE, and the UI cannot guess that. A text box labelled
// 「API key」would send the user looking for a key that does not exist on their Google project.
//
// TestProviderMeta_CredentialShapeIsDeclared:Vertex 是唯一「key」不是粘贴字符串、而是一个服务账号
// **JSON 文件**的家,而 UI 猜不出来。一个写着「API key」的文本框会把用户送去找一把在他的 Google 项目里
// **根本不存在**的 key。
func TestProviderMeta_CredentialShapeIsDeclared(t *testing.T) {
	v, ok := GetProviderMeta("google-vertex")
	if !ok {
		t.Fatal("vertex is implemented now (service-account token + OpenAI-compatible endpoint)")
	}
	if v.Credential != CredentialServiceAccountJSON {
		t.Errorf("vertex credential = %q, want the file kind", v.Credential)
	}
	if v.TestMethod != TestMethodVertexToken {
		t.Errorf("vertex probe = %q; minting the token IS the check", v.TestMethod)
	}
	if !v.BaseURLRequired {
		t.Error("the vertex host carries the user's region, so it must be supplied")
	}
	// Everyone else stays a pasted string — a credential kind that spread would put a file picker in
	// front of an ordinary API key. 其余各家仍是粘贴字符串——一个会扩散的凭证种类,会把文件选择器摆到
	// 一把普通 API key 前面。
	for _, name := range []string{"openai", "groq", "azure", "amazon-bedrock", "anselm"} {
		m, ok := GetProviderMeta(name)
		if !ok {
			continue
		}
		if m.Credential != CredentialAPIKey {
			t.Errorf("%s credential = %q, want a plain key", name, m.Credential)
		}
	}
}

// TestProviderMeta_EveryOfferedProviderIsReachable: the honest-absence law applied to dialects —
// whatever the offered list contains must be something this build can actually talk to. With Vertex
// implemented the catalog now has no unspeakable dialect left, so the assertion is stated as the
// INVARIANT rather than against a particular example that keeps becoming reachable.
//
// TestProviderMeta_EveryOfferedProviderIsReachable:诚实缺席律用在方言上——摆出来的每一家都必须是本
// 构建**真的说得了**的。Vertex 实现之后目录里已**没有**说不了的方言,故这条断言写成**不变量**、而不是
// 对着某个「总在变得可达」的具体例子。
func TestProviderMeta_EveryOfferedProviderIsReachable(t *testing.T) {
	for _, p := range ListProviders(true) {
		if p.Category != CategoryLLM {
			continue
		}
		if !isValidProvider(p.Name) {
			t.Errorf("%s is offered but would be refused at key creation", p.Name)
		}
	}
	if !isValidProvider("azure") {
		t.Error("azure IS implemented (deployment in the path + api-key header)")
	}
	// Bedrock's OpenAI-compatible endpoint is region-specific, so the base URL is the user's to
	// supply — but the provider itself is reachable.
	// Bedrock 的 OpenAI 兼容端点按区域不同,故 base URL 归用户填——但这家**本身是够得着的**。
	m, ok := GetProviderMeta("amazon-bedrock")
	if !ok || !isValidProvider("amazon-bedrock") {
		t.Fatal("bedrock speaks OpenAI-compatible chat completions with a bearer token")
	}
	if !m.BaseURLRequired {
		t.Error("the bedrock endpoint carries a region, so the user must supply the base URL")
	}
}

// TestProviderMeta_HandWrittenURLTablesStayHonest guards the two hand-written maps H12-f added, in
// the three ways a hand-written table rots:
//
//   - a row for a provider the catalog no longer has is DEAD — it will never be read again, and it
//     reads like a maintained fact;
//   - a row that duplicates what the catalog already publishes is WORSE than dead: the catalog moves
//     on and our copy silently wins;
//   - a hint that is a real address (or a value that is a template) inverts the whole point —
//     `BaseURLRequired` would come out backwards and the user would be asked for something we have,
//     or handed a `{region}` to call.
//
// TestProviderMeta_HandWrittenURLTablesStayHonest 守住 H12-f 加的两张手写表,按手写表腐烂的三种方式:
//
//   - 目录已经没有的那家的行是**死的**——它再也不会被读到,却读起来像一条在维护的事实;
//   - 与目录**已经公布**的重复的行比死的更糟:目录往前走,而我们的副本静默地赢;
//   - 一条是真地址的 hint(或一个是模板的值)把整件事**反过来了**——`BaseURLRequired` 会算反,
//     用户会被要求填一样我们本来就有的东西、或者拿到一个 `{region}` 去调用。
func TestProviderMeta_HandWrittenURLTablesStayHonest(t *testing.T) {
	for id, url := range knownBaseURLs {
		p, ok := llminfra.CatalogProvider(id)
		if !ok {
			t.Errorf("knownBaseURLs has %q, which the catalog no longer names", id)
			continue
		}
		if p.BaseURL != "" {
			t.Errorf("knownBaseURLs duplicates %q — the catalog publishes %q", id, p.BaseURL)
		}
		if strings.Contains(url, "{") || strings.Contains(url, "$") {
			t.Errorf("knownBaseURLs[%q] = %q is a template, not an address", id, url)
		}
		if !strings.HasPrefix(url, "https://") {
			t.Errorf("knownBaseURLs[%q] = %q is not an https URL", id, url)
		}
	}
	for id, hint := range knownBaseURLHints {
		p, ok := llminfra.CatalogProvider(id)
		if !ok {
			t.Errorf("knownBaseURLHints has %q, which the catalog no longer names", id)
			continue
		}
		if p.BaseURL != "" {
			t.Errorf("knownBaseURLHints duplicates %q — the catalog publishes %q", id, p.BaseURL)
		}
		if _, dup := knownBaseURLs[id]; dup {
			t.Errorf("%q is in BOTH tables — the value wins and the hint is dead", id)
		}
		if !strings.Contains(hint, "{") {
			t.Errorf("knownBaseURLHints[%q] = %q has no placeholder — if it is a real address it belongs in knownBaseURLs", id, hint)
		}
		// A hint must still leave the field required — it is a shape, not a value.
		// hint 必须仍然让那一栏是必填的——它是形状、不是值。
		m, _ := GetProviderMeta(id)
		if !m.BaseURLRequired || m.DefaultBaseURL != "" {
			t.Errorf("%q has a hint but is not asking the user for a value (required=%v default=%q)", id, m.BaseURLRequired, m.DefaultBaseURL)
		}
	}
}
