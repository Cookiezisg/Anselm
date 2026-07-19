package main

import (
	"io"
	"testing"
	"time"
)

// The deadman switch must fire on EOF and ONLY on EOF — a live (silent) parent pipe must never
// trigger shutdown, because the launcher writes nothing to our stdin during normal operation.
//
// 死人开关必须且只在 EOF 时触发——活着但沉默的父管道绝不能引发关停(launcher 正常运行期间不往我们的
// stdin 写任何东西)。
func TestWatchParent(t *testing.T) {
	t.Run("silent live pipe never fires", func(t *testing.T) {
		r, w := io.Pipe()
		fired := make(chan struct{})
		go watchParent(r, func() { close(fired) })
		select {
		case <-fired:
			t.Fatal("fired while the parent pipe was still open — a silent parent is a LIVE parent")
		case <-time.After(100 * time.Millisecond):
		}
		_ = w.Close()
	})

	t.Run("EOF fires exit", func(t *testing.T) {
		r, w := io.Pipe()
		fired := make(chan struct{})
		go watchParent(r, func() { close(fired) })
		_ = w.Close() // the parent dying closes its end — every exit path looks like this. 父死=关端。
		select {
		case <-fired:
		case <-time.After(2 * time.Second):
			t.Fatal("EOF did not fire exit — the sidecar would orphan under launchd")
		}
	})
}
