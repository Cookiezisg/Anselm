// Package chat is the domain layer for conversation messaging: Message /
// Block / Attachment entities, sentinels, Repository contract. No LLM
// orchestration here — that's in app/chat.
//
// Package chat 是对话消息 domain 层：Message / Block / Attachment 实体、
// sentinel、Repository 契约。LLM 编排在 app/chat。
package chat

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

// Message is one conversation turn. Content lives in Blocks. ErrorCode /
// ErrorMessage are populated only when Status="error", giving the UI a
// structured failure reason without re-parsing assistant text.
//
// Message 是对话的一个回合。内容在 Blocks 里。ErrorCode / ErrorMessage 仅
// 在 Status="error" 时填，给 UI 结构化失败原因，免去再解析 assistant 文本。
type Message struct {
	ID             string         `gorm:"primaryKey;type:text" json:"id"`
	ConversationID string         `gorm:"not null;index;type:text" json:"conversationId"`
	UserID         string         `gorm:"not null;type:text" json:"-"`
	Role           string         `gorm:"not null;type:text" json:"role"`
	Status         string         `gorm:"not null;type:text;default:'completed'" json:"status"`
	StopReason     string         `gorm:"type:text;default:''" json:"stopReason,omitempty"`
	ErrorCode      string         `gorm:"type:text;default:''" json:"errorCode,omitempty"`
	ErrorMessage   string         `gorm:"type:text;default:''" json:"errorMessage,omitempty"`
	InputTokens    int            `gorm:"default:0" json:"inputTokens,omitempty"`
	OutputTokens   int            `gorm:"default:0" json:"outputTokens,omitempty"`
	CreatedAt      time.Time      `json:"createdAt"`
	UpdatedAt      time.Time      `json:"updatedAt"`
	DeletedAt      gorm.DeletedAt `gorm:"index" json:"-"`

	// Blocks is not a DB column — store layer fills after query.
	// Blocks 非 DB 列——store 查询后填充。
	Blocks []Block `gorm:"-" json:"blocks"`
}

func (Message) TableName() string { return "messages" }

const (
	RoleUser      = "user"
	RoleAssistant = "assistant"
)

const (
	StatusPending   = "pending"
	StatusStreaming = "streaming"
	StatusCompleted = "completed"
	StatusError     = "error"
	StatusCancelled = "cancelled"
)

const (
	StopReasonEndTurn   = "end_turn"
	StopReasonMaxTokens = "max_tokens"
	StopReasonCancelled = "cancelled"
	StopReasonError     = "error"
)

// Block is one typed content element within a Message. All content lives
// in Blocks — Message holds only metadata.
//
// Block 是 Message 内一个类型化内容元素。所有内容在 Block；Message 仅元数据。
type Block struct {
	ID        string    `gorm:"primaryKey;type:text" json:"id"`
	MessageID string    `gorm:"not null;index:idx_mb_msg_seq,priority:1;type:text" json:"-"`
	Seq       int       `gorm:"not null;index:idx_mb_msg_seq,priority:2" json:"seq"`
	Type      string    `gorm:"not null;type:text" json:"type"`
	Data      string    `gorm:"not null;type:text" json:"data"` // JSON; shape varies by Type
	CreatedAt time.Time `json:"createdAt"`
}

func (Block) TableName() string { return "message_blocks" }

const (
	BlockTypeText          = "text"
	BlockTypeReasoning     = "reasoning"
	BlockTypeToolCall      = "tool_call"
	BlockTypeToolResult    = "tool_result"
	BlockTypeAttachmentRef = "attachment_ref"
)

// TextData is the Data payload for BlockTypeText / BlockTypeReasoning.
// TextData 是 BlockTypeText / BlockTypeReasoning 的 Data 载荷。
type TextData struct {
	Text string `json:"text"`
}

// ToolCallData is the Data payload for BlockTypeToolCall. Arguments never
// contains the three framework-injected standard fields ("summary" /
// "destructive" / "execution_group") — those are first-class fields here.
//
// ToolCallData 是 BlockTypeToolCall 的 Data 载荷。Arguments 不含三个框架
// 注入的标准字段（"summary" / "destructive" / "execution_group"）——
// 三者作为一等字段独立存储。
type ToolCallData struct {
	ID   string `json:"id"`
	Name string `json:"name"`

	// Summary is the LLM's one-line description; empty when the LLM omitted it.
	// Summary 是 LLM 一句话描述；LLM 漏填时为空。
	Summary string `json:"summary"`

	// Destructive: LLM self-reports irreversible-damage potential; UI shows badge.
	// Destructive：LLM 自报本次可能不可逆破坏；UI 据此显徽章。
	Destructive bool `json:"destructive"`

	// ExecutionGroup is the LLM parallel-batch hint (≥1). 0 = missing/auto;
	// chat/tools.go partition assigns a unique sequential group per 0-valued
	// call (run alone, after explicit groups). Same explicit value = parallel.
	//
	// ExecutionGroup 是 LLM 并行 batch 提示（≥1）。0 = 缺失/自动；
	// chat/tools.go 分批给每个 0 值分配唯一串行 group（独自运行，
	// 排在显式 group 之后）。同显式值 = 并行。
	ExecutionGroup int `json:"executionGroup"`

	Arguments map[string]any `json:"arguments"` // standard fields stripped
}

