// client.go — stdio Client wrapper around modelcontextprotocol/go-sdk
// v1.6.0. Thin layer adding the project-specific concerns the upstream
// SDK leaves to the application:
//
//   - stderr → zap.L().Named("mcp.<server>") + 256KB ring buffer
//     (UI / debug-page consumers read the tail)
//   - per-call timeout wrapping CallTool (the SDK doesn't impose one;
//     mcp.md §5.7 picks the precedence ServerConfig → RegistryEntry →
//     global default 30s — enforced in the calling Service layer)
//   - Tool / CallToolResult.Content → mcpdomain.ToolDef / string
//     conversion (the SDK exposes its own Tool struct; we keep wire
//     types in mcpdomain so app/transport layers don't depend on the
//     SDK's symbol set)
//
// Initialize handshake + stdout-pollution detection + SIGTERM→5s→SIGKILL
// graceful shutdown are all handled by the SDK's mcp.CommandTransport +
// mcp.Client.Connect flow — we just wire stderr through and convert types.
//
// client.go ——modelcontextprotocol/go-sdk v1.6.0 的 stdio Client 包装。
// 上游 SDK 留给应用的项目特有关切：stderr → zap + 256KB 环形缓冲；
// 每次 CallTool 包超时（precedence 由调用 Service 层决定，详 mcp.md §5.7）；
// Tool / Content → mcpdomain.ToolDef / string 转换（不让 app/transport 层
// 依赖 SDK symbol）。
//
// Initialize 握手 / stdout 污染检测 / SIGTERM→5s→SIGKILL 优雅关停均由 SDK
// 的 mcp.CommandTransport + mcp.Client.Connect 流处理——我们只接 stderr +
// 转类型。
package mcp

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os/exec"
	"strings"
	"sync"

	mcpsdk "github.com/modelcontextprotocol/go-sdk/mcp"
	"go.uber.org/zap"

	mcpdomain "github.com/sunweilin/forgify/backend/internal/domain/mcp"
)

// stderrBufferMax caps each server's stderr ring buffer. 256 KB chosen
// per mcp.md §5.6 — enough to keep the trailing context that usually
// contains the actual error, without growing without bound for long-
// running chatty servers.
//
// stderrBufferMax 限定每 server stderr 环形缓冲。256 KB（mcp.md §5.6）
// ——足够保留通常含真错的尾部上下文，长跑啰嗦 server 也不会无界增长。
const stderrBufferMax = 256 * 1024

// Client is the per-server stdio MCP client interface used by the
// app/mcp Service. Lets the Service mock subprocess concerns at unit-
// test time (and lets us swap to Streamable HTTP transport in V2
// without touching Service).
//
// Client 是 app/mcp Service 用的 per-server stdio MCP client 接口。让
// Service 单测能 mock 子进程；V2 切 Streamable HTTP 也不动 Service。
type Client interface {
	// Initialize starts the subprocess and completes the MCP handshake.
	// Failure here means the server is unusable (bad command, stdout
	// pollution, version mismatch, etc.) — Service should mark
	// status=failed and not retry without user action.
	//
	// Initialize 起子进程 + 完成 MCP 握手。失败 = server 不可用（命令错、
	// stdout 污染、版本不匹配等）——Service 标 status=failed，无用户动作不重试。
	Initialize(ctx context.Context) error

	// ListTools fetches the server's tools/list and converts to our
	// domain shape. Caller caches the result on ServerStatus.Tools.
	//
	// ListTools 取 server 的 tools/list 转 domain 形状。调用方缓存到
	// ServerStatus.Tools。
	ListTools(ctx context.Context) ([]mcpdomain.ToolDef, error)

	// CallTool invokes one tool. ctx carries the per-call timeout
	// (Service applies the §5.7 precedence). Result is the joined text
	// content; multi-modal content (image, resource_link) is rendered
	// as a placeholder pending V2 inline-attachment support.
	//
	// CallTool 调一个 tool。ctx 携带 per-call 超时（Service 应用 §5.7
	// precedence）。返回拼接后的 text content；多模态内容（image / resource_link）
	// 渲染为占位符，待 V2 inline-attachment 支持。
	CallTool(ctx context.Context, name string, args json.RawMessage) (string, error)

	// Close shuts down the subprocess. Idempotent. SDK's CommandTransport
	// handles SIGTERM → 5s → SIGKILL internally.
	//
	// Close 关停子进程。幂等。SDK CommandTransport 内部 SIGTERM → 5s →
	// SIGKILL。
	Close() error

	// StderrTail returns the captured stderr tail (up to 256 KB) for
	// the UI's "view server logs" panel + diagnostic error reports.
	//
	// StderrTail 返捕获的 stderr 尾部（≤ 256 KB），供 UI 日志面板 + 诊断报错用。
	StderrTail() string
}

