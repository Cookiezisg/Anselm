// call_log.go — per-entity Handler call history (D22). Each row is the terminal
// record of one Service.Call invocation. Common 16 fields per spec/08-
// executions.md §2 plus handler-specific (handler_id / version_id / method /
// instance_id / owner_kind / owner_id — 6 fields vs function's 3).
//
// call_log.go —— per-entity Handler 调用历史(D22)。共 16 通用字段 + 6 handler 专属。

package handler

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

// Call status enumeration. Same 4 terminal states as function executions.
//
// Call 状态(跟 function execution 同 4 终态)。
const (
	CallStatusOK        = "ok"
	CallStatusFailed    = "failed"
	CallStatusCancelled = "cancelled"
	CallStatusTimeout   = "timeout"
)

// Call is one terminal record of a Service.Call. Written by Service.recordCall
// after the method invocation returns (or fails). Schema per spec/08-executions
// §2 common 16 + §4.2 handler-specific.
//
// Call 是 Service.Call 完成后的终态记录,由 Service.recordCall 写。
type Call struct {
	// Common 16
	ID             string         `gorm:"primaryKey;type:text" json:"id"`
	UserID         string         `gorm:"not null;index:idx_hcl_user_id;type:text" json:"userId"`
	Status         string         `gorm:"not null;check:status IN ('ok','failed','cancelled','timeout');type:text" json:"status"`
	TriggeredBy    string         `gorm:"not null;check:triggered_by IN ('chat','workflow','http','test');type:text" json:"triggeredBy"`
	Input          map[string]any `gorm:"serializer:json;type:text;default:'{}'" json:"input"`
	Output         any            `gorm:"serializer:json;type:text" json:"output,omitempty"`
	ErrorCode      string         `gorm:"type:text;default:''" json:"errorCode,omitempty"`
	ErrorMessage   string         `gorm:"type:text;default:''" json:"errorMessage,omitempty"`
	ElapsedMs      int64          `gorm:"not null;default:0" json:"elapsedMs"`
	StartedAt      time.Time      `gorm:"not null;index:idx_hcl_started_at,sort:desc" json:"startedAt"`
	EndedAt        time.Time      `gorm:"not null" json:"endedAt"`
	ConversationID string         `gorm:"type:text;default:'';index:idx_hcl_conv,priority:1" json:"conversationId,omitempty"`
	MessageID      string         `gorm:"type:text;default:'';index:idx_hcl_conv,priority:2" json:"messageId,omitempty"`
	ToolCallID     string         `gorm:"type:text;default:''" json:"toolCallId,omitempty"`
	FlowrunID      string         `gorm:"type:text;default:'';index:idx_hcl_flowrun,priority:1" json:"flowrunId,omitempty"`
	FlowrunNodeID  string         `gorm:"type:text;default:''" json:"flowrunNodeId,omitempty"`

	// Handler-specific (6 fields)
	HandlerID  string `gorm:"not null;type:text;index:idx_hcl_handler,priority:1" json:"handlerId"`
	VersionID  string `gorm:"not null;type:text" json:"versionId"`
	Method     string `gorm:"not null;type:text;index:idx_hcl_method" json:"method"`
	InstanceID string `gorm:"type:text;default:''" json:"instanceId,omitempty"`
	OwnerKind  string `gorm:"type:text;default:''" json:"ownerKind,omitempty"`
	OwnerID    string `gorm:"type:text;default:''" json:"ownerId,omitempty"`

	CreatedAt time.Time      `gorm:"index:idx_hcl_handler,priority:2,sort:desc" json:"createdAt"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Call) TableName() string { return "handler_calls" }

// CallFilter is the query shape for Repository.ListCalls / Service.SearchCalls.
//
// CallFilter ListCalls/SearchCalls 的查询形状。
type CallFilter struct {
	HandlerID      string
	VersionID      string
	Method         string
	InstanceID     string
	OwnerKind      string
	Status         string
	ConversationID string
	FlowrunID      string
	Since          *time.Time
	Until          *time.Time
	Limit          int
	Cursor         string
}

// CallAggregates is the rollup returned alongside the page (same shape as
// function ExecutionAggregates).
//
// CallAggregates 调用聚合(跟 function ExecutionAggregates 同形)。
type CallAggregates struct {
	OKCount        int   `json:"okCount"`
	FailedCount    int   `json:"failedCount"`
	CancelledCount int   `json:"cancelledCount"`
	TimeoutCount   int   `json:"timeoutCount"`
	AvgElapsedMs   int64 `json:"avgElapsedMs"`
	P95ElapsedMs   int64 `json:"p95ElapsedMs"`
}

// ErrCallNotFound is returned when GET-by-id misses.
//
// ErrCallNotFound 按 id 查未命中时返。
var ErrCallNotFound = errors.New("handler: call not found")

// CallRepository extends the handler Repository with call-log methods. Kept
// as a separate interface so a "no logs" deployment could wire a no-op.
//
// CallRepository 扩展 Repository 加 call-log;独立接口让 no-op 部署可行。
type CallRepository interface {
	SaveCall(ctx context.Context, c *Call) error
	GetCallByID(ctx context.Context, id string) (*Call, error)
	ListCalls(ctx context.Context, filter CallFilter) ([]*Call, string, error)
	ComputeCallAggregates(ctx context.Context, filter CallFilter) (CallAggregates, error)
}
