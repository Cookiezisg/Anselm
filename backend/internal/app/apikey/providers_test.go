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

// TestProviderMeta_UnspeakableDialectIsRefusedAtCreation: Bedrock is in the catalog and has no
// implementation. It must be absent from the offered list AND rejected by validation — the
// honest-absence law: 功能诚实地不出现,而非调用后失败.
//
// TestProviderMeta_UnspeakableDialectIsRefusedAtCreation:Bedrock 在目录里、没有实现。它必须**不出现**
// 在可选列表里,并被校验拒绝——诚实缺席律:绝不「先摆出来、调了才失败」。
func TestProviderMeta_UnspeakableDialectIsRefusedAtCreation(t *testing.T) {
	if isValidProvider("amazon-bedrock") {
		t.Error("bedrock's dialect has no implementation; accepting the key moves the failure to the last hop")
	}
	for _, p := range ListProviders(false) {
		if p.Name == "amazon-bedrock" {
			t.Error("an unspeakable dialect must not be offered")
		}
	}
	if !isValidProvider("azure") {
		t.Error("azure IS implemented now (deployment in the path + api-key header)")
	}
}
