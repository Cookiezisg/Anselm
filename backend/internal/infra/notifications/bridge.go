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
	"sync"
	"time"

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
	log *zap.Logger

	mu     sync.Mutex
	seq    int64
	buffer []bufferedEnvelope
	subs   []*subscription
}

type bufferedEnvelope struct {
	env notificationsdomain.Envelope
	at  time.Time
}

type subscription struct {
	ch     chan notificationsdomain.Envelope
	done   chan struct{}
	closed sync.Once
}

// NewBridge constructs an empty Bridge.
//
// NewBridge 构造空 Bridge。
func NewBridge(log *zap.Logger) *Bridge {
	if log == nil {
		log = zap.NewNop()
	}
	return &Bridge{log: log.Named("notifications.bridge")}
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

	b.buffer = append(b.buffer, bufferedEnvelope{env: env, at: time.Now()})
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
		if len(b.buffer) > 0 && b.buffer[0].env.Seq > fromSeq+1 {
			b.mu.Unlock()
			return nil, nil, notificationsdomain.ErrSeqTooOld
		}
		for _, be := range b.buffer {
			if be.env.Seq > fromSeq {
				select {
				case sub.ch <- be.env:
				default:
					b.mu.Unlock()
					return nil, nil, notificationsdomain.ErrSeqTooOld
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
