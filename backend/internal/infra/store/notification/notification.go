// Package notification is the orm-backed implementation of notificationdomain.Repository
// plus the notifications table DDL. Workspace isolation is applied by the orm layer.
//
// Package notification 是 notificationdomain.Repository 的 orm 实现 + notifications 表 DDL。
// workspace 隔离由 orm 层施加。
package notification

import (
	"context"
	"fmt"
	"time"

	notificationdomain "github.com/sunweilin/anselm/backend/internal/domain/notification"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

// Schema is the notifications DDL. No deleted_at — notifications are append-only;
// auto-pruning is a deferred feature. The unread partial index backs the badge count.
//
// Schema 是 notifications 表 DDL。无 deleted_at——通知只增；自动清理是延后特性。未读
// partial 索引支撑 badge 计数。
var Schema = []string{
	`CREATE TABLE IF NOT EXISTS notifications (
		id           TEXT PRIMARY KEY,
		workspace_id TEXT NOT NULL,
		type         TEXT NOT NULL,
		payload      TEXT NOT NULL DEFAULT '{}',
		read_at      DATETIME,
		created_at   DATETIME NOT NULL
	)`,
	`CREATE INDEX IF NOT EXISTS idx_noti_ws_created ON notifications(workspace_id, created_at DESC)`,
	`CREATE INDEX IF NOT EXISTS idx_noti_unread ON notifications(workspace_id) WHERE read_at IS NULL`,
}

// Store implements notificationdomain.Repository over pkg/orm.
//
// Store 基于 pkg/orm 实现 notificationdomain.Repository。
type Store struct {
	repo *ormpkg.Repo[notificationdomain.Notification]
}

// New builds a Store bound to the notifications table.
//
// New 构造绑定 notifications 表的 Store。
func New(db *ormpkg.DB) *Store {
	return &Store{repo: ormpkg.For[notificationdomain.Notification](db, "notifications")}
}

var _ notificationdomain.Repository = (*Store)(nil)

func (s *Store) Save(ctx context.Context, n *notificationdomain.Notification) error {
	if err := s.repo.Save(ctx, n); err != nil {
		return fmt.Errorf("notificationstore.Save: %w", err)
	}
	return nil
}

// List returns newest-first, keyset-paginated notifications for the workspace.
//
// List 返回该 workspace 最新优先、keyset 分页的通知。
func (s *Store) List(ctx context.Context, cursor string, limit int) ([]*notificationdomain.Notification, string, error) {
	rows, next, err := s.repo.Query().Page(ctx, cursor, limit)
	if err != nil {
		return nil, "", fmt.Errorf("notificationstore.List: %w", err)
	}
	return rows, next, nil
}

// MarkRead stamps read_at on one notification; ErrNotFound when no row matched.
//
// MarkRead 给一条通知盖 read_at；无行命中返 ErrNotFound。
func (s *Store) MarkRead(ctx context.Context, id string) error {
	n, err := s.repo.WhereEq("id", id).Update(ctx, "read_at", time.Now().UTC())
	if err != nil {
		return fmt.Errorf("notificationstore.MarkRead: %w", err)
	}
	if n == 0 {
		return notificationdomain.ErrNotFound
	}
	return nil
}

// MarkAllRead stamps read_at on every unread notification within the window (whole ledger when unbounded).
//
// MarkAllRead 给窗口内所有未读通知盖 read_at（不设界=整本账）。
func (s *Store) MarkAllRead(ctx context.Context, window notificationdomain.MarkAllWindow) error {
	if _, err := windowed(s.repo.WhereNull("read_at"), window).Update(ctx, "read_at", time.Now().UTC()); err != nil {
		return fmt.Errorf("notificationstore.MarkAllRead: %w", err)
	}
	return nil
}

// MarkAllUnread clears read_at on every read notification within the window — the exact mirror of
// MarkAllRead (write NULL where non-null, vs write now() where null); a nil arg binds SQL NULL.
//
// MarkAllUnread 给窗口内所有已读通知清 read_at——MarkAllRead 的精确镜像（在非空处写 NULL，
// 对称于在空处写 now()）；nil 参数绑定 SQL NULL。
func (s *Store) MarkAllUnread(ctx context.Context, window notificationdomain.MarkAllWindow) error {
	if _, err := windowed(s.repo.WhereNotNull("read_at"), window).Update(ctx, "read_at", nil); err != nil {
		return fmt.Errorf("notificationstore.MarkAllUnread: %w", err)
	}
	return nil
}

// windowed narrows a query to the half-open [After, Before) window on created_at (a zero bound = unbounded).
// Plain column comparisons on UTC bounds — the flowrun started_at window idiom verbatim: bound and stored
// values go through the same driver serialization, and a bare created_at predicate stays sargable on
// idx_noti_ws_created (workspace equality + created_at range).
//
// windowed 把查询收到 created_at 上的半开窗 [After, Before)（零界=不设界）。裸列比较、界值 UTC——flowrun
// started_at 窗的逐字翻版：界值与存储值走同一 driver 序列化，裸 created_at 谓词在 idx_noti_ws_created 上可走索引。
func windowed(q *ormpkg.Query[notificationdomain.Notification], window notificationdomain.MarkAllWindow) *ormpkg.Query[notificationdomain.Notification] {
	if !window.After.IsZero() {
		q = q.Where("created_at >= ?", window.After)
	}
	if !window.Before.IsZero() {
		q = q.Where("created_at < ?", window.Before)
	}
	return q
}

// CountUnread returns the unread count for the badge.
//
// CountUnread 返回未读数（badge 用）。
func (s *Store) CountUnread(ctx context.Context) (int, error) {
	n, err := s.repo.WhereNull("read_at").Count(ctx)
	if err != nil {
		return 0, fmt.Errorf("notificationstore.CountUnread: %w", err)
	}
	return int(n), nil
}
