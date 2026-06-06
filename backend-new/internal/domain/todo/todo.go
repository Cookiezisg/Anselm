// Package todo is the domain layer for the agent's working-memory checklist — a
// TodoWrite-style scratchpad scoped to one execution context (a conversation, or a
// subagent run nested within it). The whole list is the unit: a write replaces it
// wholesale, mirroring Claude Code's TodoWrite (no per-item ids, no CRUD bookkeeping).
// Its value is staying in front of the model (re-injected each turn) and visible to the
// user (live on the messages stream) — not durable record-keeping.
//
// Package todo 是 agent 工作记忆清单的 domain 层——TodoWrite 式草稿本，作用域为一个执行
// 上下文（一个对话，或嵌在其中的 subagent run）。整张清单是单位：一次写整体替换，对标
// Claude Code 的 TodoWrite（无逐项 id、无 CRUD 记账）。它的价值在于常驻模型眼前（每轮重注入）
// 与对用户可见（messages 流实时）——而非持久存档。
package todo

import (
	"context"
	"errors"
	"time"
)

// Item statuses. A removed task simply isn't in the next write (whole-list replace) —
// there is no "deleted" status and items are never soft-deleted individually.
//
// 项状态。移除的任务只是不在下次写入里（整列替换）——没有 "deleted" 状态、项也从不单独软删。
const (
	StatusPending    = "pending"
	StatusInProgress = "in_progress"
	StatusCompleted  = "completed"
)

// IsValidStatus reports whether s is one of the three item statuses.
//
// IsValidStatus 报告 s 是否三种项状态之一。
func IsValidStatus(s string) bool {
	switch s {
	case StatusPending, StatusInProgress, StatusCompleted:
		return true
	}
	return false
}

// MaxItems caps a single write. A working checklist needing more than this is a planning
// smell, not a real need; the cap also bounds the per-turn reminder injection.
//
// MaxItems 单次写上限。工作清单超过此数是规划异味、非真需求；上限也给每轮 reminder 注入设界。
const MaxItems = 64

// Item is one checklist entry. Content is the imperative title ("Run the tests");
// ActiveForm is its present-continuous form ("Running the tests"), shown while
// in_progress. No id — the list is a value addressed positionally, not a set of entities.
//
// Item 是一条清单项。Content 是祈使标题（"Run the tests"）；ActiveForm 是其进行时形式
// （"Running the tests"），in_progress 时展示。无 id——清单是值、按位置寻址，非实体集。
type Item struct {
	Content    string `json:"content"`
	ActiveForm string `json:"activeForm"`
	Status     string `json:"status"`
}

// List is the persisted row: one checklist per execution scope. ScopeID is the owning
// context's id — the subagent id when SubagentID is set, else the conversation id — a
// polymorphic owner ref (kind ∈ {conversation, subagent}), like relation's from_id.
// Exactly one row per (workspace, conversation, subagent?) scope; ScopeID is its PK.
//
// List 是持久化行：每执行作用域一张清单。ScopeID 是拥有上下文的 id——SubagentID 有值时为
// subagent id、否则为对话 id——多态 owner 引用（kind ∈ {conversation, subagent}），同
// relation 的 from_id。每 (workspace, conversation, subagent?) 作用域恰一行；ScopeID 是其 PK。
type List struct {
	ScopeID        string     `db:"scope_id,pk"        json:"-"`
	WorkspaceID    string     `db:"workspace_id,ws"    json:"-"`
	ConversationID string     `db:"conversation_id"    json:"conversationId"`
	SubagentID     *string    `db:"subagent_id"        json:"subagentId,omitempty"`
	Items          []Item     `db:"items,json"         json:"todos"`
	CreatedAt      time.Time  `db:"created_at,created" json:"createdAt"`
	UpdatedAt      time.Time  `db:"updated_at,updated" json:"updatedAt"`
	DeletedAt      *time.Time `db:"deleted_at,deleted" json:"-"`
}

// Sentinel errors. They never reach HTTP: the only writer is the TodoWrite tool (波次
// 2/3), which renders them as a tool-result string for the model to self-correct, and the
// REST read never validates input. So they are plain errors (no Kind / wire code) —
// unlike the HTTP-bound domain errors built with errorsdomain.New (S20). todo therefore
// holds no error-code contract.
//
// Sentinel 错误。它们从不抵达 HTTP：唯一写入者是 TodoWrite 工具（波次 2/3），把它们渲染成
// tool-result 字符串供模型自纠，REST 读也从不校验输入。故为 plain error（无 Kind / wire code）——
// 不同于用 errorsdomain.New 构造、会冒泡 HTTP 的 domain 错误（S20）。todo 因此不持错误码契约。
var (
	ErrEmptyContent  = errors.New("todo: item content is required")
	ErrInvalidStatus = errors.New("todo: invalid item status")
	ErrTooManyItems  = errors.New("todo: too many items")
)

// Repository persists one checklist per scope. Workspace isolation is applied by the orm
// layer from ctx; ScopeID is the row key. GetByScope returns (nil, nil) for a scope with
// no list so callers treat "no list" and "empty list" alike (an absent checklist is not
// an error). Upsert writes the whole list (insert-or-replace-items).
//
// Repository 每作用域持久化一张清单。workspace 隔离由 orm 层据 ctx 施加；ScopeID 是行键。
// GetByScope 对无清单的作用域返 (nil, nil)，使调用方对"无清单"与"空清单"一视同仁（缺清单非
// 错误）。Upsert 写整张清单（insert 或 replace items）。
type Repository interface {
	GetByScope(ctx context.Context, scopeID string) (*List, error)
	Upsert(ctx context.Context, l *List) error
}
