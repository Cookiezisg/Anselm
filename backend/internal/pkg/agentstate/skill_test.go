// skill_test.go — exercises the ActiveSkill side-channel: atomic
// set/get/clear semantics + wildcardMatch glob coverage + paren-form
// pattern matching for Bash + per-spec edge cases (concurrent overwrite
// is benign per skill.md §9.5).
//
// skill_test.go ——验 ActiveSkill 旁路：原子 set/get/clear + wildcardMatch
// 覆盖 + Bash paren-form pattern + spec 边界（并发覆写良性 §9.5）。
package agentstate

import (
	"encoding/json"
	"sync"
	"testing"

	skilldomain "github.com/sunweilin/forgify/backend/internal/domain/skill"
)

func TestActiveSkill_NilWhenUnset(t *testing.T) {
	var s AgentState
	if got := s.ActiveSkill(); got != nil {
		t.Errorf("ActiveSkill() = %v on zero AgentState, want nil", got)
	}
	if s.IsToolPreApprovedBySkill("Bash", []byte(`{}`)) {
		t.Error("IsToolPreApprovedBySkill = true with no active skill")
	}
}

func TestActiveSkill_SetGetClear(t *testing.T) {
	var s AgentState
	sk := &skilldomain.Skill{Name: "pr-review"}
	s.SetActiveSkill(sk)
	if got := s.ActiveSkill(); got != sk {
		t.Errorf("ActiveSkill mismatch after Set: %v", got)
	}

	// Clear by mismatching name → no-op.
	// 名字不匹配的 Clear → 不动。
	s.ClearActiveSkillIfMatches("other-skill")
	if got := s.ActiveSkill(); got != sk {
		t.Errorf("ClearActiveSkillIfMatches mismatched name should not clear; got %v", got)
	}

	// Clear by matching name → cleared.
	// 名字匹配的 Clear → 真清。
	s.ClearActiveSkillIfMatches("pr-review")
	if got := s.ActiveSkill(); got != nil {
		t.Errorf("ClearActiveSkillIfMatches matching name should clear; got %v", got)
	}
}

func TestActiveSkill_LastWriteWins(t *testing.T) {
	// skill.md §9.5: concurrent activate races are benign — last-write-wins
	// without locking. Two writers, one reader; reader sees one of the two.
	// §9.5 并发 activate 良性——last-write-wins 无锁。两写一读，读到二者之一。
	var s AgentState
	a := &skilldomain.Skill{Name: "a"}
	b := &skilldomain.Skill{Name: "b"}

	var wg sync.WaitGroup
	wg.Add(2)
	go func() { defer wg.Done(); s.SetActiveSkill(a) }()
	go func() { defer wg.Done(); s.SetActiveSkill(b) }()
	wg.Wait()

	got := s.ActiveSkill()
	if got != a && got != b {
		t.Errorf("after concurrent set, got %v, want one of {a,b}", got)
	}
}

func TestIsToolPreApprovedBySkill_BareName(t *testing.T) {
	var s AgentState
	s.SetActiveSkill(&skilldomain.Skill{
		Name: "x",
		Frontmatter: skilldomain.Frontmatter{
			AllowedTools: []string{"Read", "Grep"},
		},
	})

	tests := []struct {
		tool string
		want bool
	}{
		{"Read", true},
		{"Grep", true},
		{"Bash", false},
		{"WebFetch", false},
	}
	for _, tt := range tests {
		got := s.IsToolPreApprovedBySkill(tt.tool, []byte(`{}`))
		if got != tt.want {
			t.Errorf("IsToolPreApprovedBySkill(%q) = %v, want %v", tt.tool, got, tt.want)
		}
	}
}

func TestIsToolPreApprovedBySkill_BashAnyArgs(t *testing.T) {
	var s AgentState
	s.SetActiveSkill(&skilldomain.Skill{
		Frontmatter: skilldomain.Frontmatter{
			AllowedTools: []string{"Bash"},
		},
	})
	for _, cmd := range []string{"git status", "rm -rf /", "echo hi"} {
		args, _ := json.Marshal(map[string]string{"command": cmd})
		if !s.IsToolPreApprovedBySkill("Bash", args) {
			t.Errorf("bare 'Bash' should match any command; rejected %q", cmd)
		}
	}
}

