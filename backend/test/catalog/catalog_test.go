//go:build pipeline

// catalog_test.go — pipeline tests for the Capability Catalog. Three
// offline scenarios drive the full registration → poll → fingerprint
// → mechanical-fallback path with real forge / skill / mcp services
// wired through the harness's CatalogSource adapters (D8-4).
//
// Scenarios per catalog.md §11:
//
//  1. AllSourcesCovered_E2E
//     Seed 1 forge + 1 skill via the harness services → call
//     Catalog.Refresh → assert Coverage map includes IDs from both
//     sources + Summary contains both names + chat's next system
//     prompt carries the catalog block.
//
//  2. ForgeDescriptionChange_TriggersRegen
//     Seed forge with description 'v1' → Refresh (Version=1) → update
//     forge.Description to 'v2' → Refresh again → assert Version=2,
//     fingerprint changed, Summary now contains 'v2'.
//
//  3. NoLLMKey_FallsBackToMechanical
//     Harness wires LLMGenerator but no apikey is seeded → Generator
//     fails LLM resolve → Service.Refresh switches to mechanical
//     fallback → assert GeneratedBy='mechanical-fallback' + lastFP
//     still updates (catalog.md §3 'user-activity-driven retry'
//     invariant — next tick won't re-call LLM until source data
//     actually changes).
//
// All three are offline (no LLM / no network). LLM-driven Generator
// happy-path coverage requires a live LLM and isn't included here —
// the prompt + parsing logic is unit-covered in
// internal/app/catalog/generator_test.go.
//
// catalog_test.go ——Capability Catalog 的 pipeline 测试。3 个离线场景驱
// 动注册 → 轮询 → fingerprint → mechanical-fallback 全路径，经 harness
// CatalogSource 适配器（D8-4）接 forge / skill / mcp 真服务。
package catalog

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	forgeapp "github.com/sunweilin/forgify/backend/internal/app/forge"
	th "github.com/sunweilin/forgify/backend/test/harness"
)

// seedSkillForCatalog writes a SKILL.md to harness's SkillsDir and
// triggers Service.Scan so the Skill source's ListItems returns it on
// the next catalog Refresh.
//
// seedSkillForCatalog 写 SKILL.md 到 harness SkillsDir + 调 Service.Scan
// 让 Skill source 下次 catalog Refresh 时返。
func seedSkillForCatalog(t *testing.T, h *th.Harness, name, desc string) {
	t.Helper()
	dir := filepath.Join(h.Skill.SkillsDir(), name)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatalf("mkdir skill dir: %v", err)
	}
	content := "---\nname: " + name + "\ndescription: " + desc + "\n---\n# Body\nrun.\n"
	if err := os.WriteFile(filepath.Join(dir, "SKILL.md"), []byte(content), 0o644); err != nil {
		t.Fatalf("write SKILL.md: %v", err)
	}
	if err := h.Skill.Scan(context.Background()); err != nil {
		t.Fatalf("Skill.Scan: %v", err)
	}
}

// ── 1. all 3 sources end-to-end ─────────────────────────────────────

func TestCatalog_AllSourcesCovered_E2E(t *testing.T) {
	h := th.New(t)

	// Seed one forge + one skill (no MCP server seeded — the mcp source
	// just returns an empty list, which is fine; coverage will only have
	// forge + skill keys).
	// 种一 forge + 一 skill（不种 MCP server——mcp source 返空，coverage
	// 只 forge + skill key）。
	forge := h.NewForge(t, "csv-clean", "def run(args):\n    return args\n")

	seedSkillForCatalog(t, h, "deploy", "Deploy via internal CI")

	if err := h.Catalog.Refresh(context.Background()); err != nil {
		t.Fatalf("Catalog.Refresh: %v", err)
	}

	cat := h.Catalog.Get()
	if cat == nil {
		t.Fatal("Catalog still nil after Refresh")
	}
	// Mechanical fallback fires (no apikey wired in this test variant).
	// mechanical fallback 启（本变体未接 apikey）。
	if cat.GeneratedBy != "mechanical-fallback" && cat.GeneratedBy != "llm" {
		t.Errorf("unexpected GeneratedBy=%q", cat.GeneratedBy)
	}

	// Coverage must list the seeded forge + skill IDs.
	// Coverage 必须列种入的 forge + skill ID。
	forgeIDs := cat.Coverage["forge"]
	skillIDs := cat.Coverage["skill"]
	if !contains(forgeIDs, forge.ID) {
		t.Errorf("Coverage[forge]=%v missing forge ID %q", forgeIDs, forge.ID)
	}
	if !contains(skillIDs, "deploy") {
		t.Errorf("Coverage[skill]=%v missing 'deploy'", skillIDs)
	}

	// Summary text contains item names so chat's LLM can read them.
	// Summary 文本含 item 名让 chat LLM 读到。
	if !strings.Contains(cat.Summary, "csv-clean") {
		t.Errorf("Summary missing forge name: %q", cat.Summary)
	}
	if !strings.Contains(cat.Summary, "deploy") {
		t.Errorf("Summary missing skill name: %q", cat.Summary)
	}

	// Catalog injection into chat: GetForSystemPrompt must return the
	// same Summary + this is what chat.runner.buildSystemPrompt
	// prepends to every conversation's system prompt (covered by the
	// chat unit test TestBuildSystemPrompt_NonEmptyProvider — here we
	// just verify the wiring upstream of that test path).
	// catalog 注入 chat：GetForSystemPrompt 返同 Summary + 这是
	// chat.runner.buildSystemPrompt 前置每个对话 system prompt 的内容
	// （chat 单测 TestBuildSystemPrompt_NonEmptyProvider 已覆盖；本处
	// 仅验那条路径上游接线）。
	if got := h.Catalog.GetForSystemPrompt(); got != cat.Summary {
		t.Errorf("GetForSystemPrompt mismatch with Get().Summary")
	}
}

