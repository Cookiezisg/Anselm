// Package conversation is the domain layer for chat-thread containers: the persistent,
// per-workspace thread entity (title, pin/archive, soft-delete) plus its thread-level
// config (system prompt, attached documents, model override). Messages are NOT here —
// they belong to chat; this package owns only the thread record + storage contract.
//
// Package conversation 是对话线程容器的 domain 层：按 workspace 持久化的线程实体（标题、
// 置顶/归档、软删）及其线程级配置（system prompt、挂载文档、模型覆盖）。消息**不在这里**——
// 归 chat；本包只持有线程记录 + 存储契约。
package conversation

import (
	"context"
	"time"

	documentdomain "github.com/sunweilin/anselm/backend/internal/domain/document"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// Conversation is a chat-thread container. The thread's messages live in chat's
// message_blocks; this record carries only the thread's identity, interaction state,
// and the config the chat runtime reads each turn. Summary / SummaryCoversUpToSeq are
// written by the compactor (app/contextmgr); AutoTitled is set by chat after it auto-names
// a turn-1 thread — all three are declared here (one coherent thread record) but kept off the
// PATCH surface. SystemPrompt / AttachedDocuments / ModelOverride are user-editable settings
// (this is conversation's job); chat merely consumes them at runtime.
//
// Conversation 是对话线程容器。线程消息在 chat 的 message_blocks；本记录只承载线程身份、
// 交互状态、chat 运行时每轮要读的配置。Summary / SummaryCoversUpToSeq 由压缩器（app/contextmgr）
// 写；AutoTitled 由 chat 给首轮线程自动命名后设——三者在此声明（一份内聚的线程记录）但
// 不进 PATCH 面。SystemPrompt / AttachedDocuments / ModelOverride 是用户可改的设置（conversation
// 的职责）；chat 仅在运行时消费。
type Conversation struct {
	ID                   string                            `db:"id,pk"                    json:"id"`
	WorkspaceID          string                            `db:"workspace_id,ws"          json:"-"`
	Title                string                            `db:"title"                    json:"title"`
	AutoTitled           bool                              `db:"auto_titled"              json:"autoTitled"`
	SystemPrompt         string                            `db:"system_prompt"            json:"systemPrompt,omitempty"`
	Summary              string                            `db:"summary"                  json:"summary,omitempty"`
	SummaryCoversUpToSeq int64                             `db:"summary_covers_up_to_seq" json:"summaryCoversUpToSeq,omitempty"`
	AttachedDocuments    []documentdomain.AttachedDocument `db:"attached_documents,json"  json:"attachedDocuments,omitempty"`
	Archived             bool                              `db:"archived"                 json:"archived"`
	Pinned               bool                              `db:"pinned"                   json:"pinned"`
	ModelOverride        *modeldomain.ModelRef             `db:"model_override,json"      json:"modelOverride,omitempty"`
	CreatedAt            time.Time                         `db:"created_at,created"       json:"createdAt"`
	UpdatedAt            time.Time                         `db:"updated_at,updated"       json:"updatedAt"`
	// LastMessageAt is the recency-sort key: the time of the most recent message added to the
	// thread (set at creation, bumped by chat on each user turn). It is a plain column — NOT the
	// ,updated tag — so pin/rename/model-override (which bump updated_at) never reorder the list.
	//
	// LastMessageAt 是最近活跃排序键：线程最后一条消息加入的时间（创建时设、chat 每个用户回合刷）。
	// 它是普通列、非 ,updated tag——故 pin/改名/换模型（刷 updated_at）不会重排列表。
	LastMessageAt time.Time  `db:"last_message_at" json:"lastMessageAt"`
	DeletedAt     *time.Time `db:"deleted_at,deleted" json:"-"`

	// IsGenerating is a derived runtime flag (NOT persisted, db:"-"): true when chat has an
	// in-flight assistant turn for this conversation. Filled per-row in the app layer from the
	// chat registry (GeneratingQuerier) so a freshly-connected client can cold-start its live
	// activity dots; read-only on the wire, never accepted in PATCH.
	//
	// IsGenerating 是派生运行时标志（不落库，db:"-"）：chat 有该对话在途 assistant 回合时为 true。
	// 由 app 层据 chat 登记（GeneratingQuerier）逐行填，使刚连上的客户端能冷启动活动圆点；线缆只读、
	// 不进 PATCH。
	IsGenerating bool `db:"-" json:"isGenerating"`

	// AwaitingInput is a derived runtime flag (NOT persisted, db:"-"): true when this conversation has
	// ≥1 pending human-in-loop interaction (an approve/answer the user must resolve before the turn
	// continues). Filled per-row in the app layer from the in-memory humanloop broker
	// (AwaitingInputQuerier), mirroring IsGenerating, so a freshly-connected client cold-starts its
	// "needs you" rail dot. Pending interactions live ONLY in the broker (no DB table, intentionally
	// ephemeral — a restart leaves none), so this is always derived, never stored. Read-only on the
	// wire, never accepted in PATCH.
	//
	// AwaitingInput 是派生运行时标志（不落库，db:"-"）：该对话有 ≥1 个待决人在环 interaction（用户须批准/回答、
	// 回合才续）时为 true。由 app 层据内存 humanloop broker（AwaitingInputQuerier）逐行填，镜像 IsGenerating，
	// 使刚连上的客户端冷启动「等你」rail 点。待决 interaction 只活在 broker（无 DB 表、刻意 ephemeral——重启即无），
	// 故恒派生、不落库。线缆只读、不进 PATCH。
	AwaitingInput bool `db:"-" json:"awaitingInput"`

	// Unread is a PERSISTED boolean (NOT db:"-"): true when a COMPLETED assistant reply has landed that
	// the user has not yet seen — the "answered while you were away" rail dot (green). It is a stored
	// flag, not a derived comparison: set true by the assistant-finalize TouchLastMessage (folded into
	// the same UPDATE, so it is atomic with the recency bump), and cleared (false) on the user's own
	// send (TouchLastMessage with unread=false — sending is seeing), on MarkSeen (the :seen action when
	// the user opens the thread), and at creation (column default 0). A stored bool — NOT a timestamp /
	// seq watermark — because this is a single-user, conversation-level binary: it needs no read-position
	// granularity, and storing the answer directly sidesteps wall-clock comparison entirely (no NTP
	// step-back / coarse-tick mis-flag). Survives restart (it is a column). System-write, wire read-only,
	// never accepted in PATCH (like Summary / AutoTitled).
	//
	// Unread 是**持久布尔**（非 db:"-"）：有一条**完成的** assistant 回复落地、用户尚未看 → 为 true，即「你不在时答完了」
	// 的 rail 绿点。它是存的标志、非派生比较：由 assistant 终态的 TouchLastMessage 置 true（折进同一条 UPDATE，故与
	// recency 刷新原子），并在用户自己发送（TouchLastMessage unread=false——发即是看）、MarkSeen（用户打开线程的 :seen
	// 动作）、创建（列默认 0）时清为 false。用存布尔、**非时间戳/seq watermark**——因为这是单用户、会话级的二元量：不需要
	// 读位置粒度，且直接存答案彻底绕开墙上时钟比较（无 NTP 回拨 / 粗 tick 误判）。重启照样记得（是列）。系统写、线缆只读、
	// 不进 PATCH（同 Summary / AutoTitled）。
	Unread bool `db:"unread" json:"hasUnread"`
}

// ArchiveScope selects which archive states the conversation list returns. The zero value is
// ArchiveActive (active-only) — the common default. It is an explicit 3-state enum, NOT an
// overloaded *bool: the rail's "show archived" needs an ACTIVE+ARCHIVED-together mode that a
// nil/true/false pointer cannot express (and whose absence silently broke list_conversations'
// includeArchived). The store applies exactly one predicate per scope.
//
// ArchiveScope 选列表返回哪些归档态。零值 ArchiveActive（仅活跃）——常用默认。它是显式三态枚举、非
// 重载 *bool：rail 的「显示已归档」要一个**活跃+归档同列**的模式，nil/true/false 指针表达不了
// （其缺失正是 list_conversations 的 includeArchived 静默失效之因）。store 按每个 scope 套恰好一个谓词。
type ArchiveScope string

const (
	ArchiveActive   ArchiveScope = ""         // active only (default / zero value)
	ArchiveArchived ArchiveScope = "archived" // archived only
	ArchiveAll      ArchiveScope = "all"      // both active and archived (rail "show archived" — archived rows carry archived=true for the gray dot)
)

// ListFilter narrows the conversation list. Archive selects the archive scope (default ArchiveActive
// = active-only). Search is a case-insensitive title LIKE.
//
// ListFilter 收窄对话列表。Archive 选归档范围（默认 ArchiveActive = 仅活跃）。Search 是标题大小写不敏感 LIKE。
// ListSort selects the conversation list ordering (always pinned-first within each). Empty defaults
// to ListSortActivity. The keyset cursor tracks the chosen sort's column (activity/created walk a
// time key descending via Page; name walks the title string ascending + NOCASE via PageAsc), so a
// client that switches sort MUST drop its cursor (start a fresh page) — a cursor minted under one
// sort is meaningless under another.
//
// ListSort 选对话列表排序（每种都置顶优先）。空 = ListSortActivity。keyset 游标随所选排序的列走（activity/created
// 经 Page 走时间键降序；name 经 PageAsc 走 title 字符串升序 + NOCASE），故客户端切换排序时**必须丢弃游标**
// （重新翻页）——一种排序下铸的游标在另一种下无意义。
type ListSort string

const (
	ListSortActivity ListSort = "activity" // pinned-first, then last_message_at DESC — "recently chatted" (default)
	ListSortCreated  ListSort = "created"  // pinned-first, then created_at DESC — "when opened"
	ListSortName     ListSort = "name"     // pinned-first, then title A–Z (case-insensitive) — "by name"
)

type ListFilter struct {
	Cursor  string
	Limit   int
	Search  string
	Archive ArchiveScope // "" → ArchiveActive (active only)
	Sort    ListSort     // "" → ListSortActivity
}

// UpdateInput is the PATCH payload; a nil field is left unchanged. ModelOverride is a
// pointer-to-pointer for tristate: nil = leave, &nil = clear, &(&ref) = set.
//
// UpdateInput 是 PATCH 载荷；nil 字段不动。ModelOverride 是指针的指针以表三态：nil = 不变、
// &nil = 清除、&(&ref) = 设置。
type UpdateInput struct {
	Title             *string
	SystemPrompt      *string
	AttachedDocuments *[]documentdomain.AttachedDocument
	Archived          *bool
	Pinned            *bool
	ModelOverride     **modeldomain.ModelRef
}

var (
	// ErrNotFound: get/update/delete on an unknown (or soft-deleted) conversation.
	// ErrNotFound：对未知（或已软删）对话 get/update/delete。
	ErrNotFound = errorspkg.New(errorspkg.KindNotFound, "CONVERSATION_NOT_FOUND", "conversation not found")

	// ErrInvalidModelOverride: a set modelOverride is missing apiKeyId or modelId. Mirrors
	// agent — structural only; key existence is resolved (and may fail gracefully) at chat time.
	// ErrInvalidModelOverride：已设的 modelOverride 缺 apiKeyId 或 modelId。照 agent——仅结构；
	// key 存在性在 chat 时解析（可优雅失败）。
	ErrInvalidModelOverride = errorspkg.New(errorspkg.KindUnprocessable, "CONVERSATION_INVALID_MODEL_OVERRIDE", "invalid modelOverride (apiKeyId and modelId both required)")

	// ErrAttachedDocumentNotFound: a PATCH set attachedDocuments to include a doc id that does not
	// exist (mistyped or since-deleted). Rejected 422 at attach time with the missing ids in Details —
	// mirrors agent's eager knowledge-mount check, instead of silently accepting a dangling reference
	// that only surfaces as a render-time warning later (F168-M5; F167 render warning still backstops
	// old data not re-validated here).
	//
	// ErrAttachedDocumentNotFound：PATCH 把 attachedDocuments 设成含不存在的 doc id（拼错或已删）。attach
	// 时即 422、Details 带缺失 id——照 agent 的 eager knowledge 挂载校验，而非静默接受悬挂引用、只在后续渲染
	// 时才警告（F168-M5；F167 渲染警告仍兜底此处不回溯校验的老数据）。
	ErrAttachedDocumentNotFound = errorspkg.New(errorspkg.KindUnprocessable, "CONVERSATION_ATTACHED_DOC_NOT_FOUND", "conversation attaches a document that does not exist")
)

// Repository is the storage contract; workspace isolation + soft-delete are applied by the
// orm layer from ctx, so methods take no workspace id and List excludes tombstones.
//
// Repository 是存储契约；workspace 隔离 + 软删由 orm 层据 ctx 施加，故方法不带 workspace id、
// List 自动排除墓碑。
type Repository interface {
	Insert(ctx context.Context, c *Conversation) error
	Get(ctx context.Context, id string) (*Conversation, error)
	GetBatch(ctx context.Context, ids []string) ([]*Conversation, error)
	List(ctx context.Context, filter ListFilter) (items []*Conversation, next string, err error)
	Update(ctx context.Context, c *Conversation) error
	// TouchLastMessage sets last_message_at AND the unread flag on one conversation (chat calls it when a
	// message lands) — a single cheap UPDATE carrying recency + the unread bit atomically; the ORM
	// ,updated tag also bumps updated_at. `unread` is the new unread state: false on the user's own send
	// (sending is seeing), true on a COMPLETED assistant finalize (a reply to read), false on a
	// non-completed terminal.
	//
	// TouchLastMessage 把某对话的 last_message_at 与 unread 标志一并设（chat 在消息落地时调）——一次廉价 UPDATE
	// 原子带 recency + 未读位；ORM ,updated tag 顺带刷 updated_at。unread 是新未读态：用户自己发送时 false（发即是看）、
	// assistant **完成**终态时 true（有回复待读）、非完成终态时 false。
	TouchLastMessage(ctx context.Context, id string, t time.Time, unread bool) error
	// MarkSeen clears the unread flag (the :seen action — the user opened the thread without sending).
	// A single focused UPDATE on the unread column only; idempotent (a no-op on an unknown id returns
	// nil). Does NOT touch last_message_at, so opening a thread never reorders the activity list.
	//
	// MarkSeen 清 unread 标志（:seen 动作——用户没发消息、只是打开了线程）。只针对 unread 列的聚焦 UPDATE；幂等
	// （未知 id 上 no-op 返 nil）。不动 last_message_at，故打开线程绝不重排活跃列表。
	MarkSeen(ctx context.Context, id string) error
	SoftDelete(ctx context.Context, id string) error
}
