package handler

import (
	"io"
	"sync"
)

// stderrFan fans a resident instance's stderr lines out to per-call sinks. The process
// stderr is one INSTANCE-level stream (a resident process prints whenever it likes), but
// the consumers — chat progress, the entity run terminal, the call's persisted logs —
// are CALL-scoped. The bridge is window attribution: a call attaches a sink for its
// duration and receives every line emitted in that window. Concurrent calls on the same
// instance each receive the window's lines (cross-talk is accepted and documented; the
// alternative, serializing calls, would trade latency for an attribution nicety).
//
// stderrFan 把常驻实例的 stderr 行扇出给 per-call sink。进程 stderr 是**实例级**的一条流
// （常驻进程想打就打），而消费方——chat 进度、实体 run 终端、调用落盘 logs——是**调用级**的。
// 桥接方式是窗口归属：调用在自己存续期挂一个 sink，收到窗口内的所有行。同实例并发调用各收
// 各窗口的行（接受并明示串扰；另一条路「调用串行化」是拿延迟换归属洁癖，不值）。
type stderrFan struct {
	mu    sync.Mutex
	sinks map[int]io.Writer
	next  int
}

func newStderrFan() *stderrFan { return &stderrFan{sinks: map[int]io.Writer{}} }

// attach registers a sink and returns its detach. Detach is idempotent.
//
// attach 注册一个 sink 并返回其卸载函数。卸载幂等。
func (f *stderrFan) attach(w io.Writer) (detach func()) {
	f.mu.Lock()
	id := f.next
	f.next++
	f.sinks[id] = w
	f.mu.Unlock()
	return func() {
		f.mu.Lock()
		delete(f.sinks, id)
		f.mu.Unlock()
	}
}

// Write implements io.Writer: deliver p to every attached sink (errors swallowed — a
// broken sink must never stall the stderr reader goroutine). nil-safe.
//
// Write 实现 io.Writer：把 p 投给所有在挂的 sink（错误吞掉——坏 sink 绝不能卡住 stderr
// 读取 goroutine）。nil 安全。
func (f *stderrFan) Write(p []byte) (int, error) {
	if f == nil {
		return len(p), nil
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	for _, w := range f.sinks {
		_, _ = w.Write(p)
	}
	return len(p), nil
}
