// Package eventlog defines the recursive event-log protocol — 5 event
// types and 6 block types that together describe every UI-visible
// happening in a conversation. Replaces the entity-snapshot model in
// domain/events. See documents/version-1.2/event-log-protocol.md.
//
// Package eventlog 定义递归事件日志协议——5 种事件 + 6 种 block 描述
// 对话中所有 UI 可见事件。替换 domain/events 的 entity-snapshot 模型。
// 详见 documents/version-1.2/event-log-protocol.md。
package eventlog

import (
	"errors"
	"fmt"
)

// Event is a unit of the protocol. Concrete types (5 of them — exhaustive)
// are MessageStart / MessageStop / BlockStart / BlockDelta / BlockStop.
// New types must be added to the protocol spec first, then here.
//
// Event 是协议的一个单位。5 种穷举具体类型是 MessageStart / MessageStop /
// BlockStart / BlockDelta / BlockStop。新增必须先改协议文档再加。
type Event interface {
	// EventType returns the wire-level event name (snake_case).
	// EventType 返回 wire 层事件名（snake_case）。
	EventType() string
}

// Envelope wraps an Event with its bridge-assigned sequence number.
// Bridge owns seq generation; producers do not set Seq in the payload.
//
// Envelope 给 Event 套上 bridge 分配的 sequence 号。
// Bridge 拥有 seq 生成；producer 不在 payload 里设 Seq。
type Envelope struct {
	Seq   int64
	Event Event
}

// ── Block type enumeration (6, exhaustive) ───────────────────────────
//
// Adding a new block type requires changing the protocol doc + DB CHECK
// constraint + frontend renderer in the same PR.
//
// 新增 block 类型必须同 PR 改协议文档 + DB CHECK 约束 + 前端 renderer。

const (
	// BlockTypeText is LLM main text (including narration between tool calls).
	// BlockTypeText 是 LLM 主文本（含 tool_call 间的叙述）。
	BlockTypeText = "text"

	// BlockTypeReasoning is LLM extended-thinking output, collapsible in UI.
	// BlockTypeReasoning 是 LLM 思考输出，UI 可折叠。
	BlockTypeReasoning = "reasoning"

	// BlockTypeToolCall is an LLM-issued tool call. Content streams the
	// args JSON; children are tool_result / progress / nested message.
	//
	// BlockTypeToolCall 是 LLM 发起的工具调用。Content 流式接收 args
	// JSON；子 block 是 tool_result / progress / nested message。
	BlockTypeToolCall = "tool_call"

	// BlockTypeToolResult is a tool's final return value. No children.
	// BlockTypeToolResult 是工具最终返回值。无子。
	BlockTypeToolResult = "tool_result"

	// BlockTypeProgress is a tool's intermediate progress output (sandbox
	// install logs, network fetch chunks). attrs.stage is free-form text.
	//
	// BlockTypeProgress 是工具中间进度（sandbox 装包日志、网络拉块）。
	// attrs.stage 是自由文本。
	BlockTypeProgress = "progress"

	// BlockTypeMessage is a placeholder for a nested message (subagent
	// run, or any "it's running its own conversation"). attrs.messageId
	// points to the actual message row whose content is the children.
	//
	// BlockTypeMessage 是嵌套 message 占位（subagent run，或任何"它在
	// 跑独立对话"）。attrs.messageId 指向真实 message 行，其内容是子。
	BlockTypeMessage = "message"
)

// IsValidBlockType reports whether t is one of the 6 enumerated block types.
//
// IsValidBlockType 报告 t 是否 6 种枚举之一。
func IsValidBlockType(t string) bool {
	switch t {
	case BlockTypeText, BlockTypeReasoning, BlockTypeToolCall,
		BlockTypeToolResult, BlockTypeProgress, BlockTypeMessage:
		return true
	}
	return false
}

// ── Status enumeration (4, exhaustive) ───────────────────────────────

const (
	StatusStreaming = "streaming"
	StatusCompleted = "completed"
	StatusError     = "error"
	StatusCancelled = "cancelled"
)

