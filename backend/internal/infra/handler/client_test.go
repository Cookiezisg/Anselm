// client_test.go — wire-format + state-machine tests for the stdio client.
// Uses io.Pipe to simulate the subprocess; the test "driver" runs in a
// goroutine reading the client's outbound JSON lines and writing the
// scripted responses.
//
// client_test.go — stdio 客户端的协议 + 状态机测试。
// 用 io.Pipe 模拟 subprocess,测试 driver goroutine 读 client 出站行 + 写脚本响应。
package handler

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"io"
	"strings"
	"sync"
	"testing"
	"time"
)

// fakeDriver wraps the two io.Pipe pairs the test uses to play subprocess.
//
// fakeDriver 包两组 io.Pipe 当 subprocess。
type fakeDriver struct {
	t          *testing.T
	clientIn   *io.PipeWriter // client writes here (subprocess stdin)
	clientInR  *io.PipeReader // driver reads here
	clientOut  *io.PipeReader // client reads here (subprocess stdout)
	clientOutW *io.PipeWriter // driver writes here
	driverIn   *bufio.Reader
}

func newFakeDriver(t *testing.T) (Client, *fakeDriver) {
	t.Helper()
	pr1, pw1 := io.Pipe() // client → driver (client.stdin)
	pr2, pw2 := io.Pipe() // driver → client (client.stdout)

	fd := &fakeDriver{
		t:          t,
		clientIn:   pw1,
		clientInR:  pr1,
		clientOut:  pr2,
		clientOutW: pw2,
		driverIn:   bufio.NewReader(pr1),
	}
	t.Cleanup(func() {
		_ = pw1.Close()
		_ = pw2.Close()
		_ = pr1.Close()
		_ = pr2.Close()
	})
	c := New(writeCloser{pw1}, pr2, nil)
	return c, fd
}

// writeCloser adapts io.PipeWriter (which has Close) to io.WriteCloser.
type writeCloser struct{ w *io.PipeWriter }

func (w writeCloser) Write(p []byte) (int, error) { return w.w.Write(p) }
func (w writeCloser) Close() error                { return w.w.Close() }

// readMsg pulls one JSON line from the client and decodes it.
//
// readMsg 从 client 读一行 JSON 并解码。
func (fd *fakeDriver) readMsg() map[string]any {
	fd.t.Helper()
	line, err := fd.driverIn.ReadString('\n')
	if err != nil {
		fd.t.Fatalf("driver readMsg: %v (partial %q)", err, line)
	}
	var msg map[string]any
	if err := json.Unmarshal([]byte(line), &msg); err != nil {
		fd.t.Fatalf("driver readMsg: bad JSON %q: %v", line, err)
	}
	return msg
}

// writeMsg writes one JSON line to the client's stdout.
//
// writeMsg 写一行 JSON 到 client 的 stdout。
func (fd *fakeDriver) writeMsg(msg map[string]any) {
	fd.t.Helper()
	raw, err := json.Marshal(msg)
	if err != nil {
		fd.t.Fatalf("driver writeMsg: marshal: %v", err)
	}
	if _, err := fd.clientOutW.Write(append(raw, '\n')); err != nil {
		fd.t.Fatalf("driver writeMsg: write: %v", err)
	}
}

// killSubprocess closes the stdout pipe to simulate crash.
//
// killSubprocess 关 stdout 模拟 subprocess 崩溃。
func (fd *fakeDriver) killSubprocess() {
	_ = fd.clientOutW.Close()
}

// ── Init ─────────────────────────────────────────────────────────────────────

func TestInit_HappyPath(t *testing.T) {
	c, fd := newFakeDriver(t)

	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		msg := fd.readMsg()
		if msg["type"] != MsgInit {
			t.Errorf("driver got type=%v, want %s", msg["type"], MsgInit)
		}
		fd.writeMsg(map[string]any{"type": MsgReady})
	}()

	if err := c.Init(context.Background(), map[string]any{"dsn": "fake"}); err != nil {
		t.Fatalf("Init: %v", err)
	}
	wg.Wait()
}

func TestInit_InitError(t *testing.T) {
	c, fd := newFakeDriver(t)

	go func() {
		_ = fd.readMsg()
		fd.writeMsg(map[string]any{
			"type":  MsgInitError,
			"error": "ImportError: psycopg2",
			"trace": "Traceback...",
		})
	}()

	err := c.Init(context.Background(), map[string]any{})
	if !errors.Is(err, ErrInitFailed) {
		t.Errorf("expected ErrInitFailed, got %v", err)
	}
	if !strings.Contains(err.Error(), "psycopg2") {
		t.Errorf("error should preserve remote message; got %v", err)
	}
}

func TestInit_CrashedSubprocess(t *testing.T) {
	c, fd := newFakeDriver(t)

	go func() {
		_ = fd.readMsg()
		fd.killSubprocess() // close stdout without responding
	}()

	err := c.Init(context.Background(), map[string]any{})
	if !errors.Is(err, ErrCrashed) {
		t.Errorf("expected ErrCrashed after EOF, got %v", err)
	}
	if !c.Crashed() {
		t.Error("Crashed() should report true after EOF")
	}
}

