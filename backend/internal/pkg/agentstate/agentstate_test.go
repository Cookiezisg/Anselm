// agentstate_test.go — concurrency + ordering checks for AgentState.
// Covers MarkRead/WasRead, cwd round-trip, SubagentTokenLog append/read.
//
// agentstate_test.go ——AgentState 的并发与顺序检查。覆盖 MarkRead/
// WasRead、cwd round-trip、SubagentTokenLog 追加/读取。
package agentstate

import (
	"sync"
	"testing"
)

func TestMarkRead_Roundtrip(t *testing.T) {
	s := &AgentState{}
	s.MarkRead("/tmp/a.txt", 1234)
	got, ok := s.WasRead("/tmp/a.txt")
	if !ok {
		t.Fatalf("WasRead: expected hit")
	}
	if got != 1234 {
		t.Errorf("WasRead size = %d, want 1234", got)
	}
}

func TestWasRead_Missing(t *testing.T) {
	s := &AgentState{}
	if _, ok := s.WasRead("/never"); ok {
		t.Error("WasRead on absent path should return ok=false")
	}
}

func TestCwd_ZeroValue(t *testing.T) {
	s := &AgentState{}
	if got := s.Cwd(); got != "" {
		t.Errorf("zero-value Cwd = %q, want empty", got)
	}
}

func TestSetCwd_Roundtrip(t *testing.T) {
	s := &AgentState{}
	s.SetCwd("/work")
	if got := s.Cwd(); got != "/work" {
		t.Errorf("Cwd = %q, want /work", got)
	}
}

// ── SubagentTokenLog ─────────────────────────────────────────────────

func TestSubagentTokenLog_EmptyByDefault(t *testing.T) {
	s := &AgentState{}
	if log := s.SubagentTokenLog(); len(log) != 0 {
		t.Errorf("zero-value SubagentTokenLog = %v, want empty", log)
	}
}

func TestSubagentTokenLog_AppendPreservesOrder(t *testing.T) {
	s := &AgentState{}
	s.AddSubagentTokens("sar_a", "Explore", 100, 50)
	s.AddSubagentTokens("sar_b", "Plan", 200, 75)

	log := s.SubagentTokenLog()
	if len(log) != 2 {
		t.Fatalf("len = %d, want 2", len(log))
	}
	if log[0].RunID != "sar_a" || log[0].TypeName != "Explore" || log[0].TokensIn != 100 || log[0].TokensOut != 50 {
		t.Errorf("entry[0] = %+v", log[0])
	}
	if log[1].RunID != "sar_b" || log[1].TypeName != "Plan" || log[1].TokensIn != 200 || log[1].TokensOut != 75 {
		t.Errorf("entry[1] = %+v", log[1])
	}
}

func TestSubagentTokenLog_ConcurrentAppends(t *testing.T) {
	s := &AgentState{}
	const N = 32
	var wg sync.WaitGroup
	wg.Add(N)
	for i := 0; i < N; i++ {
		go func(i int) {
			defer wg.Done()
			s.AddSubagentTokens("sar_concurrent", "general-purpose", i, i*2)
		}(i)
	}
	wg.Wait()

	log := s.SubagentTokenLog()
	if len(log) != N {
		t.Fatalf("got %d entries, want %d (race likely)", len(log), N)
	}
	// Sum check — all entries got recorded, order may vary.
	// 求和——所有条目都记上了，顺序可能不同。
	var sumIn, sumOut int
	for _, e := range log {
		sumIn += e.TokensIn
		sumOut += e.TokensOut
	}
	wantIn := N * (N - 1) / 2  // 0..N-1
	wantOut := wantIn * 2
	if sumIn != wantIn || sumOut != wantOut {
		t.Errorf("sums = (%d,%d), want (%d,%d) — entries lost or duplicated",
			sumIn, sumOut, wantIn, wantOut)
	}
}

func TestSubagentTokenLog_ReturnsCopy_NotAlias(t *testing.T) {
	s := &AgentState{}
	s.AddSubagentTokens("sar_x", "Explore", 10, 5)
	log := s.SubagentTokenLog()
	// Mutate the returned slice; subsequent read should be unaffected.
	// 修改返回 slice；后续读不该受影响。
	log[0].TokensIn = 9999
	again := s.SubagentTokenLog()
	if again[0].TokensIn != 10 {
		t.Errorf("returned slice aliased internal state: %+v", again[0])
	}
}
