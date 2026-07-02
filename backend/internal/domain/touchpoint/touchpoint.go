// Package touchpoint is the domain layer for the conversation's context ledger — the
// central record of every external thing a conversation has TOUCHED: entities the user
// @-mentioned, entities the AI created/edited/viewed/executed/deleted, and attachments
// brought into the thread. One AGGREGATE row per (conversation, item, verb) — count plus
// first/last timestamps — not an event journal: the per-event history already lives in the
// message blocks, and the ledger's consumer (the chat right island) needs "what was touched,
// how, how recently", not a replay log. This is deliberately NOT the relation graph: relation
// answers "what references what NOW" (diff-synced terminal state, edges overwritten as
// versions move); touchpoint answers "what did THIS conversation ever touch" (history that
// only accumulates, surviving entity deletion via a display-name snapshot on the row).
//
// Package touchpoint 是对话上下文台账的 domain 层——对话碰过的一切外部之物的中央记录:用户
// @ 过的、AI 创建/编辑/看过/执行/删除过的实体、带进线程的附件。每 (对话, 物, 动词) 一条**聚合行**
// (count + 首末时间),非事件日志:逐事件历史已在消息 blocks 里,消费方(chat 右岛)要的是「碰过
// 什么、怎么碰的、多新鲜」而非重放日志。它刻意**不是** relation 图:relation 答「现在谁引用谁」
// (diff-sync 终态,边随版本推移被覆盖);touchpoint 答「这个对话碰过什么」(只积累的历程,实体
// 删除后靠行上显示名快照仍诚实可显)。
package touchpoint

