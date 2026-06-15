// Package notification (app layer) implements notificationdomain.Emitter and the
// notification-center reads. Emit persists a notification (DB) AND pushes a durable
// signal on the notifications SSE stream (scope=notification:<id>, node.type=event
// type) so the frontend updates live; the SSE push is best-effort (the DB row is the
// source of truth — a missed push is recovered by the next List). Workspace isolation
// is handled by the orm layer, so this layer passes no workspace id.
//
// Package notification（app 层）实现 notificationdomain.Emitter 与通知中心读。Emit 持久化
// 通知（DB）**并**在 notifications SSE 流推一条 durable signal（scope=notification:<id>，
// node.type=事件类型）让前端实时更新；SSE 推为 best-effort（DB 行是真相，漏推由下次 List
// 兜回）。workspace 隔离由 orm 层处理，本层不传 workspace id。
package notification

import (
	"context"
	"encoding/json"
	"fmt"

	"go.uber.org/zap"

	notificationdomain "github.com/sunweilin/foryx/backend/internal/domain/notification"
	streamdomain "github.com/sunweilin/foryx/backend/internal/domain/stream"
	idgenpkg "github.com/sunweilin/foryx/backend/internal/pkg/idgen"
)

// Service is the notification emitter + notification-center reader.
//
// Service 是通知发射器 + 通知中心读取器。
type Service struct {
	repo   notificationdomain.Repository
	bridge streamdomain.Bridge // notifications SSE stream; nil → no live push (still persisted)
	log    *zap.Logger
}

// NewService wires dependencies; Repo + Log required, bridge optional (nil → persist
// only, no SSE — wired at boot).
//
// NewService 装配依赖；Repo + Log 必填，bridge 可选（nil → 只持久化、不推 SSE，boot 装配）。
func NewService(repo notificationdomain.Repository, bridge streamdomain.Bridge, log *zap.Logger) *Service {
	if repo == nil {
		panic("notificationapp.NewService: repo is nil")
	}
	if log == nil {
		panic("notificationapp.NewService: log is nil")
	}
	return &Service{repo: repo, bridge: bridge, log: log}
}

var _ notificationdomain.Emitter = (*Service)(nil)

// Emit persists a notification then pushes it on the SSE stream (best-effort).
//
// Emit 持久化一条通知，然后推 SSE 流（best-effort）。
func (s *Service) Emit(ctx context.Context, eventType string, payload map[string]any) error {
	if eventType == "" {
		return notificationdomain.ErrInvalidType
	}
	n := &notificationdomain.Notification{
		ID:      idgenpkg.New("noti"),
		Type:    eventType,
		Payload: payload,
	}
	if err := s.repo.Save(ctx, n); err != nil {
		return fmt.Errorf("notificationapp.Emit: %w", err)
	}
	s.push(ctx, n)
	return nil
}

// push fans the notification onto the notifications SSE stream as a durable signal;
// failure is logged, not propagated (the DB row already persisted it).
//
// push 把通知作为 durable signal 推到 notifications SSE 流；失败只 log 不传播（DB 行已持久化）。
func (s *Service) push(ctx context.Context, n *notificationdomain.Notification) {
	if s.bridge == nil {
		return
	}
	var content json.RawMessage
	if len(n.Payload) > 0 {
		if b, err := json.Marshal(n.Payload); err != nil {
			s.log.Warn("notification payload marshal failed", zap.String("id", n.ID), zap.Error(err))
		} else {
			content = b
		}
	}
	_, err := s.bridge.Publish(ctx, streamdomain.Event{
		Scope: streamdomain.Scope{Kind: streamdomain.KindNotification, ID: n.ID},
		ID:    n.ID,
		Frame: streamdomain.Signal{Node: streamdomain.Node{Type: n.Type, Content: content}},
	})
	if err != nil {
		s.log.Warn("notification SSE push failed", zap.String("id", n.ID), zap.Error(err))
	}
}

// List returns the notification center page (newest-first, keyset cursor).
//
// List 返回通知中心一页（最新优先，keyset 游标）。
func (s *Service) List(ctx context.Context, cursor string, limit int) ([]*notificationdomain.Notification, string, error) {
	return s.repo.List(ctx, cursor, limit)
}

func (s *Service) MarkRead(ctx context.Context, id string) error { return s.repo.MarkRead(ctx, id) }
func (s *Service) MarkAllRead(ctx context.Context) error         { return s.repo.MarkAllRead(ctx) }
func (s *Service) CountUnread(ctx context.Context) (int, error)  { return s.repo.CountUnread(ctx) }