// ── 2. description change triggers regen ────────────────────────────

func TestCatalog_ForgeDescriptionChange_TriggersRegen(t *testing.T) {
	h := th.New(t)

	forge := h.NewForge(t, "describe-me", "def run(a):\n    return a\n")

	// First Refresh — version may be > 1 if the harness's startup poll
	// tick already produced one before NewForge above. We only care that
	// the second Refresh after the description edit bumps Version + the
	// fingerprint changes.
	// 首次 Refresh——若 harness 启动 tick 在 NewForge 前已出 Version > 1
	// 也无碍。我们只关心描述编辑后的第二次 Refresh bump Version + fp 变。
	if err := h.Catalog.Refresh(context.Background()); err != nil {
		t.Fatalf("Refresh #1: %v", err)
	}
	first := h.Catalog.Get()
	versionFirst := first.Version
	fpFirst := first.Fingerprint

	// Update Description so the source's ListItems returns the new text.
	// fingerprint should change → next Refresh produces a new catalog.
	// 改 Description 让 source ListItems 返新文本。fingerprint 应变 →
	// 下次 Refresh 出新 catalog。
	newDesc := "VERSION-TWO description for fingerprint test"
	updated, err := h.Forge.Update(h.LocalCtx(), forge.ID, forgeapp.UpdateInput{
		Description: &newDesc,
	})
	if err != nil {
		t.Fatalf("Forge.Update: %v", err)
	}
	if updated.Description != newDesc {
		t.Fatalf("Description not updated; got %q", updated.Description)
	}

	if err := h.Catalog.Refresh(context.Background()); err != nil {
		t.Fatalf("Refresh #2: %v", err)
	}
	second := h.Catalog.Get()
	if second.Version <= versionFirst {
		t.Errorf("Version after #2 = %d, want > %d (description change should bust fingerprint)",
			second.Version, versionFirst)
	}
	if second.Fingerprint == fpFirst {
		t.Errorf("Fingerprint unchanged after description edit: %q", second.Fingerprint)
	}
	if !strings.Contains(second.Summary, "VERSION-TWO") {
		t.Errorf("Summary did not pick up new description; got %q", second.Summary)
	}
}

// ── 3. mechanical fallback when LLM unavailable ────────────────────

func TestCatalog_NoLLMKey_FallsBackToMechanical(t *testing.T) {
	h := th.New(t)
	h.NewForge(t, "alpha", "def run(a):\n    return a\n")

	// No apikey seeded (default harness state). LLMGenerator's
	// llmclient.Resolve will fail, the Generator returns
	// ErrGenerationFailed, and Service.Refresh falls back to
	// mechanical. lastFP must still update so the next tick doesn't
	// re-call LLM (per catalog.md §3 user-activity-driven retry).
	// 未种 apikey（harness 默认）。LLMGenerator 的 llmclient.Resolve 失
	// 败，Generator 返 ErrGenerationFailed，Service.Refresh 回
	// mechanical。lastFP 仍更新让下 tick 不再调 LLM（§3 用户活动驱动重试）。
	if err := h.Catalog.Refresh(context.Background()); err != nil {
		t.Fatalf("Refresh: %v", err)
	}
	cat := h.Catalog.Get()
	if cat == nil {
		t.Fatal("Catalog nil after Refresh; mechanical fallback should have produced one")
	}
	if cat.GeneratedBy != "mechanical-fallback" {
		t.Errorf("GeneratedBy=%q, want mechanical-fallback (LLM unavailable)", cat.GeneratedBy)
	}
	if cat.Fingerprint == "" {
		t.Errorf("Fingerprint empty; lastFP didn't update")
	}
	if !strings.Contains(cat.Summary, "alpha") {
		t.Errorf("mechanical Summary missing seeded forge name: %q", cat.Summary)
	}

	// Second Refresh with same source data must short-circuit — assert
	// Version is UNCHANGED rather than absolute Version=1 (the harness's
	// startup poll tick may have produced Version 1 before the test
	// seeded the forge, so this test's Refresh #1 was Version 2; what
	// matters is that the no-op Refresh #2 doesn't bump it again,
	// proving lastFP short-circuit prevents per-tick LLM re-tries.
	// 第二次 Refresh 同 source 数据必须短路——断言 Version 不变（而非绝对
	// Version=1）。harness 启动 poll tick 可能在测试种 forge 前出 Version
	// 1，让本测试 Refresh #1 已是 Version 2；关键是 no-op Refresh #2 不
	// 再 bump，证 lastFP 短路防 per-tick LLM 重试。
	versionAfterFirst := cat.Version
	if err := h.Catalog.Refresh(context.Background()); err != nil {
		t.Fatalf("Refresh #2: %v", err)
	}
	if h.Catalog.Get().Version != versionAfterFirst {
		t.Errorf("Version after no-op Refresh #2 = %d, want %d (lastFP short-circuit)",
			h.Catalog.Get().Version, versionAfterFirst)
	}
}

// ── helpers ─────────────────────────────────────────────────────────

func contains(xs []string, want string) bool {
	for _, x := range xs {
		if x == want {
			return true
		}
	}
	return false
}