import (
	"context"
	"time"

	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// Verbs — the closed set of ways a conversation touches an item. `viewed` is deliberately
// included ("touched at all counts"); failed tool calls never record (a failed touch is not
// a touch). `deleted` keeps the ledger honest after the item is gone (paired with the name
// snapshot). The set is CHECK-enforced in the table and sealed in the frontend contract.
//
// 动词——对话触碰一个物的封闭集合。`viewed` 刻意收录(「碰过就算」);失败的工具调用不记账
// (失败的触碰不是触碰)。`deleted` 配合名字快照让台账在物消失后仍诚实。表 CHECK 强制,前端契约可 seal。
const (
	VerbMentioned = "mentioned"
	VerbCreated   = "created"
	VerbEdited    = "edited"
	VerbViewed    = "viewed"
	VerbExecuted  = "executed"
	VerbAttached  = "attached"
	VerbDeleted   = "deleted"
)

// IsValidVerb reports whether v is in the closed verb set.
//
// IsValidVerb 报告 v 是否在动词封闭集内。
func IsValidVerb(v string) bool {
	switch v {
	case VerbMentioned, VerbCreated, VerbEdited, VerbViewed, VerbExecuted, VerbAttached, VerbDeleted:
		return true
	}
	return false
}

// Actors — who performed the LAST touch on the row. The user mentions/attaches; the
// assistant (main loop) and its subagents do everything else. Aggregate rows keep only the
// last actor: the rail needs "who touched it most recently", not a per-actor breakdown.
//
// actor——行上**最后一次**触碰者。用户 @ /附件;主循环与 subagent 干其余。聚合行只留最后
// actor:rail 要「最近谁碰的」,不需要按 actor 拆账。
const (
	ActorUser      = "user"
	ActorAssistant = "assistant"
	ActorSubagent  = "subagent"
)

// IsValidActor reports whether a is in the closed actor set.
//
// IsValidActor 报告 a 是否在 actor 封闭集内。
func IsValidActor(a string) bool {
	switch a {
	case ActorUser, ActorAssistant, ActorSubagent:
		return true
	}
	return false
}

// ItemKindAttachment extends relation's 11 entity kinds with the one ledger-only kind:
// attachments are conversation cargo, not graph entities, so relation never models them —
// but the right island's gallery page needs them in the same ledger.
//
// ItemKindAttachment 在 relation 的 11 实体 kind 之外加台账独有的一种:附件是对话的货物、
// 非图实体,relation 不建模它——但右岛画廊页需要它入同一份台账。
const ItemKindAttachment = "attachment"

// IsValidItemKind reports whether k is a ledger item kind: relation's 11 entity kinds
// (reused verbatim — one vocabulary, no drift) plus attachment.
//
// IsValidItemKind 报告 k 是否台账 item kind:relation 的 11 实体 kind(逐字复用——一份词表、
// 零漂移)+ attachment。
func IsValidItemKind(k string) bool {
	return k == ItemKindAttachment || relationdomain.IsValidEntityKind(k)
}

// Touchpoint is the persisted aggregate row. ItemName is the last-known display name,
// snapshotted at write time so the ledger stays readable after the item is deleted (a
// dangling id is not an acceptable rail row). Count/FirstAt/LastAt carry the recency
// signal the rail sorts by; LastMessageID anchors "jump to where it happened".
//
// Touchpoint 是持久化聚合行。ItemName 是写入时快照的最后已知显示名——物被删后台账仍可读
// (裸 id 不配当 rail 行)。Count/FirstAt/LastAt 是 rail 排序用的新鲜度信号;LastMessageID
// 锚定「跳到发生处」。
type Touchpoint struct {
	ID             string    `db:"id,pk"           json:"id"`
	WorkspaceID    string    `db:"workspace_id,ws" json:"-"`
	ConversationID string    `db:"conversation_id" json:"conversationId"`
	ItemKind       string    `db:"item_kind"       json:"itemKind"`
	ItemID         string    `db:"item_id"         json:"itemId"`
	ItemName       string    `db:"item_name"       json:"itemName"`
	Verb           string    `db:"verb"            json:"verb"`
	LastActor      string    `db:"last_actor"      json:"lastActor"`
	Count          int64     `db:"count"           json:"count"`
	FirstAt        time.Time `db:"first_at"        json:"firstAt"`
	LastAt         time.Time `db:"last_at"         json:"lastAt"`
	LastMessageID  string    `db:"last_message_id" json:"lastMessageId"`
}

// Touch is one observed contact, the write-side input. Name may be empty (the app layer
// hydrates via Namers when it can); MessageID may be empty (not every path knows it).
//
// Touch 是一次观测到的接触,写侧输入。Name 可空(app 层能 hydrate 时经 Namers 补);
// MessageID 可空(不是每条路径都知道)。
type Touch struct {
	ConversationID string
	ItemKind       string
	ItemID         string
	ItemName       string
	Verb           string
	Actor          string
	MessageID      string
	At             time.Time
}

// Validate rejects a structurally invalid touch. Only physical-value checks (principle #6):
// the closed sets and the two ids that make the row addressable.
//
// Validate 拒绝结构非法的 touch。只做有物理价值的校验(原则 #6):封闭集 + 让行可寻址的两个 id。
func (t *Touch) Validate() error {
	if t.ConversationID == "" || t.ItemID == "" {
		return ErrInvalidRef
	}
	if !IsValidItemKind(t.ItemKind) {
		return ErrInvalidKind
	}
	if !IsValidVerb(t.Verb) {
		return ErrInvalidVerb
	}
	if !IsValidActor(t.Actor) {
		return ErrInvalidActor
	}
	return nil
}

// Sentinel errors (S20: errorspkg.New, Kind → HTTP status, stable wire codes).
//
// Sentinel 错误(S20:errorspkg.New,Kind → HTTP 状态,稳定线缆码)。
var (
	ErrInvalidRef   = errorspkg.New(errorspkg.KindInvalid, "TP_INVALID_REF", "touchpoint requires conversation and item ids")
	ErrInvalidKind  = errorspkg.New(errorspkg.KindInvalid, "TP_INVALID_KIND", "invalid touchpoint item kind")
	ErrInvalidVerb  = errorspkg.New(errorspkg.KindInvalid, "TP_INVALID_VERB", "invalid touchpoint verb")
	ErrInvalidActor = errorspkg.New(errorspkg.KindInvalid, "TP_INVALID_ACTOR", "invalid touchpoint actor")
)

// Repository persists aggregate rows. Upsert is the single write: insert on first contact,
// else bump count/last_at/last_actor/last_message_id and refresh the name snapshot (a
// non-empty incoming name wins — names drift toward freshest-known). ListByConversation
// pages by (last_at DESC, id) under optional kind/verb filters. PurgeConversation
// hard-deletes the ledger when its conversation dies (derived data, no soft delete —
// same class as relations). Workspace isolation comes from ctx via the orm layer.
//
// Repository 持久化聚合行。Upsert 是唯一写:首触 insert,否则 count/last_at/last_actor/
// last_message_id 递进 + 名字快照刷新(来名非空则覆盖——名字向最新已知漂移)。
// ListByConversation 按 (last_at DESC, id) 分页,可选 kind/verb 过滤。PurgeConversation
// 在对话死亡时硬删台账(派生数据、无软删——与 relations 同类)。workspace 隔离由 orm 层据 ctx 施加。
type Repository interface {
	Upsert(ctx context.Context, t *Touch, id string) (*Touchpoint, error)
	ListByConversation(ctx context.Context, conversationID, kind, verb string, cursor string, limit int) ([]*Touchpoint, string, error)
	PurgeConversation(ctx context.Context, conversationID string) error
}
