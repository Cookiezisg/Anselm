// Package document is the domain layer for the Notion-style tree document library.
//
// Package document 是 Notion-style 树状文档库的 domain 层。
package document

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

// Document is one node in the user's markdown tree; ParentID is nil for root-level docs.
//
// Document 是用户 markdown 树的一个节点；ParentID = nil 表示根级。
type Document struct {
	ID          string         `gorm:"primaryKey;type:text" json:"id"`
	UserID      string         `gorm:"index;not null;type:text" json:"userId"`
	ParentID    *string        `gorm:"index;type:text" json:"parentId,omitempty"`
	Name        string         `gorm:"not null;type:text" json:"name"`
	Description string         `gorm:"not null;type:text;default:''" json:"description"`
	Content     string         `gorm:"not null;type:text;default:''" json:"content"`
	Tags        []string       `gorm:"serializer:json;type:text;default:'[]'" json:"tags"`
	Position    int            `gorm:"not null;default:0" json:"position"`
	Path        string         `gorm:"index;not null;type:text" json:"path"`
	SizeBytes   int64          `gorm:"not null;default:0" json:"sizeBytes"`
	CreatedAt   time.Time      `json:"createdAt"`
	UpdatedAt   time.Time      `json:"updatedAt"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Document) TableName() string { return "documents" }

// MaxContentBytes caps a single document's markdown body; oversized payloads should split into child docs.
//
// MaxContentBytes 单文档 markdown 上限；超出应拆子文档。
const MaxContentBytes = 1 << 20 // 1 MB

// MaxNameLength caps the title — users hit this when pasting in long lines accidentally.
//
// MaxNameLength 标题上限——用户偶尔粘贴长行会撞到。
const MaxNameLength = 256

var (
	ErrNotFound         = errors.New("document: not found")
	ErrInvalidParent    = errors.New("document: invalid parent (cycle or self)")
	ErrNameConflict     = errors.New("document: name already exists under same parent")
	ErrContentTooLarge  = errors.New("document: content exceeds 1 MB limit")
	ErrInvalidName      = errors.New("document: invalid name (empty or too long)")
	ErrParentNotFound   = errors.New("document: parent not found")
)

// CreateInput is the write payload for a new document; UserID is filled by Service from ctx.
//
// CreateInput 新建写入载荷；UserID 由 Service 从 ctx 填。
type CreateInput struct {
	Name        string
	ParentID    *string
	Content     string
	Description string
	Tags        []string
}

// UpdateInput is a partial-update payload; nil pointers mean "leave alone".
//
// UpdateInput 部分更新载荷；nil 指针表示不动。
type UpdateInput struct {
	Name        *string
	Description *string
	Content     *string
	Tags        *[]string
}

// MoveInput identifies a relocation; nil ParentID moves to root; nil Position appends to end.
//
// MoveInput 描述一次移动；nil ParentID 移到根；nil Position 追加到末尾。
type MoveInput struct {
	ParentID *string
	Position *int
}

// AttachedDocument is one entry in a workflow llm/agent node's
// AttachedDocuments list (or Conversation.AttachedDocuments).
// IncludeSubtree=true makes the resolver expand to all live descendants
// at dispatch time (live-resolve, not snapshot).
//
// AttachedDocument 是 workflow llm/agent 节点(或 Conversation)挂载列表
// 中的一项。IncludeSubtree=true 时 resolver 在 dispatch 时展开成当前所有
// 后裔(live-resolve,非快照)。
type AttachedDocument struct {
	DocumentID     string `json:"documentId"`
	IncludeSubtree bool   `json:"includeSubtree,omitempty"`
}

// Repository is the storage contract; UserID-scoped (multi-tenant ready, V1 hard-coded local-user).
//
// Repository 是存储契约；按 UserID 作用域（多租户预留，V1 硬编码 local-user）。
type Repository interface {
	Insert(ctx context.Context, d *Document) error
	Get(ctx context.Context, userID, id string) (*Document, error)
	GetBatch(ctx context.Context, userID string, ids []string) ([]*Document, error)
	ListByParent(ctx context.Context, userID string, parentID *string) ([]*Document, error)
	ListAll(ctx context.Context, userID string) ([]*Document, error)
	Search(ctx context.Context, userID, query string, limit int) ([]*Document, error)
	Update(ctx context.Context, d *Document) error
	UpdateBatch(ctx context.Context, docs []*Document) error
	SoftDeleteSubtree(ctx context.Context, userID, id string) (deletedCount int64, err error)
	IsAncestor(ctx context.Context, userID, candidateAncestorID, descendantID string) (bool, error)
	CountChildren(ctx context.Context, userID, id string) (int64, error)
	CountDescendants(ctx context.Context, userID, id string) (int64, error)
	MaxSiblingPosition(ctx context.Context, userID string, parentID *string) (int, error)

	// ListSubtreeIDs returns [rootID, ...all live descendant IDs] via BFS;
	// empty when root id not found. Used by documentapp.ResolveAttached to
	// live-expand `IncludeSubtree=true` attach entries.
	//
	// ListSubtreeIDs 经 BFS 返 [rootID, ...所有活跃后裔 ID]；root id 不存在
	// 返空切片。给 documentapp.ResolveAttached 展开 IncludeSubtree=true 用。
	ListSubtreeIDs(ctx context.Context, userID, rootID string) ([]string, error)
}
