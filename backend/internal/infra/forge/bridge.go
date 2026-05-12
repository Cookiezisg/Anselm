// Package forge provides the in-process Bridge implementation for the
// trinity-forging SSE protocol. Per-user keying, replay buffer for
// Last-Event-ID reconnect, block-on-slow-subscriber semantic — same
// pattern as infra/eventlog + infra/notifications post D-redo-2/3.
//
// Sized for single-user desktop load: forge events fire ~once per
// trinity create/edit lifecycle (a handful per active session), so the
// buffer is generously sized at 1024 (≈ 12-hour active dev session).
//
// Package forge 提供 trinity 锻造 SSE 协议的进程内 Bridge。per-user key、
// replay buffer + Last-Event-ID 重连、慢订阅者阻塞 publisher——跟
// infra/eventlog + infra/notifications 同模式(D-redo-2/3 后统一)。
package forge

import (
	"context"
	"fmt"
	"sync"

	"go.uber.org/zap"

	forgedomain "github.com/sunweilin/forgify/backend/internal/domain/forge"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// Tunables. Forge events fire once per create/edit lifecycle (~10 events
// per active session). 1024 covers a multi-hour dev session.
//
// 调参。forge 事件每次 create/edit 触发一组(~10 个);1024 够 multi-hour 会话。
const (
	replayBufferSize     = 1024
	subscriberBufferSize = 1280 // = replayBufferSize + 256 live headroom
)

// Bridge is the thread-safe in-process forge dispatcher.
//
// Bridge 是线程安全的进程内 forge 分发器。
type Bridge struct {
	mu    sync.Mutex
	users map[string]*userState
}

type userState struct {
	mu     sync.Mutex
	seq    int64
	buffer []forgedomain.Envelope
	subs   []*subscription
}

type subscription struct {
	ch     chan forgedomain.Envelope
	done   chan struct{}
	closed sync.Once
}

// NewBridge constructs an empty Bridge. The log parameter is accepted
// for API symmetry with eventlog / notifications NewBridge but is
// currently unused — bridge follows §S10 "synchronous primitive"
// rule (don't self-log; let callers decide).
//
// NewBridge 构造空 Bridge。log 参数为 API 对称保留,目前未用。
func NewBridge(_ *zap.Logger) *Bridge {
	return &Bridge{users: make(map[string]*userState)}
}

func (b *Bridge) ensureUser(id string) *userState {
	b.mu.Lock()
	defer b.mu.Unlock()
	state, ok := b.users[id]
	if !ok {
		state = &userState{}
		b.users[id] = state
	}
	return state
}

// Publish reads user_id from ctx, validates, assigns seq, dispatches.
//
// Publish 从 ctx 读 user_id;校验、分配 seq、扇出。
func (b *Bridge) Publish(ctx context.Context, e forgedomain.Event) (forgedomain.Envelope, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return forgedomain.Envelope{}, fmt.Errorf("forge.Bridge.Publish: %w", err)
	}
	if err := forgedomain.ValidateEvent(e); err != nil {
		return forgedomain.Envelope{}, err
	}

	state := b.ensureUser(uid)
	state.mu.Lock()
	defer state.mu.Unlock()

	state.seq++
	env := forgedomain.Envelope{Seq: state.seq, Event: e}

	state.buffer = append(state.buffer, env)
	if len(state.buffer) > replayBufferSize {
		state.buffer = state.buffer[len(state.buffer)-replayBufferSize:]
	}

	for _, s := range state.subs {
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

// Subscribe reads user_id from ctx and registers a subscriber. fromSeq>0
// replays buffered envelopes with seq > fromSeq before live; ErrSeqTooOld
// if too old.
//
// Subscribe 从 ctx 读 user_id 注册订阅者。fromSeq>0 先 replay 再投实时;
// 过旧返 ErrSeqTooOld。
func (b *Bridge) Subscribe(ctx context.Context, fromSeq int64) (<-chan forgedomain.Envelope, func(), error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, nil, fmt.Errorf("forge.Bridge.Subscribe: %w", err)
	}

	state := b.ensureUser(uid)
	sub := &subscription{
		ch:   make(chan forgedomain.Envelope, subscriberBufferSize),
		done: make(chan struct{}),
	}

	state.mu.Lock()
	if fromSeq > 0 && fromSeq < state.seq {
		if len(state.buffer) > 0 && state.buffer[0].Seq > fromSeq+1 {
			state.mu.Unlock()
			return nil, nil, forgedomain.ErrSeqTooOld
		}
		for _, env := range state.buffer {
			if env.Seq > fromSeq {
				select {
				case sub.ch <- env:
				default:
					state.mu.Unlock()
					return nil, nil, fmt.Errorf("forge: replay overflow (cap=%d)", subscriberBufferSize)
				}
			}
		}
	}
	state.subs = append(state.subs, sub)
	state.mu.Unlock()

	cancel := func() {
		sub.closed.Do(func() { close(sub.done) })
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

// Compile-time check.
//
// 编译期检查。
var _ forgedomain.Bridge = (*Bridge)(nil)
