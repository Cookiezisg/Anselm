// Package handler provides the stdio line-JSON client for one HandlerInstance
// subprocess. Wire format is custom (not JSON-RPC 2.0):
//
//	Outbound (Go → Python):  {"type":"init",     "args":{...}}
//	                         {"type":"call",     "id":N, "method":"X", "args":{...}}
//	                         {"type":"shutdown"}
//
//	Inbound  (Python → Go):  {"type":"ready"}
//	                         {"type":"init_error", "error":"...", "trace":"..."}
//	                         {"type":"progress",   "id":N, "data":...}
//	                         {"type":"return",     "id":N, "data":...}
//	                         {"type":"error",      "id":N, "error":"...", "trace":"..."}
//
// One JSON object per line (LF separator). The driver template lives in
// spec/03-handler.md §5.5 and is composed by app/handler/rpc.go (Phase 4).
//
// Concurrency model — V1 simplification (per spec/02-handler-domain.md §3):
// calls are serialized per-instance via Client.mu. A streaming call (one that
// emits progress before return) reads multiple messages under the same lock;
// subsequent callers wait. Each long-lived Client wraps ONE subprocess; the
// registry holds N Clients for N instances and parallelism happens across
// instances, not within one.
//
// Package handler 提供单个 HandlerInstance subprocess 的 stdio 行 JSON 客户端。
// Wire format 是自定义的(非 JSON-RPC 2.0):一行一个 JSON 对象,LF 分隔。
// V1 简化:per-instance 调用串行,registry 在多个 instance 之间并发。
package handler

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"sync"
	"time"

	"go.uber.org/zap"
)

// Message-type discriminators (the JSON object's "type" field). Stable
// strings — change requires updating the Python driver template in lockstep.
//
// 消息类型常量(JSON 对象的 "type" 字段)。改名要同步 Python driver 模板。
const (
	MsgInit      = "init"
	MsgReady     = "ready"
	MsgInitError = "init_error"
	MsgCall      = "call"
	MsgReturn    = "return"
	MsgError     = "error"
	MsgProgress  = "progress"
	MsgShutdown  = "shutdown"
)

// ── Errors ────────────────────────────────────────────────────────────────────

var (
	// ErrCrashed is returned when the subprocess died unexpectedly. After
	// this fires for any method, the client is dead — registry should
	// discard and respawn for the next acquire.
	//
	// ErrCrashed 在 subprocess 异常退出后由任何方法返;客户端已死,registry
	// 应丢弃并下次 acquire 时重 spawn。
	ErrCrashed = errors.New("handler.Client: subprocess crashed")

	// ErrInitFailed wraps the Python __init__ exception (e.g. bad config /
	// missing dep). The remote `trace` field is preserved in the error
	// message for diagnostic logs.
	//
	// ErrInitFailed 包装 Python __init__ 抛的异常(配置错 / 缺依赖等)。
	ErrInitFailed = errors.New("handler.Client: init failed")

	// ErrCallFailed wraps a Python method exception during Call. Remote
	// trace is preserved in the wrapped error.
	//
	// ErrCallFailed 包装 method 调用时 Python 抛的异常。
	ErrCallFailed = errors.New("handler.Client: call failed")

	// ErrShutdownAlready is returned by methods called after Shutdown.
	//
	// ErrShutdownAlready 在 Shutdown 之后还调方法时返。
	ErrShutdownAlready = errors.New("handler.Client: already shut down")

	// ErrProtocol marks malformed wire data from the subprocess (invalid
	// JSON / unexpected message type / id mismatch). Treated as a fatal
	// driver bug — client transitions to crashed state.
	//
	// ErrProtocol 标记 subprocess 发的协议数据非法(JSON 不合法 / 意外
	// 消息类型 / id 不匹配)。视为 driver bug;客户端转 crashed 态。
	ErrProtocol = errors.New("handler.Client: protocol error")
)

// ── Client interface ─────────────────────────────────────────────────────────

// Client is the contract one HandlerInstance subprocess exposes. Five methods:
// Init (one-shot post-spawn) / Call (synchronous RPC) / StreamCall (RPC + per-
// yield progress callback) / Shutdown (graceful close) / Crashed (state check).
//
// Implementations: stdioClient (this file, production); fakes in client_test.go.
//
// Client 是单个 HandlerInstance subprocess 的对外契约。5 个方法:Init / Call /
// StreamCall / Shutdown / Crashed。生产实现 stdioClient;测试用 fake。
type Client interface {
	Init(ctx context.Context, args map[string]any) error
	Call(ctx context.Context, method string, args map[string]any) (any, error)
	StreamCall(ctx context.Context, method string, args map[string]any, onProgress func(any)) (any, error)
	Shutdown(ctx context.Context) error
	Crashed() bool
}

