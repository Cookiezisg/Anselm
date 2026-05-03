// Package chat is the domain layer for conversation messaging.
// It owns the Message and Block entities, their lifecycle constants,
// sentinel errors, and the storage contract (Repository).
// No LLM orchestration logic lives here — that belongs in app/chat.
//
// Package chat 是对话消息的 domain 层。
// 拥有 Message 和 Block 实体、生命周期常量、sentinel 错误及存储契约（Repository）。
// 不含 LLM 编排逻辑——那部分属于 app/chat。
package chat

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

// ── Message ───────────────────────────────────────────────────────────────────

// Message is one turn in a conversation. Role identifies the speaker;
// Status tracks the generation lifecycle for assistant messages.
// Content is stored in the associated Blocks, not directly on Message.
// ErrorCode/ErrorMessage are populated only when Status="error" — they
// carry the structured failure reason so the UI can show it without
// re-parsing the assistant text or trailing tool_result blocks.
//
// Message 是对话中的一个回合。Role 标识发言方；
// Status 追踪 assistant 消息的生成生命周期。
// 内容存储在关联的 Blocks 中，不直接在 Message 上。
// ErrorCode / ErrorMessage 仅在 Status="error" 时填充——存放结构化失败原因，
// 让 UI 无需再解析 assistant 文本或 trailing tool_result block。
type Message struct {
	ID             string         `gorm:"primaryKey;type:text" json:"id"`
	ConversationID string         `gorm:"not null;index;type:text" json:"conversationId"`
	UserID         string         `gorm:"not null;type:text" json:"-"`
	Role           string         `gorm:"not null;type:text" json:"role"` // "user" | "assistant"
	Status         string         `gorm:"not null;type:text;default:'completed'" json:"status"`
	StopReason     string         `gorm:"type:text;default:''" json:"stopReason,omitempty"`
	ErrorCode      string         `gorm:"type:text;default:''" json:"errorCode,omitempty"`    // "" when Status != "error"
	ErrorMessage   string         `gorm:"type:text;default:''" json:"errorMessage,omitempty"` // "" when Status != "error"
	InputTokens    int            `gorm:"default:0" json:"inputTokens,omitempty"`
	OutputTokens   int            `gorm:"default:0" json:"outputTokens,omitempty"`
	CreatedAt      time.Time      `json:"createdAt"`
	UpdatedAt      time.Time      `json:"updatedAt"`
	DeletedAt      gorm.DeletedAt `gorm:"index" json:"-"`

	// Blocks is not a DB column — populated by the store layer after a query.
	// Blocks 不是 DB 列，由 store 层查询后填充。
	Blocks []Block `gorm:"-" json:"blocks"`
}

// TableName locks the DB table to "messages".
// TableName 把表名锁定为 "messages"。
func (Message) TableName() string { return "messages" }

// Role values for Message.Role.
// Message.Role 的取值。
const (
	RoleUser      = "user"
	RoleAssistant = "assistant"
)

// Status values for Message.Status.
// Message.Status 的取值。
const (
	StatusPending   = "pending"
	StatusStreaming = "streaming"
	StatusCompleted = "completed"
	StatusError     = "error"
	StatusCancelled = "cancelled"
)

// StopReason values for Message.StopReason (assistant messages only).
// Message.StopReason 的取值（仅 assistant 消息）。
const (
	StopReasonEndTurn   = "end_turn"
	StopReasonMaxTokens = "max_tokens"
	StopReasonCancelled = "cancelled"
	StopReasonError     = "error"
)

// ── Block ─────────────────────────────────────────────────────────────────────

// Block is one typed content element within a Message.
// All content lives in Blocks — a Message row holds only metadata.
//
// Block 是 Message 中一个有类型的内容元素。
// 所有内容都在 Block 中——Message 行只存元数据。
type Block struct {
	ID        string    `gorm:"primaryKey;type:text" json:"id"`
	MessageID string    `gorm:"not null;index:idx_mb_msg_seq,priority:1;type:text" json:"-"`
	Seq       int       `gorm:"not null;index:idx_mb_msg_seq,priority:2" json:"seq"`
	Type      string    `gorm:"not null;type:text" json:"type"`
	Data      string    `gorm:"not null;type:text" json:"data"` // JSON, structure varies by Type
	CreatedAt time.Time `json:"createdAt"`
}

// TableName locks the DB table to "message_blocks".
// TableName 把表名锁定为 "message_blocks"。
func (Block) TableName() string { return "message_blocks" }

// Block type constants.
// Block 类型常量。
const (
	BlockTypeText          = "text"
	BlockTypeReasoning     = "reasoning"
	BlockTypeToolCall      = "tool_call"
	BlockTypeToolResult    = "tool_result"
	BlockTypeAttachmentRef = "attachment_ref"
)

// ── Block data shapes ─────────────────────────────────────────────────────────
// These structs are used by app/chat to marshal/unmarshal Block.Data JSON.
// 这些结构体供 app/chat 序列化/反序列化 Block.Data JSON。

// TextData is the Data payload for BlockTypeText and BlockTypeReasoning.
// TextData 是 BlockTypeText 和 BlockTypeReasoning 的 Data 载荷。
type TextData struct {
	Text string `json:"text"`
}