// stdioClient is the production Client. One instance per ServerConfig.
//
// stdioClient 是生产 Client。每个 ServerConfig 一份。
type stdioClient struct {
	cfg     mcpdomain.ServerConfig
	log     *zap.Logger
	cmd     *exec.Cmd
	session *mcpsdk.ClientSession
	stderr  *ringBuffer
}

// NewStdioClient constructs an unstarted Client. Call Initialize to
// actually spawn the subprocess + handshake.
//
// NewStdioClient 构造未启动的 Client。调 Initialize 才真起子进程 + 握手。
func NewStdioClient(cfg mcpdomain.ServerConfig, log *zap.Logger) Client {
	if log == nil {
		log = zap.NewNop()
	}
	return &stdioClient{
		cfg:    cfg,
		log:    log.Named("mcp." + cfg.Name),
		stderr: newRingBuffer(stderrBufferMax),
	}
}

// Initialize spawns the subprocess + runs the MCP handshake via the
// go-sdk. Stderr is wired to a tee (zap + ring buffer) before the SDK
// takes over stdin/stdout via CommandTransport.
//
// Initialize 起子进程 + 走 MCP 握手（go-sdk）。stderr 在 SDK 接管
// stdin/stdout 前接好 tee（zap + 环形缓冲）。
func (c *stdioClient) Initialize(ctx context.Context) error {
	cmd := exec.Command(c.cfg.Command, c.cfg.Args...)
	cmd.Env = composeEnv(c.cfg.Env)

	stderrPipe, err := cmd.StderrPipe()
	if err != nil {
		return fmt.Errorf("mcp.Client.Initialize: stderr pipe: %w", err)
	}
	// Drain stderr in a goroutine: each line goes to zap (Warn level —
	// many MCP servers print routine info to stderr by convention) and
	// to the ring buffer for tail retrieval. Goroutine exits when the
	// subprocess closes its stderr (typically at exit).
	//
	// goroutine 排空 stderr：每行进 zap（Warn 级——MCP server 常规走
	// stderr 输出 info）+ 环形缓冲。子进程关 stderr（通常退出时）后退出。
	go c.drainStderr(stderrPipe)

	c.cmd = cmd

	transport := &mcpsdk.CommandTransport{Command: cmd}
	sdkClient := mcpsdk.NewClient(&mcpsdk.Implementation{
		Name:    "forgify",
		Version: "1.2.0",
	}, nil)

	session, err := sdkClient.Connect(ctx, transport, nil)
	if err != nil {
		// Connect failure could be: subprocess didn't start (bad path),
		// stdout pollution before initialize, version mismatch, or
		// handshake protocol error. All collapse to ErrServerNotConnected
		// for the Service to reflect on ServerStatus.
		//
		// Connect 失败原因：子进程没起（路径错）、initialize 前 stdout 污染、
		// 版本不匹配、或握手协议错。一律收敛到 ErrServerNotConnected 让 Service
		// 反映到 ServerStatus。
		return fmt.Errorf("mcp.Client.Initialize: connect %s: %w: %v",
			c.cfg.Name, mcpdomain.ErrServerNotConnected, err)
	}
	c.session = session
	return nil
}

// ListTools fetches tools/list and converts the SDK Tool slice to our
// domain ToolDef. ServerName is stamped from the wrapper's config so
// downstream consumers can route call_mcp dispatch by server.
//
// ListTools 取 tools/list + 把 SDK Tool slice 转 domain ToolDef。ServerName
// 从 wrapper 的 config 印进去，让下游 call_mcp 派发能按 server 路由。
func (c *stdioClient) ListTools(ctx context.Context) ([]mcpdomain.ToolDef, error) {
	if c.session == nil {
		return nil, fmt.Errorf("mcp.Client.ListTools: %w", mcpdomain.ErrServerNotConnected)
	}
	res, err := c.session.ListTools(ctx, &mcpsdk.ListToolsParams{})
	if err != nil {
		return nil, fmt.Errorf("mcp.Client.ListTools %s: %w: %v",
			c.cfg.Name, mcpdomain.ErrToolCallFailed, err)
	}
	out := make([]mcpdomain.ToolDef, 0, len(res.Tools))
	for _, t := range res.Tools {
		schemaJSON, _ := json.Marshal(t.InputSchema)
		out = append(out, mcpdomain.ToolDef{
			ServerName:  c.cfg.Name,
			Name:        t.Name,
			Description: t.Description,
			InputSchema: schemaJSON,
		})
	}
	return out, nil
}

