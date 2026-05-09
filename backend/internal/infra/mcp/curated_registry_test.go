package mcp

import (
	"context"
	"errors"
	"strings"
	"testing"

	mcpdomain "github.com/sunweilin/forgify/backend/internal/domain/mcp"
)

// TestCurated_ListCount asserts the curated catalog stays at the
// expected size — adding/removing entries should be a deliberate change
// reflected here, not a silent edit.
//
// TestCurated_ListCount 守 curated 数量 — 增删条目需显式改这测试，
// 防止悄悄改清单。
func TestCurated_ListCount(t *testing.T) {
	if got := len(curatedEntries); got != 21 {
		t.Errorf("curatedEntries count = %d, want 21 — update both the catalog and this guard if changing intentionally", got)
	}
}

// TestCurated_AllEntriesValid runs minimal sanity checks per entry:
// required fields populated, runtime is one of node/python, install
// command non-empty, Tier >= 1 entries declare a SetupURL, etc.
//
// TestCurated_AllEntriesValid 逐条最小合法性：必填非空、runtime 是
// node/python、install cmd 非空、Tier >= 1 必带 SetupURL 等。
func TestCurated_AllEntriesValid(t *testing.T) {
	seen := map[string]bool{}
	validRuntime := map[string]bool{"node": true, "python": true}

	for _, e := range curatedEntries {
		if e.Name == "" {
			t.Errorf("entry has empty Name: %+v", e)
			continue
		}
		if seen[e.Name] {
			t.Errorf("duplicate Name %q", e.Name)
		}
		seen[e.Name] = true

		if e.Description == "" {
			t.Errorf("%s: empty Description", e.Name)
		}
		if !validRuntime[e.Runtime] {
			t.Errorf("%s: invalid Runtime %q (want node or python)", e.Name, e.Runtime)
		}
		if e.InstallCmd.Command == "" {
			t.Errorf("%s: empty InstallCmd.Command", e.Name)
		}
		if len(e.InstallCmd.Args) == 0 {
			t.Errorf("%s: empty InstallCmd.Args", e.Name)
		}
		if e.Category == "" {
			t.Errorf("%s: empty Category", e.Name)
		}
		if e.Tier < 0 || e.Tier > 3 {
			t.Errorf("%s: Tier %d out of range [0,3]", e.Name, e.Tier)
		}
		// Tier >= 1 entries that declare RequiredEnv must each include a
		// SetupURL — the marketplace UI relies on it for the "where to get
		// this key" link.
		// Tier >= 1 的 RequiredEnv 必须每条带 SetupURL — UI 拿来"在哪拿 key"。
		for _, env := range e.RequiredEnv {
			if env.Name == "" {
				t.Errorf("%s: RequiredEnv has empty Name", e.Name)
			}
			if env.Description == "" {
				t.Errorf("%s: RequiredEnv %s has empty Description", e.Name, env.Name)
			}
			if e.Tier >= 1 && env.SetupURL == "" {
				t.Errorf("%s: Tier %d but RequiredEnv %s lacks SetupURL", e.Name, e.Tier, env.Name)
			}
		}
		// Tier 2 (OAuth device code) needs explicit Notes — user must know
		// to watch stderr for the login URL.
		// Tier 2 (OAuth) 必带 Notes — 用户要知道看 stderr 找登录 URL。
		if e.Tier == 2 && len(e.RequiredEnv) == 0 && e.Notes == "" {
			t.Errorf("%s: OAuth-tier entry lacks Notes describing the auth flow", e.Name)
		}
	}
}

// TestCurated_RuntimeMix asserts the catalog stays node + python only
// (the whole point of curating is to let us drop other sandbox runtimes).
//
// TestCurated_RuntimeMix 守 catalog 只有 node + python — 这是砍 sandbox
// 多语种依据。
func TestCurated_RuntimeMix(t *testing.T) {
	for _, e := range curatedEntries {
		if e.Runtime != "node" && e.Runtime != "python" {
			t.Errorf("%s: runtime %q breaks the node+python-only invariant", e.Name, e.Runtime)
		}
	}
}

// TestCurated_NewSourceWiresAllEntries checks the constructor populates
// both lookup maps and that they're consistent.
//
// TestCurated_NewSourceWiresAllEntries 验构造器把两个 lookup 装齐 + 一致。
func TestCurated_NewSourceWiresAllEntries(t *testing.T) {
	src := NewCuratedRegistrySource()
	if got := len(src.all); got != len(curatedEntries) {
		t.Errorf("src.all = %d, want %d", got, len(curatedEntries))
	}
	if got := len(src.byName); got != len(curatedEntries) {
		t.Errorf("src.byName = %d, want %d", got, len(curatedEntries))
	}
	for _, e := range curatedEntries {
		if _, ok := src.byName[e.Name]; !ok {
			t.Errorf("byName missing %q", e.Name)
		}
	}
}