// ToolCallData is the Data payload for BlockTypeToolCall.
// Arguments never contains the three framework-injected standard fields
// ("summary" / "destructive" / "execution_group") — those are stored
// separately as first-class fields here.
//
// ToolCallData 是 BlockTypeToolCall 的 Data 载荷。
// Arguments 不含三个框架注入的标准字段（"summary" / "destructive" /
// "execution_group"），三者作为一等字段独立存储。
type ToolCallData struct {
	ID   string `json:"id"`
	Name string `json:"name"`

	// Summary is the LLM-provided one-line description; may be empty when
	// the LLM omitted the (schema-required) field.
	//
	// Summary 是 LLM 提供的一句话描述；LLM 漏填 schema 必填字段时为空。
	Summary string `json:"summary"`

	// Destructive is the LLM's self-report that this call may cause
	// irreversible damage; the UI shows a warning badge when true.
	//
	// Destructive 是 LLM 自报"本次调用可能不可逆破坏"；为 true 时 UI 显示警示徽章。
	Destructive bool `json:"destructive"`

	// ExecutionGroup is the LLM's parallel-batch hint (≥1). 0 means
	// "missing/auto" — chat/tools.go's partition layer assigns a unique
	// sequential group to each 0-valued call (run alone, after any explicit
	// groups). Same explicit group value across calls = parallel batch.
	//
	// ExecutionGroup 是 LLM 自报的并行 batch 提示（≥1）。0 表示"缺失/自动"
	// ——chat/tools.go 的分批层给每个 0 值调用分配唯一的串行 group（独自运行，
	// 排在所有显式 group 之后）。多个调用的显式 group 值相同 = 并行 batch。
	ExecutionGroup int `json:"executionGroup"`

	Arguments map[string]any `json:"arguments"` // stripped of the three standard fields
}

// ToolResultData is the Data payload for BlockTypeToolResult.
// Result holds the success payload (free-form string, often JSON);
// ErrorMsg is populated only when OK=false so callers don't have to
// parse the error out of Result. ElapsedMs is end-to-end wall time.
//
// ToolResultData 是 BlockTypeToolResult 的 Data 载荷。
// Result 存成功负载（自由格式字符串，常为 JSON）；ErrorMsg 仅在 OK=false 时
// 填充，调用方无需从 Result 中再解析错误。ElapsedMs 是端到端 wall time。
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

// ── Attachment ────────────────────────────────────────────────────────────────

// Attachment is a file uploaded by the user. File bytes are stored on disk
// at StoragePath; the DB row holds only metadata. Soft-deletable so a
// deleted user-message attachment doesn't break older conversations that
// still reference it.
//
// Attachment 是用户上传的文件。文件字节存在磁盘的 StoragePath；DB 行只存元数据。
// 支持软删除——用户删除附件后，仍引用它的旧对话不会失去引用。
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

// TableName locks the DB table to "attachments".
// TableName 把表名锁定为 "attachments"。
func (Attachment) TableName() string { return "attachments" }

// MaxAttachmentBytes is the upload size limit (50 MB).
// MaxAttachmentBytes 是上传大小限制（50 MB）。
const MaxAttachmentBytes = 50 * 1024 * 1024

// ── ListFilter ────────────────────────────────────────────────────────────────

// ListFilter is the query shape for paginated message listing.
// ListFilter 是分页消息列表的查询形状。
type ListFilter struct {
	Cursor string
	Limit  int
}

// ── Sentinel errors ───────────────────────────────────────────────────────────

var (
	ErrMessageNotFound           = errors.New("chat: message not found")
	ErrStreamNotFound            = errors.New("chat: no active stream for conversation")
	ErrStreamInProgress          = errors.New("chat: stream already in progress")
	ErrProviderUnavailable       = errors.New("chat: LLM provider unavailable")
	ErrAttachmentTooLarge        = errors.New("chat: attachment exceeds 50 MB limit")
	ErrAttachmentTypeUnsupported = errors.New("chat: attachment type not supported")
	ErrAttachmentParseFailed     = errors.New("chat: attachment parse failed")
	ErrVisionNotSupported        = errors.New("chat: provider does not support vision")
)

// ── Repository ────────────────────────────────────────────────────────────────

// Repository is the storage contract for Message, Block, and Attachment.
// Implementations scope every query to the userID in ctx.
//
// Implemented by: infra/store/chat.Store
// Consumer:       app/chat.Service only
//
// Repository 是 Message、Block 和 Attachment 的存储契约。
// 实现按 ctx 中的 userID 过滤所有查询。
type Repository interface {
	// Save inserts or updates a Message and its Blocks atomically.
	// Callers populate m.Blocks before calling; existing blocks are replaced.
	//
	// Save 原子地插入或更新 Message 及其 Blocks。
	// 调用方在调用前填充 m.Blocks；已有 blocks 会被替换。
	Save(ctx context.Context, m *Message) error

	// Get fetches a single Message by id, scoped to the current user.
	// Returns ErrMessageNotFound if no live record matches.
	//
	// Get 按 id 查单条 Message，按当前用户过滤。未命中返回 ErrMessageNotFound。
	Get(ctx context.Context, id string) (*Message, error)

	// ListByConversation returns cursor-paginated messages with their Blocks,
	// ordered by created_at ASC (chronological).
	//
	// ListByConversation 返回带 Blocks 的 cursor 分页消息，按 created_at ASC 排序。
	ListByConversation(ctx context.Context, conversationID string, filter ListFilter) ([]*Message, string, error)

	// SaveAttachment inserts an Attachment record (write-once).
	// SaveAttachment 插入 Attachment 记录（仅写一次）。
	SaveAttachment(ctx context.Context, a *Attachment) error

	// GetAttachment fetches an Attachment by id, scoped to the current user.
	// GetAttachment 按 id 查 Attachment，按当前用户过滤。
	GetAttachment(ctx context.Context, id string) (*Attachment, error)
}
