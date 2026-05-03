// Package task (infra/store/task) is the GORM-backed implementation of
// the domain task Repository port.
//
// Scoping: Task rows are conversation-scoped, NOT user-scoped at the
// store layer. The chat-runner stamps the conversation_id on the
// outbound ctx, and app/task.Service is the layer that asserts the
// caller's conversation matches the row before mutating. The store
// merely persists by ConversationID — it does not enforce ownership.
//
// Package task（infra/store/task）是 domain task Repository port 的
// GORM 实现。
//
// 作用域：Task 行按 conversation 作用域，而非 user 作用域。chat-runner
// 把 conversation_id 印在出向 ctx；app/task.Service 在变更前断言调用方
// 的 conversation 与行匹配。store 仅按 ConversationID 持久化，不强制所有权。
package task

import (
	"context"
	"errors"
	"fmt"

	"gorm.io/gorm"

	taskdomain "github.com/sunweilin/forgify/backend/internal/domain/task"
)

// Store is the GORM implementation of taskdomain.Repository.
//
// Store 是 taskdomain.Repository 的 GORM 实现。
type Store struct {
	db *gorm.DB
}

// New constructs a Store bound to the given *gorm.DB.
//
// New 基于给定 *gorm.DB 构造 Store。
func New(db *gorm.DB) *Store {
	return &Store{db: db}
}

// Create inserts a new task. Returns the GORM error wrapped with
// "taskstore.Create:" — uniqueness conflicts surface unwrapped via
// errors.Is.
//
// Create 插入新任务；GORM 错用 "taskstore.Create:" 包装；唯一冲突原样可
// errors.Is 透出。
func (s *Store) Create(ctx context.Context, t *taskdomain.Task) error {
	if err := s.db.WithContext(ctx).Create(t).Error; err != nil {
		return fmt.Errorf("taskstore.Create: %w", err)
	}
	return nil
}

// Get fetches by id. Returns ErrNotFound when absent or soft-deleted
// (GORM auto-filters deleted_at).
//
// Get 按 id 取；不存在或软删返 ErrNotFound（GORM 自动过滤 deleted_at）。
func (s *Store) Get(ctx context.Context, id string) (*taskdomain.Task, error) {
	var t taskdomain.Task
	err := s.db.WithContext(ctx).Where("id = ?", id).First(&t).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, taskdomain.ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("taskstore.Get: %w", err)
	}
	return &t, nil
}

// ListByConversation returns active tasks for a conversation, ordered
// by created_at ascending so the LLM sees creation order.
//
// ListByConversation 按 created_at 升序返某对话活跃任务（LLM 看到创建顺序）。
func (s *Store) ListByConversation(ctx context.Context, conversationID string) ([]*taskdomain.Task, error) {
	var rows []*taskdomain.Task
	err := s.db.WithContext(ctx).
		Where("conversation_id = ?", conversationID).
		Order("created_at ASC").
		Find(&rows).Error
	if err != nil {
		return nil, fmt.Errorf("taskstore.ListByConversation: %w", err)
	}
	return rows, nil
}

// Update writes the task back. GORM's Save updates all fields including
// zero values; the service is expected to load + mutate + Save the same
// pointer so we don't accidentally clobber columns the caller didn't
// touch.
//
// Update 写回任务；GORM Save 会更新所有字段（含零值），service 用 load +
// 改 + Save 同一指针的模式避免误清空。
func (s *Store) Update(ctx context.Context, t *taskdomain.Task) error {
	if err := s.db.WithContext(ctx).Save(t).Error; err != nil {
		return fmt.Errorf("taskstore.Update: %w", err)
	}
	return nil
}

// SoftDelete sets deleted_at via GORM's built-in soft-delete behaviour.
// Idempotent: deleting an already-deleted row affects 0 rows but does
// not error.
//
// SoftDelete 用 GORM 内置软删置 deleted_at。幂等：重复删 0 行影响但不报错。
func (s *Store) SoftDelete(ctx context.Context, id string) error {
	res := s.db.WithContext(ctx).Where("id = ?", id).Delete(&taskdomain.Task{})
	if res.Error != nil {
		return fmt.Errorf("taskstore.SoftDelete: %w", res.Error)
	}
	if res.RowsAffected == 0 {
		// Treat "0 rows" as not-found so the service can return the
		// canonical sentinel rather than swallowing silently.
		// 0 行视为 not-found，让 service 返规范 sentinel 而非静默吞掉。
		return taskdomain.ErrNotFound
	}
	return nil
}