// ToolResultData is the Data payload for BlockTypeToolResult. ErrorMsg is
// populated only when OK=false. ElapsedMs is end-to-end wall time.
//
// ToolResultData 是 BlockTypeToolResult 的 Data 载荷。ErrorMsg 仅 OK=false
// 时填。ElapsedMs 是端到端 wall time。
type ToolResultData struct {
	ToolCallID string `json:"toolCallId"`
	OK         bool   `json:"ok"`
	Result     string `json:"result"`
	ErrorMsg   string `json:"errorMsg,omitempty"`
	ElapsedMs  int64  `json:"elapsedMs,omitempty"`
}

// AttachmentRefData is the Data payload for BlockTypeAttachmentRef.
// AttachmentRefData 是 BlockTypeAttachmentRef 的 Data 载荷。
type AttachmentRefData struct {
	AttachmentID string `json:"attachmentId"`
	FileName     string `json:"fileName"`
	MimeType     string `json:"mimeType"`
}

// Attachment is a user-uploaded file. Bytes are at StoragePath on disk;
// row is metadata only. Soft-deletable so older conversations don't lose refs.
//
// Attachment 是用户上传文件。字节在 StoragePath；行仅元数据。
// 软删除——避免旧对话失去引用。
type Attachment struct {
	ID          string         `gorm:"primaryKey;type:text" json:"id"`
	UserID      string         `gorm:"not null;index;type:text" json:"-"`
	FileName    string         `gorm:"not null;type:text" json:"fileName"`
	MimeType    string         `gorm:"not null;type:text" json:"mimeType"`
	SizeBytes   int64          `gorm:"not null" json:"sizeBytes"`
	StoragePath string         `gorm:"not null;type:text" json:"-"`
	CreatedAt   time.Time      `json:"createdAt"`
	UpdatedAt   time.Time      `json:"updatedAt"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Attachment) TableName() string { return "attachments" }

// MaxAttachmentBytes is the upload size limit (50 MB).
// MaxAttachmentBytes 是上传大小限制（50 MB）。
const MaxAttachmentBytes = 50 * 1024 * 1024

// ListFilter is the query shape for paginated message listing.
// ListFilter 是分页消息列表的查询形状。
type ListFilter struct {
	Cursor string
	Limit  int
}

var (
	ErrMessageNotFound           = errors.New("chat: message not found")
	ErrBlockNotFound             = errors.New("chat: block not found")
	ErrStreamNotFound            = errors.New("chat: no active stream for conversation")
	ErrStreamInProgress          = errors.New("chat: stream already in progress")
	ErrProviderUnavailable       = errors.New("chat: LLM provider unavailable")
	ErrAttachmentTooLarge        = errors.New("chat: attachment exceeds 50 MB limit")
	ErrAttachmentTypeUnsupported = errors.New("chat: attachment type not supported")
	ErrAttachmentParseFailed     = errors.New("chat: attachment parse failed")
	ErrVisionNotSupported        = errors.New("chat: provider does not support vision")
)

// Repository is the storage contract for Message / Block / Attachment.
// Scoped to ctx user.
//
// Repository 是 Message / Block / Attachment 存储契约。按 ctx 用户过滤。
type Repository interface {
	// Save atomically writes Message + its Blocks; existing Blocks replaced.
	// Save 原子写 Message + Blocks；已有 Blocks 替换。
	Save(ctx context.Context, m *Message) error

	// Get fetches by id, scoped to ctx user; ErrMessageNotFound when absent.
	// Get 按 id 取，按 ctx 用户过滤；不存在返 ErrMessageNotFound。
	Get(ctx context.Context, id string) (*Message, error)

	// ListByConversation returns cursor-paginated messages with Blocks,
	// ordered by created_at ASC.
	// ListByConversation 返带 Blocks 的 cursor 分页消息，created_at ASC 排序。
	ListByConversation(ctx context.Context, conversationID string, filter ListFilter) ([]*Message, string, error)

	// SaveAttachment inserts (write-once).
	// SaveAttachment 插入（一次写）。
	SaveAttachment(ctx context.Context, a *Attachment) error

	// GetAttachment fetches by id, scoped to ctx user.
	// GetAttachment 按 id 取，按 ctx 用户过滤。
	GetAttachment(ctx context.Context, id string) (*Attachment, error)
}
