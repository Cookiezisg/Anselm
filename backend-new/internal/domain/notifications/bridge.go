package notifications

import (
	"context"

	streamdomain "github.com/sunweilin/forgify/backend/internal/domain/stream"
)

// Bridge is the notifications-stream port. Beyond the shared stream.Bridge it adds
// List for the REST snapshot pull — notifications has no DB persistence, so List
// reads the in-memory replay buffer (durable frames only).
//
// Bridge 是 notifications 流端口。在共享 stream.Bridge 之外额外提供 List 供 REST 快照
// 拉取——notifications 无 DB 落盘，List 读内存 replay buffer（仅 durable 帧）。
type Bridge interface {
	streamdomain.Bridge

	// List returns up to limit durable envelopes with Seq > fromSeq for the ctx workspace; bool = hasMore.
	//
	// List 返回 ctx workspace 下最多 limit 条 Seq > fromSeq 的 durable Envelope；bool = hasMore。
	List(ctx context.Context, fromSeq int64, limit int) ([]streamdomain.Envelope, bool, error)
}
