// generator_test.go — exercises the buildPrompt unit helper. Full
// Generator.Generate is covered integration-style via the pipeline tests
// (D8-7) since it requires a real or fake LLM transport.
//
// Post-2026-05-08 屎山拯救计划 #7: removed tests for findMissing /
// groupSourceIDs / missing-hint retry path — those helpers are gone.
//
// generator_test.go ——验 buildPrompt 单元 helper。完整 Generator.Generate
// 由 pipeline 测试（D8-7）集成式覆盖，因其需真/假 LLM 传输。
//
// 2026-05-08 屎山拯救计划 #7 后：删了 findMissing / groupSourceIDs / 漏 hint
// 重试路径的测试——这些 helper 已删。
package catalog

import (
	"strings"
	"testing"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
)

func TestBuildPrompt_ContainsAllItems(t *testing.T) {
	items := []catalogdomain.Item{
		{Source: "forge", ID: "f_a", Name: "alpha", Description: "first forge"},
		{Source: "skill", ID: "s_b", Name: "beta", Description: "first skill"},
		{Source: "mcp", ID: "github", Name: "github", Description: "github server"},
	}
	gMap := map[string]catalogdomain.Granularity{
		"forge": catalogdomain.PerItem,
		"skill": catalogdomain.PerItem,
		"mcp":   catalogdomain.PerServer,
	}
	got := buildPrompt(items, gMap)

	for _, want := range []string{
		"f_a", "alpha", "first forge",
		"s_b", "beta", "first skill",
		"github", "github server",
		"granularity=PerItem", "granularity=PerServer",
	} {
		if !strings.Contains(got, want) {
			t.Errorf("prompt missing %q\nfull prompt:\n%s", want, got)
		}
	}
}

func TestBuildPrompt_NoRetryHintArtifact(t *testing.T) {
	// Single-attempt design: there is no "previous attempt missed" hint
	// any more. This test guards against accidental reintroduction (e.g.
	// someone adding back the missingHint param without thinking).
	//
	// 单次设计：不再有 "previous attempt missed" hint。本测试防意外重引
	// （比如有人想都没想就把 missingHint 参数加回来）。
	got := buildPrompt(
		[]catalogdomain.Item{{Source: "forge", ID: "f", Name: "x", Description: "y"}},
		map[string]catalogdomain.Granularity{"forge": catalogdomain.PerItem},
	)
	if strings.Contains(got, "previous attempt missed") {
		t.Errorf("retry-hint phrasing leaked into single-attempt prompt:\n%s", got)
	}
}

func TestNewLLMGenerator_NilLogOK(t *testing.T) {
	// NewLLMGenerator should accept nil logger and substitute zap.Nop —
	// matches the convention from mcp.NewStdioClient and the post-#1 skill
	// service constructor.
	//
	// NewLLMGenerator 应接 nil log + 替 zap.Nop——与 mcp.NewStdioClient 等约定一致。
	g := NewLLMGenerator(nil, nil, nil, nil)
	if g == nil {
		t.Fatal("NewLLMGenerator returned nil")
	}
	if g.log == nil {
		t.Error("log should be non-nil after construction even with nil arg")
	}
}
