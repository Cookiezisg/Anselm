// Package touchpoint is the orm-backed implementation of touchpointdomain.Repository plus
// the conversation_touchpoints DDL. Rows are hard-deleted (derived ledger, same class as
// relations — no soft-delete column); the ONLY delete path is the conversation-death cascade.
// Workspace isolation is applied automatically by the orm layer from ctx.
//
// Package touchpoint 是 touchpointdomain.Repository 的 orm 实现 + conversation_touchpoints
// 表 DDL。行硬删(派生台账,与 relations 同类——无软删列);唯一删除路径 = 对话死亡级联。
// workspace 隔离由 orm 层据 ctx 自动施加。
package touchpoint

import (
	"context"
	"errors"
	"fmt"

	touchpointdomain "github.com/sunweilin/anselm/backend/internal/domain/touchpoint"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

// Schema is the conversation_touchpoints DDL. idx_tp_dedup makes (conversation, item, verb)
// unique per workspace — the aggregate-row invariant (D3-style): concurrent recorders collide
// there and converge via the conflict-retry in Upsert. idx_tp_conv backs the rail's
// recency-ordered page walk.
//
// Schema 是 conversation_touchpoints 表 DDL。idx_tp_dedup 使每 workspace 下 (对话,物,动词)
// 唯一——聚合行不变式(D3 类):并发记账在此相撞、经 Upsert 的冲突重试收敛。idx_tp_conv 支撑
// rail 的新鲜度序分页。
var Schema = []string{
	`CREATE TABLE IF NOT EXISTS conversation_touchpoints (
		id              TEXT PRIMARY KEY,
		workspace_id    TEXT NOT NULL,
		conversation_id TEXT NOT NULL,
		item_kind       TEXT NOT NULL,
		item_id         TEXT NOT NULL,
		item_name       TEXT NOT NULL DEFAULT '',
		verb            TEXT NOT NULL CHECK (verb IN ('mentioned','created','edited','viewed','executed','attached','deleted')),
		last_actor      TEXT NOT NULL CHECK (last_actor IN ('user','assistant','subagent')),
		count           INTEGER NOT NULL DEFAULT 1,
		first_at        DATETIME NOT NULL,
		last_at         DATETIME NOT NULL,
		last_message_id TEXT NOT NULL DEFAULT ''
	)`,
	`CREATE UNIQUE INDEX IF NOT EXISTS idx_tp_dedup ON conversation_touchpoints(workspace_id, conversation_id, item_kind, item_id, verb)`,
	`CREATE INDEX IF NOT EXISTS idx_tp_conv ON conversation_touchpoints(workspace_id, conversation_id, last_at)`,
}

// Store implements touchpointdomain.Repository over pkg/orm.
//
// Store 基于 pkg/orm 实现 touchpointdomain.Repository。
type Store struct {
	repo *ormpkg.Repo[touchpointdomain.Touchpoint]
}

// New builds a Store bound to the conversation_touchpoints table.
//
// New 构造绑定 conversation_touchpoints 表的 Store。
func New(db *ormpkg.DB) *Store {
	return &Store{repo: ormpkg.For[touchpointdomain.Touchpoint](db, "conversation_touchpoints")}
}

var _ touchpointdomain.Repository = (*Store)(nil)

// Upsert records one touch: insert on first contact, else bump the aggregate (count,
// last_at, last_actor, last_message_id; a non-empty incoming name refreshes the snapshot).
// Same-group tool calls run concurrently, so a lookup-miss may still hit the dedup index —
// ErrConflict re-reads and bumps instead (one retry converges: the row now exists).
//
// Upsert 记一次触碰:首触 insert,否则聚合递进(count/last_at/last_actor/last_message_id;
// 来名非空则刷新快照)。同组工具并发跑,查空后仍可能撞 dedup 索引——ErrConflict 转重读递进
// (一次重试即收敛:行已存在)。
func (s *Store) Upsert(ctx context.Context, t *touchpointdomain.Touch, id string) (*touchpointdomain.Touchpoint, error) {
	existing, err := s.get(ctx, t)
	if err != nil {
		return nil, err
	}
	if existing == nil {
		name := t.ItemName
		if name == "" {
			// Borrow the snapshot from a sibling-verb row of the same item: a `deleted` touch is
			// always this tuple's FIRST row and hydration just missed (the entity is already gone,
			// namers are live-scoped) — but the conversation that deletes an item almost always
			// viewed/edited it first, and that row still holds the name.
			// 从同物的兄弟动词行借快照:`deleted` 触碰必然是该键的**首行**且 hydrate 刚好落空(实体已删,
			// namer 只查活体)——但删它的对话几乎总先看过/改过它,那行还留着名字。
			name = s.siblingName(ctx, t)
		}
		row := &touchpointdomain.Touchpoint{
			ID:             id,
			ConversationID: t.ConversationID,
			ItemKind:       t.ItemKind,
			ItemID:         t.ItemID,
			ItemName:       name,
			Verb:           t.Verb,
			LastActor:      t.Actor,
			Count:          1,
			FirstAt:        t.At,
			LastAt:         t.At,
			LastMessageID:  t.MessageID,
		}
		err := s.repo.Create(ctx, row)
		if err == nil {
			return row, nil
		}
		if !errors.Is(err, ormpkg.ErrConflict) {
			return nil, fmt.Errorf("touchpointstore.Upsert insert: %w", err)
		}
		if existing, err = s.get(ctx, t); err != nil {
			return nil, err
		}
		if existing == nil {
			return nil, fmt.Errorf("touchpointstore.Upsert: conflict but row absent for %s/%s/%s", t.ConversationID, t.ItemID, t.Verb)
		}
	}
	existing.Count++
	existing.LastAt = t.At
	existing.LastActor = t.Actor
	if t.MessageID != "" {
		existing.LastMessageID = t.MessageID
	}
	if t.ItemName != "" {
		existing.ItemName = t.ItemName
	}
	if err := s.repo.Save(ctx, existing); err != nil {
		return nil, fmt.Errorf("touchpointstore.Upsert save: %w", err)
	}
	return existing, nil
}

// siblingName returns the display-name snapshot from any named row of the same
// (conversation, kind, item) — regardless of verb — or "".
//
// siblingName 从同 (对话,类,物) 任意有名行(不论动词)取显示名快照,无则 ""。
func (s *Store) siblingName(ctx context.Context, t *touchpointdomain.Touch) string {
	rows, err := s.repo.WhereEq("conversation_id", t.ConversationID).
		WhereEq("item_kind", t.ItemKind).
		WhereEq("item_id", t.ItemID).
		Where("item_name != ''").
		Limit(1).Find(ctx)
	if err != nil || len(rows) == 0 {
		return ""
	}
	return rows[0].ItemName
}

// get fetches the aggregate row for a touch's (conversation, item, verb), or nil.
//
// get 取该 touch 的 (对话,物,动词) 聚合行,无则 nil。
func (s *Store) get(ctx context.Context, t *touchpointdomain.Touch) (*touchpointdomain.Touchpoint, error) {
	rows, err := s.repo.WhereEq("conversation_id", t.ConversationID).
		WhereEq("item_kind", t.ItemKind).
		WhereEq("item_id", t.ItemID).
		WhereEq("verb", t.Verb).
		Limit(1).Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("touchpointstore.get: %w", err)
	}
	if len(rows) == 0 {
		return nil, nil
	}
	return rows[0], nil
}