// CallTool invokes one tool. The caller's ctx is the per-call timeout
// (Service applied the §5.7 precedence already). On ctx.Done the SDK
// translates to notifications/cancelled toward the server (best-
// effort — server may ignore) and we return ErrToolCallTimeout. Other
// failure modes wrap ErrToolCallFailed with the server's error text
// preserved.
//
// CallTool 调一个 tool。ctx 是调用方应用 §5.7 precedence 后的 per-call 超时。
// ctx.Done 时 SDK 给 server 发 notifications/cancelled（best-effort，server
// 可忽略）我们返 ErrToolCallTimeout。其他失败 wrap ErrToolCallFailed 保留
// server 错误文本。
func (c *stdioClient) CallTool(ctx context.Context, name string, args json.RawMessage) (string, error) {
	if c.session == nil {
		return "", fmt.Errorf("mcp.Client.CallTool %s/%s: %w",
			c.cfg.Name, name, mcpdomain.ErrServerNotConnected)
	}

	var argsMap any
	if len(args) > 0 {
		if err := json.Unmarshal(args, &argsMap); err != nil {
			return "", fmt.Errorf("mcp.Client.CallTool %s/%s: parse args: %w",
				c.cfg.Name, name, err)
		}
	}

	res, err := c.session.CallTool(ctx, &mcpsdk.CallToolParams{
		Name:      name,
		Arguments: argsMap,
	})
	if err != nil {
		// Distinguish ctx-cancellation (timeout) from other RPC failures
		// — UI cares about the difference (timeout = retry might work,
		// other = server is misbehaving).
		// 区分 ctx-cancellation（超时）与其他 RPC 失败——UI 关心区别（超时 =
		// 重试可能成，其他 = server 在乱来）。
		if errors.Is(err, context.DeadlineExceeded) || errors.Is(err, context.Canceled) {
			return "", fmt.Errorf("mcp.Client.CallTool %s/%s: %w: %v",
				c.cfg.Name, name, mcpdomain.ErrToolCallTimeout, err)
		}
		return "", fmt.Errorf("mcp.Client.CallTool %s/%s: %w: %v",
			c.cfg.Name, name, mcpdomain.ErrToolCallFailed, err)
	}
	if res.IsError {
		// Server returned isError=true with the failure message inside
		// the content array — preserve that text for the LLM.
		// server 返 isError=true，错误文本在 content 数组——保留给 LLM。
		return "", fmt.Errorf("mcp.Client.CallTool %s/%s: %w: %s",
			c.cfg.Name, name, mcpdomain.ErrToolCallFailed, joinContent(res.Content))
	}
	return joinContent(res.Content), nil
}

// Close shuts down the session. SDK's pipeRWC.Close handles
// SIGTERM → 5s → SIGKILL internally per the MCP spec.
//
// Close 关 session。SDK pipeRWC.Close 内部按 MCP spec 处理 SIGTERM →
// 5s → SIGKILL。
func (c *stdioClient) Close() error {
	if c.session == nil {
		return nil
	}
	err := c.session.Close()
	c.session = nil
	return err
}

// StderrTail returns the current ring-buffer contents.
//
// StderrTail 返当前环形缓冲内容。
func (c *stdioClient) StderrTail() string {
	return c.stderr.String()
}

// drainStderr reads stderr line-by-line, ships each line to zap, and
// keeps the last stderrBufferMax bytes in the ring buffer for the UI
// log panel. Long-lived goroutine — exits when the subprocess closes
// its stderr (typically at exit).
//
// drainStderr 按行读 stderr，每行发 zap + 保留尾部 stderrBufferMax 字节
// 给 UI 日志面板。长生命 goroutine——子进程关 stderr（通常退出）时退出。
func (c *stdioClient) drainStderr(r io.Reader) {
	scanner := bufio.NewScanner(r)
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)
	for scanner.Scan() {
		line := scanner.Text()
		c.log.Warn("stderr", zap.String("line", line))
		c.stderr.WriteLine(line)
	}
}

