// Package humanloop is the in-memory human-in-the-loop broker (R0064): a tool that needs a human
// decision — ask_user, or the danger gate before a self-reported-dangerous tool runs — calls
// Broker.Request, which surfaces the pending interaction to the front end and BLOCKS the calling
// goroutine until an HTTP resolve arrives (or the run is cancelled). It is deliberately in-memory:
// Forgify is a single-process desktop app, so "survive an app restart" buys almost nothing (a
// closed app runs no agents), and a held goroutine is free. Nesting needs zero extra machinery —
// a sub-agent's tool blocking naturally holds the whole call stack above it.
//
// Package humanloop 是内存人在环 broker（R0064）：需要人决定的工具——ask_user，或自报危险工具执行前的 danger
// 门——调 Broker.Request，它把待决交互露给前端并**阻塞调用 goroutine**，直到 HTTP resolve 到达（或运行被取消）。
// 刻意内存：Forgify 是单进程桌面 app，「跨 app 重启存活」几乎无收益（app 关了没 agent 在跑），挂个 goroutine 零成本。
// 嵌套零额外机制——子 agent 的工具阻塞天然 hold 住它上面整个调用栈。
package humanloop

import (
	"context"
	"encoding/json"
	"sync"
)

// Interaction kinds.
//
// 交互种类。
const (
	KindAsk    = "ask"    // an ask_user call — the agent wants the human's answer
	KindDanger = "danger" // a self-reported dangerous tool call — gate it before it runs
)

// Decisions a human returns. cancel is NOT a decision — it arrives as ctx cancellation.
//
// 人返回的决定。cancel 不是决定——它经 ctx 取消到达。
const (
	DecisionApprove       = "approve"        // danger: run the gated tool
	DecisionApproveAlways = "approve_always" // danger: run it + session-whitelist the tool
	DecisionDeny          = "deny"           // danger: skip it, feed the denial back
	DecisionAccept        = "accept"         // ask: the answer is in Response.Answer
	DecisionDecline       = "decline"        // ask: refused to answer, feed back
)

// Model-facing feedback recorded as the tool_result when an interaction is refused, so the model
// re-routes (standard reject behavior).
//
// 拒绝交互时记为 tool_result 的、面向模型的反馈，使模型改道（标准 reject 行为）。
const (
	DenyFeedback    = "The user denied running this tool. Do not retry it unless the user explicitly asks."
	DeclineFeedback = "The user declined to answer this question. Proceed without it or ask differently."
)

// Request is a pending human interaction (surfaced to the front end, keyed by ToolCallID).
//
// Request 是一条待决人机交互（露给前端，按 ToolCallID 键）。
type Request struct {
	ToolCallID     string          `json:"toolCallId"`
	Kind           string          `json:"kind"` // KindAsk | KindDanger
	Tool           string          `json:"tool"` // the tool name (danger: gated tool; ask: "ask_user")
	ConversationID string          `json:"conversationId,omitempty"`
	Prompt         json.RawMessage `json:"prompt,omitempty"` // ask: {message, options}; danger: {summary, args}
}

// Response is the human's decision.
//
// Response 是人的决定。
type Response struct {
	Action string `json:"action"` // a Decision*
	Answer string `json:"answer"` // ask accept: the answer
}

// Surface is how a pending interaction reaches the front end — injected by the host (chat emits a
// messages-stream signal). nil → no live surface (the run still blocks; the resolve endpoint /
// pending-list re-syncs).
//
// Surface 是待决交互怎么到前端——由 host 注入（chat 发一条 messages 流 signal）。nil → 无 live 露出（运行仍阻塞；
// resolve 端点 / pending 列表重新同步）。
type Surface func(ctx context.Context, req Request)

// Broker holds in-flight interactions + the always-allow session whitelist. One per app, seeded
// into ctx by the interactive host (chat); it flows from there into nested agent runs.
//
// Broker 持有飞行中交互 + always-allow 会话白名单。每 app 一个，由交互 host（chat）seed 进 ctx；从那里流入嵌套
// agent 运行。
type Broker struct {
	surface Surface
	mu      sync.Mutex
	pending map[string]*waiter // toolCallID → waiter
	allowed map[string]bool    // conversationID\x00tool → always-allow
}

