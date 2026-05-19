package wikilink

import (
	"sort"
	"testing"
)

func TestParse_EmptyBody(t *testing.T) {
	if got := Parse(""); got != nil {
		t.Errorf("expected nil, got %v", got)
	}
}

func TestParse_NoMatch(t *testing.T) {
	body := "Just plain markdown — no wikilinks here."
	if got := Parse(body); got != nil {
		t.Errorf("expected nil, got %v", got)
	}
}

func TestParse_SingleWikilink(t *testing.T) {
	body := "See [[fn_a1b2c3d4e5f6a7b8]] for details."
	got := Parse(body)
	if len(got) != 1 {
		t.Fatalf("expected 1 ref, got %d", len(got))
	}
	if got[0].Kind != "function" || got[0].ID != "fn_a1b2c3d4e5f6a7b8" || got[0].Count != 1 {
		t.Errorf("got %+v", got[0])
	}
}

func TestParse_DropsUnknownPrefix(t *testing.T) {
	// `xyz_` is not in KindByPrefix
	body := "Unknown [[xyz_a1b2c3d4e5f6a7b8]] and known [[doc_aabbccdd11223344]]"
	got := Parse(body)
	if len(got) != 1 {
		t.Fatalf("expected 1 ref (unknown dropped), got %d: %+v", len(got), got)
	}
	if got[0].ID != "doc_aabbccdd11223344" {
		t.Errorf("expected doc kept, got %+v", got[0])
	}
}

func TestParse_DedupAndCount(t *testing.T) {
	body := `First mention [[fn_a1b2c3d4e5f6a7b8]].
Second mention [[fn_a1b2c3d4e5f6a7b8]] again.
And once: [[wf_11223344aabbccdd]].`
	got := Parse(body)
	if len(got) != 2 {
		t.Fatalf("expected 2 dedup'd refs, got %d", len(got))
	}
	sort.Slice(got, func(i, j int) bool { return got[i].ID < got[j].ID })
	if got[0].ID != "fn_a1b2c3d4e5f6a7b8" || got[0].Count != 2 {
		t.Errorf("expected fn count=2, got %+v", got[0])
	}
	if got[1].ID != "wf_11223344aabbccdd" || got[1].Count != 1 {
		t.Errorf("expected wf count=1, got %+v", got[1])
	}
}

func TestParse_AllSupportedPrefixes(t *testing.T) {
	body := `
[[fn_0000000000000001]]
[[hd_0000000000000002]]
[[wf_0000000000000003]]
[[doc_0000000000000004]]
[[cv_0000000000000005]]
`
	got := Parse(body)
	if len(got) != 5 {
		t.Errorf("expected 5 refs, got %d: %+v", len(got), got)
	}
	kinds := map[string]bool{}
	for _, r := range got {
		kinds[r.Kind] = true
	}
	expected := []string{"function", "handler", "workflow", "document", "conversation"}
	for _, k := range expected {
		if !kinds[k] {
			t.Errorf("missing kind %q in result", k)
		}
	}
}

func TestParse_MalformedSkipped(t *testing.T) {
	// Not 16-hex chars / wrong format / nested brackets — all should not match
	body := "[[fn_short]] [[fn_a1b2c3d4e5f6a7b8z]] [fn_aabbccdd11223344] [[FN_aabbccdd11223344]]"
	got := Parse(body)
	if got != nil {
		t.Errorf("expected no matches for malformed/wrong-case, got %+v", got)
	}
}

func TestParse_SkillMcpNotMatched(t *testing.T) {
	// skill / mcp use name-based keys, so [[csv_parse]] doesn't match our regex
	body := "[[csv_parse]] is a skill; [[postgres]] is an mcp server."
	got := Parse(body)
	if got != nil {
		t.Errorf("expected no matches for name-based refs, got %+v", got)
	}
}
