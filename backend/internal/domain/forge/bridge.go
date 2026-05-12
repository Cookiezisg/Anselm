package forge

import "context"

// Bridge dispatches forge events to per-user subscribers (D-redo-2/3 pattern
// shared with eventlog + notifications). user_id is read from ctx via
// reqctxpkg.RequireUserID; the bridge does not appear in any caller signature
// so producer / consumer stay decoupled from auth.
//
// Bridge 把 forge 事件分发给 per-user 订阅者(跟 eventlog/notifications 共享
// 模式)。user_id 经 reqctxpkg.RequireUserID 从 ctx 读。
type Bridge interface {
	// Publish reads user_id from ctx, validates payload, assigns seq,
	// dispatches to that user's subscribers. Block-on-slow semantic
	// (forge events drive UI state machines — losing them desyncs UI).
	// Returns ErrInvalidEvent or reqctx user-id error.
	//
	// Publish 从 ctx 读 user_id;校验 + 分配 seq + 扇出该用户订阅者。
	// 慢订阅者阻塞(forge 事件驱动 UI 状态机)。返 ErrInvalidEvent 或
	// reqctx user-id 错。
	Publish(ctx context.Context, e Event) (Envelope, error)

	// Subscribe reads user_id from ctx and registers a subscriber.
	// fromSeq>0 replays buffered envelopes with seq > fromSeq before
	// live; ErrSeqTooOld if too old.
	//
	// Subscribe 从 ctx 读 user_id 注册订阅者。fromSeq>0 先 replay seq >
	// fromSeq 再投递实时;过旧返 ErrSeqTooOld。
	Subscribe(ctx context.Context, fromSeq int64) (<-chan Envelope, func(), error)
}
