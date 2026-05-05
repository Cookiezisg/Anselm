package events

import "context"

// Bridge is the event dispatcher contract; implementations are safe for
// concurrent Publish + Subscribe.
//
// Bridge 是事件分发契约；实现支持 Publish + Subscribe 并发调用。
type Bridge interface {
	// Publish sends e to subscribers with filterKey == key. Best-effort:
	// slow subscribers drop events, never block the publisher.
	//
	// Publish 把 e 发给 filterKey == key 的订阅者。尽力投递：
	// 慢订阅者丢事件，绝不阻塞 publisher。
	Publish(ctx context.Context, key string, e Event)

	// Subscribe returns a receive channel + cancel. The channel is never
	// closed — callers stop by ctx.Done() or cancel.
	//
	// Subscribe 返接收 channel + cancel。channel 永不关闭——
	// 调用方靠 ctx.Done() 或 cancel 停止。
	Subscribe(ctx context.Context, key string) (<-chan Event, func())
}
