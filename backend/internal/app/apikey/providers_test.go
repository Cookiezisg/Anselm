// providers_test.go — unit tests for the provider registry.
//
// providers_test.go — provider 注册表的单元测试。
package apikey

import (
	"slices"
	"testing"

	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
)

// expectedProviders is the contract: these 11 LLM production names must
// always be supported. Removing one is a breaking change for existing data.
// Plus "mock" — dev-only LLM provider added by TE-4a for the testend Mock
// LLM tab; not removable but treated as a separate slot since user-facing
// provider lists should hide it. Plus 4 search providers added when
// WebSearch was switched to BYOK + MCP routing (屎山拯救计划 #4).
//
// expectedProviders 是契约：11 个 LLM 生产 provider 必须始终被支持。移除任一
// 项对已有数据造成破坏性变更。再加 "mock"——TE-4a 加的 dev-only LLM provider
// 给 testend Mock LLM tab；不可移但作独立 slot，因用户面 provider 列表应隐藏。
// 再加 4 个搜索 provider，WebSearch 切 BYOK + MCP 路由时引入（屎山拯救计划 #4）。
var expectedProviders = []string{
	"openai", "anthropic", "google", "deepseek", "openrouter",
	"qwen", "zhipu", "moonshot", "doubao", "ollama", "custom",
}

const expectedDevProviders = 1 // "mock"

var expectedSearchProviders = []string{"brave", "serper", "tavily", "bocha"}

func TestListProviders_ContainsAll(t *testing.T) {
	got := ListProviders()
	want := len(expectedProviders) + expectedDevProviders + len(expectedSearchProviders)
	if len(got) != want {
		t.Errorf("count: got %d, want %d (%d LLM production + %d dev + %d search)",
			len(got), want, len(expectedProviders), expectedDevProviders, len(expectedSearchProviders))
	}
	for _, name := range expectedProviders {
		if !slices.Contains(got, name) {
			t.Errorf("missing LLM production provider: %q", name)
		}
	}
	if !slices.Contains(got, "mock") {
		t.Errorf("missing dev provider: \"mock\" (added in TE-4a)")
	}
	for _, name := range expectedSearchProviders {
		if !slices.Contains(got, name) {
			t.Errorf("missing search provider: %q", name)
		}
	}
}

func TestIsValidProvider(t *testing.T) {
	for _, name := range expectedProviders {
		if !IsValidProvider(name) {
			t.Errorf("IsValidProvider(%q) = false, want true", name)
		}
	}

	invalid := []string{"", "OpenAI", "chatgpt", "baidu", "unknown", " openai"}
	for _, name := range invalid {
		if IsValidProvider(name) {
			t.Errorf("IsValidProvider(%q) = true, want false", name)
		}
	}
}

func TestGetProviderMeta_AllHaveRequiredFields(t *testing.T) {
	allNames := append([]string{}, expectedProviders...)
	allNames = append(allNames, expectedSearchProviders...)
	allNames = append(allNames, "mock")
	for _, name := range allNames {
		m, ok := GetProviderMeta(name)
		if !ok {
			t.Errorf("GetProviderMeta(%q) not found", name)
			continue
		}
		if m.Name != name {
			t.Errorf("%s: Name mismatch = %q", name, m.Name)
		}
		if m.DisplayName == "" {
			t.Errorf("%s: missing DisplayName", name)
		}
		if m.TestMethod == "" {
			t.Errorf("%s: missing TestMethod", name)
		}
		if m.Category == "" {
			t.Errorf("%s: missing Category", name)
		}
	}
}

func TestGetProviderMeta_SearchProvidersHaveSearchCategory(t *testing.T) {
	for _, name := range expectedSearchProviders {
		m, ok := GetProviderMeta(name)
		if !ok {
			t.Fatalf("GetProviderMeta(%q) not found", name)
		}
		if m.Category != CategorySearch {
			t.Errorf("%s: Category = %q, want %q", name, m.Category, CategorySearch)
		}
		if m.TestMethod != TestMethodSearchPing {
			t.Errorf("%s: TestMethod = %q, want %q", name, m.TestMethod, TestMethodSearchPing)
		}
		if m.DefaultBaseURL == "" {
			t.Errorf("%s: missing DefaultBaseURL", name)
		}
	}
}

func TestSearchProviderPriority_MatchesExpectedSet(t *testing.T) {
	// Priority list (in domain/apikey) and registered set (in this app
	// package) must agree — adding a search provider here without
	// updating the priority would cause it to never be tried by WebSearch.
	// 优先级列表（domain/apikey）与已注册集合（此 app 包）必须一致——这里
	// 加搜索 provider 不改优先级会让 WebSearch 永远不试它。
	priority := apikeydomain.SearchProviderPriority
	if len(priority) != len(expectedSearchProviders) {
		t.Errorf("SearchProviderPriority len = %d, want %d", len(priority), len(expectedSearchProviders))
	}
	for _, name := range priority {
		if !slices.Contains(expectedSearchProviders, name) {
			t.Errorf("SearchProviderPriority has %q which is not in expectedSearchProviders", name)
		}
	}
}

func TestGetProviderMeta_BaseURLRequiredFlags(t *testing.T) {
	// ollama and custom MUST require base_url (no sensible default).
	// Everyone else MUST have a default base_url.
	//
	// ollama 和 custom **必须**要求 base_url（没有合理默认值）。
	// 其他 provider **必须**有默认 base_url。
	cases := []struct {
		name            string
		baseURLRequired bool
	}{
		{"openai", false},
		{"anthropic", false},
		{"google", false},
		{"deepseek", false},
		{"openrouter", false},
		{"qwen", false},
		{"zhipu", false},
		{"moonshot", false},
		{"doubao", false},
		{"ollama", true},
		{"custom", true},
	}
	for _, c := range cases {
		m, _ := GetProviderMeta(c.name)
		if m.BaseURLRequired != c.baseURLRequired {
			t.Errorf("%s: BaseURLRequired = %v, want %v", c.name, m.BaseURLRequired, c.baseURLRequired)
		}
		if !c.baseURLRequired && m.DefaultBaseURL == "" {
			t.Errorf("%s: missing DefaultBaseURL (not required-provider)", c.name)
		}
	}
}

func TestGetProviderMeta_Unknown(t *testing.T) {
	_, ok := GetProviderMeta("nonexistent")
	if ok {
		t.Errorf("GetProviderMeta(\"nonexistent\") = true, want false")
	}
}