// ── Implementation ───────────────────────────────────────────────────────────

// New constructs a stdio Client around the subprocess pipes. The registry
// owns process lifetime; this client only touches stdin/stdout. Stderr is
// captured separately by the registry (registry.go in Phase 4).
//
// New 构造 stdio Client,只接 stdin/stdout;subprocess 生命周期由 registry 管,
// stderr 由 registry 独立捕获。
func New(stdin io.WriteCloser, stdout io.Reader, log *zap.Logger) Client {
	if log == nil {
		log = zap.NewNop()
	}
	return &stdioClient{
		stdin:  stdin,
		stdout: bufio.NewReader(stdout),
		log:    log.Named("handler.client"),
	}
}

type stdioClient struct {
	mu         sync.Mutex // serializes Init / Call / StreamCall / Shutdown
	stdin      io.WriteCloser
	stdout     *bufio.Reader
	log        *zap.Logger
	nextReqID  int
	crashed    bool
	shutdown   bool
}

// Crashed reports whether the subprocess died unexpectedly. Cheap to call.
//
// Crashed 报子进程是否异常死亡。
func (c *stdioClient) Crashed() bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.crashed
}

// Init sends the init message + waits for ready/init_error. ctx cancel kills
// the wait but NOT the subprocess (caller is responsible — registry will
// kill via process group).
//
// Init 发 init + 等 ready/init_error。ctx cancel 退出等待(不杀进程,registry 管)。
func (c *stdioClient) Init(ctx context.Context, args map[string]any) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.crashed {
		return ErrCrashed
	}
	if c.shutdown {
		return ErrShutdownAlready
	}

	if err := c.send(map[string]any{"type": MsgInit, "args": args}); err != nil {
		return c.fail(fmt.Errorf("send init: %w", err))
	}

	msg, err := c.readMessage(ctx)
	if err != nil {
		return c.fail(err)
	}
	switch msg["type"] {
	case MsgReady:
		return nil
	case MsgInitError:
		errStr, _ := msg["error"].(string)
		trace, _ := msg["trace"].(string)
		return fmt.Errorf("%w: %s\n%s", ErrInitFailed, errStr, trace)
	default:
		return c.fail(fmt.Errorf("%w: expected ready/init_error after init, got %q",
			ErrProtocol, msg["type"]))
	}
}

// Call sends a call message + waits for return/error. progress messages mid-
// call are ignored (caller doesn't want streaming).
//
// Call 发 call + 等 return/error。中途的 progress 消息忽略(调用方不要流)。
func (c *stdioClient) Call(ctx context.Context, method string, args map[string]any) (any, error) {
	return c.doCall(ctx, method, args, nil)
}

// StreamCall sends a call + invokes onProgress for each progress yield, then
// returns the final value. ctx cancel mid-call returns the ctx error (the
// subprocess keeps running until the next Call serializes behind it; caller
// can Shutdown to kill).
//
// StreamCall 发 call + 每个 progress yield 调 onProgress,最后返终值。
// ctx cancel 中途返 ctx 错;subprocess 不停(下次 Call 后排队执行)。
func (c *stdioClient) StreamCall(ctx context.Context, method string, args map[string]any, onProgress func(any)) (any, error) {
	return c.doCall(ctx, method, args, onProgress)
}

