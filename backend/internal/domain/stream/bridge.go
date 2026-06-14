package stream

import (
	"context"

	errorspkg "github.com/sunweilin/forgify/backend/internal/pkg/errors"
)

// Bridge is the per-workspace dispatch port for one stream: assign seq, buffer
// durable frames for replay, fan out to subscribers. Implemented in infra/stream
// by a single Bus type instantiated three times (messages / entities /
// notifications); producers depend on this one interface, never the concrete Bus.
//
// Bridge 是单条流的 per-workspace 分发端口：分配 seq、把 durable 帧入 buffer 供
// replay、扇出订阅者。实现在 infra/stream 的单一 Bus 类型、实例化三次（messages /
// entities / notifications）；producer 只依赖此接口、不碰具体 Bus。
type Bridge interface {
	// Publish validates e, stamps a seq (0 for ephemeral), buffers durable frames, fans out.
	//
	// Publish 校验 e、盖 seq（ephemeral 为 0）、durable 帧入 buffer、扇出。
	Publish(ctx context.Context, e Event) (Envelope, error)

	// Subscribe registers a subscriber; fromSeq>0 replays buffered durable frames first.
	// The channel is not closed by the bridge; cancel is idempotent. Too old → ErrSeqTooOld.
	//
	// Subscribe 注册订阅者；fromSeq>0 先 replay 缓存的 durable 帧。channel 不由 bridge
	// 关，cancel 幂等。过旧 → ErrSeqTooOld。
	Subscribe(ctx context.Context, fromSeq int64) (<-chan Envelope, func(), error)
}

// ErrSeqTooOld is returned when fromSeq has been evicted from the replay buffer; the
// client must refetch full state (messages: DB history; entities: resubscribe;
// notifications: pull history from notification.List, which is DB-backed). It is a
// structured domain error (KindGone → HTTP 410) so transport maps it via statusForKind
// with no special case — this error reaches the wire.
//
// ErrSeqTooOld 在 fromSeq 已被 replay buffer 淘汰时返回；客户端须全量重取（messages 走
// DB 历史；entities 重订阅；notifications 从 DB 支撑的 notification.List 拉历史）。它是
// 结构化 domain 错误（KindGone → HTTP 410），transport 经 statusForKind 映射、零特例。
var ErrSeqTooOld = errorspkg.New(errorspkg.KindGone, "SEQ_TOO_OLD",
	"requested seq too old (evicted from replay buffer)")
