package eventlog

import "context"

// Bridge dispatches events to per-conversation subscribers and assigns
// each event a conversation-monotonic sequence number. Implementations
// MUST be safe for concurrent Publish + Subscribe.
//
// Bridge 把事件分发给 per-conversation 订阅者，并给每个事件分配
// per-conversation 单调 sequence。实现必须支持并发 Publish + Subscribe。
type Bridge interface {
	// Publish assigns a seq, validates payload, and dispatches to
	// subscribers of conversationID. Returns the assigned envelope.
	//
	// Semantic for slow subscribers: BLOCK the publisher (delta events
	// must not be lost — append-only semantic relies on no gaps). This
	// reverses the entity-snapshot bridge's drop-on-slow default. Each
	// subscriber buffer is small (~256) so blocking happens promptly.
	//
	// Returns ErrInvalidEvent for malformed payloads (caller bug, not
	// recoverable). Returns ctx.Err() if ctx cancelled.
	//
	// Publish 分配 seq、校验 payload、分发给 conversationID 的订阅者。
	// 返回分配好的 Envelope。
	//
	// 慢订阅者语义：阻塞 publisher（delta 不允许丢——append-only 依赖
	// 无 gap）。这反转了 entity-snapshot bridge 的 drop-on-slow 默认。
	// 每个订阅者 buffer 小（~256）让阻塞快速发生。
	//
	// payload 形状错误返 ErrInvalidEvent（caller bug，不可恢复）。
	// ctx 取消返 ctx.Err()。
	Publish(ctx context.Context, conversationID string, e Event) (Envelope, error)

	// Subscribe registers a subscriber for conversationID. fromSeq>0
	// triggers replay of buffered envelopes with seq > fromSeq before
	// live delivery. fromSeq=0 starts at live (no replay). Returns
	// ErrSeqTooOld if fromSeq is older than the buffer's oldest entry.
	//
	// The returned channel is never closed by the bridge; callers stop
	// by ctx.Done() or invoking cancel. cancel is idempotent.
	//
	// Subscribe 注册 conversationID 的订阅者。fromSeq>0 先 replay 缓存
	// 中 seq > fromSeq 的 envelope，再投递实时事件。fromSeq=0 直接从实
	// 时开始（无 replay）。fromSeq 比 buffer 最旧 entry 还旧返
	// ErrSeqTooOld。
	//
	// 返回的 channel 不会被 bridge 关闭；调用方靠 ctx.Done() 或
	// cancel 停止。cancel 幂等。
	Subscribe(ctx context.Context, conversationID string, fromSeq int64) (<-chan Envelope, func(), error)
}