// ListByConversation pages the conversation's ledger by recency (last_at DESC, id DESC —
// PageKeyset aligns the cursor with the sort). kind/verb are optional filters. Recency is a
// MUTATING sort key: a row touched between page fetches may shift pages — inherent to any
// recency feed and harmless here (the rail re-pulls on live signals anyway).
//
// ListByConversation 按新鲜度分页对话台账(last_at DESC, id DESC——PageKeyset 使游标与排序
// 对齐)。kind/verb 可选过滤。新鲜度是**会变的**排序键:两页之间被触碰的行可能换页——任何
// 新鲜度流的固有性质,此处无害(rail 反正随实时信号重拉)。
func (s *Store) ListByConversation(ctx context.Context, conversationID, kind, verb, cursor string, limit int) ([]*touchpointdomain.Touchpoint, string, error) {
	q := s.repo.WhereEq("conversation_id", conversationID)
	if kind != "" {
		q = q.WhereEq("item_kind", kind)
	}
	if verb != "" {
		q = q.WhereEq("verb", verb)
	}
	rows, next, err := q.PageKeyset("last_at").Page(ctx, cursor, limit)
	if err != nil {
		return nil, "", fmt.Errorf("touchpointstore.ListByConversation: %w", err)
	}
	return rows, next, nil
}

// PurgeConversation hard-deletes the whole ledger of a dead conversation.
//
// PurgeConversation 硬删死亡对话的整份台账。
func (s *Store) PurgeConversation(ctx context.Context, conversationID string) error {
	if _, err := s.repo.WhereEq("conversation_id", conversationID).Delete(ctx); err != nil {
		return fmt.Errorf("touchpointstore.PurgeConversation: %w", err)
	}
	return nil
}
