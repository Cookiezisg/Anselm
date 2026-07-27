package mcp

import (
	"context"
	"fmt"
	"time"

	mcpsdk "github.com/modelcontextprotocol/go-sdk/mcp"
)

// drainProgress waits a short REAL-TIME quiet window so the SDK's async notification handler
// flushes a call's already-queued progress lines to the sink before the caller unregisters the
// per-call token. It counted Gosched yields until 2026-07-28, and that lost progress under load:
// a yield hands the processor to SOME goroutine, not necessarily the handler, so on a machine
// running the full parallel testend (16 server universes) two quiet yields elapsed before the
// handler ever ran — the token was unregistered and the durable call log raced empty (observed as
// a rare TestMCP_ScriptedServerLifecycle flake; the deterministic repro remains GOMAXPROCS=1).
// Yield COUNTS are not time. The quiet window is real milliseconds now: a progress-opted call pays
// ~2ms — noise against a subprocess round-trip — and the deadline still backstops a stuck handler.
//
// drainProgress 等一小段**真实时间**的安静窗，使 SDK 异步通知处理器在调用方注销 per-call token 前把已
// 入队的进度行刷进 sink。2026-07-28 之前它数的是 Gosched 让度次数,而那在重负载下丢进度:一次让度把
// 处理器交给**某个** goroutine、不保证是 handler,于是在跑满并行 testend(16 个 server 宇宙)的机器上,
// 两次「安静让度」流逝时 handler 还没跑过——token 被注销,durable 调用日志竞争为空(表现为
// TestMCP_ScriptedServerLifecycle 的罕见 flake;确定性复现仍是 GOMAXPROCS=1)。**让度次数不是时间。**
// 安静窗现在是真实毫秒:opt-in 进度的调用付 ~2ms——相对一次子进程往返是噪声——deadline 仍兜底卡死的
// handler。
func drainProgress(seen <-chan struct{}) {
	const (
		quietWindow = 2 * time.Millisecond   // silence this long = drained 安静这么久=已排空
		maxWait     = 150 * time.Millisecond // hard ceiling against a chatty/stuck handler 硬顶
	)
	deadline := time.NewTimer(maxWait)
	defer deadline.Stop()
	for {
		quiet := time.NewTimer(quietWindow)
		select {
		case <-seen:
			quiet.Stop()
		case <-quiet.C:
			return
		case <-deadline.C:
			quiet.Stop()
			return
		}
	}
}

type progressKey struct{}

// WithProgress attaches a sink that receives an MCP tool call's progress notifications as they
// arrive. The tool layer sets it (bound to the call's live UI stream); CallTool reads it and, when
// present, requests progress via a per-call token. No ctx value = no progress (REST / boot).
//
// WithProgress 挂一个 sink，接收 MCP 工具调用到来的进度通知。工具层设置它（绑到调用的实时 UI 流）；
// CallTool 读到则用 per-call token 请求进度。ctx 无此值 = 不要进度（REST / boot）。
func WithProgress(ctx context.Context, sink func(string)) context.Context {
	if sink == nil {
		return ctx
	}
	return context.WithValue(ctx, progressKey{}, sink)
}

// ProgressFrom returns the sink set by WithProgress (nil if unset) — exported so the app layer can
// wrap an existing sink (e.g. tee the chat sink AND the entities run terminal).
//
// ProgressFrom 返回 WithProgress 设的 sink（未设为 nil）——导出使 app 层能包既有 sink（如同时 tee chat sink
// 与 entities run 终端）。
func ProgressFrom(ctx context.Context) func(string) {
	sink, _ := ctx.Value(progressKey{}).(func(string))
	return sink
}

// onProgress forwards a server progress notification to the CallTool that registered its token.
// Session-global (one handler per client); an unmatched token is dropped (a stale / untracked call).
//
// onProgress 把 server 进度通知转给登记了该 token 的 CallTool。session 级全局；未匹配 token 丢弃。
func (c *client) onProgress(_ context.Context, req *mcpsdk.ProgressNotificationClientRequest) {
	if req == nil {
		return
	}
	tok, ok := req.Params.ProgressToken.(string)
	if !ok {
		return
	}
	v, ok := c.progress.Load(tok)
	if !ok {
		return
	}
	if sink, _ := v.(func(string)); sink != nil {
		sink(formatProgress(req.Params))
	}
}

// formatProgress renders one progress notification as a human line for the stream.
//
// formatProgress 把一条进度通知渲成一行人读文本，供流式推送。
func formatProgress(p *mcpsdk.ProgressNotificationParams) string {
	msg := p.Message
	if msg == "" {
		msg = "working…"
	}
	if p.Total > 0 {
		return fmt.Sprintf("%s (%.0f/%.0f)\n", msg, p.Progress, p.Total)
	}
	return msg + "\n"
}
