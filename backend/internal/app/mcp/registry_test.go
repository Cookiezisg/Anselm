// registry_test.go — built-in catalog shape + filter behaviour.
//
// registry_test.go ——内置目录形状 + 过滤行为。
package mcp

import (
	"runtime"
	"slices"
	"testing"

	mcpdomain "github.com/sunweilin/forgify/backend/internal/domain/mcp"
)

func TestRegistry_BuiltInSix(t *testing.T) {
	r := NewRegistry()
	all := r.List()
	if len(all) != 6 {
		t.Fatalf("List len = %d, want 6", len(all))
	}
	want := []string{"context7", "duckduckgo-search", "everything", "markitdown", "playwright", "sqlite"}
	for i, n := range want {
		if all[i].Name != n {
			t.Errorf("List[%d] = %q, want %q (alpha order)", i, all[i].Name, n)
		}
	}
}

func TestRegistry_Get_HappyPath(t *testing.T) {
	r := NewRegistry()
	for _, name := range []string{"playwright", "markitdown", "sqlite", "everything"} {
		e, ok := r.Get(name)
		if !ok {
			t.Errorf("Get(%q) = false, want true", name)
			continue
		}
		if e.Name != name {
			t.Errorf("Get(%q).Name = %q", name, e.Name)
		}
		if e.InstallCmd.Command == "" {
			t.Errorf("%s missing InstallCmd.Command", name)
		}
		if e.Runtime == "" {
			t.Errorf("%s missing Runtime", name)
		}
	}
}

func TestRegistry_Get_Unknown(t *testing.T) {
	r := NewRegistry()
	if _, ok := r.Get("nonexistent"); ok {
		t.Error("Get of unknown name returned ok=true")
	}
}

func TestRegistry_Visible_HidesHidden(t *testing.T) {
	r := NewRegistry()
	visible := r.Visible()
	for _, e := range visible {
		if e.Hidden {
			t.Errorf("Visible() returned Hidden entry: %q", e.Name)
		}
		if e.Name == "everything" {
			t.Errorf("Visible() returned 'everything' (Hidden=true)")
		}
	}
	// All 5 non-hidden entries should be present (assuming current GOOS
	// isn't in any UnsupportedPlatforms — V1 entries don't set it).
	// 5 个非 hidden 都应在（V1 条目未设 UnsupportedPlatforms）。
	if len(visible) != 5 {
		t.Errorf("Visible() len = %d, want 5 (5 non-hidden V1 entries)", len(visible))
	}
}

func TestRegistry_Visible_FiltersByGOOS(t *testing.T) {
	// Inject a synthetic entry that excludes the current GOOS via the
	// builtIns slice — done by clearing once + replacing the index.
	// We can't mutate package-level builtInEntries safely across tests,
	// so build a private Registry that bypasses the once.Do guard.
	//
	// 注入合成条目排除当前 GOOS——清 once + 替换 index。无法跨测安全
	// 改 package-level builtInEntries，所以建 private Registry 跳过
	// once.Do 守卫。
	r := &Registry{
		idx: map[string]mcpdomain.RegistryEntry{
			"keep": {Name: "keep", Runtime: "node"},
			"hide": {Name: "hide", Runtime: "node", UnsupportedPlatforms: []string{runtime.GOOS}},
		},
	}
	// trigger ensureIndexed-skip by completing once
	r.once.Do(func() {})

	visible := r.Visible()
	names := make([]string, 0, len(visible))
	for _, e := range visible {
		names = append(names, e.Name)
	}
	if slices.Contains(names, "hide") {
		t.Errorf("Visible() leaked entry with UnsupportedPlatforms=%v on GOOS=%s: %v",
			[]string{runtime.GOOS}, runtime.GOOS, names)
	}
	if !slices.Contains(names, "keep") {
		t.Errorf("Visible() dropped 'keep' which has no UnsupportedPlatforms: %v", names)
	}
}

func TestRegistry_Playwright_HasPostInstallChromium(t *testing.T) {
	r := NewRegistry()
	pw, _ := r.Get("playwright")
	if len(pw.PostInstallSteps) != 1 {
		t.Fatalf("playwright PostInstallSteps len = %d, want 1", len(pw.PostInstallSteps))
	}
	step := pw.PostInstallSteps[0]
	if !slices.Contains(step.Args, "chromium") {
		t.Errorf("playwright post-install should include 'chromium': %v", step.Args)
	}
	if !step.StreamProgress {
		t.Error("playwright post-install should StreamProgress (~150MB download)")
	}
	if pw.DefaultTimeoutSec != 60 {
		t.Errorf("playwright DefaultTimeoutSec = %d, want 60", pw.DefaultTimeoutSec)
	}
}

func TestRegistry_SQLite_HasDBPathRequiredArg(t *testing.T) {
	r := NewRegistry()
	sq, _ := r.Get("sqlite")
	if len(sq.RequiredArgs) != 1 {
		t.Fatalf("sqlite RequiredArgs len = %d, want 1", len(sq.RequiredArgs))
	}
	arg := sq.RequiredArgs[0]
	if arg.Name != "dbPath" || arg.Type != "path" {
		t.Errorf("sqlite required arg = %+v", arg)
	}
	// InstallCmd.Args must reference ${dbPath} for the template substitute.
	// InstallCmd.Args 必须引用 ${dbPath} 让模板替换工作。
	if !slices.Contains(sq.InstallCmd.Args, "${dbPath}") {
		t.Errorf("sqlite InstallCmd.Args missing ${dbPath} placeholder: %v", sq.InstallCmd.Args)
	}
}

func TestRegistry_Context7_OnlineOnly(t *testing.T) {
	r := NewRegistry()
	c7, _ := r.Get("context7")
	if !c7.OnlineOnly {
		t.Error("context7 should be marked OnlineOnly (calls hosted service)")
	}
}

func TestRegistry_AllBundledTrue(t *testing.T) {
	// V1 ships only Bundled=true entries; user-added customs go straight
	// into mcp.json and never live in the registry.
	// V1 仅含 Bundled=true 条目；用户自加的自定义直接进 mcp.json，永不
	// 在 registry 里。
	r := NewRegistry()
	for _, e := range r.List() {
		if !e.Bundled {
			t.Errorf("entry %q has Bundled=false; V1 should be all-bundled", e.Name)
		}
	}
}