// IsValidStatus reports whether s is one of the 4 enumerated statuses.
//
// IsValidStatus 报告 s 是否 4 种枚举之一。
func IsValidStatus(s string) bool {
	switch s {
	case StatusStreaming, StatusCompleted, StatusError, StatusCancelled:
		return true
	}
	return false
}

// ── 5 event types (exhaustive) ───────────────────────────────────────
//
// All structs carry ConversationID for self-contained JSON wire form
// (Bridge.Publish takes it as a separate arg too — caller must keep
// them consistent; Bridge does not validate).
//
// 所有 struct 带 ConversationID 让 JSON 自描述（Bridge.Publish 也单独
// 收一个——调用方保证一致；Bridge 不验证）。

// MessageStart opens a new message. Top-level messages have empty
// ParentBlockID; nested messages (subagent runs) point to the tool_call
// block that triggered them.
//
// MessageStart 开新 message。顶层 message 的 ParentBlockID 为空；
// 嵌套 message（subagent）指向触发它的 tool_call block。
type MessageStart struct {
	ConversationID string         `json:"conversationId"`
	ID             string         `json:"id"`
	ParentBlockID  string         `json:"parentBlockId,omitempty"`
	Role           string         `json:"role"`
	Attrs          map[string]any `json:"attrs,omitempty"`
}

// EventType returns "message_start".
//
// EventType 返回 "message_start"。
func (MessageStart) EventType() string { return "message_start" }

// MessageStop closes a message with terminal status + optional metadata.
//
// MessageStop 关闭 message，终态 + 可选元数据。
type MessageStop struct {
	ConversationID string `json:"conversationId"`
	ID             string `json:"id"`
	Status         string `json:"status"`
	StopReason     string `json:"stopReason,omitempty"`
	ErrorCode      string `json:"errorCode,omitempty"`
	ErrorMessage   string `json:"errorMessage,omitempty"`
	InputTokens    int    `json:"inputTokens,omitempty"`
	OutputTokens   int    `json:"outputTokens,omitempty"`
}

// EventType returns "message_stop".
//
// EventType 返回 "message_stop"。
func (MessageStop) EventType() string { return "message_stop" }

// BlockStart opens a block under ParentID. ParentID may be a message ID
// (top-level block in that message) or another block ID (nested block —
// e.g. progress under tool_call). MessageID is the top-level message
// the block ultimately belongs to (redundant with ParentID chain but
// convenient for frontends).
//
// BlockStart 在 ParentID 下开 block。ParentID 可以是 message ID（该
// message 下的顶层 block）或另一个 block ID（嵌套——如 tool_call 下的
// progress）。MessageID 是 block 最终归属的顶层 message（与 ParentID 链
// 冗余但前端方便）。
type BlockStart struct {
	ConversationID string         `json:"conversationId"`
	ID             string         `json:"id"`
	ParentID       string         `json:"parentId"`
	MessageID      string         `json:"messageId"`
	BlockType      string         `json:"blockType"`
	Attrs          map[string]any `json:"attrs,omitempty"`
}

// EventType returns "block_start".
//
// EventType 返回 "block_start"。
func (BlockStart) EventType() string { return "block_start" }

// BlockDelta appends Delta to an open block. Append-only — frontends
// never overwrite, never reorder, just concatenate.
//
// BlockDelta 给开着的 block 追加 Delta。append-only——前端不重写、不
// 重排，纯拼接。
type BlockDelta struct {
	ConversationID string `json:"conversationId"`
	ID             string `json:"id"`
	Delta          string `json:"delta"`
}

// EventType returns "block_delta".
//
// EventType 返回 "block_delta"。
func (BlockDelta) EventType() string { return "block_delta" }

// BlockStop closes a block with terminal status. Error is non-empty
// only when Status == StatusError.
//
// BlockStop 关闭 block，终态。Error 仅 Status == StatusError 时非空。
type BlockStop struct {
	ConversationID string `json:"conversationId"`
	ID             string `json:"id"`
	Status         string `json:"status"`
	Error          string `json:"error,omitempty"`
}

// EventType returns "block_stop".
//
// EventType 返回 "block_stop"。
func (BlockStop) EventType() string { return "block_stop" }

