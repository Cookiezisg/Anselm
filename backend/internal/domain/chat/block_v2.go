// block_v2.go — new Block model for the recursive event-log protocol.
// Coexists with the legacy Block during Phase 1; Phase 4 cutover renames
// message_blocks_v2 → message_blocks and deletes the legacy struct +
// related store paths.
//
// New columns vs legacy Block:
//   - ConversationID: redundant with messages.conversation_id but lets
//     replay queries skip the join.
//   - ParentBlockID: nullable; empty = top-level block of the message
//     (event-side, ParentID = messageID for top-level blocks).
//   - Seq: per-conversation monotonic event sequence (legacy was
//     per-message). Carries the Bridge-assigned event seq.
//   - Attrs (JSON): replaces legacy Data. Pure metadata; streamed text
//     content moved to Content column.
//   - Content: append-only flow body. Concatenation of all BlockDelta.
//   - Status / Error: terminal state from BlockStop.
//   - UpdatedAt: GORM-maintained; legacy Block had only CreatedAt.
//
// See documents/version-1.2/event-log-protocol.md §6.
//
// block_v2.go ——递归事件日志协议的新 Block 模型。Phase 1 与 legacy Block
// 共存；Phase 4 cutover 把 message_blocks_v2 重命名回 message_blocks，删
// 旧 struct + store 路径。
//
// 新增列对比 legacy：
//   - ConversationID：与 messages.conversation_id 冗余，但 replay 查询
//     可跳过 join。
//   - ParentBlockID：可空；空 = 该 message 的顶层 block（事件侧，
//     ParentID = messageID 表示顶层 block）。
//   - Seq：per-conversation 单调事件序号（legacy 是 per-message）。
//     承载 Bridge 分配的 event seq。
//   - Attrs（JSON）：替代 legacy 的 Data。纯元数据；流式正文移到 Content。
//   - Content：append-only 流式正文。所有 BlockDelta 的拼接。
//   - Status / Error：来自 BlockStop 的终态。
//   - UpdatedAt：GORM 自动维护；legacy 仅有 CreatedAt。
package chat

import (
	"time"
)

// BlockV2 is the new Block row backing the recursive event-log protocol.
//
// CHECK constraints on Type / Status are declared via GORM tag (project
// precedent: see sandbox.SandboxEnv.OwnerKind). The 6/4 enumerated values
// are the closed sets defined in domain/eventlog.
//
// BlockV2 是递归事件日志协议背后的新 Block 行。
//
// Type / Status 的 CHECK 约束经 GORM tag 声明（项目惯例：参 sandbox
// .SandboxEnv.OwnerKind）。6/4 枚举值是 domain/eventlog 定义的封闭集合。
type BlockV2 struct {
	ID             string    `gorm:"primaryKey;type:text" json:"id"`
	ConversationID string    `gorm:"not null;type:text;uniqueIndex:idx_blocks_v2_conv_seq,priority:1" json:"conversationId"`
	MessageID      string    `gorm:"not null;type:text;index" json:"messageId"`
	ParentBlockID  string    `gorm:"type:text;index" json:"parentBlockId,omitempty"`
	Seq            int64     `gorm:"not null;uniqueIndex:idx_blocks_v2_conv_seq,priority:2" json:"seq"`
	Type           string    `gorm:"not null;type:text;check:type IN ('text','reasoning','tool_call','tool_result','progress','message')" json:"type"`
	Attrs          string    `gorm:"type:text" json:"attrs,omitempty"` // JSON
	Content        string    `gorm:"not null;type:text;default:''" json:"content"`
	Status         string    `gorm:"not null;type:text;check:status IN ('streaming','completed','error','cancelled')" json:"status"`
	Error          string    `gorm:"type:text" json:"error,omitempty"`
	CreatedAt      time.Time `json:"createdAt"`
	UpdatedAt      time.Time `json:"updatedAt"`
}

// TableName fixes the table to message_blocks_v2 during Phase 1.
// Phase 4 migration renames it to message_blocks (after legacy table drop).
//
// TableName 在 Phase 1 固定为 message_blocks_v2。
// Phase 4 迁移把它改名回 message_blocks（旧表删后）。
func (BlockV2) TableName() string { return "message_blocks_v2" }
