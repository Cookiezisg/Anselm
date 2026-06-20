package mcp

import (
	"strings"
	"testing"

	mcpdomain "github.com/sunweilin/anselm/backend/internal/domain/mcp"
)

// TestFilterMarketViews: the marketplace capability filter (round-1 ask lane — an unfiltered list
// dumped ~96 servers into the agent's context). A query narrows by name+description substring
// (case-insensitive); un-installable entries (Plan ok=false) are always hidden.
func TestFilterMarketViews(t *testing.T) {
	entries := []mcpdomain.RegistryEntry{
		{Name: "github-notifier", Description: "send notifications to slack", Packages: []mcpdomain.Package{{RuntimeHint: "npx", Name: "gh-notify"}}},
		{Name: "pg-tool", Description: "query a postgres DATABASE", Packages: []mcpdomain.Package{{RuntimeHint: "uvx", Name: "pgtool"}}},
		{Name: "broken", Description: "unsupported runtime", Packages: []mcpdomain.Package{{RuntimeHint: "bogus-runtime", Name: "x"}}}, // Plan ok=false → always hidden
	}

	// No query → every INSTALLABLE entry (broken stays hidden).
	if got := filterMarketViews(entries, ""); len(got) != 2 {
		t.Fatalf("no-query should list 2 installable, got %d", len(got))
	}

	// Capability filter matches on description, case-insensitive (entry side lowercased too).
	if got := filterMarketViews(entries, "notif"); len(got) != 1 || got[0].Name != "github-notifier" {
		t.Fatalf("query 'notif' should match only github-notifier, got %+v", got)
	}
	if got := filterMarketViews(entries, "database"); len(got) != 1 || got[0].Name != "pg-tool" {
		t.Fatalf("query 'database' (entry has DATABASE) should match only pg-tool, got %+v", got)
	}

	// A query that only matches an un-installable entry yields nothing (it stays hidden).
	if got := filterMarketViews(entries, "unsupported"); len(got) != 0 {
		t.Fatalf("un-installable entry must stay hidden even on a matching query, got %+v", got)
	}

	// Guard: the tool advertises the query knob so the agent reaches for it instead of dumping all.
	if !strings.Contains(string((&ListMarketplace{}).Parameters()), "query") {
		t.Error("list_mcp_marketplace must expose a `query` filter param")
	}
}
