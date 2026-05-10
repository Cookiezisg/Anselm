// Package eventlog provides the in-process Bridge implementation for
// the recursive event-log protocol. Per-conversation monotonic seq,
// replay buffer for Last-Event-ID reconnect, block-on-slow-subscriber
// semantic (delta events are append-only — losing them corrupts the
// wire stream).
//
// Single backing implementation: there is no redis / disk variant on
// the roadmap for this single-user local desktop app, so we don't
// pre-split into infra/eventlog/<backend>/ subpackages (per §S12).
//
// Package eventlog 提供递归事件日志协议的进程内 Bridge 实现。
// per-conversation 单调 seq、Last-Event-ID 重连用 replay buffer、
// 慢订阅者阻塞 publisher 语义（delta 事件 append-only——丢了 wire 流就坏了）。
//
// 单一实现：单用户本地桌面 app 路线图里没有 redis / disk 变体，故不预拆
// infra/eventlog/<backend>/ 子包（§S12）。
package eventlog

import (
	"context"
	"fmt"
	"sync"

	"go.uber.org/zap"

	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
)

// Tunables. Sized for single-user desktop load:
//   - ~10 active conversations × replayBufferSize events ≈ a few MB
//   - subscriberBufferSize fits replayBufferSize + headroom so Subscribe
//     can push the full replay non-blocking before live events flow.
//
// 调参。按单用户桌面负载估：
//   - ~10 活跃 conversation × replayBufferSize ≈ 几 MB
//   - subscriberBufferSize 容得下 replayBufferSize + 余量，让 Subscribe
//     能非阻塞 push 完整 replay 后再接实时事件。
const (
	replayBufferSize     = 4096
	subscriberBufferSize = 4352 // = replayBufferSize + 256 live headroom
)

// Bridge is a thread-safe, in-process eventlog dispatcher.
//
// Bridge 是线程安全的进程内 eventlog 分发器。
type Bridge struct {
	mu    sync.Mutex
	convs map[string]*convState
}

// convState holds per-conversation seq counter + replay buffer + subs.
// All fields guarded by mu.
//
// convState 持有 per-conversation 的 seq 计数器 + replay buffer + sub。
// 所有字段由 mu 守护。
type convState struct {
	mu     sync.Mutex
	seq    int64
	buffer []eventlogdomain.Envelope
	subs   []*subscription
}

type subscription struct {
	ch     chan eventlogdomain.Envelope
	done   chan struct{}
	closed sync.Once
}

// NewBridge constructs an empty Bridge. The log parameter is accepted
// for API symmetry with notifications.NewBridge / future variants but
// is currently unused — the bridge follows §S10's "synchronous primitive"
// rule (don't self-log; let callers decide). We keep the parameter so a
// future addition (e.g. slow-subscriber warnings) won't break callers.
//
// NewBridge 构造空 Bridge。log 参数为 API 对称（与 notifications.NewBridge
// / 未来变体一致）保留，目前未用——bridge 按 §S10 "同步原语"原则不自打日志。
// 未来若加慢订阅者警告等可直接用，不破坏 caller。
func NewBridge(_ *zap.Logger) *Bridge {
	return &Bridge{
		convs: make(map[string]*convState),
	}
}

// ensureConv returns the convState for id, creating it on first touch.
//
// ensureConv 返 id 的 convState；首次访问时创建。
func (b *Bridge) ensureConv(id string) *convState {
	b.mu.Lock()
	defer b.mu.Unlock()
	state, ok := b.convs[id]
	if !ok {
		state = &convState{}
		b.convs[id] = state
	}
	return state
}

