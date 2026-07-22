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
	"fmt"

	touchpointdomain "github.com/sunweilin/anselm/backend/internal/domain/touchpoint"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// Schema is the conversation_touchpoints DDL. idx_tp_dedup makes (conversation, item, verb)
// unique per workspace — the aggregate-row invariant (D3-style) AND Upsert's native ON CONFLICT
// key: concurrent recorders converge inside one atomic statement. idx_tp_conv backs the rail's
// recency-ordered page walk.
//
// Schema 是 conversation_touchpoints 表 DDL。idx_tp_dedup 使每 workspace 下 (对话,物,动词)
// 唯一——聚合行不变式(D3 类)**兼 Upsert 的原生 ON CONFLICT 冲突键**:并发记账在单条原子语句内
// 收敛。idx_tp_conv 支撑 rail 的新鲜度序分页。
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
	db   *ormpkg.DB // raw handle for the native-upsert write path 原生 upsert 写径的裸把手
}

// New builds a Store bound to the conversation_touchpoints table.
//
// New 构造绑定 conversation_touchpoints 表的 Store。
func New(db *ormpkg.DB) *Store {
	return &Store{repo: ormpkg.For[touchpointdomain.Touchpoint](db, "conversation_touchpoints"), db: db}
}

var _ touchpointdomain.Repository = (*Store)(nil)

// Upsert records one touch as ONE atomic statement: the dedup index IS the conflict key, so a
// native INSERT … ON CONFLICT DO UPDATE replaces the old SELECT + INSERT/UPDATE pair and its
// whole concurrent-collision retry branch (same-group tool calls race here; the database now
// converges them, not application code). Semantics preserved exactly: first contact seeds
// count=1/first_at; a bump increments count and refreshes last_at/last_actor, while
// last_message_id / item_name refresh only when the INCOMING value is non-empty — the borrowed
// sibling name (below) rides the INSERT half only, via a separate bind of the raw incoming name
// in the UPDATE half.
//
// Upsert 单条原子语句记一次触碰:dedup 索引本身就是冲突键,原生 INSERT…ON CONFLICT DO UPDATE 换掉
// 旧的 SELECT + INSERT/UPDATE 两趟与整个并发撞车重试分支(同组工具在此竞速,收敛交给数据库、不再靠
// 应用代码)。语义逐字保留:首触 count=1/first_at;递进 count+1、刷 last_at/last_actor,而
// last_message_id/item_name 只在**来值非空**时刷——借来的兄弟名(下)只随 INSERT 半生效,UPDATE 半
// 单独绑原始来名。
func (s *Store) Upsert(ctx context.Context, t *touchpointdomain.Touch, id string) (*touchpointdomain.Touchpoint, error) {
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return nil, fmt.Errorf("touchpointstore.Upsert: %w", err)
	}
	insertName := t.ItemName
	if insertName == "" {
		// Borrow the snapshot from a sibling-verb row of the same item: a `deleted` touch is
		// always this tuple's FIRST row and hydration just missed (the entity is already gone,
		// namers are live-scoped) — but the conversation that deletes an item almost always
		// viewed/edited it first, and that row still holds the name.
		// 从同物的兄弟动词行借快照:`deleted` 触碰必然是该键的**首行**且 hydrate 刚好落空(实体已删,
		// namer 只查活体)——但删它的对话几乎总先看过/改过它,那行还留着名字。
		insertName = s.siblingName(ctx, t)
	}
	row := touchpointdomain.Touchpoint{}
	if err := s.db.QueryRow(ctx, `
		INSERT INTO conversation_touchpoints
			(id, workspace_id, conversation_id, item_kind, item_id, item_name, verb, last_actor, count, first_at, last_at, last_message_id)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?)
		ON CONFLICT(workspace_id, conversation_id, item_kind, item_id, verb) DO UPDATE SET
			count           = count + 1,
			last_at         = excluded.last_at,
			last_actor      = excluded.last_actor,
			last_message_id = CASE WHEN excluded.last_message_id <> '' THEN excluded.last_message_id ELSE last_message_id END,
			item_name       = CASE WHEN ? <> '' THEN ? ELSE item_name END
		RETURNING id, conversation_id, item_kind, item_id, item_name, verb, last_actor, count, first_at, last_at, last_message_id`,
		id, wsID, t.ConversationID, t.ItemKind, t.ItemID, insertName, t.Verb, t.Actor, t.At, t.At, t.MessageID,
		t.ItemName, t.ItemName,
	).Scan(
		&row.ID, &row.ConversationID, &row.ItemKind, &row.ItemID, &row.ItemName,
		&row.Verb, &row.LastActor, &row.Count, &row.FirstAt, &row.LastAt, &row.LastMessageID,
	); err != nil {
		return nil, fmt.Errorf("touchpointstore.Upsert: %w", err)
	}
	return &row, nil
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
