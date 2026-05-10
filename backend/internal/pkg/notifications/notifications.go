// Package notifications provides the producer-side helper around
// notifications.Bridge: a Publisher that wraps the bridge with logger
// injection and a noop fallback for tests / unwired services.
//
// Service code holds the Publisher as a struct field (constructor-
// injected); there is no ctx-wiring counterpart to pkg/eventlog's
// Emitter ctx pattern because no producer needs it.
//
// Package notifications 提供 notifications.Bridge 的 producer 侧 helper：
// 包 bridge + logger 注入 + 测试/未接线 service 的 noop 回退。
//
// service 代码把 Publisher 当 struct 字段持（构造器注入）；不像
// pkg/eventlog 提供 ctx-wiring——没有 producer 需要。
package notifications

import (
	"context"

	"go.uber.org/zap"

	notificationsdomain "github.com/sunweilin/forgify/backend/internal/domain/notifications"
)

// Publisher is the high-level publish API for service code.
//
// Publisher 是 service 代码的高层 publish API。
type Publisher interface {
	// Publish fires a notification. conversationID is required — pass
	// "" for entity types that are not conversation-scoped (e.g.
	// "mcp_server" / "system_warning"). Best-effort: failures log but do
	// not surface as errors (notifications are observability, not
	// business).
	//
	// Publish 发一条通知。conversationID 必填——不绑对话的实体传 ""
	// （如 "mcp_server" / "system_warning"）。Best-effort：失败 log 不上
	// 抛（通知是可观测性，不是业务）。
	Publish(ctx context.Context, eventType, id string, data any, conversationID string)
}

// New constructs a Publisher backed by bridge. log may be nil (zap.Nop).
// bridge nil → returns a noop Publisher (so service constructors can
// safely default-fall-back to it without dereferencing).
//
// New 构造由 bridge 支撑的 Publisher。log 可 nil。bridge 为 nil 时返
// noop Publisher（service 构造器可安全 fallback 不会解 nil 引用）。
func New(bridge notificationsdomain.Bridge, log *zap.Logger) Publisher {
	if bridge == nil {
		return noopPublisher{}
	}
	if log == nil {
		log = zap.NewNop()
	}
	return &publisher{bridge: bridge, log: log.Named("notifications.publisher")}
}

type publisher struct {
	bridge notificationsdomain.Bridge
	log    *zap.Logger
}

func (p *publisher) Publish(ctx context.Context, eventType, id string, data any, conversationID string) {
	if _, err := p.bridge.Publish(ctx, notificationsdomain.Event{
		Type:           eventType,
		ID:             id,
		Data:           data,
		ConversationID: conversationID,
	}); err != nil {
		p.log.Warn("notification publish failed",
			zap.String("type", eventType),
			zap.String("id", id),
			zap.Error(err))
	}
}

// ── no-op fallback ───────────────────────────────────────────────────

type noopPublisher struct{}

func (noopPublisher) Publish(context.Context, string, string, any, string) {}
