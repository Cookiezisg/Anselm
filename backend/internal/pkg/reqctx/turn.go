package reqctx

import "context"

// chatTurnWallClockKey marks the chat-owned deadline so the shared loop can distinguish a
// protective turn timeout from an explicit user cancellation. Other loop hosts keep their
// historical cancellation semantics.
//
// chatTurnWallClockKey 标记 chat 自己拥有的墙钟 deadline，使共享 loop 能区分保护性超时与用户主动取消。
// 其它 loop 宿主保持既有取消语义。
type chatTurnWallClockKey struct{}

// MarkChatTurnWallClock returns a context whose DeadlineExceeded should become a chat timeout
// terminal rather than a user-cancelled terminal.
//
// MarkChatTurnWallClock 返回一个 context：其 DeadlineExceeded 应落成 chat timeout 终态，而非用户取消终态。
func MarkChatTurnWallClock(ctx context.Context) context.Context {
	return context.WithValue(ctx, chatTurnWallClockKey{}, true)
}

// IsChatTurnWallClock reports whether ctx belongs to the chat-owned total turn deadline.
//
// IsChatTurnWallClock 判断 ctx 是否属于 chat 自己的回合总墙钟。
func IsChatTurnWallClock(ctx context.Context) bool {
	v, _ := ctx.Value(chatTurnWallClockKey{}).(bool)
	return v
}
