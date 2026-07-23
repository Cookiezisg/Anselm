package agentstate

import (
	"fmt"
	"strconv"
	"sync"
	"testing"
)

func TestNew_Empty(t *testing.T) {
	s := New()
	if _, ok := s.WasRead("/x/a.go"); ok {
		t.Fatalf("fresh state must not report any seen file")
	}
}

func TestMarkRead_RoundTrip(t *testing.T) {
	s := New()
	s.MarkRead("/x/a.go", 1024)
	size, ok := s.WasRead("/x/a.go")
	if !ok {
		t.Fatalf("WasRead = ok=false after MarkRead")
	}
	if size != 1024 {
		t.Fatalf("size = %d, want 1024", size)
	}
}

func TestMarkRead_OverwritesSize(t *testing.T) {
	s := New()
	s.MarkRead("/x/a.go", 1024)
	s.MarkRead("/x/a.go", 2048) // simulate post-Write update
	size, _ := s.WasRead("/x/a.go")
	if size != 2048 {
		t.Fatalf("size = %d, want 2048 (post-write refresh)", size)
	}
}

func TestWasRead_OtherPath_NotSeen(t *testing.T) {
	s := New()
	s.MarkRead("/x/a.go", 1)
	if _, ok := s.WasRead("/x/b.go"); ok {
		t.Fatalf("WasRead /x/b.go = ok=true; seenFiles must be per-path")
	}
}

// TestMarkRead_BoundedLRU: across more than seenFilesCap distinct paths the seenFiles set stays
// bounded (the oldest age out), while a path re-marked just before the flood stays resident — the
// recent-working-set invariant the write-before-read check relies on (R17).
//
// TestMarkRead_BoundedLRU：跨超过 seenFilesCap 个不同路径时 seenFiles 集保持有界（最旧的淘汰），
// 而刚在洪流前重标的路径仍常驻——写前必读所依赖的近期工作集不变式（R17）。
func TestMarkRead_BoundedLRU(t *testing.T) {
	s := New()

	// "hot" is marked, then kept fresh right before the eviction wave, so it must survive.
	s.MarkRead("/hot.go", 1)

	// Flood with cap*2 distinct paths. Refresh /hot.go near the END (within the last cap/2 marks)
	// so it stays inside the resident window and is NOT the LRU tail when eviction settles.
	flood := seenFilesCap * 2
	refreshAt := flood - seenFilesCap/2
	for i := 0; i < flood; i++ {
		if i == refreshAt {
			s.MarkRead("/hot.go", 1) // refresh recency late in the flood
		}
		s.MarkRead("/x/"+strconv.Itoa(i)+".go", int64(i))
	}

	// Bounded: the live set never exceeds the cap (white-box read of the LRU + index, both guarded).
	s.seenMu.Lock()
	lruLen, idxLen := s.seenLRU.Len(), len(s.seenIndex)
	s.seenMu.Unlock()
	if lruLen > seenFilesCap || idxLen > seenFilesCap {
		t.Fatalf("seenFiles grew to lru=%d index=%d, must be <= cap %d", lruLen, idxLen, seenFilesCap)
	}
	if lruLen != idxLen {
		t.Fatalf("LRU/index drift: lru=%d index=%d (eviction must remove from both)", lruLen, idxLen)
	}

	// The recently-refreshed hot path still reads back.
	if _, ok := s.WasRead("/hot.go"); !ok {
		t.Fatalf("recently-marked /hot.go was evicted; write-before-read invariant broken for the working set")
	}

	// A very early flood path (long past the cap window) has aged out.
	if _, ok := s.WasRead("/x/0.go"); ok {
		t.Fatalf("/x/0.go should have been evicted after %d newer marks", flood)
	}
}

func TestMarkRead_Concurrent(t *testing.T) {
	// Tools within an execution-group batch run in parallel; concurrent MarkRead
	// must not race or lose writes.
	//
	// 同 execution-group 批内工具并行跑；并发 MarkRead 不许竞争或丢写。
	s := New()
	var wg sync.WaitGroup
	for i := range 100 {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			path := "/x/" + string(rune('a'+i%26)) + ".go"
			s.MarkRead(path, int64(i))
		}(i)
	}
	wg.Wait()
	// At least one path must be visible afterwards.
	if _, ok := s.WasRead("/x/a.go"); !ok {
		t.Fatalf("concurrent MarkRead lost /x/a.go")
	}
}

func TestDiscoveredTools_RoundTrip(t *testing.T) {
	s := New()
	if s.IsToolDiscovered("run_function") {
		t.Fatalf("fresh state must not report any discovered tool")
	}
	s.MarkToolDiscovered("run_function")
	s.MarkToolDiscovered("trigger_workflow")
	if !s.IsToolDiscovered("run_function") || !s.IsToolDiscovered("trigger_workflow") {
		t.Fatalf("marked tools not reported discovered")
	}
	if s.IsToolDiscovered("call_mcp_tool") {
		t.Fatalf("unmarked tool reported discovered")
	}
	got := s.DiscoveredTools()
	if len(got) != 2 {
		t.Fatalf("DiscoveredTools = %v, want 2", got)
	}
}

func TestMarkToolDiscovered_Concurrent(t *testing.T) {
	s := New()
	var wg sync.WaitGroup
	for i := range 100 {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			s.MarkToolDiscovered("tool_" + string(rune('a'+i%26)))
		}(i)
	}
	wg.Wait()
	got := s.DiscoveredTools()
	if len(got) != discoveredToolsCap {
		t.Fatalf("bounded concurrent discoveries = %d, want cap %d: %v", len(got), discoveredToolsCap, got)
	}
}

func TestDiscoveredTools_EvictsOldest(t *testing.T) {
	s := New()
	for i := 0; i < discoveredToolsCap+1; i++ {
		s.MarkToolDiscovered(fmt.Sprintf("tool_%02d", i))
	}
	if s.IsToolDiscovered("tool_00") {
		t.Fatal("oldest discovered tool should be evicted")
	}
	if !s.IsToolDiscovered(fmt.Sprintf("tool_%02d", discoveredToolsCap)) {
		t.Fatal("newest discovered tool should remain active")
	}
}
