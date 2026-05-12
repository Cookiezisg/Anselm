// node.go — FlowRunNode entity per spec/08-executions.md §4.5. One row
// per node dispatch within a FlowRun (capability nodes also write a
// second row to their entity execution log table — function_executions
// / handler_calls / mcp_calls / skill_executions — cross-linked via
// flowrun_node_id).
//
// node.go —— FlowRunNode 实体(spec 08 §4.5)。每节点 dispatch 写一行;
// capability 节点(function/handler/mcp/skill)同时写对应 entity 表,
// 经 flowrun_node_id 字段交叉引用。

package flowrun

import (
	"errors"
	"time"

	"gorm.io/gorm"
)

// Node status values (4 terminal + 2 transient). Aligns with common
// 16-field schema (08 §2) but adds `pending` / `running` / `skipped`
// for control-flow nodes (condition / loop branch unselected, etc.).
//
// Node 状态值(4 终态 + 2 过渡)。对齐通用 16 字段 schema;另加 pending /
// running / skipped 给控制流节点用。
const (
	NodeStatusPending   = "pending"
	NodeStatusRunning   = "running"
	NodeStatusOK        = "ok"
	NodeStatusFailed    = "failed"
	NodeStatusCancelled = "cancelled"
	NodeStatusTimeout   = "timeout"
	NodeStatusSkipped   = "skipped"
)

// Node is one node-dispatch record within a FlowRun. Schema follows
// spec/08-executions.md §2 (common 16) + §4.5 (flowrun-specific:
// node_id / node_type / attempts).
//
// Node 是 FlowRun 内一次节点 dispatch 的记录;schema 走 spec 08 §2 + §4.5。
type Node struct {
	// Common 16
	ID             string         `gorm:"primaryKey;type:text" json:"id"`
	UserID         string         `gorm:"not null;index:idx_frn_user_id;type:text" json:"userId"`
	Status         string         `gorm:"not null;check:status IN ('pending','running','ok','failed','cancelled','timeout','skipped');type:text" json:"status"`
	TriggeredBy    string         `gorm:"not null;check:triggered_by IN ('chat','workflow','http','test');type:text" json:"triggeredBy"`
	Input          map[string]any `gorm:"serializer:json;type:text;default:'{}'" json:"input"`
	Output         any            `gorm:"serializer:json;type:text" json:"output,omitempty"`
	ErrorCode      string         `gorm:"type:text;default:''" json:"errorCode,omitempty"`
	ErrorMessage   string         `gorm:"type:text;default:''" json:"errorMessage,omitempty"`
	ElapsedMs      int64          `gorm:"not null;default:0" json:"elapsedMs"`
	StartedAt      time.Time      `gorm:"not null;index:idx_frn_started_at,sort:desc" json:"startedAt"`
	EndedAt        time.Time      `gorm:"not null" json:"endedAt"`
	ConversationID string         `gorm:"type:text;default:'';index:idx_frn_conv,priority:1" json:"conversationId,omitempty"`
	MessageID      string         `gorm:"type:text;default:'';index:idx_frn_conv,priority:2" json:"messageId,omitempty"`
	ToolCallID     string         `gorm:"type:text;default:''" json:"toolCallId,omitempty"`
	FlowrunID      string         `gorm:"not null;type:text;index:idx_frn_flowrun,priority:1" json:"flowrunId"`
	FlowrunNodeID  string         `gorm:"type:text;default:''" json:"flowrunNodeId,omitempty"`

	// Flowrun-specific (per spec 08 §4.5)
	NodeID   string `gorm:"not null;type:text" json:"nodeId"`
	NodeType string `gorm:"not null;type:text" json:"nodeType"`
	Attempts int    `gorm:"not null;default:1" json:"attempts"`

	CreatedAt time.Time      `gorm:"index:idx_frn_flowrun,priority:2,sort:desc" json:"createdAt"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

// TableName pins the table name (matches function_executions / handler_calls
// naming pattern — singular entity + plural collection).
//
// TableName 显式指定表名。
func (Node) TableName() string { return "flowrun_nodes" }

// NodeFilter is the query shape for Repository.ListNodes.
//
// NodeFilter 是 ListNodes 查询形状。
type NodeFilter struct {
	FlowrunID      string
	NodeType       string
	Status         string
	ConversationID string
	Cursor         string
	Limit          int
}

// ErrNodeNotFound is returned when GetNode misses.
//
// ErrNodeNotFound 是 GetNode 未命中时返。
var ErrNodeNotFound = errors.New("flowrun: node not found")