// Publish validates, assigns seq, appends to replay buffer, and fans
// out to subscribers. Blocks if any subscriber buffer is full
// (intentional — delta events must not be lost). Returns ctx.Err if
// ctx cancelled mid-fanout (the event is still recorded in the
// replay buffer so future subscribers can pick it up).
//
// Publish 校验、分配 seq、追加 replay buffer、扇出给订阅者。订阅者
// buffer 满时阻塞（故意——delta 不能丢）。扇出途中 ctx 取消返
// ctx.Err（事件已进 replay buffer，未来订阅者仍能取）。
func (b *Bridge) Publish(ctx context.Context, conversationID string, e eventlogdomain.Event) (eventlogdomain.Envelope, error) {
	if conversationID == "" {
		return eventlogdomain.Envelope{}, fmt.Errorf("%w: empty conversationID", eventlogdomain.ErrInvalidEvent)
	}
	if err := eventlogdomain.ValidateEvent(e); err != nil {
		return eventlogdomain.Envelope{}, err
	}

	state := b.ensureConv(conversationID)
	state.mu.Lock()
	defer state.mu.Unlock()

	state.seq++
	env := eventlogdomain.Envelope{Seq: state.seq, Event: e}

	// Append to replay buffer; trim oldest when full.
	// 追加到 replay buffer；满时丢最旧。
	state.buffer = append(state.buffer, env)
	if len(state.buffer) > replayBufferSize {
		state.buffer = state.buffer[len(state.buffer)-replayBufferSize:]
	}

	// Fan out under state.mu so seq order matches send order.
	// 在 state.mu 下扇出，保证 seq 顺序与 send 顺序一致。
	for _, s := range state.subs {
		select {
		case s.ch <- env:
			// delivered / 已投递
		case <-s.done:
			// subscriber cancelled — skip without blocking
			// 订阅者已取消——跳过不阻塞
		case <-ctx.Done():
			return env, ctx.Err()
		}
	}
	return env, nil
}

// Subscribe registers a subscriber for conversationID. fromSeq>0 replays
// buffered envelopes with seq > fromSeq before live delivery; returns
// ErrSeqTooOld if fromSeq is older than the buffer's oldest entry.
//
// Subscribe 给 conversationID 注册订阅者。fromSeq>0 先 replay seq >
// fromSeq 的 buffer 项再投递实时事件；fromSeq 比 buffer 最旧还旧返
// ErrSeqTooOld。
func (b *Bridge) Subscribe(ctx context.Context, conversationID string, fromSeq int64) (<-chan eventlogdomain.Envelope, func(), error) {
	if conversationID == "" {
		return nil, nil, fmt.Errorf("%w: empty conversationID", eventlogdomain.ErrInvalidEvent)
	}

	state := b.ensureConv(conversationID)
	sub := &subscription{
		ch:   make(chan eventlogdomain.Envelope, subscriberBufferSize),
		done: make(chan struct{}),
	}

	state.mu.Lock()
	// Replay logic: only when caller wants resume (fromSeq>0).
	// fromSeq=0 means "live only, no history". fromSeq>=current means
	// "I already have everything", no replay needed.
	//
	// Replay 逻辑：仅当调用方要 resume（fromSeq>0）。
	// fromSeq=0 = "只要实时不要历史"。fromSeq>=current = "我都有了"，无 replay。
	if fromSeq > 0 && fromSeq < state.seq {
		// Check if fromSeq has been evicted: oldest buffer entry > fromSeq+1
		// means events fromSeq+1..oldest-1 are gone.
		//
		// 检查 fromSeq 是否被淘汰：最旧 buffer 项 > fromSeq+1 表示
		// fromSeq+1..oldest-1 段已丢。
		if len(state.buffer) > 0 && state.buffer[0].Seq > fromSeq+1 {
			state.mu.Unlock()
			return nil, nil, eventlogdomain.ErrSeqTooOld
		}
		for _, env := range state.buffer {
			if env.Seq > fromSeq {
				// Non-blocking push — channel cap >= replayBufferSize
				// guarantees this fits.
				// 非阻塞 push——channel cap >= replayBufferSize 保证装得下。
				select {
				case sub.ch <- env:
				default:
					// Defensive: should be unreachable given cap.
					// 防御：cap 保证不该到这里。
					state.mu.Unlock()
					return nil, nil, fmt.Errorf("eventlog: replay overflow (cap=%d)", subscriberBufferSize)
				}
			}
		}
	}

	state.subs = append(state.subs, sub)
	state.mu.Unlock()

	cancel := func() {
		sub.closed.Do(func() {
			close(sub.done)
		})
		// Remove from state.subs (separate from close(done) so Publish
		// can unblock via <-s.done before we wait for state.mu).
		//
		// 从 state.subs 移除（与 close(done) 分开，让 Publish 通过
		// <-s.done 解阻塞，再等 state.mu）。
		state.mu.Lock()
		for i, s := range state.subs {
			if s == sub {
				state.subs = append(state.subs[:i], state.subs[i+1:]...)
				break
			}
		}
		state.mu.Unlock()
	}

	go func() {
		select {
		case <-ctx.Done():
			cancel()
		case <-sub.done:
		}
	}()

	return sub.ch, cancel, nil
}

// Compile-time check that *Bridge satisfies eventlogdomain.Bridge.
//
// 编译期确认 *Bridge 满足 eventlogdomain.Bridge。
var _ eventlogdomain.Bridge = (*Bridge)(nil)
