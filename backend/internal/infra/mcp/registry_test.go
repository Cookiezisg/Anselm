package mcp

import "testing"

// TestEmbeddedSnapshot_ParsesAndMostlyPlannable verifies the baked-in registry snapshot parses
// to ~99 servers and that the vast majority resolve to an install plan (we support
// node/python/docker/dotnet + remote) — guards the GitHub→domain mapping and runtime coverage.
//
// TestEmbeddedSnapshot_ParsesAndMostlyPlannable 验证内嵌 registry snapshot 解析出 ~99 个 server
// 且绝大多数能解析出安装计划（我们支持 node/python/docker/dotnet + remote）——守住 GitHub→domain
// 映射与 runtime 覆盖。
func TestEmbeddedSnapshot_ParsesAndMostlyPlannable(t *testing.T) {
	entries, err := parseGitHub(embeddedSnapshot)
	if err != nil {
		t.Fatalf("parse embedded snapshot: %v", err)
	}
	if len(entries) < 90 {
		t.Fatalf("embedded snapshot should hold ~99 servers, got %d", len(entries))
	}
	planned := 0
	for _, e := range entries {
		if _, ok := e.Plan(); ok {
			planned++
		}
	}
	if planned < 95 {
		t.Fatalf("expected >=95 plannable entries, got %d/%d", planned, len(entries))
	}
}

func TestParseImport_Roundtrip(t *testing.T) {
	raw := []byte(`{"mcpServers":{"github":{"command":"npx","args":["-y","@x/y"],"env":{"T":"v"}}}}`)
	entries, err := ParseImport(raw)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	e, ok := entries["github"]
	if !ok || e.Command != "npx" || e.Env["T"] != "v" {
		t.Fatalf("import parse wrong: %+v", entries)
	}
}

func TestParseImport_Empty(t *testing.T) {
	if _, err := ParseImport([]byte(`{"mcpServers":{}}`)); err == nil {
		t.Fatal("expected error for empty mcpServers map")
	}
}
