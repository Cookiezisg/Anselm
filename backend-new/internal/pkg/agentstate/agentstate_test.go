package agentstate

import (
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
	if !s.IsToolDiscovered("tool_a") {
		t.Fatalf("concurrent MarkToolDiscovered lost tool_a")
	}
}
