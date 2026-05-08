// Package notifications provides the producer-side helper around
// notifications.Bridge: a Publisher with ctx-injected wiring so
// service code can fire `Publish("conversation", id, snapshot)`
// without dragging the bridge through every call site.
//
// Mirrors pkg/eventlog pattern (Emitter + With/From/MustFrom).
//
// Package notifications 提供 notifications.Bridge 的 producer 侧 helper：
// ctx-injected Publisher，service 代码可直接 `Publish("conversation", id,
// snapshot)` 不必把 bridge 传穿每个 call site。
//
// 镜像 pkg/eventlog pattern (Emitter + With/From/MustFrom)。
package notifications

import (
	"context"
	"fmt"

	"go.uber.org/zap"

	notificationsdomain "github.com/sunweilin/forgify/backend/internal/domain/notifications"
)

// Publisher is the high-level publish API for service code.
//
// Publisher 是 service 代码的高层 publish API。
type Publisher interface {
	// Publish fires a notification. conversationID is optional — pass
	// "" for entity types that are not conversation-scoped (e.g. future
	// "mcp_server" / "system_warning"). Best-effort: failures log but do
	// not surface as errors (notifications are observability, not
	// business).
	//
	// Publish 发一条通知。conversationID 可选——不绑对话的实体传 ""
	// （如未来 "mcp_server" / "system_warning"）。Best-effort：失败 log
	// 不上抛（通知是可观测性，不是业务）。
	Publish(ctx context.Context, eventType, id string, data any, conversationID ...string)
}

// New constructs a Publisher backed by bridge. log may be nil (zap.Nop).
//
// New 构造由 bridge 支撑的 Publisher。log 可 nil。
func New(bridge notificationsdomain.Bridge, log *zap.Logger) Publisher {
	if log == nil {
		log = zap.NewNop()
	}
	return &publisher{bridge: bridge, log: log.Named("notifications.publisher")}
}

type publisher struct {
	bridge notificationsdomain.Bridge
	log    *zap.Logger
}

func (p *publisher) Publish(ctx context.Context, eventType, id string, data any, conversationID ...string) {
	convID := ""
	if len(conversationID) > 0 {
		convID = conversationID[0]
	}
	if _, err := p.bridge.Publish(ctx, notificationsdomain.Event{
		Type:           eventType,
		ID:             id,
		Data:           data,
		ConversationID: convID,
	}); err != nil {
		p.log.Warn("notification publish failed",
			zap.String("type", eventType),
			zap.String("id", id),
			zap.Error(err))
	}
}

// ── ctx wiring ───────────────────────────────────────────────────────

type publisherKey struct{}

// With returns a copy of ctx carrying p. From recovers it.
//
// With 返 ctx 拷贝携带 p。From 取回。
func With(ctx context.Context, p Publisher) context.Context {
	return context.WithValue(ctx, publisherKey{}, p)
}

// From returns the Publisher stored in ctx, or a no-op Publisher if
// absent. No nil-checks needed at call sites.
//
// From 返 ctx 中的 Publisher，缺失返 no-op。call site 无须 nil 检查。
func From(ctx context.Context) Publisher {
	p, ok := ctx.Value(publisherKey{}).(Publisher)
	if !ok || p == nil {
		return noopPublisher{}
	}
	return p
}

// MustFrom returns the Publisher or panics. For positions where
// missing publisher is unambiguously a wiring bug.
//
// MustFrom 返 Publisher 或 panic。"缺即接线 bug"的位置用。
func MustFrom(ctx context.Context) Publisher {
	p, ok := ctx.Value(publisherKey{}).(Publisher)
	if !ok || p == nil {
		panic(fmt.Sprintf("notifications.MustFrom: no publisher in ctx"))
	}
	return p
}

// ── no-op fallback ───────────────────────────────────────────────────

type noopPublisher struct{}

func (noopPublisher) Publish(context.Context, string, string, any, ...string) {}
