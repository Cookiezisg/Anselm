// Package handler is the stdio line-JSON RPC client for one resident HandlerInstance
// subprocess. One Client wraps one subprocess's stdin/stdout; the process lifetime is
// the app-layer instance manager's job. Calls are serialised by a mutex (single stdio
// pipe), so a shared resident instance handles concurrent callers one at a time.
//
// Package handler 是单个常驻 HandlerInstance 子进程的 stdio 行-JSON RPC 客户端。一个 Client
// 包一个子进程的 stdin/stdout；进程生命周期由 app 层实例管理器负责。调用经 mutex 串行（单 stdio
// 管道），故共享常驻实例对并发调用方逐个处理。
package handler

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	"io"
	"sync"
	"time"

	"go.uber.org/zap"
)

// Wire message-type discriminators; renaming requires a lockstep change in the Python driver.
//
// Wire 消息类型常量；改名需同步 Python driver 模板。
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

var (
	ErrCrashed         = errorspkg.New(errorspkg.KindBadGateway, "HANDLER_CLIENT_CRASHED", "handler.Client: subprocess crashed")
	ErrInitFailed      = errorspkg.New(errorspkg.KindBadGateway, "HANDLER_CLIENT_INIT_FAILED", "handler.Client: init failed")
	ErrCallFailed      = errorspkg.New(errorspkg.KindBadGateway, "HANDLER_CLIENT_CALL_FAILED", "handler.Client: call failed")
	ErrShutdownAlready = errorspkg.New(errorspkg.KindInternal, "HANDLER_CLIENT_ALREADY_SHUTDOWN", "handler.Client: already shut down")
	ErrProtocol        = errorspkg.New(errorspkg.KindBadGateway, "HANDLER_CLIENT_PROTOCOL", "handler.Client: protocol error")
)

// Client is the contract a HandlerInstance subprocess exposes.
//
// Client 是 HandlerInstance 子进程的对外契约。
type Client interface {
	Init(ctx context.Context, args map[string]any) error
	StreamCall(ctx context.Context, method string, args map[string]any, onProgress func(any)) (any, error)
	Shutdown(ctx context.Context) error
	Crashed() bool
}

// New wraps subprocess stdin/stdout into a Client.
//
// New 用 stdin/stdout 包出 Client。
func New(stdin io.WriteCloser, stdout io.Reader, log *zap.Logger) Client {
	if log == nil {
		log = zap.NewNop()
	}
	return &stdioClient{stdin: stdin, stdout: bufio.NewReader(stdout), log: log.Named("handler.client")}
}

type stdioClient struct {
	mu        sync.Mutex
	stdin     io.WriteCloser
	stdout    *bufio.Reader
	log       *zap.Logger
	nextReqID int
	crashed   bool
	shutdown  bool
}

func (c *stdioClient) Crashed() bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.crashed
}

// Init sends init then waits for ready / init_error; ctx cancel aborts the wait, not the subprocess.
//
// Init 发 init 等 ready / init_error；ctx cancel 只退出等待，不杀子进程。
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
		return c.fail(fmt.Errorf("%w: expected ready/init_error after init, got %q", ErrProtocol, msg["type"]))
	}
}

func (c *stdioClient) StreamCall(ctx context.Context, method string, args map[string]any, onProgress func(any)) (any, error) {
	return c.doCall(ctx, method, args, onProgress)
}

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
	if err := c.send(map[string]any{"type": MsgCall, "id": reqID, "method": method, "args": args}); err != nil {
		return nil, c.fail(fmt.Errorf("send call: %w", err))
	}

	for {
		msg, err := c.readMessage(ctx)
		if err != nil {
			return nil, c.fail(err)
		}
		gotID, _ := msg["id"].(float64)
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

// Shutdown sends shutdown and closes stdin; idempotent, with a 500ms send cap for wedged stdio.
//
// Shutdown 发 shutdown 并关 stdin；幂等，send 有 500ms 上限防卡住。
func (c *stdioClient) Shutdown(ctx context.Context) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.shutdown {
		return nil
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

func (c *stdioClient) fail(err error) error {
	if c.crashed {
		return err
	}
	c.crashed = true
	c.log.Warn("handler.Client transitioning to crashed", zap.Error(err))
	return err
}

var _ Client = (*stdioClient)(nil)
