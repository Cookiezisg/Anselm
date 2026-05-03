// Package task is the domain layer for the LLM-facing task tracker —
// a per-conversation to-do list the LLM uses to plan and resume complex
// multi-step work. It carries the entity, status enum, sentinel errors,
// and the storage Repository port. Cross-domain consumers go through
// app/task.Service (the only consumer in v1: app/tool/task).
//
// Naming convention: domain / app / store all declare `package task`;
// callers alias by role (taskdomain / taskapp / taskstore) per §S13.
//
// Package task 是 LLM 用的对话级任务追踪 domain——LLM 用来规划与续接复杂
// 多步工作的 per-conversation to-do 列表。包含实体、状态枚举、sentinel
// 错误以及存储 Repository 端口。跨 domain 消费走 app/task.Service（v1
// 唯一消费者：app/tool/task）。
//
// 命名约定：domain / app / store 三处都声明 `package task`；调用方按 §S13
// 别名（taskdomain / taskapp / taskstore）。
package task

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

// Task is one entry on a conversation's task list. The owner is the
// conversation that created it; tasks are not portable across conversations.
//
// Task 是对话任务列表上的一条；归属于创建它的对话，跨对话不可移植。
type Task struct {
	ID             string         `gorm:"primaryKey;type:text" json:"id"`
	ConversationID string         `gorm:"not null;index:idx_tk_conv_status,priority:1;type:text" json:"conversationId"`
	Subject        string         `gorm:"not null;type:text" json:"subject"`
	Description    string         `gorm:"type:text" json:"description,omitempty"`
	ActiveForm     string         `gorm:"type:text" json:"activeForm,omitempty"`
	Status         string         `gorm:"not null;type:text;index:idx_tk_conv_status,priority:2;default:pending" json:"status"`
	Owner          string         `gorm:"type:text" json:"owner,omitempty"`
	BlockedBy      []string       `gorm:"serializer:json" json:"blockedBy,omitempty"`
	Metadata       map[string]any `gorm:"serializer:json" json:"metadata,omitempty"`
	CreatedAt      time.Time      `json:"createdAt"`
	UpdatedAt      time.Time      `json:"updatedAt"`
	DeletedAt      gorm.DeletedAt `gorm:"index" json:"-"`
}

// TableName locks the table to "tasks".
//
// TableName 把表名锁定为 "tasks"。
func (Task) TableName() string { return "tasks" }

// ── Status enum ───────────────────────────────────────────────────────────────

// Status constants. Lifecycle: pending → in_progress → completed (terminal).
// Tasks may be marked deleted at any point; the row remains until GORM
// soft-delete sweeps it.
//
// Status 常量。生命周期：pending → in_progress → completed（终态）。
// 任何时点都可被 deleted 标记；行在 GORM 软删扫描前保留。
const (
	StatusPending    = "pending"
	StatusInProgress = "in_progress"
	StatusCompleted  = "completed"
	StatusDeleted    = "deleted"
)

// IsValidStatus reports whether s is a recognised status. Validation lives
// in the app layer (not DB CHECK) so future statuses can be added without
// a schema migration.
//
// IsValidStatus 报告 s 是否合法状态；校验在 app 层而非 DB CHECK，便于
// 新增状态时不做 schema 迁移。
func IsValidStatus(s string) bool {
	switch s {
	case StatusPending, StatusInProgress, StatusCompleted, StatusDeleted:
		return true
	default:
		return false
	}
}

// ListStatuses returns every recognised status. Production code does not
// call this; it backs the contract test that asserts ListStatuses ≡
// IsValidStatus.
//
// ListStatuses 返回所有合法状态。生产代码不调用；为支撑 ListStatuses 与
// IsValidStatus 列表一致的契约测试。
func ListStatuses() []string {
	return []string{StatusPending, StatusInProgress, StatusCompleted, StatusDeleted}
}

// ── Sentinels ─────────────────────────────────────────────────────────────────

var (
	// ErrNotFound: task ID was not present in the store.
	// ErrNotFound：任务 ID 不在存储中。
	ErrNotFound = errors.New("task: not found")

	// ErrSubjectRequired: Create / Update without a non-empty subject.
	// ErrSubjectRequired：Create / Update 缺非空 subject。
	ErrSubjectRequired = errors.New("task: subject is required")

	// ErrInvalidStatus: status not in the supported whitelist.
	// ErrInvalidStatus：status 不在支持的白名单内。
	ErrInvalidStatus = errors.New("task: invalid status")

	// ErrConversationMismatch: caller tried to mutate a task belonging to
	// a different conversation than the current ctx. Defensive — reject
	// the operation rather than silently scope-leak across conversations.
	// ErrConversationMismatch：调用方尝试修改归属于另一个 conversation 的
	// 任务；防御性拒绝，避免跨对话静默作用域泄漏。
	ErrConversationMismatch = errors.New("task: conversation mismatch")
)

// ── Repository port ───────────────────────────────────────────────────────────

// Repository is the storage contract for Task. Implementations filter by
// the ConversationID stamped on each row; callers never mutate
// ConversationID after Create.
//
// Implemented by: infra/store/task.Store
// Consumer:       app/task.Service (only)
//
// Repository 是 Task 的存储契约。实现按行上的 ConversationID 过滤；调用方
// 不在 Create 之后修改 ConversationID。
//
// 实现：infra/store/task.Store
// 消费：仅 app/task.Service
type Repository interface {
	// Create inserts a new task. Caller must have set ID, ConversationID,
	// Subject, and a valid Status before calling.
	//
	// Create 插入新任务；调用方传入前应已填好 ID / ConversationID / Subject /
	// 合法 Status。
	Create(ctx context.Context, t *Task) error

	// Get fetches by ID. Returns ErrNotFound if absent or soft-deleted.
	//
	// Get 按 ID 取；不存在或软删返 ErrNotFound。
	Get(ctx context.Context, id string) (*Task, error)

	// ListByConversation returns active tasks for a conversation, ordered
	// by created_at ascending so the LLM sees them in creation order.
	//
	// ListByConversation 返回某对话的活跃任务，按 created_at 升序——LLM 看到
	// 创建顺序。
	ListByConversation(ctx context.Context, conversationID string) ([]*Task, error)

	// Update writes changes back. Caller is expected to load + mutate +
	// pass the same pointer so GORM's optimistic concurrency etc. could
	// be added later.
	//
	// Update 写回改动；调用方按 load + 修改 + 传同一指针的模式，便于将来
	// 接入 GORM 乐观并发等。
	Update(ctx context.Context, t *Task) error

	// SoftDelete sets deleted_at; the row is kept for auditability but no
	// longer surfaces in ListByConversation / Get.
	//
	// SoftDelete 置 deleted_at；行保留可审计，但 ListByConversation / Get
	// 不再返。
	SoftDelete(ctx context.Context, id string) error
}