// doCall is shared logic — read until return/error matching our id, dispatch
// progress to onProgress (nil = drop).
//
// doCall 共用逻辑——读到匹配 id 的 return/error 才出;progress 派 onProgress。
func (c *stdioClient) doCall(ctx context.Context, method string, args map[string]any, onProgress func(any)) (any, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.crashed {
		return nil, ErrCrashed
	}
	if c.shutdown {
		return nil, ErrShutdownAlready
	}

	c.nextReqID++
	reqID := c.nextReqID
	if err := c.send(map[string]any{
		"type":   MsgCall,
		"id":     reqID,
		"method": method,
		"args":   args,
	}); err != nil {
		return nil, c.fail(fmt.Errorf("send call: %w", err))
	}

	for {
		msg, err := c.readMessage(ctx)
		if err != nil {
			return nil, c.fail(err)
		}

		// Match the response id. Drivers may interleave progress for the
		// same call before return/error; id mismatch on terminal frames is
		// a protocol error (V1 calls are serialized — only one in-flight id).
		//
		// 匹配响应 id。同一 call 可能交错 progress 再 return;终态帧 id 不
		// 匹配 = 协议错(V1 串行,只一个在飞的 id)。
		gotID, _ := msg["id"].(float64) // JSON 数字解到 float64
		switch msg["type"] {
		case MsgProgress:
			if int(gotID) != reqID {
				return nil, c.fail(fmt.Errorf("%w: progress id %d != reqID %d", ErrProtocol, int(gotID), reqID))
			}
			if onProgress != nil {
				onProgress(msg["data"])
			}
		case MsgReturn:
			if int(gotID) != reqID {
				return nil, c.fail(fmt.Errorf("%w: return id %d != reqID %d", ErrProtocol, int(gotID), reqID))
			}
			return msg["data"], nil
		case MsgError:
			if int(gotID) != reqID {
				return nil, c.fail(fmt.Errorf("%w: error id %d != reqID %d", ErrProtocol, int(gotID), reqID))
			}
			errStr, _ := msg["error"].(string)
			trace, _ := msg["trace"].(string)
			return nil, fmt.Errorf("%w: %s\n%s", ErrCallFailed, errStr, trace)
		default:
			return nil, c.fail(fmt.Errorf("%w: unexpected message type %q during call", ErrProtocol, msg["type"]))
		}
	}
}

// Shutdown sends shutdown + closes stdin. Idempotent (further calls return
// ErrShutdownAlready). Does NOT wait for subprocess exit — the registry
// process-group manager does that.
//
// Send is bounded by a 500ms timeout in case the subprocess is wedged
// (stdin pipe full, OS won't drain). Closing stdin unblocks any pending
// Write via ErrClosedPipe, so the spawned goroutine always returns.
//
// Shutdown 发 shutdown + 关 stdin。幂等;不等子进程退出(registry 进程组管)。
// 发送有 500ms 上限防 subprocess 卡住;关 stdin 时 PipeWriter.Close 中断
// 待写 goroutine,不漏。
func (c *stdioClient) Shutdown(ctx context.Context) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.shutdown {
		return nil // idempotent
	}
	c.shutdown = true
	if c.crashed {
		_ = c.stdin.Close()
		return nil
	}

	done := make(chan struct{})
	go func() {
		_ = c.send(map[string]any{"type": MsgShutdown})
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(500 * time.Millisecond):
	case <-ctx.Done():
	}
	_ = c.stdin.Close()
	return nil
}

// ── helpers ───────────────────────────────────────────────────────────────────

// send marshals msg to JSON + writes line + flushes. Must be called under c.mu.
//
// send marshal msg 写入 + 换行 + flush。调用方持 c.mu。
func (c *stdioClient) send(msg map[string]any) error {
	raw, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("marshal: %w", err)
	}
	raw = append(raw, '\n')
	if _, err := c.stdin.Write(raw); err != nil {
		return fmt.Errorf("write stdin: %w", err)
	}
	return nil
}

// readMessage reads one line from stdout + unmarshals JSON. Respects ctx
// cancellation via a small read goroutine + select (bufio.Reader has no
// SetDeadline, and io.Pipe / os.Pipe don't either on most paths).
//
// readMessage 读一行 + 解 JSON。经 goroutine + select 接 ctx cancel
// (bufio.Reader 无 SetDeadline)。
func (c *stdioClient) readMessage(ctx context.Context) (map[string]any, error) {
	type result struct {
		line string
		err  error
	}
	resCh := make(chan result, 1)
	go func() {
		line, err := c.stdout.ReadString('\n')
		resCh <- result{line: line, err: err}
	}()

	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	case r := <-resCh:
		if r.err != nil {
			if errors.Is(r.err, io.EOF) {
				return nil, ErrCrashed
			}
			return nil, fmt.Errorf("read stdout: %w", r.err)
		}
		var msg map[string]any
		if err := json.Unmarshal([]byte(r.line), &msg); err != nil {
			return nil, fmt.Errorf("%w: bad JSON line %q: %v", ErrProtocol, r.line, err)
		}
		return msg, nil
	}
}

// fail marks the client crashed (so future calls short-circuit) and returns
// the underlying error wrapped with context. Caller must hold c.mu.
//
// fail 标 crashed(后续调用短路)并返包装好的错;调用方持 c.mu。
func (c *stdioClient) fail(err error) error {
	if c.crashed {
		return err
	}
	c.crashed = true
	c.log.Warn("handler.Client transitioning to crashed", zap.Error(err))
	return err
}

// Compile-time interface assertion.
var _ Client = (*stdioClient)(nil)
