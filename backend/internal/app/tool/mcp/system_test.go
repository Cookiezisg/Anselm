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

	// F91/F113-multiword: words are matched independently across name+description in ANY position and
	// results are RANKED by how many words a server matches (≥1 match is included). A server matching
	// every word still ranks first; a query whose words spread across DIFFERENT servers no longer
	// returns 0 (the AND-too-strict trap). "send notifications" spans desc words; "notifications slack"
	// is out-of-order — both fully match github-notifier (score 2).
	if got := filterMarketViews(entries, "send notifications"); len(got) != 1 || got[0].Name != "github-notifier" {
		t.Fatalf("multi-word 'send notifications' should match github-notifier, got %+v", got)
	}
	if got := filterMarketViews(entries, "notifications slack"); len(got) != 1 || got[0].Name != "github-notifier" {
		t.Fatalf("out-of-order multi-word 'notifications slack' should match github-notifier, got %+v", got)
	}
	if got := filterMarketViews(entries, "query database"); len(got) != 1 || got[0].Name != "pg-tool" {
		t.Fatalf("out-of-order multi-word 'query database' should match pg-tool, got %+v", got)
	}
	// F113-andtoostrict: a query whose words spread across different servers must NOT return 0 — each
	// server matching one word is included (OR), so the agent sees the relevant candidates.
	if got := filterMarketViews(entries, "database notifications"); len(got) != 2 {
		t.Fatalf("words spread across servers must surface both (OR), got %+v", got)
	}
	// Ranking: a server matching MORE query words ranks first. "send notifications database" →
	// github-notifier (2 words) before pg-tool (1 word).
	if got := filterMarketViews(entries, "send notifications database"); len(got) != 2 || got[0].Name != "github-notifier" {
		t.Fatalf("server matching more words must rank first, got %+v", got)
	}

	// Guard: the tool advertises the query knob so the agent reaches for it instead of dumping all.
	if !strings.Contains(string((&ListMarketplace{}).Parameters()), "query") {
		t.Error("list_mcp_marketplace must expose a `query` filter param")
	}
}
