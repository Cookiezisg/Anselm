// Package notification (app layer) implements notificationdomain.Emitter and the
// notification-center reads. The notifications SSE stream carries two tiers of durable
// signal: Emit persists an inbox ROW and pushes the signal (the row is truth, recovered
// via List; failures/entity-lifecycle the user should find later), while Broadcast pushes
// the signal ONLY — no row — for high-frequency reconciliation echoes (rail re-sort, tree
// refresh) whose truth is the entity's own state, not a notification row. Both pushes are
// best-effort. Workspace isolation is handled by the orm layer, so this layer passes no
// workspace id.
//
// Package notification（app 层）实现 notificationdomain.Emitter 与通知中心读。notifications SSE
// 流承载两档 durable signal：Emit 落**收件箱行** + 推信号（行是真相、List 兜回；用户该事后找到的
// 失败/实体生命周期），Broadcast **只推**信号、不落行——供高频对账回声（rail 重排、树刷新），其真相
// 是实体自身状态、非通知行。两种推送皆 best-effort。workspace 隔离由 orm 层处理，本层不传 workspace id。
package notification

import (
	"context"
	"encoding/json"
	"fmt"

	"go.uber.org/zap"

	notificationdomain "github.com/sunweilin/anselm/backend/internal/domain/notification"
	streamdomain "github.com/sunweilin/anselm/backend/internal/domain/stream"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
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

// Emit persists a notification (inbox row) then pushes it on the SSE stream (best-effort).
//
// Emit 持久化一条通知（收件箱行），然后推 SSE 流（best-effort）。
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
	s.push(ctx, n.ID, n.Type, n.Payload, true)
	return nil
}

// Broadcast pushes a durable live signal WITHOUT persisting a row — the frame-only tier
// for reconciliation echoes (see the Emitter port doc). A transient id anchors the wire
// frame (never referenced again — there is no row to mark-read); the frame is shaped
// exactly like Emit's, minus the persisted row. No push is the only failure mode, and it
// is swallowed (best-effort, same as Emit's push).
//
// Broadcast 推一条 durable live signal、**不落行**——对账回声的仅帧档（见 Emitter 端口文档）。
// 临时 id 锚定线缆帧（不再被引用——无行可 mark-read）；帧形与 Emit 的差异仅 `inbox` 标（见 push）。
// 唯一失败是推送失败、已吞（best-effort，同 Emit 的 push）。
func (s *Service) Broadcast(ctx context.Context, eventType string, payload map[string]any) error {
	if eventType == "" {
		return notificationdomain.ErrInvalidType
	}
	s.push(ctx, idgenpkg.New("noti"), eventType, payload, false)
	return nil
}

// push fans a lifecycle event onto the notifications SSE stream as a durable signal;
// failure is logged, not propagated (the caller already did — or deliberately skipped —
// the durable write). id anchors the wire frame (a row id for Emit, a transient id for
// Broadcast); the frontend self-filters by node.type, not by scope.id.
//
// push 把生命周期事件作为 durable signal 推到 notifications SSE 流；失败只 log 不传播（调用方
// 已做—或刻意跳过—耐久写）。id 锚定线缆帧（Emit 用行 id、Broadcast 用临时 id）；前端按 node.type
// 自滤、不按 scope.id。
func (s *Service) push(ctx context.Context, id, eventType string, payload map[string]any, inbox bool) {
	if s.bridge == nil {
		return
	}
	// The inbox marker (WRK-062 S-8): Emit frames (persisted, user-relevant) carry `inbox:true` so
	// the client's "all" notification level has an honest denominator — Broadcast reconciliation
	// echoes are shaped identically otherwise and must never become toast candidates. The payload is
	// COPIED (callers may reuse their map).
	// inbox 标(S-8):Emit 帧(落行、用户相关)带 inbox:true,客户端「全部」档才有诚实分母——Broadcast
	// 对账回声帧形其余全同、绝不能进 toast 候选。payload 复制后再加(调用方可能复用其 map)。
	if inbox {
		p := make(map[string]any, len(payload)+1)
		for k, v := range payload {
			p[k] = v
		}
		p["inbox"] = true
		payload = p
	}
	var content json.RawMessage
	if len(payload) > 0 {
		if b, err := json.Marshal(payload); err != nil {
			s.log.Warn("notification payload marshal failed", zap.String("id", id), zap.Error(err))
		} else {
			content = b
		}
	}
	_, err := s.bridge.Publish(ctx, streamdomain.Event{
		Scope: streamdomain.Scope{Kind: streamdomain.KindNotification, ID: id},
		ID:    id,
		Frame: streamdomain.Signal{Node: streamdomain.Node{Type: eventType, Content: content}},
	})
	if err != nil {
		s.log.Warn("notification SSE push failed", zap.String("id", id), zap.Error(err))
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