// composeEnv merges the per-server env on top of os.Environ() so the
// subprocess inherits PATH / HOME / etc. while still seeing the user-
// provided secrets (GitHub PAT, etc.). Mimics how shells launch
// programs.
//
// composeEnv 把 per-server env 叠加到 os.Environ()，子进程继承 PATH /
// HOME 等同时看到用户提供的 secret（GitHub PAT 等）。模拟 shell 启动行为。
func composeEnv(extras map[string]string) []string {
	if len(extras) == 0 {
		return nil // nil = inherit os.Environ() per exec.Cmd convention
	}
	// We build a fresh slice rather than calling os.Environ() because
	// nil cmd.Env causes inherit-everything; we want extras layered on
	// top of inheritance, so we explicitly include os.Environ() then
	// our keys (last write wins for duplicates).
	//
	// 新建 slice 而非 os.Environ()——nil cmd.Env 是继承所有；想 extras 叠加
	// 在继承之上，显式列 os.Environ() 再加我们的 key（重复时后写胜）。
	out := append([]string(nil), osEnviron()...)
	for k, v := range extras {
		out = append(out, k+"="+v)
	}
	return out
}

// osEnviron is a var so tests can override.
//
// osEnviron 是 var 让测试可覆盖。
var osEnviron = func() []string {
	return defaultOSEnviron()
}

// joinContent flattens an MCP content array to a string. Text content
// is included verbatim; non-text (image, resource_link, etc.) is
// rendered as a `[image: …]` / `[resource: …]` placeholder pending V2
// inline-attachment routing. Reasoning: the LLM cares about the text
// 95% of the time; if it later wants the image, V2 can route it as a
// chat attachment with a stable handle.
//
// joinContent 把 MCP content 数组拍平为 string。text 原样；非 text（image、
// resource_link 等）渲染为 `[image: …]` / `[resource: …]` 占位符待 V2
// inline-attachment 路由。理由：LLM 95% 时间只关心文字；要 image 时 V2
// 路由为 chat attachment 带稳定 handle。
func joinContent(content []mcpsdk.Content) string {
	var b strings.Builder
	for _, c := range content {
		switch v := c.(type) {
		case *mcpsdk.TextContent:
			b.WriteString(v.Text)
		case *mcpsdk.ImageContent:
			fmt.Fprintf(&b, "[image: %s]", v.MIMEType)
		case *mcpsdk.AudioContent:
			fmt.Fprintf(&b, "[audio: %s]", v.MIMEType)
		case *mcpsdk.ResourceLink:
			fmt.Fprintf(&b, "[resource: %s]", v.URI)
		case *mcpsdk.EmbeddedResource:
			if v.Resource != nil {
				fmt.Fprintf(&b, "[resource: %s]", v.Resource.URI)
			} else {
				b.WriteString("[resource]")
			}
		default:
			fmt.Fprintf(&b, "[%T]", c)
		}
	}
	return b.String()
}

// ── ringBuffer ───────────────────────────────────────────────────────

// ringBuffer is a fixed-capacity byte buffer that drops oldest data
// when full. Concurrency-safe; a single drainStderr goroutine writes
// while StderrTail can read at any time from any goroutine.
//
// ringBuffer 是固定容量字节缓冲，满时丢最早数据。并发安全；单 drainStderr
// goroutine 写、StderrTail 任意 goroutine 任意时点读。
type ringBuffer struct {
	mu  sync.Mutex
	buf []byte
	cap int
}

func newRingBuffer(capacity int) *ringBuffer {
	return &ringBuffer{cap: capacity}
}

// WriteLine appends a line + newline to the buffer, dropping from the
// head when capacity is exceeded.
//
// WriteLine 追加 line + \n，超 capacity 时从头部丢。
func (r *ringBuffer) WriteLine(line string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.buf = append(r.buf, line...)
	r.buf = append(r.buf, '\n')
	if len(r.buf) > r.cap {
		// Drop the oldest bytes by sub-slicing — preserves the most
		// recent capacity worth of data.
		// 子切片丢最早字节——保留最近 capacity 字节。
		r.buf = r.buf[len(r.buf)-r.cap:]
	}
}

// String returns a copy of the current contents (read-side safe to
// hand out without further locking).
//
// String 返当前内容拷贝（读侧分发后无需再锁）。
func (r *ringBuffer) String() string {
	r.mu.Lock()
	defer r.mu.Unlock()
	return string(r.buf)
}