// ── Call ─────────────────────────────────────────────────────────────────────

func TestCall_HappyPath(t *testing.T) {
	c, fd := newFakeDriver(t)

	go func() {
		// init
		_ = fd.readMsg()
		fd.writeMsg(map[string]any{"type": MsgReady})

		// call
		msg := fd.readMsg()
		if msg["type"] != MsgCall {
			t.Errorf("expected call, got %v", msg["type"])
		}
		if msg["method"] != "do_query" {
			t.Errorf("method = %v, want do_query", msg["method"])
		}
		id := msg["id"]
		fd.writeMsg(map[string]any{
			"type": MsgReturn,
			"id":   id,
			"data": []any{"row1", "row2"},
		})
	}()

	_ = c.Init(context.Background(), nil)
	res, err := c.Call(context.Background(), "do_query", map[string]any{"sql": "SELECT 1"})
	if err != nil {
		t.Fatalf("Call: %v", err)
	}
	rows, ok := res.([]any)
	if !ok || len(rows) != 2 {
		t.Errorf("result = %v, want []any{row1,row2}", res)
	}
}

func TestCall_RemoteException(t *testing.T) {
	c, fd := newFakeDriver(t)

	go func() {
		_ = fd.readMsg()
		fd.writeMsg(map[string]any{"type": MsgReady})

		msg := fd.readMsg()
		fd.writeMsg(map[string]any{
			"type":  MsgError,
			"id":    msg["id"],
			"error": "ValueError: nope",
			"trace": "Traceback...",
		})
	}()

	_ = c.Init(context.Background(), nil)
	_, err := c.Call(context.Background(), "boom", nil)
	if !errors.Is(err, ErrCallFailed) {
		t.Errorf("expected ErrCallFailed, got %v", err)
	}
	if !strings.Contains(err.Error(), "ValueError") {
		t.Errorf("error should preserve remote message; got %v", err)
	}
}

// ── StreamCall ───────────────────────────────────────────────────────────────

func TestStreamCall_ProgressThenReturn(t *testing.T) {
	c, fd := newFakeDriver(t)

	go func() {
		_ = fd.readMsg()
		fd.writeMsg(map[string]any{"type": MsgReady})

		msg := fd.readMsg()
		id := msg["id"]
		// 2 progress yields, then return.
		fd.writeMsg(map[string]any{"type": MsgProgress, "id": id, "data": "chunk-1"})
		fd.writeMsg(map[string]any{"type": MsgProgress, "id": id, "data": "chunk-2"})
		fd.writeMsg(map[string]any{"type": MsgReturn, "id": id, "data": "final"})
	}()

	_ = c.Init(context.Background(), nil)
	var captured []any
	res, err := c.StreamCall(context.Background(), "stream", nil, func(p any) {
		captured = append(captured, p)
	})
	if err != nil {
		t.Fatalf("StreamCall: %v", err)
	}
	if res != "final" {
		t.Errorf("res = %v, want final", res)
	}
	if len(captured) != 2 || captured[0] != "chunk-1" || captured[1] != "chunk-2" {
		t.Errorf("progress captures = %v, want [chunk-1 chunk-2]", captured)
	}
}

// ── Ctx cancel ───────────────────────────────────────────────────────────────

func TestCall_CtxCancel(t *testing.T) {
	c, fd := newFakeDriver(t)

	// driver init then never responds to call
	go func() {
		_ = fd.readMsg()
		fd.writeMsg(map[string]any{"type": MsgReady})
		_ = fd.readMsg() // read the call, don't respond
	}()
	_ = c.Init(context.Background(), nil)

	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()
	_, err := c.Call(ctx, "slow", nil)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Errorf("expected context.DeadlineExceeded, got %v", err)
	}
	if !c.Crashed() {
		t.Error("after ctx cancel mid-call, client should transition to crashed (no way to recover serialized state)")
	}
}

// ── Shutdown ─────────────────────────────────────────────────────────────────

func TestShutdown_Idempotent(t *testing.T) {
	c, fd := newFakeDriver(t)
	_ = fd // suppress unused warning

	if err := c.Shutdown(context.Background()); err != nil {
		t.Fatalf("Shutdown: %v", err)
	}
	if err := c.Shutdown(context.Background()); err != nil {
		t.Fatalf("second Shutdown: %v", err)
	}

	// Subsequent calls error.
	if _, e := c.Call(context.Background(), "x", nil); !errors.Is(e, ErrShutdownAlready) {
		t.Errorf("expected ErrShutdownAlready from Call after Shutdown; got %v", e)
	}
	if e := c.Init(context.Background(), nil); !errors.Is(e, ErrShutdownAlready) {
		t.Errorf("expected ErrShutdownAlready from Init after Shutdown; got %v", e)
	}
}
