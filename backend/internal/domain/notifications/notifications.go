// Package notifications defines the global entity-update event bus.
// One generic envelope (Event) covers all entity types — `Type` is the
// discriminator string, `Data` carries the entity snapshot. Routed as
// a single global broadcast (single-user local; per-user routing is a
// future addition when multi-user lands).
//
// Distinct from domain/eventlog: that protocol is per-conversation and
// streams chat content (5 events × 6 block types). This protocol is
// app-global and pushes whole entity snapshots ("conv X renamed to Y",
// "todo Z updated"). Both share the same Bridge implementation pattern
// (per-key seq + replay buffer + Last-Event-ID reconnect).
//
// See documents/version-1.2/event-log-protocol.md for full design.
//
// Package notifications 定义全局 entity-update 事件总线。1 个通用 envelope
// （Event）覆盖所有实体类型——`Type` 是判别字符串，`Data` 携 entity 快照。
// 单全局广播路由（单用户本地；多用户落地时再加 per-user 路由）。
//
// 与 domain/eventlog 区别：那个协议是 per-conversation 流式 chat 内容
// （5 events × 6 block types）。本协议 app-global 推完整 entity 快照
// （"conv X 改名 Y"、"todo Z 更新"）。两者复用同一 Bridge 实现 pattern
// （per-key seq + replay buffer + Last-Event-ID 重连）。
package notifications

import (
	"context"
	"errors"
	"fmt"
)

// Event is a single notification carrying an entity snapshot.
//
// Type discriminates entity kind: "conversation" / "todo" / future
// "mcp_server" / "skill" / "system_warning" etc. Subscribers (frontend
// UI) dispatch on Type to entity-specific renderers.
//
// ConversationID is set only when the entity is conversation-scoped
// (e.g. "todo" has a conversationId; "system_warning" doesn't).
// Frontends watching a specific conversation can filter by it; the
// global sidebar ignores it.
//
// Event 是单条 notification，携 entity 快照。
//
// Type 区分实体种类："conversation" / "todo" / 未来 "mcp_server" /
// "skill" / "system_warning" 等。订阅方（前端 UI）按 Type 分派到
// entity-specific renderer。
//
// ConversationID 仅当 entity 跟某对话相关时填（例：todo 有
// conversationId；system_warning 没有）。绑定到某对话的前端可按它
// 过滤；全局侧栏忽略。
type Event struct {
	Type           string `json:"type"`
	ID             string `json:"id"`
	Data           any    `json:"data"`
	ConversationID string `json:"conversationId,omitempty"`
}

// Envelope wraps an Event with its bridge-assigned sequence number.
//
// Envelope 给 Event 套上 bridge 分配的 seq。
type Envelope struct {
	Seq   int64
	Event Event
}

// Bridge dispatches notifications to subscribers and assigns each event
// a global-monotonic sequence number. Implementations MUST be safe for
// concurrent Publish + Subscribe.
//
// Single-channel: there is no per-key routing — all subscribers receive
// every published event (single-user local; multi-user is future).
// Subscribers filter client-side on Type / ConversationID.
//
// Bridge 把通知分发给订阅者并分配全局单调 seq。实现必须支持并发
// Publish + Subscribe。
//
// 单 channel：无 per-key 路由——所有订阅者收到每个发布事件（单用户
// 本地；多用户未来）。订阅方按 Type / ConversationID 客户端过滤。
type Bridge interface {
	// Publish assigns seq, validates, dispatches. Block-on-slow semantic
	// (entity snapshots can't be lost — UI relies on seeing every state
	// change). Returns ErrInvalidEvent for malformed payloads.
	//
	// Publish 分配 seq、校验、分发。慢订阅者阻塞 publisher（entity
	// 快照不能丢——UI 靠看到每次状态变化）。payload 形状错误返
	// ErrInvalidEvent。
	Publish(ctx context.Context, e Event) (Envelope, error)

	// Subscribe registers a subscriber. fromSeq>0 replays buffered
	// envelopes with seq > fromSeq before live; ErrSeqTooOld if too old.
	//
	// Subscribe 注册订阅者。fromSeq>0 先 replay 缓存中 seq > fromSeq
	// 再投递实时；过旧返 ErrSeqTooOld。
	Subscribe(ctx context.Context, fromSeq int64) (<-chan Envelope, func(), error)
}

// ErrSeqTooOld is returned by Bridge.Subscribe when fromSeq has been
// evicted from the replay buffer. Client should resubscribe with
// fromSeq=0 (live only) and re-fetch any state it cares about via REST.
//
// ErrSeqTooOld 由 Bridge.Subscribe 在 fromSeq 已被 replay buffer 淘汰
// 时返。客户端应重订 fromSeq=0（仅实时）再经 REST 取需要的状态。
var ErrSeqTooOld = errors.New("notifications: requested seq too old (evicted from replay buffer)")

// ErrInvalidEvent is returned for malformed events (empty Type / ID).
// Producer bug — caller should fix.
//
// ErrInvalidEvent 形状错误事件（空 Type / ID）返。Producer bug。
var ErrInvalidEvent = errors.New("notifications: invalid event")

// ValidateEvent runs minimal shape checks. Empty Type / ID fail; Data
// can be nil (rare — e.g. signaling event with no payload). Bridge
// implementations call this in Publish so violations surface at the
// producer boundary.
//
// ValidateEvent 跑最小形状检查。空 Type / ID 失败；Data 可空（罕见
// ——如纯信号事件无 payload）。Bridge 实现在 Publish 中调，让违规在
// producer 边界暴露。
func ValidateEvent(e Event) error {
	if e.Type == "" {
		return fmt.Errorf("%w: empty Type", ErrInvalidEvent)
	}
	if e.ID == "" {
		return fmt.Errorf("%w: empty ID", ErrInvalidEvent)
	}
	return nil
}
