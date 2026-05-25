package main

import "testing"

func TestFindGhostToolRefs_FlagsBacktickGhost(t *testing.T) {
	real := map[string]bool{"edit_function": true}
	got := findGhostToolRefs("then call `edit_forge`, not `edit_function`", real, map[string]bool{})
	if len(got) != 1 || got[0] != "edit_forge" {
		t.Fatalf("got %v, want [edit_forge]", got)
	}
}

func TestFindGhostToolRefs_RealAndAllowlistPass(t *testing.T) {
	real := map[string]bool{"run_function": true}
	allow := map[string]bool{"execution_group": true}
	got := findGhostToolRefs("use `run_function` honoring `execution_group`", real, allow)
	if len(got) != 0 {
		t.Fatalf("got %v, want none", got)
	}
}

func TestFindGhostToolRefs_AllowedToolsSliceValidatedAgainstRegistry(t *testing.T) {
	real := map[string]bool{"Read": true, "search_function": true}
	got := findGhostToolRefs(`AllowedTools:    []string{"Read", "search_forges", "search_function"}`, real, map[string]bool{})
	if len(got) != 1 || got[0] != "search_forges" {
		t.Fatalf("got %v, want [search_forges]", got)
	}
}

func TestRealToolNames_FindsKnownTools(t *testing.T) {
	// test cwd is cmd/lintprompts/ → backend root is two levels up.
	real := realToolNames("../../internal/app/tool")
	for _, want := range []string{"run_function", "edit_handler", "trigger_workflow", "search_mcp_tools", "call_mcp_tool"} {
		if !real[want] {
			t.Errorf("realToolNames missing %q", want)
		}
	}
}
