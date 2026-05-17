// Package conversation is the domain layer for chat thread management.
//
// Package conversation 是对话线程 domain 层（消息归 chat domain）。
package conversation

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"

	documentdomain "github.com/sunweilin/forgify/backend/internal/domain/document"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
)

// Conversation is a chat thread container; Summary is the anchored-append summary from app/contextmgr.
// AttachedDocuments persists which document(s) to prepend to every system prompt as cache-friendly
// context — same struct as workflow llm/agent nodes; resolved live via documentapp.ResolveAttached.
//
// Conversation 是对话线程容器；Summary 是 app/contextmgr 维护的 anchored-append 摘要。
// AttachedDocuments 持久化"挂在每轮 system prompt 前的 doc"——跟 workflow llm/agent 节点
// 同 struct,经 documentapp.ResolveAttached live 展开。
type Conversation struct {
	ID                   string                            `gorm:"primaryKey;type:text" json:"id"`
	UserID               string                            `gorm:"not null;index;type:text" json:"-"`
	Title                string                            `gorm:"not null;type:text;default:''" json:"title"`
	AutoTitled           bool                              `gorm:"not null;default:false" json:"autoTitled"`
	SystemPrompt         string                            `gorm:"type:text;default:''" json:"systemPrompt,omitempty"`
	Summary              string                            `gorm:"type:text;default:''" json:"summary,omitempty"`
	SummaryCoversUpToSeq int64                             `gorm:"not null;default:0" json:"summaryCoversUpToSeq,omitempty"`
	AttachedDocuments    []documentdomain.AttachedDocument `gorm:"serializer:json;type:text;default:'[]'" json:"attachedDocuments,omitempty"`
	Archived             bool                              `gorm:"not null;default:false;index" json:"archived"`
	Pinned               bool                              `gorm:"not null;default:false" json:"pinned"`
	ModelOverride        *modeldomain.ModelRef             `gorm:"serializer:json;type:text" json:"modelOverride,omitempty"`
	CreatedAt            time.Time                         `json:"createdAt"`
	UpdatedAt            time.Time                         `json:"updatedAt"`
	DeletedAt            gorm.DeletedAt                    `gorm:"index" json:"-"`
}

func (Conversation) TableName() string { return "conversations" }

type ListFilter struct {
	Cursor   string
	Limit    int
	Search   string // §4.3: optional SQL LIKE on title (V1; message-content / tool-name 走 FTS5 后续)
	Archived *bool  // §17.12: nil = exclude archived (default), true = archived only, false = active only
}

var ErrNotFound = errors.New("conversation: not found")

// Repository is the storage contract for Conversation, scoped by ctx user.
//
// Repository 是 Conversation 的存储契约，按 ctx 用户过滤。
type Repository interface {
	Save(ctx context.Context, c *Conversation) error
	Get(ctx context.Context, id string) (*Conversation, error)
	List(ctx context.Context, filter ListFilter) ([]*Conversation, string, error)
	Delete(ctx context.Context, id string) error
}
