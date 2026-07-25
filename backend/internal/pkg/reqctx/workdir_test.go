package reqctx

import (
	"context"
	"testing"
)

// TestWorkDir_SeedAndRead: an unseeded ctx answers "" (no residency), a seeded one answers its value, and a
// DERIVED ctx inherits it — that last one is the whole reason the residency lives here instead of in
// AgentState, because it is what makes subagent inheritance free.
//
// TestWorkDir_SeedAndRead：未播种的 ctx 答 ""（无驻地），播种过的答它的值，而**派生**的 ctx 继承它——最后这条
// 正是驻地住在此处而不住在 AgentState 的全部理由，因为它就是让 subagent 继承免费的那件事。
func TestWorkDir_SeedAndRead(t *testing.T) {
	base := context.Background()
	if got := GetWorkDir(base); got != "" {
		t.Fatalf("an unseeded ctx must answer \"\" (no residency), got %q", got)
	}

	seeded := SetWorkDir(base, "/proj/anselm")
	if got := GetWorkDir(seeded); got != "/proj/anselm" {
		t.Fatalf("GetWorkDir = %q, want /proj/anselm", got)
	}
	// Derivation carries it: a subagent's ctx is derived from its parent turn's, so it lands inside the same
	// residency with no plumbing. 派生把它带走：subagent 的 ctx 由父回合的派生而来，故它零管线地落在同一驻地里。
	derived, cancel := context.WithCancel(SetConversationID(seeded, "cv_1"))
	defer cancel()
	if got := GetWorkDir(derived); got != "/proj/anselm" {
		t.Fatalf("a derived ctx must inherit the residency, got %q", got)
	}
	// Re-seeding wins (a switch mid-run would, though today only processTask seeds). 重新播种胜出。
	if got := GetWorkDir(SetWorkDir(seeded, "/other")); got != "/other" {
		t.Fatalf("re-seeding must win, got %q", got)
	}
	// Seeding EMPTY is the same fact as not seeding — every consumer treats "" as its no-op, which is why the
	// getter returns one value and not an `ok`. 播种**空**与不播种是同一个事实——每个消费方都把 "" 当自己的 no-op，
	// 这正是这个 getter 只返一个值、不返 `ok` 的原因。
	if got := GetWorkDir(SetWorkDir(seeded, "")); got != "" {
		t.Fatalf("seeding empty must read as no residency, got %q", got)
	}
}