func TestIsToolPreApprovedBySkill_BashWildcard(t *testing.T) {
	var s AgentState
	s.SetActiveSkill(&skilldomain.Skill{
		Frontmatter: skilldomain.Frontmatter{
			AllowedTools: []string{"Bash(git *)", "Bash(npm test)"},
		},
	})
	tests := []struct {
		cmd  string
		want bool
	}{
		{"git status", true},
		{"git push --force", true},
		{"git", false},     // trailing space in pattern requires content after
		{"npm test", true}, // exact match
		{"npm tests", false},
		{"rm -rf /", false},
	}
	for _, tt := range tests {
		args, _ := json.Marshal(map[string]string{"command": tt.cmd})
		got := s.IsToolPreApprovedBySkill("Bash", args)
		if got != tt.want {
			t.Errorf("Bash %q: got %v, want %v", tt.cmd, got, tt.want)
		}
	}
}

func TestIsToolPreApprovedBySkill_MalformedPatternIsRejected(t *testing.T) {
	// Author bug (unbalanced paren) must not collapse the permission gate
	// into "everything allowed" — must instead fail closed.
	// 作者 bug（括号不闭合）不该把权限门击穿为"全允许"——必须 fail closed。
	var s AgentState
	s.SetActiveSkill(&skilldomain.Skill{
		Frontmatter: skilldomain.Frontmatter{
			AllowedTools: []string{"Bash(git", "Read("},
		},
	})
	if s.IsToolPreApprovedBySkill("Bash", []byte(`{"command":"git status"}`)) {
		t.Error("malformed Bash( pattern should not match")
	}
	if s.IsToolPreApprovedBySkill("Read", []byte(`{}`)) {
		t.Error("malformed Read( pattern should not match")
	}
}

func TestIsToolPreApprovedBySkill_ParenForNonBashFallsThrough(t *testing.T) {
	// V1 only knows the Bash arg schema for paren patterns; other tools
	// fall through to non-match. (V2 would add per-tool extractors.)
	// V1 paren pattern 仅支持 Bash；其他 tool 退化为不匹配（V2 加 per-tool）。
	var s AgentState
	s.SetActiveSkill(&skilldomain.Skill{
		Frontmatter: skilldomain.Frontmatter{
			AllowedTools: []string{"WebFetch(https://example.com/*)"},
		},
	})
	if s.IsToolPreApprovedBySkill("WebFetch", []byte(`{"url":"https://example.com/foo"}`)) {
		t.Error("V1 paren pattern on non-Bash tool should fall through to non-match")
	}
}

func TestWildcardMatch(t *testing.T) {
	tests := []struct {
		pattern string
		subject string
		want    bool
	}{
		{"git *", "git status", true},
		{"git *", "git push --force", true},
		{"git *", "git", false},
		{"npm test", "npm test", true},
		{"npm test", "npm tests", false},
		{"*foo*", "barfoobar", true},
		{"*foo*", "barbaz", false},
		{"*", "anything", true},
		{"*", "", true},
		{"prefix*suffix", "prefix-MIDDLE-suffix", true},
		{"prefix*suffix", "prefix-suffix", true},
		{"prefix*suffix", "prefixsuffix", true},
		{"prefix*suffix", "wrong", false},
	}
	for _, tt := range tests {
		got := wildcardMatch(tt.pattern, tt.subject)
		if got != tt.want {
			t.Errorf("wildcardMatch(%q, %q) = %v, want %v", tt.pattern, tt.subject, got, tt.want)
		}
	}
}

func TestIsToolPreApprovedBySkill_BadJSONArgsDoesNotPanic(t *testing.T) {
	// Tool dispatch should never panic on permission check; bad args JSON
	// just means "no primary command extracted" → paren patterns
	// non-match. Bare patterns still match.
	// dispatch 不该 panic；坏 args JSON = 提不到 command → paren 不匹配；
	// 裸 pattern 仍匹配。
	var s AgentState
	s.SetActiveSkill(&skilldomain.Skill{
		Frontmatter: skilldomain.Frontmatter{
			AllowedTools: []string{"Bash", "Bash(git *)"},
		},
	})
	bad := []byte(`{not json}`)
	if !s.IsToolPreApprovedBySkill("Bash", bad) {
		t.Error("bare Bash should still match even with malformed args")
	}
	// Paren pattern can't extract from bad JSON; bare match wins above.
	// paren 提不出来；上面裸 pattern 已匹配胜出。
}
