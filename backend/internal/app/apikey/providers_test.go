package apikey

import (
	"strings"
	"testing"
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

// TestProviderMeta_UnspeakableDialectIsRefusedAtCreation: the honest-absence law applied to
// dialects. The example is Vertex, and it is the honest one for a reason the CATALOG states: its
// credential is a service-account JSON file (`GOOGLE_APPLICATION_CREDENTIALS`), not an API key, so
// routing it to the ordinary Gemini provider would 401 every time with a message that blames the
// user's key when Vertex does not take keys at all.
//
// **Bedrock used to be this test's example and no longer is** — not because the rule softened but
// because the fact changed: AWS serves an OpenAI-compatible Chat Completions endpoint authenticated
// by a plain bearer token, so 116 models became reachable with no new code. The `npm` package name
// (`@ai-sdk/amazon-bedrock`, which speaks Converse over SigV4) had said otherwise, which is the
// whole lesson: npm names WHICH SDK EXISTS, not WHAT THE PROVIDER CAN SPEAK.
//
// TestProviderMeta_UnspeakableDialectIsRefusedAtCreation:诚实缺席律用在方言上。例子用 Vertex,而它是
// 诚实的那个例子,理由**目录自己写着**:它的凭证是一个**服务账号 JSON 文件**、不是 API key,故把它路由
// 到普通 Gemini provider 会**每次都 401**,而消息会去怪用户的 key——可 Vertex **根本不收 key**。
//
// **Bedrock 曾经是这个测试的例子、现在不是了**——不是规则松了,是**事实变了**:AWS 提供 OpenAI 兼容的
// Chat Completions 端点、用普通 bearer 鉴权,于是 116 个模型**零新代码**变得可达。而 `npm` 包名
// (`@ai-sdk/amazon-bedrock`,讲的是 Converse + SigV4)说的是另一回事——这正是那条教训:npm 说的是
// **存在哪个 SDK**、不是**这家能说什么**。
func TestProviderMeta_UnspeakableDialectIsRefusedAtCreation(t *testing.T) {
	if isValidProvider("google-vertex") {
		t.Error("vertex takes a service-account file, not a key; accepting it moves the failure to a 401 that blames the user")
	}
	for _, p := range ListProviders(false) {
		if p.Name == "google-vertex" || p.Name == "google-vertex-anthropic" {
			t.Errorf("an unspeakable dialect must not be offered: %s", p.Name)
		}
	}
	if !isValidProvider("azure") {
		t.Error("azure IS implemented now (deployment in the path + api-key header)")
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