// ── Sentinels ────────────────────────────────────────────────────────

// ErrSeqTooOld is returned by Bridge.Subscribe when the requested
// fromSeq has been evicted from the replay buffer. The client must
// re-fetch full state via the HTTP history endpoint.
//
// ErrSeqTooOld 由 Bridge.Subscribe 在 fromSeq 已被 replay buffer 淘汰
// 时返回。客户端必须经 HTTP 历史端点 refetch 全态。
var ErrSeqTooOld = errors.New("eventlog: requested seq too old (evicted from replay buffer)")

// ErrInvalidEvent is returned when a payload fails minimal shape checks
// (empty ConversationID, unknown block type, etc.). Bridge implementations
// MUST NOT silently drop — they must return this so producers see the bug.
//
// ErrInvalidEvent 在 payload 最小形状检查失败时返回（空 ConversationID、
// 未知 block 类型等）。Bridge 实现禁止静默丢弃——必须返回让 producer
// 看到 bug。
var ErrInvalidEvent = errors.New("eventlog: invalid event")

// ValidateEvent runs minimal shape checks on e. Empty ConversationID
// and unknown enum values fail; missing optional fields do not. Bridge
// implementations call this in Publish so the violation surfaces at
// the boundary closest to the producer.
//
// ValidateEvent 跑 e 的最小形状检查。空 ConversationID 和未知枚举值失败；
// 可选字段空不算。Bridge 实现在 Publish 调用，让违规在最接近 producer
// 的边界暴露。
func ValidateEvent(e Event) error {
	switch ev := e.(type) {
	case MessageStart:
		if ev.ConversationID == "" {
			return fmt.Errorf("%w: MessageStart.ConversationID empty", ErrInvalidEvent)
		}
		if ev.ID == "" {
			return fmt.Errorf("%w: MessageStart.ID empty", ErrInvalidEvent)
		}
		if ev.Role == "" {
			return fmt.Errorf("%w: MessageStart.Role empty", ErrInvalidEvent)
		}
	case MessageStop:
		if ev.ConversationID == "" {
			return fmt.Errorf("%w: MessageStop.ConversationID empty", ErrInvalidEvent)
		}
		if ev.ID == "" {
			return fmt.Errorf("%w: MessageStop.ID empty", ErrInvalidEvent)
		}
		if !IsValidStatus(ev.Status) {
			return fmt.Errorf("%w: MessageStop.Status=%q", ErrInvalidEvent, ev.Status)
		}
	case BlockStart:
		if ev.ConversationID == "" {
			return fmt.Errorf("%w: BlockStart.ConversationID empty", ErrInvalidEvent)
		}
		if ev.ID == "" {
			return fmt.Errorf("%w: BlockStart.ID empty", ErrInvalidEvent)
		}
		if ev.ParentID == "" {
			return fmt.Errorf("%w: BlockStart.ParentID empty", ErrInvalidEvent)
		}
		if ev.MessageID == "" {
			return fmt.Errorf("%w: BlockStart.MessageID empty", ErrInvalidEvent)
		}
		if !IsValidBlockType(ev.BlockType) {
			return fmt.Errorf("%w: BlockStart.BlockType=%q", ErrInvalidEvent, ev.BlockType)
		}
	case BlockDelta:
		if ev.ConversationID == "" {
			return fmt.Errorf("%w: BlockDelta.ConversationID empty", ErrInvalidEvent)
		}
		if ev.ID == "" {
			return fmt.Errorf("%w: BlockDelta.ID empty", ErrInvalidEvent)
		}
	case BlockStop:
		if ev.ConversationID == "" {
			return fmt.Errorf("%w: BlockStop.ConversationID empty", ErrInvalidEvent)
		}
		if ev.ID == "" {
			return fmt.Errorf("%w: BlockStop.ID empty", ErrInvalidEvent)
		}
		if !IsValidStatus(ev.Status) {
			return fmt.Errorf("%w: BlockStop.Status=%q", ErrInvalidEvent, ev.Status)
		}
	default:
		return fmt.Errorf("%w: unknown event type %T", ErrInvalidEvent, e)
	}
	return nil
}
