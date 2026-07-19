// Package notification is the domain for the user-facing notification center: a
// persisted, per-workspace event log (entity changed, memory updated, …) that the
// frontend lists and a badge counts. Any module raises one via the Emitter port; the
// app stores it (DB) and pushes a signal on the notifications SSE stream so the
// frontend updates live, while the history survives restarts — unlike the SSE replay
// ring, which only bridges short reconnects.
//
// Package notification 是用户通知中心的 domain：一份持久化、按 workspace 的事件日志（实体
// 变更、memory 更新…），前端列出、badge 计数。任何模块经 Emitter 端口发通知；app 存 DB
// 并在 notifications SSE 流推一条 signal 让前端实时更新，历史跨重启留存——不同于只兜短时
// 重连的 SSE replay 环。
package notification

import (
	"context"
	"time"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// Notification is one persisted event. Type is the event kind (<domain>.<action>,
// e.g. "memory.updated") — the wire/SSE Node.Type; Payload is the producer-defined
// detail the frontend renders (the backend does NOT format a human-readable string).
// ReadAt nil = unread.
//
// Notification 是一条持久化事件。Type 是事件类型（<域>.<动作>，如 "memory.updated"）——即
// 线缆/SSE 的 Node.Type；Payload 是 producer 定义、前端渲染的细节（后端**不**拼人类文案）。
// ReadAt nil = 未读。
type Notification struct {
	ID          string         `db:"id,pk" json:"id"`
	WorkspaceID string         `db:"workspace_id,ws" json:"-"`
	Type        string         `db:"type" json:"type"`
	Payload     map[string]any `db:"payload,json" json:"payload,omitempty"`
	ReadAt      *time.Time     `db:"read_at" json:"readAt,omitempty"`
	CreatedAt   time.Time      `db:"created_at,created" json:"createdAt"`
}

var (
	// ErrNotFound: MarkRead on an unknown id.
	// ErrNotFound：对未知 id 调 MarkRead。
	ErrNotFound = errorspkg.New(errorspkg.KindNotFound, "NOTIFICATION_NOT_FOUND", "notification not found")

	// ErrInvalidType: Emit with an empty event type.
	// ErrInvalidType：Emit 时事件类型为空。
	ErrInvalidType = errorspkg.New(errorspkg.KindInvalid, "NOTIFICATION_INVALID_TYPE", "notification type required (<domain>.<action>)")

	// ErrInvalidWindow: a mark-all window bound (after/before) that isn't RFC3339 — a loud 422, the
	// same verdict flowruns give a bad ?startedAfter, so a mistyped window never silently marks everything.
	// ErrInvalidWindow：mark-all 窗口界（after/before）非 RFC3339——大声 422（同 flowrun 对坏 ?startedAfter 的判决），
	// 打错的窗口界绝不静默地标掉一切。
	ErrInvalidWindow = errorspkg.New(errorspkg.KindUnprocessable, "NOTIFICATION_INVALID_WINDOW", "invalid notification mark-all window bound (RFC3339 required)")
)

// MarkAllWindow bounds a bulk read-state change to a half-open [After, Before) slice of created_at (both
// bounds UTC; a ZERO bound is unbounded — both zero = the whole ledger, the backward-compatible default a
// bodyless call gets). The tray scopes a time-group's "mark all read/unread" to just that group's rows
// with it, so clearing "Today" leaves the "Earlier" backlog untouched.
//
// MarkAllWindow 把批量读态变更限在 created_at 的半开窗 [After, Before)（两界皆 UTC；零界=不设界——两界皆零=整本
// 账，即无 body 调用得到的向后兼容默认）。托盘用它把某时间组的「全部已读/未读」限在该组行，故清「今天」不动「更早」的积压。
type MarkAllWindow struct {
	After  time.Time
	Before time.Time
}

// Emitter is the port any module calls to raise a lifecycle event on the notifications
// stream. It has two tiers, because the stream carries two kinds of durable signal:
//
//   - Emit persists a notification-center ROW and pushes a durable live signal. Use for
//     events the user should find in their inbox later — failures, and entity lifecycle
//     the AI may have driven (created/edited/deleted). The row is the source of truth,
//     recoverable via the REST list; the signal is the live nudge.
//   - Broadcast pushes ONLY the durable live signal — no row. Use for high-frequency
//     reconciliation echoes that drive live UI (rail re-sort, tree refresh) but would be
//     noise in the inbox (a rename, a pin toggle, a tree save). Their truth is the
//     entity's OWN state, re-fetched on resync — not a notification row. On the wire the
//     frame is shaped identically to Emit's (a transient id anchors it); it simply leaves
//     no trace in the notification center.
//
// Both are best-effort on the push and know nothing of storage or transport — producers
// only name the event and its payload, and pick the tier by whether it belongs in the inbox.
//
// Emitter 是任何模块在 notifications 流上发生命周期事件的端口。分两档，因为该流承载两种 durable
// signal：Emit 落**收件箱行** + 推 durable live signal（值得事后在通知中心找到的事件——失败、
// AI 可能干的实体生命周期；行是真相、REST 可兜回，信号是实时提示）；Broadcast **只推** durable
// live signal、不落行（驱动实时 UI 但进收件箱即噪音的高频对账回声——改名、pin 翻转、树保存；其真相
// 是实体**自身**状态、resync 时重取，非通知行；线缆帧形与 Emit 完全一致[临时 id 锚定]，只是通知中心不留痕）。
type Emitter interface {
	Emit(ctx context.Context, eventType string, payload map[string]any) error
	Broadcast(ctx context.Context, eventType string, payload map[string]any) error
}

// Repository is the storage contract; workspace isolation is applied by the orm
// layer from ctx. List is newest-first, keyset-paginated (next == "" at end).
//
// Repository 是存储契约；workspace 隔离由 orm 层据 ctx 施加。List 最新优先、keyset 分页
// （到底 next == ""）。
type Repository interface {
	Save(ctx context.Context, n *Notification) error
	List(ctx context.Context, cursor string, limit int) (items []*Notification, next string, err error)
	MarkRead(ctx context.Context, id string) error
	MarkAllRead(ctx context.Context, window MarkAllWindow) error
	MarkAllUnread(ctx context.Context, window MarkAllWindow) error
	CountUnread(ctx context.Context) (int, error)
}
