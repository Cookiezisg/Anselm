// execution_log.go — per-entity Function execution history (D22). Each row
// is the terminal record of one Service.RunFunction call;status enumerates
// ok/failed/cancelled/timeout. Common 16 fields per spec/08-executions.md §2
// plus the function-specific FunctionID / VersionID / PythonVersion.
//
// execution_log.go —— per-entity Function 执行历史(D22)。每行是一次
// Service.RunFunction 的终态记录。

package function

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

// Execution status enumeration (4 terminal states).
//
// Execution 状态枚举(4 终态)。
const (
	ExecutionStatusOK        = "ok"
	ExecutionStatusFailed    = "failed"
	ExecutionStatusCancelled = "cancelled"
	ExecutionStatusTimeout   = "timeout"
)

// Execution trigger sources (4 fixed values).
//
// Execution 触发源(4 固定值)。
const (
	TriggeredByChat     = "chat"
	TriggeredByWorkflow = "workflow"
	TriggeredByHTTP     = "http"
	TriggeredByTest     = "test"
)

// Execution is one terminal record of a Service.RunFunction call. Written
// once per RunFunction completion (success / failure / timeout / cancel) via
// Service.recordExecution with a detached context (§S9). Schema follows
// spec/08-executions.md §2 (common 16) + §4.1 (function-specific).
//
// Execution 是一次 Service.RunFunction 完成后的终态记录。Service.
// recordExecution 用 detached ctx 写(§S9)。
type Execution struct {
	// Common 16
	ID             string         `gorm:"primaryKey;type:text" json:"id"`
	UserID         string         `gorm:"not null;index:idx_fne_user_id;type:text" json:"userId"`
	Status         string         `gorm:"not null;check:status IN ('ok','failed','cancelled','timeout');type:text" json:"status"`
	TriggeredBy    string         `gorm:"not null;check:triggered_by IN ('chat','workflow','http','test');type:text" json:"triggeredBy"`
	Input          map[string]any `gorm:"serializer:json;type:text;default:'{}'" json:"input"`
	Output         any            `gorm:"serializer:json;type:text" json:"output,omitempty"`
	ErrorCode      string         `gorm:"type:text;default:''" json:"errorCode,omitempty"`
	ErrorMessage   string         `gorm:"type:text;default:''" json:"errorMessage,omitempty"`
	ElapsedMs      int64          `gorm:"not null;default:0" json:"elapsedMs"`
	StartedAt      time.Time      `gorm:"not null;index:idx_fne_started_at,sort:desc" json:"startedAt"`
	EndedAt        time.Time      `gorm:"not null" json:"endedAt"`
	ConversationID string         `gorm:"type:text;default:'';index:idx_fne_conv,priority:1" json:"conversationId,omitempty"`
	MessageID      string         `gorm:"type:text;default:'';index:idx_fne_conv,priority:2" json:"messageId,omitempty"`
	ToolCallID     string         `gorm:"type:text;default:''" json:"toolCallId,omitempty"`
	FlowrunID      string         `gorm:"type:text;default:'';index:idx_fne_flowrun,priority:1" json:"flowrunId,omitempty"`
	FlowrunNodeID  string         `gorm:"type:text;default:''" json:"flowrunNodeId,omitempty"`

	// Function-specific
	FunctionID    string `gorm:"not null;type:text;index:idx_fne_function,priority:1" json:"functionId"`
	VersionID     string `gorm:"not null;type:text" json:"versionId"`
	PythonVersion string `gorm:"type:text;default:''" json:"pythonVersion,omitempty"`

	CreatedAt time.Time      `gorm:"index:idx_fne_function,priority:2,sort:desc" json:"createdAt"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Execution) TableName() string { return "function_executions" }

// ExecutionFilter is the query shape for Repository.ListExecutions /
// Service.SearchExecutions. Empty fields = no filter on that dimension.
//
// ExecutionFilter 是 ListExecutions/SearchExecutions 的查询形状。
type ExecutionFilter struct {
	FunctionID     string
	VersionID      string
	Status         string
	ConversationID string
	FlowrunID      string
	Since          *time.Time
	Until          *time.Time
	Limit          int
	Cursor         string
}

// ExecutionAggregates is the rollup returned alongside the page of executions
// — lets the LLM at-a-glance see "ok_count vs failed_count" before drilling in.
//
// ExecutionAggregates 是分页结果旁的聚合,让 LLM 一眼看到 ok / failed 比例。
type ExecutionAggregates struct {
	OKCount        int   `json:"okCount"`
	FailedCount    int   `json:"failedCount"`
	CancelledCount int   `json:"cancelledCount"`
	TimeoutCount   int   `json:"timeoutCount"`
	AvgElapsedMs   int64 `json:"avgElapsedMs"`
	P95ElapsedMs   int64 `json:"p95ElapsedMs"`
}

// ErrExecutionNotFound is returned when GET-by-id misses.
//
// ErrExecutionNotFound 在按 id 查未命中时返。
var ErrExecutionNotFound = errors.New("function: execution not found")

// ExecutionRepository extends the function Repository with execution-log
// methods. Kept as a separate interface so a future "no logs" deployment
// can wire a no-op Repository without breaking ExecutionRepository
// requirements.
//
// ExecutionRepository 是 Repository 的扩展接口,带 execution log 方法。
// 单独接口让未来"不记日志"的部署可以挂 no-op 实现。
type ExecutionRepository interface {
	SaveExecution(ctx context.Context, e *Execution) error
	GetExecutionByID(ctx context.Context, id string) (*Execution, error)
	ListExecutions(ctx context.Context, filter ExecutionFilter) ([]*Execution, string, error)
	ComputeAggregates(ctx context.Context, filter ExecutionFilter) (ExecutionAggregates, error)
}
