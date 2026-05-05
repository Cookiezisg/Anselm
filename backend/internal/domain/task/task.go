// Package task is the domain layer for the LLM-facing per-conversation
// to-do tracker. v1 consumer: app/tool/task via app/task.Service.
//
// Package task 是 LLM 对话级任务追踪 domain。v1 消费者：通过
// app/task.Service 的 app/tool/task。
package task

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

// Task is one entry on a conversation's task list; owned by the creating
// conversation, not portable across conversations.
//
// Task 是对话任务列表上一条；归属创建对话，不可跨对话。
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

func (Task) TableName() string { return "tasks" }

// Status lifecycle: pending → in_progress → completed (terminal).
// Tasks may be deleted at any point. App-layer validation, not DB CHECK,
// so adding new statuses needs no schema migration.
//
// Status 生命周期：pending → in_progress → completed（终态）。任何时点可
// 标 deleted。校验在 app 层（非 DB CHECK），新增状态不需 schema 迁移。
const (
	StatusPending    = "pending"
	StatusInProgress = "in_progress"
	StatusCompleted  = "completed"
	StatusDeleted    = "deleted"
)

// IsValidStatus reports whether s is a recognised status.
// IsValidStatus 报告 s 是否合法状态。
func IsValidStatus(s string) bool {
	switch s {
	case StatusPending, StatusInProgress, StatusCompleted, StatusDeleted:
		return true
	default:
		return false
	}
}

// ListStatuses returns every recognised status. Backs the contract test
// asserting ListStatuses ≡ IsValidStatus; production code does not call it.
//
// ListStatuses 返所有合法状态。支撑 ListStatuses ≡ IsValidStatus 契约测试；生产不调。
func ListStatuses() []string {
	return []string{StatusPending, StatusInProgress, StatusCompleted, StatusDeleted}
}

var (
	ErrNotFound        = errors.New("task: not found")
	ErrSubjectRequired = errors.New("task: subject is required")
	ErrInvalidStatus   = errors.New("task: invalid status")
	// ErrConversationMismatch: caller tried to mutate a task from a different
	// conversation than ctx — defensive reject to prevent scope leak.
	// ErrConversationMismatch：调用方改了归属另一对话的任务——防御性拒绝防作用域泄漏。
	ErrConversationMismatch = errors.New("task: conversation mismatch")
)

// Repository is the storage contract for Task. Filters by row's
// ConversationID; callers don't mutate ConversationID after Create.
//
// Repository 是 Task 存储契约。按行 ConversationID 过滤；调用方 Create 后
// 不改 ConversationID。
type Repository interface {
	// Create inserts a new task; caller fills ID / ConversationID / Subject / valid Status.
	// Create 插入新任务；调用方先填 ID / ConversationID / Subject / 合法 Status。
	Create(ctx context.Context, t *Task) error

	// Get fetches by ID; ErrNotFound when absent or soft-deleted.
	// Get 按 ID 取；不存在或软删返 ErrNotFound。
	Get(ctx context.Context, id string) (*Task, error)

	// ListByConversation returns active tasks for one conversation, created_at ASC.
	// ListByConversation 返某对话活跃任务，created_at 升序。
	ListByConversation(ctx context.Context, conversationID string) ([]*Task, error)

	// Update writes back; caller follows load → mutate → pass same pointer.
	// Update 写回；调用方按 load → 修改 → 传同一指针。
	Update(ctx context.Context, t *Task) error

	// SoftDelete sets deleted_at; row kept for audit, hidden from List/Get.
	// SoftDelete 置 deleted_at；行保留可审计，不再被 List/Get 见。
	SoftDelete(ctx context.Context, id string) error
}
