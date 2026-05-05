// Package conversation is the domain layer for chat thread management.
// A Conversation is a named container; messages live in chat domain.
//
// Package conversation 是对话线程 domain 层。
// Conversation 是命名容器；消息归 chat domain。
package conversation

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

// Conversation is a chat thread container. Title may be empty until rename
// or Phase 5 auto-naming.
//
// Conversation 是对话线程容器。Title 可空，待重命名或 Phase 5 自动命名。
type Conversation struct {
	ID           string         `gorm:"primaryKey;type:text" json:"id"`
	UserID       string         `gorm:"not null;index;type:text" json:"-"`
	Title        string         `gorm:"not null;type:text;default:''" json:"title"`
	AutoTitled   bool           `gorm:"not null;default:false" json:"autoTitled"`
	SystemPrompt string         `gorm:"type:text;default:''" json:"systemPrompt,omitempty"`
	CreatedAt    time.Time      `json:"createdAt"`
	UpdatedAt    time.Time      `json:"updatedAt"`
	DeletedAt    gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Conversation) TableName() string { return "conversations" }

// ListFilter is the query shape for Repository.List.
//
// ListFilter 是 Repository.List 的查询形状。
type ListFilter struct {
	Cursor string
	Limit  int
}

// ErrNotFound: conversation id has no matching live record.
// ErrNotFound：conversation id 无匹配活跃记录。
var ErrNotFound = errors.New("conversation: not found")

// Repository is the storage contract for Conversation, scoped to ctx user.
//
// Repository 是 Conversation 的存储契约，按 ctx 用户过滤。
type Repository interface {
	// Save inserts or updates by primary key.
	// Save 按主键插入或更新。
	Save(ctx context.Context, c *Conversation) error

	// Get fetches by id, scoped to ctx user; ErrNotFound when absent.
	// Get 按 id 取，按 ctx 用户过滤；不存在返 ErrNotFound。
	Get(ctx context.Context, id string) (*Conversation, error)

	// List returns one page for ctx user, newest first.
	// List 返当前用户一页，最新优先。
	List(ctx context.Context, filter ListFilter) ([]*Conversation, string, error)

	// Delete soft-deletes; ErrNotFound when no live record matched.
	// Delete 软删除；未命中返 ErrNotFound。
	Delete(ctx context.Context, id string) error
}
