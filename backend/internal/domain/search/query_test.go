package search

import "testing"

func TestParseQuery_TokenRouting(t *testing.T) {
	p := ParseQuery("  天气预报 引擎 api go  ")
	if len(p.Long) != 2 || p.Long[0] != "天气预报" || p.Long[1] != "api" {
		t.Fatalf("long tokens mis-routed: %+v", p.Long)
	}
	// 2-char CJK and 2-char latin are both below the trigram window.
	// 2 字中文与 2 字母都低于 trigram 窗口。
	if len(p.Short) != 2 || p.Short[0] != "引擎" || p.Short[1] != "go" {
		t.Fatalf("short tokens mis-routed: %+v", p.Short)
	}
	if got := ParseQuery("   "); len(got.Long)+len(got.Short) != 0 {
		t.Fatalf("blank query should parse empty: %+v", got)
	}
}

func TestBuildMatch_NeutralizesOperators(t *testing.T) {
	got := BuildMatch([]string{`foo OR bar`, `ti"tle`, `(near*`})
	want := `"foo OR bar" "ti""tle" "(near*"`
	if got != want {
		t.Fatalf("BuildMatch = %q, want %q", got, want)
	}
}

func TestRefHint(t *testing.T) {
	cases := []struct {
		t      EntityType
		id, an string
		want   string
	}{
		{TypeFunction, "fn_a", "", "fn_a"},
		{TypeAgent, "ag_a", "", "ag_a"},
		{TypeControl, "ctl_a", "", "ctl_a"},
		{TypeApproval, "apf_a", "", "apf_a"},
		{TypeHandler, "hd_a", "sendMail", "hd_a.sendMail"},
		{TypeHandler, "hd_a", "", "hd_a"},
		{TypeMCP, "mcp_a", "search", "mcp:mcp_a/search"},
		{TypeMCP, "mcp_a", "", ""},
		{TypeConversation, "cv_a", "msg_1", ""},
		{TypeDocument, "doc_a", "", ""},
	}
	for _, c := range cases {
		if got := RefHint(c.t, c.id, c.an); got != c.want {
			t.Fatalf("RefHint(%s,%s,%s) = %q, want %q", c.t, c.id, c.an, got, c.want)
		}
	}
}

func TestEntityTypeSets(t *testing.T) {
	if len(AllEntityTypes) != 12 {
		t.Fatalf("coverage must stay 12 types, got %d", len(AllEntityTypes))
	}
	if !IsValidEntityType(TypeMemory) || IsValidEntityType("nope") {
		t.Fatal("IsValidEntityType broken")
	}
	if !IsBlockEntityType(TypeHandler) || IsBlockEntityType(TypeConversation) {
		t.Fatal("IsBlockEntityType broken")
	}
}

func TestEffectiveEmbedder(t *testing.T) {
	if EffectiveEmbedder("") != EmbedderBuiltin || EffectiveEmbedder("garbage") != EmbedderBuiltin {
		t.Fatal("unset/garbage must default to builtin")
	}
	if EffectiveEmbedder(EmbedderOff) != EmbedderOff || EffectiveEmbedder(EmbedderOllama) != EmbedderOllama {
		t.Fatal("explicit values must pass through")
	}
	if !IsValidEmbedder("builtin") || IsValidEmbedder("") {
		t.Fatal("IsValidEmbedder broken")
	}
}
