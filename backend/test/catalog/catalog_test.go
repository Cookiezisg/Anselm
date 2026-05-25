//go:build pipeline

// Package catalog runs pipeline tests for the Capability Catalog.
//
// Package catalog 跑 Capability Catalog pipeline 测试。
package catalog

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	functionapp "github.com/sunweilin/forgify/backend/internal/app/function"
	th "github.com/sunweilin/forgify/backend/test/harness"
)

// seedSkillForCatalog writes a SKILL.md and triggers Scan so the next build sees it.
//
// seedSkillForCatalog 写 SKILL.md 并 Scan，让下次构建看到它。
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

func TestCatalog_AllSourcesCovered_E2E(t *testing.T) {
	h := th.New(t)

	fn := h.NewFunction(t, "csv_clean", "def csv_clean(args):\n    return args\n")
	seedSkillForCatalog(t, h, "deploy", "Deploy via internal CI")

	cat, err := h.Catalog.Get(h.LocalCtx())
	if err != nil {
		t.Fatalf("Catalog.Get: %v", err)
	}
	if cat.GeneratedBy != "mechanical" {
		t.Errorf("GeneratedBy=%q, want mechanical", cat.GeneratedBy)
	}

	functionIDs := cat.Coverage["function"]
	skillIDs := cat.Coverage["skill"]
	if !contains(functionIDs, fn.ID) {
		t.Errorf("Coverage[function]=%v missing function ID %q", functionIDs, fn.ID)
	}
	if !contains(skillIDs, "deploy") {
		t.Errorf("Coverage[skill]=%v missing 'deploy'", skillIDs)
	}

	if !strings.Contains(cat.Summary, "csv_clean") {
		t.Errorf("Summary missing function name: %q", cat.Summary)
	}
	if !strings.Contains(cat.Summary, "deploy") {
		t.Errorf("Summary missing skill name: %q", cat.Summary)
	}

	if got := h.Catalog.GetForSystemPrompt(h.LocalCtx()); got != cat.Summary {
		t.Errorf("GetForSystemPrompt mismatch with Get().Summary")
	}
}

func TestCatalog_FunctionDescriptionChange_ReflectedOnRebuild(t *testing.T) {
	h := th.New(t)

	fn := h.NewFunction(t, "describe_me", "def describe_me(a):\n    return a\n")

	if _, err := h.Catalog.Get(h.LocalCtx()); err != nil {
		t.Fatalf("Get #1: %v", err)
	}

	newDesc := "VERSION-TWO description for rebuild test"
	updated, err := h.Function.UpdateMeta(h.LocalCtx(), functionapp.UpdateMetaInput{
		ID:          fn.ID,
		Description: &newDesc,
	})
	if err != nil {
		t.Fatalf("Function.UpdateMeta: %v", err)
	}
	if updated.Description != newDesc {
		t.Fatalf("Description not updated; got %q", updated.Description)
	}

	second, err := h.Catalog.Get(h.LocalCtx())
	if err != nil {
		t.Fatalf("Get #2: %v", err)
	}
	if !strings.Contains(second.Summary, "VERSION-TWO") {
		t.Errorf("Summary did not pick up new description; got %q", second.Summary)
	}
}

func TestCatalog_AlwaysMechanical(t *testing.T) {
	h := th.New(t)
	h.NewFunction(t, "alpha", "def alpha(a):\n    return a\n")

	cat, err := h.Catalog.Get(h.LocalCtx())
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if cat.GeneratedBy != "mechanical" {
		t.Errorf("GeneratedBy=%q, want mechanical", cat.GeneratedBy)
	}
	if !strings.Contains(cat.Summary, "alpha") {
		t.Errorf("mechanical Summary missing seeded function name: %q", cat.Summary)
	}
}

func contains(xs []string, want string) bool {
	for _, x := range xs {
		if x == want {
			return true
		}
	}
	return false
}