// TestCurated_List_AllEntriesReturned asserts List returns every
// curated entry exactly once.
//
// TestCurated_List_AllEntriesReturned List 返每条精确一次。
func TestCurated_List_AllEntriesReturned(t *testing.T) {
	src := NewCuratedRegistrySource()
	got, err := src.List(context.Background())
	if err != nil {
		t.Fatalf("List err: %v", err)
	}
	if len(got) != len(curatedEntries) {
		t.Errorf("List len = %d, want %d", len(got), len(curatedEntries))
	}
	seen := make(map[string]int, len(got))
	for _, e := range got {
		seen[e.Name]++
	}
	for _, e := range curatedEntries {
		if seen[e.Name] != 1 {
			t.Errorf("entry %q appeared %d times, want 1", e.Name, seen[e.Name])
		}
	}
}

// TestCurated_List_SortedByTierThenName guards the documented ordering
// contract: easiest-to-use (tier 0) first, alphabetical within tier.
//
// TestCurated_List_SortedByTierThenName 守住"tier asc + name asc"排序契约。
func TestCurated_List_SortedByTierThenName(t *testing.T) {
	src := NewCuratedRegistrySource()
	got, _ := src.List(context.Background())
	for i := 1; i < len(got); i++ {
		prev, cur := got[i-1], got[i]
		if prev.Tier > cur.Tier {
			t.Errorf("tier order broken: %s(tier=%d) before %s(tier=%d)",
				prev.Name, prev.Tier, cur.Name, cur.Tier)
		}
		if prev.Tier == cur.Tier && prev.Name > cur.Name {
			t.Errorf("name order broken within tier %d: %s before %s",
				prev.Tier, prev.Name, cur.Name)
		}
	}
}

// TestCurated_List_ReturnsCopy ensures callers can't mutate internal
// state by editing the returned slice.
//
// TestCurated_List_ReturnsCopy 返切片不允许穿透 mutate 内部。
func TestCurated_List_ReturnsCopy(t *testing.T) {
	src := NewCuratedRegistrySource()
	got, _ := src.List(context.Background())
	if len(got) == 0 {
		t.Fatal("List returned 0 entries")
	}
	original := got[0].Name
	got[0].Name = "tampered"
	got2, _ := src.List(context.Background())
	if got2[0].Name != original {
		t.Errorf("internal state mutated: got2[0].Name = %q, want %q", got2[0].Name, original)
	}
}

// TestCurated_Get_KnownAndUnknown verifies Get hits and misses correctly.
//
// TestCurated_Get_KnownAndUnknown 验 Get 命中与不命中。
func TestCurated_Get_KnownAndUnknown(t *testing.T) {
	src := NewCuratedRegistrySource()
	e, err := src.Get(context.Background(), "playwright")
	if err != nil {
		t.Fatalf("Get(playwright): %v", err)
	}
	if e == nil || e.Name != "playwright" {
		t.Errorf("got %+v", e)
	}

	_, err = src.Get(context.Background(), "definitely-not-a-real-server")
	if !errors.Is(err, mcpdomain.ErrRegistryEntryNotFound) {
		t.Errorf("Get(unknown) err = %v, want ErrRegistryEntryNotFound", err)
	}
}

// TestCurated_NotesPresentForGotchas spot-checks that entries with
// known first-run gotchas (Playwright chromium download, Chrome attach,
// Notion share-with-integration ritual) surface those notes.
//
// TestCurated_NotesPresentForGotchas 抽检几条已知"陷阱"必带 Notes。
func TestCurated_NotesPresentForGotchas(t *testing.T) {
	src := NewCuratedRegistrySource()
	mustContain := map[string]string{
		"playwright":      "Chromium",
		"chrome-devtools": "Chrome",
		"notion":          "SHARE",
		"google-workspace": "Cloud Console",
		"ms365":            "devicelogin",
	}
	for name, want := range mustContain {
		e, err := src.Get(context.Background(), name)
		if err != nil {
			t.Errorf("%s: %v", name, err)
			continue
		}
		if !strings.Contains(strings.ToLower(e.Notes), strings.ToLower(want)) {
			t.Errorf("%s Notes does not contain %q. Notes=%q", name, want, e.Notes)
		}
	}
}
