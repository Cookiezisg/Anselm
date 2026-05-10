// Package notifications provides the in-process Bridge for global
// notification events. Single-channel broadcast (all subscribers see
// every event); per-key seq monotonic; replay buffer + Last-Event-ID
// reconnect; block-on-slow-subscriber semantic (entity snapshots
// matter — losing them leaves UI showing stale state).
//
// Mirrors infra/eventlog/bridge.go pattern; only differences are
// single channel (no per-conv keying) and event payload type.
//
// Package notifications 提供全局通知事件的进程内 Bridge。单 channel
// 广播（所有订阅者收每个事件）；全局单调 seq；replay buffer +
// Last-Event-ID 重连；慢订阅者阻塞 publisher（entity 快照重要——丢
// 了 UI 看到陈旧状态）。
//
// 镜像 infra/eventlog/bridge.go pattern；区别仅在单 channel（无 per-conv
// keying）+ event payload 类型。
package notifications

import (
	"context"
	"fmt"
	"sync"

	"go.uber.org/zap"

	notificationsdomain "github.com/sunweilin/forgify/backend/internal/domain/notifications"
)

// Tunables. Sized for single-user desktop:
//   - replayBufferSize: keeps last N events for reconnect. 1024 is
//     generous; sane home-use rarely produces > a few hundred
//     state changes per minute.
//   - subscriberBufferSize: buffer per subscribe channel. Wide enough
//     to hold a full replay burst plus live headroom.
//
// 调参，按单用户桌面：1024 足量重连缓存；subscriber 缓冲容下完整 replay
// 突发 + 实时余量。
const (
	replayBufferSize     = 1024
	subscriberBufferSize = 1280 // = replayBufferSize + 256 live headroom
)

// Bridge is the thread-safe in-process notification dispatcher.
//
// Bridge 是线程安全的进程内通知分发器。
type Bridge struct {
	mu     sync.Mutex
	seq    int64
	buffer []notificationsdomain.Envelope
	subs   []*subscription
}

type subscription struct {
	ch     chan notificationsdomain.Envelope
	done   chan struct{}
	closed sync.Once
}

// NewBridge constructs an empty Bridge. The log parameter is accepted
// for API symmetry with eventlog.NewBridge but is currently unused —
// the bridge follows §S10's "synchronous primitive" rule (don't
// self-log; let callers decide).
//
// NewBridge 构造空 Bridge。log 参数为 API 对称（与 eventlog.NewBridge 一致）
// 保留，目前未用——bridge 按 §S10 "同步原语"原则不自打日志。
func NewBridge(_ *zap.Logger) *Bridge {
	return &Bridge{}
}

// Publish validates, assigns seq, appends to replay buffer, and fans
// out to all subscribers. Blocks if any subscriber buffer is full
// (intentional — snapshots must not be lost). Returns ctx.Err if ctx
// cancelled mid-fanout (event still recorded in replay buffer so
// future subscribers can pick up).
//
// Publish 校验、分配 seq、追加 replay buffer、扇出给所有订阅者。
// 订阅者 buffer 满时阻塞（故意——快照不能丢）。扇出途中 ctx 取消
// 返 ctx.Err（事件已进 replay buffer）。
func (b *Bridge) Publish(ctx context.Context, e notificationsdomain.Event) (notificationsdomain.Envelope, error) {
	if err := notificationsdomain.ValidateEvent(e); err != nil {
		return notificationsdomain.Envelope{}, err
	}

	b.mu.Lock()
	defer b.mu.Unlock()

	b.seq++
	env := notificationsdomain.Envelope{Seq: b.seq, Event: e}

	b.buffer = append(b.buffer, env)
	if len(b.buffer) > replayBufferSize {
		b.buffer = b.buffer[len(b.buffer)-replayBufferSize:]
	}

	for _, s := range b.subs {
		select {
		case s.ch <- env:
		case <-s.done:
			// subscriber cancelled — skip
		case <-ctx.Done():
			return env, ctx.Err()
		}
	}
	return env, nil
}

// Subscribe registers a subscriber. fromSeq>0 replays buffered
// envelopes with seq > fromSeq before live; ErrSeqTooOld if fromSeq
// is older than the buffer's oldest entry.
//
// Subscribe 注册订阅者。fromSeq>0 先 replay buffer 内 seq > fromSeq
// 再投递实时；fromSeq 比 buffer 最旧还旧返 ErrSeqTooOld。
func (b *Bridge) Subscribe(ctx context.Context, fromSeq int64) (<-chan notificationsdomain.Envelope, func(), error) {
	sub := &subscription{
		ch:   make(chan notificationsdomain.Envelope, subscriberBufferSize),
		done: make(chan struct{}),
	}

	b.mu.Lock()
	if fromSeq > 0 && fromSeq < b.seq {
		if len(b.buffer) > 0 && b.buffer[0].Seq > fromSeq+1 {
			b.mu.Unlock()
			return nil, nil, notificationsdomain.ErrSeqTooOld
		}
		for _, env := range b.buffer {
			if env.Seq > fromSeq {
				// Non-blocking push — channel cap >= replayBufferSize
				// guarantees this fits. Defensive default: if cap math
				// ever drifts, surface as a distinct error (not
				// ErrSeqTooOld which means "evicted from buffer" — wrong
				// semantic for a buffer-overflow situation).
				//
				// 非阻塞 push——channel cap >= replayBufferSize 保证装得下。
				// 防御 default：cap 计算出错时用独立错误（不是 ErrSeqTooOld，
				// 那是"被 buffer 淘汰"——overflow 用错语义）。
				select {
				case sub.ch <- env:
				default:
					b.mu.Unlock()
					return nil, nil, fmt.Errorf("notifications: replay overflow (cap=%d)", subscriberBufferSize)
				}
			}
		}
	}
	b.subs = append(b.subs, sub)
	b.mu.Unlock()

	cancel := func() {
		sub.closed.Do(func() { close(sub.done) })
		b.mu.Lock()
		for i, s := range b.subs {
			if s == sub {
				b.subs = append(b.subs[:i], b.subs[i+1:]...)
				break
			}
		}
		b.mu.Unlock()
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

// Compile-time check.
//
// 编译期检查。
var _ notificationsdomain.Bridge = (*Bridge)(nil)
