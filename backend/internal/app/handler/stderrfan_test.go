package handler

import (
	"strings"
	"sync"
	"testing"
)

type recSink struct {
	mu sync.Mutex
	b  strings.Builder
}

func (r *recSink) Write(p []byte) (int, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.b.Write(p)
}

func (r *recSink) String() string {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.b.String()
}

// TestStderrFan_WindowAttribution: a sink receives only the lines written while
// attached — the per-call window semantics the call log depends on.
//
// TestStderrFan_WindowAttribution：sink 只收到挂载期间写入的行——调用日志依赖的窗口归属语义。
func TestStderrFan_WindowAttribution(t *testing.T) {
	fan := newStderrFan()
	fan.Write([]byte("before\n")) // no sink attached → dropped

	sink := &recSink{}
	detach := fan.attach(sink)
	fan.Write([]byte("during\n"))
	detach()
	detach() // idempotent
	fan.Write([]byte("after\n"))

	if got := sink.String(); got != "during\n" {
		t.Fatalf("window attribution broken: %q", got)
	}
}

// TestStderrFan_ConcurrentCalls: two attached sinks both receive the window's lines;
// nil fan and concurrent attach/write/detach are safe.
//
// TestStderrFan_ConcurrentCalls：两个在挂 sink 都收到窗口内的行；nil fan 与并发挂/写/卸安全。
func TestStderrFan_ConcurrentCalls(t *testing.T) {
	var nilFan *stderrFan
	if _, err := nilFan.Write([]byte("x")); err != nil {
		t.Fatalf("nil fan must be inert: %v", err)
	}

	fan := newStderrFan()
	a, b := &recSink{}, &recSink{}
	da := fan.attach(a)
	db := fan.attach(b)

	var wg sync.WaitGroup
	for range 4 {
		wg.Go(func() {
			for range 50 {
				fan.Write([]byte("line\n"))
			}
		})
	}
	wg.Wait()
	da()
	db()

	if na, nb := strings.Count(a.String(), "line"), strings.Count(b.String(), "line"); na != 200 || nb != 200 {
		t.Fatalf("fan-out lost lines: a=%d b=%d (want 200 each)", na, nb)
	}
}
