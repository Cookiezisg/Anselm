// generator_test.go — exercises the buildPrompt / findMissing /
// groupSourceIDs unit helpers. Full Generator.Generate is covered
// integration-style via the pipeline tests (D8-7) since it requires
// a real or fake LLM transport — covering it here would mean
// re-implementing the LLM client mock.
//
// generator_test.go ——验 buildPrompt / findMissing / groupSourceIDs
// 单元 helper。完整 Generator.Generate 由 pipeline 测试（D8-7）集成式
// 覆盖，因其需真/假 LLM 传输——本文件复刻 LLM client mock 不划算。
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
	got := buildPrompt(items, gMap, nil)

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

func TestBuildPrompt_NoMissingHint_OnFirstAttempt(t *testing.T) {
	got := buildPrompt(
		[]catalogdomain.Item{{Source: "forge", ID: "f", Name: "x", Description: "y"}},
		map[string]catalogdomain.Granularity{"forge": catalogdomain.PerItem},
		nil,
	)
	if strings.Contains(got, "previous attempt missed") {
		t.Errorf("first attempt prompt should not contain retry hint:\n%s", got)
	}
}

func TestBuildPrompt_MissingHint_OnRetry(t *testing.T) {
	got := buildPrompt(
		[]catalogdomain.Item{{Source: "forge", ID: "f", Name: "x", Description: "y"}},
		map[string]catalogdomain.Granularity{"forge": catalogdomain.PerItem},
		[]string{"forge/f_dropped", "skill/s_dropped"},
	)
	if !strings.Contains(got, "previous attempt missed") {
		t.Error("retry prompt missing hint header")
	}
	if !strings.Contains(got, "forge/f_dropped") || !strings.Contains(got, "skill/s_dropped") {
		t.Errorf("retry prompt missing specific dropped IDs:\n%s", got)
	}
}

func TestGroupSourceIDs(t *testing.T) {
	items := []catalogdomain.Item{
		{Source: "forge", ID: "f1"},
		{Source: "forge", ID: "f2"},
		{Source: "skill", ID: "s1"},
	}
	got := groupSourceIDs(items)
	if !got["forge"]["f1"] || !got["forge"]["f2"] {
		t.Errorf("forge IDs missing: %v", got["forge"])
	}
	if !got["skill"]["s1"] {
		t.Errorf("skill IDs missing: %v", got["skill"])
	}
	if len(got["mcp"]) != 0 {
		t.Errorf("mcp source should not appear; got %v", got["mcp"])
	}
}

func TestFindMissing_FullCoverage(t *testing.T) {
	want := groupSourceIDs([]catalogdomain.Item{
		{Source: "forge", ID: "f1"},
		{Source: "skill", ID: "s1"},
	})
	got := map[string][]string{"forge": {"f1"}, "skill": {"s1"}}
	if missing := findMissing(want, got); len(missing) != 0 {
		t.Errorf("findMissing reported missing on full coverage: %v", missing)
	}
}

func TestFindMissing_PartialCoverage(t *testing.T) {
	want := groupSourceIDs([]catalogdomain.Item{
		{Source: "forge", ID: "f1"},
		{Source: "forge", ID: "f2"},
		{Source: "skill", ID: "s1"},
	})
	got := map[string][]string{"forge": {"f1"}} // missing f2 + s1 entirely
	missing := findMissing(want, got)
	if len(missing) != 2 {
		t.Errorf("missing = %v, want 2 entries", missing)
	}
	wants := map[string]bool{"forge/f2": true, "skill/s1": true}
	for _, m := range missing {
		if !wants[m] {
			t.Errorf("unexpected missing entry %q", m)
		}
	}
}

func TestFindMissing_ExtraInGotIgnored(t *testing.T) {
	// LLM may merge / rename items in coverage that aren't in our
	// input — those are NOT errors (the LLM is allowed to be creative
	// in grouping). We only check that no input item is dropped.
	// LLM 可在 coverage 合并/改名输入没有的 item——不是错误（LLM 可在
	// 分组上创意）。我们只验输入 item 没漏。
	want := groupSourceIDs([]catalogdomain.Item{
		{Source: "forge", ID: "f1"},
	})
	got := map[string][]string{"forge": {"f1", "f_extra"}, "extra-source": {"x"}}
	if missing := findMissing(want, got); len(missing) != 0 {
		t.Errorf("extras should not count as missing; got %v", missing)
	}
}

func TestNewLLMGenerator_NilLogOK(t *testing.T) {
	// NewLLMGenerator should accept nil logger and substitute zap.Nop —
	// matches the convention from skill.NewWatcher / mcp.NewStdioClient.
	// NewLLMGenerator 应接 nil log + 替 zap.Nop——同 skill.NewWatcher /
	// mcp.NewStdioClient 约定。
	g := NewLLMGenerator(nil, nil, nil, nil)
	if g == nil {
		t.Fatal("NewLLMGenerator returned nil")
	}
	if g.log == nil {
		t.Error("log should be non-nil after construction even with nil arg")
	}
}