type waiter struct {
	req Request
	ch  chan Response
}

func New(surface Surface) *Broker {
	return &Broker{surface: surface, pending: map[string]*waiter{}, allowed: map[string]bool{}}
}

// Request registers a pending interaction, surfaces it, and BLOCKS until resolved or the ctx is
// cancelled (the run aborted). approve_always also session-whitelists the tool. A duplicate
// ToolCallID (shouldn't happen — ids are unique per turn) replaces the prior waiter.
//
// Request 注册一条待决交互、露出它、阻塞至 resolve 或 ctx 取消（运行中止）。approve_always 顺带会话白名单该工具。
// 重复 ToolCallID（不应发生——回合内 id 唯一）替换旧 waiter。
func (b *Broker) Request(ctx context.Context, req Request) (Response, error) {
	w := &waiter{req: req, ch: make(chan Response, 1)}
	b.mu.Lock()
	b.pending[req.ToolCallID] = w
	b.mu.Unlock()
	defer func() {
		b.mu.Lock()
		delete(b.pending, req.ToolCallID)
		b.mu.Unlock()
	}()

	if b.surface != nil {
		b.surface(ctx, req)
	}
	select {
	case resp := <-w.ch:
		if resp.Action == DecisionApproveAlways && req.Kind == KindDanger {
			b.Allow(req.ConversationID, req.Tool)
		}
		return resp, nil
	case <-ctx.Done():
		return Response{}, ctx.Err()
	}
}

// Resolve delivers a human decision to a blocked Request, returning false if no interaction with
// that id is pending (already resolved / unknown — a double POST is a safe no-op).
//
// Resolve 把人的决定送给阻塞的 Request，无该 id 待决则返 false（已决议 / 未知——重复 POST 安全 no-op）。
func (b *Broker) Resolve(toolCallID string, resp Response) bool {
	b.mu.Lock()
	w := b.pending[toolCallID]
	b.mu.Unlock()
	if w == nil {
		return false
	}
	select {
	case w.ch <- resp:
		return true
	default:
		return false // already resolved
	}
}

// IsAllowed reports whether the tool was session-whitelisted (always-allow) in this conversation.
//
// IsAllowed 报告该工具在本对话是否会话白名单（always-allow）。
func (b *Broker) IsAllowed(conversationID, tool string) bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.allowed[conversationID+"\x00"+tool]
}

// Allow session-whitelists a tool for a conversation.
//
// Allow 为一个对话会话白名单一个工具。
func (b *Broker) Allow(conversationID, tool string) {
	if tool == "" {
		return
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	b.allowed[conversationID+"\x00"+tool] = true
}

// Pending lists the interactions currently awaiting a human in a conversation — the front end's
// reconnect/refresh re-sync (the broker's in-memory map is the source of truth).
//
// Pending 列出一个对话当前待人决议的交互——前端重连/刷新的重新同步（broker 内存表是真相源）。
func (b *Broker) Pending(conversationID string) []Request {
	b.mu.Lock()
	defer b.mu.Unlock()
	out := make([]Request, 0)
	for _, w := range b.pending {
		if w.req.ConversationID == conversationID {
			out = append(out, w.req)
		}
	}
	return out
}

type brokerKey struct{}

// WithBroker seeds the broker into ctx so the loop's danger gate + the ask_user tool can reach it
// without a dependency. No broker in ctx → no gating (pure trust) and ask_user reports no user.
//
// WithBroker 把 broker 种进 ctx，使 loop 的 danger 门 + ask_user 工具无依赖即可取到。ctx 无 broker → 不门控
// （纯信任）、ask_user 报告无用户。
func WithBroker(ctx context.Context, b *Broker) context.Context {
	if b == nil {
		return ctx
	}
	return context.WithValue(ctx, brokerKey{}, b)
}

// From returns the broker seeded by WithBroker, or nil.
//
// From 返回 WithBroker 种入的 broker，或 nil。
func From(ctx context.Context) *Broker {
	b, _ := ctx.Value(brokerKey{}).(*Broker)
	return b
}
