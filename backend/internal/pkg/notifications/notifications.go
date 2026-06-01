// Package notifications provides the producer-side Publisher helper around notifications.Bridge.
//
// Package notifications 提供 notifications.Bridge 的 producer 侧 Publisher helper。
package notifications

import (
	"context"

	"go.uber.org/zap"

	notificationsdomain "github.com/sunweilin/forgify/backend/internal/domain/notifications"
)

// Publisher is the high-level publish API; failures are best-effort log-only.
//
// Publisher 是高层 publish API；失败仅 log，不阻断业务。
type Publisher interface {
	Publish(ctx context.Context, eventType, id string, data any, conversationID string)

	// PublishEphemeral emits a live-only, lossy, no-backpressure signal (flowrun runtime tick) — no
	// seq, no replay buffer; a full subscriber drops it. Best-effort: failures are log-only.
	//
	// PublishEphemeral 发实时可丢无背压信号（flowrun tick）；无 seq、不入 buffer、满则丢；失败仅 log。
	PublishEphemeral(ctx context.Context, eventType, id string, data any)
}

// New constructs a Publisher backed by bridge; bridge nil returns a no-op.
//
// New 构造由 bridge 支撑的 Publisher；bridge 为 nil 返 no-op。
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

// PublishEphemeral delivers a runtime tick live-only (no seq/buffer/backpressure); failures log-only.
func (p *publisher) PublishEphemeral(ctx context.Context, eventType, id string, data any) {
	if err := p.bridge.PublishEphemeral(ctx, notificationsdomain.Event{
		Type: eventType,
		ID:   id,
		Data: data,
	}); err != nil {
		p.log.Warn("ephemeral notification publish failed",
			zap.String("type", eventType),
			zap.String("id", id),
			zap.Error(err))
	}
}

type noopPublisher struct{}

func (noopPublisher) Publish(context.Context, string, string, any, string) {}

func (noopPublisher) PublishEphemeral(context.Context, string, string, any) {}
