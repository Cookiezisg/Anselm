// Package agent is the domain layer for Agent entities — the 4th forge entity (quadrinity).
// Agent = a configured LLM worker: prompt + skill (0-1) + knowledge (doc refs) + tools (fn/hd/mcp)
// + outputSchema + model override. Agents are versioned, pending/accept cycle mirrors function/handler.
//
// Package agent 是 Agent 实体的 domain 层（quadrinity 第四元）。
// Agent = 配置好的 LLM worker：prompt/skill/knowledge/tools/outputSchema/model。
// 有版本管理，pending/accept 周期与 function/handler 相同。
package agent

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

// OutputSchemaKind enumerates the three valid outputSchema modes (doc 09/13/15).
type OutputSchemaKind string

const (
	OutputSchemaFreeText   OutputSchemaKind = "free_text"
	OutputSchemaEnum       OutputSchemaKind = "enum"
	OutputSchemaJSONSchema OutputSchemaKind = "json_schema"
)

// Agent is the top-level forge entity (ag_ prefix). Mutable fields go on AgentVersion.
//
// Agent 是顶层锻造实体(ag_ 前缀)。可变字段在 AgentVersion。
type Agent struct {
	ID          string         `gorm:"primaryKey;type:text" json:"id"`
	UserID      string         `gorm:"not null;type:text;index" json:"userId"`
	Name        string         `gorm:"not null;uniqueIndex:uq_agent_name_user,priority:1;index:uq_agent_name_user,priority:2;type:text" json:"name"`
	Description string         `gorm:"type:text;default:''" json:"description"`
	Tags        []string       `gorm:"serializer:json;type:text;default:'[]'" json:"tags"`
	// ActiveVersionID is the accepted version currently in production.
	ActiveVersionID string `gorm:"type:text;default:''" json:"activeVersionId,omitempty"`
	NeedsAttention  bool   `gorm:"not null;default:false" json:"needsAttention"`
	CreatedAt       time.Time      `json:"createdAt"`
	UpdatedAt       time.Time      `json:"updatedAt"`
	DeletedAt       gorm.DeletedAt `gorm:"index" json:"-"`

	// Populated on demand — not stored.
	ActiveVersion *AgentVersion `gorm:"-" json:"activeVersion,omitempty"`
	Pending       *AgentVersion `gorm:"-" json:"pending,omitempty"`
}

func (Agent) TableName() string { return "agents" }

// OutputSchema specifies how the agent's final output should be shaped.
//
// OutputSchema 指定 agent 最终输出的形态。
type OutputSchema struct {
	Kind   OutputSchemaKind `json:"kind"`
	Schema map[string]any   `json:"schema,omitempty"` // used when Kind=json_schema
	Enums  []string         `json:"enums,omitempty"`  // used when Kind=enum
}

// ToolRef is a reference to a callable that the agent can use.
// Only fn_/hd_/mcp: prefixes are valid — no ag_ (agents cannot call agents).
//
// ToolRef 是 agent 可用的 callable 引用;只允许 fn_/hd_/mcp:，不允许 ag_（员工不调员工）。
type ToolRef struct {
	Ref  string `json:"ref"`  // fn_xxx, hd_xxx.method, mcp:server/tool
	Name string `json:"name"` // display name (resolved at runtime)
}

// AgentVersion is one immutable snapshot of an agent's configuration.
//
// AgentVersion 是 agent 配置的一份不可变快照。
type AgentVersion struct {
	ID      string `gorm:"primaryKey;type:text" json:"id"`
	AgentID string `gorm:"not null;type:text;index" json:"agentId"`
	UserID  string `gorm:"not null;type:text;index" json:"userId"`

	Prompt  string `gorm:"not null;type:text" json:"prompt"`
	// Skill is an optional single skill name to pre-activate.
	Skill string `gorm:"type:text;default:''" json:"skill,omitempty"`
	// Knowledge is a list of document IDs to attach as knowledge.
	Knowledge    []string      `gorm:"serializer:json;type:text;default:'[]'" json:"knowledge"`
	// Tools are callable refs available to this agent (no ag_ refs).
	Tools        []ToolRef     `gorm:"serializer:json;type:text;default:'[]'" json:"tools"`
	OutputSchema *OutputSchema `gorm:"serializer:json;type:text" json:"outputSchema,omitempty"`
	// ModelOverride: if non-empty, overrides the default agent scenario model.
	ModelOverride string `gorm:"type:text;default:''" json:"modelOverride,omitempty"`

	// Version is the 1-based version number (assigned on accept).
	Version *int `gorm:"index" json:"version,omitempty"`
	Status  string `gorm:"not null;check:status IN ('pending','accepted');type:text" json:"status"`
	AcceptedAt *time.Time `json:"acceptedAt,omitempty"`
	ChangeReason string `gorm:"type:text;default:''" json:"changeReason,omitempty"`

	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}

func (AgentVersion) TableName() string { return "agent_versions" }

// Execution-log enums — mirror function (execution_log.go) 1:1 so the agent execution surface
// (invoke_agent / search_agent_executions / get_agent_execution) matches run_function exactly.
//
// 执行日志枚举 —— 与 function 1:1 对齐。
const (
	ExecutionStatusOK        = "ok"
	ExecutionStatusFailed    = "failed"
	ExecutionStatusCancelled = "cancelled"
	ExecutionStatusTimeout   = "timeout"
)

const (
	TriggeredByChat     = "chat"
	TriggeredByWorkflow = "workflow"
	TriggeredByHTTP     = "http"
	TriggeredByTest     = "test"
)

// AgentExecution is one terminal record of a Service.InvokeAgent call (mirrors function.Execution).
//
// AgentExecution 是 Service.InvokeAgent 完成后的终态记录（对标 function.Execution）。
type AgentExecution struct {
	ID             string         `gorm:"primaryKey;type:text" json:"id"`
	UserID         string         `gorm:"not null;index:idx_age_user_id;type:text" json:"userId"`
	Status         string         `gorm:"not null;check:status IN ('ok','failed','cancelled','timeout');type:text" json:"status"`
	TriggeredBy    string         `gorm:"not null;check:triggered_by IN ('chat','workflow','http','test');type:text" json:"triggeredBy"`
	Input          map[string]any `gorm:"serializer:json;type:text;default:'{}'" json:"input"`
	Output         any            `gorm:"serializer:json;type:text" json:"output,omitempty"`
	ErrorCode      string         `gorm:"type:text;default:''" json:"errorCode,omitempty"`
	ErrorMessage   string         `gorm:"type:text;default:''" json:"errorMessage,omitempty"`
	ElapsedMs      int64          `gorm:"not null;default:0" json:"elapsedMs"`
	StartedAt      time.Time      `gorm:"not null;index:idx_age_started_at,sort:desc" json:"startedAt"`
	EndedAt        time.Time      `gorm:"not null" json:"endedAt"`
	ConversationID string         `gorm:"type:text;default:'';index:idx_age_conv,priority:1" json:"conversationId,omitempty"`
	MessageID      string         `gorm:"type:text;default:'';index:idx_age_conv,priority:2" json:"messageId,omitempty"`
	ToolCallID     string         `gorm:"type:text;default:''" json:"toolCallId,omitempty"`
	FlowrunID      string         `gorm:"type:text;default:'';index:idx_age_flowrun,priority:1" json:"flowrunId,omitempty"`
	FlowrunNodeID  string         `gorm:"type:text;default:''" json:"flowrunNodeId,omitempty"`

	AgentID   string `gorm:"not null;type:text;index:idx_age_agent,priority:1" json:"agentId"`
	VersionID string `gorm:"not null;type:text" json:"versionId"`
	ModelID   string `gorm:"type:text;default:''" json:"modelId,omitempty"` // which model ran (agent analog of function.PythonVersion)

	CreatedAt time.Time      `gorm:"index:idx_age_agent,priority:2,sort:desc" json:"createdAt"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (AgentExecution) TableName() string { return "agent_executions" }

// ExecutionFilter mirrors function.ExecutionFilter (FunctionID→AgentID).
//
// ExecutionFilter 对标 function.ExecutionFilter。
type ExecutionFilter struct {
	AgentID        string
	VersionID      string
	Status         string
	ConversationID string
	FlowrunID      string
	Since          *time.Time
	Until          *time.Time
	Limit          int
	Cursor         string
}

// ExecutionAggregates mirrors function.ExecutionAggregates 1:1.
//
// ExecutionAggregates 与 function 完全同名。
type ExecutionAggregates struct {
	OKCount        int   `json:"okCount"`
	FailedCount    int   `json:"failedCount"`
	CancelledCount int   `json:"cancelledCount"`
	TimeoutCount   int   `json:"timeoutCount"`
	AvgElapsedMs   int64 `json:"avgElapsedMs"`
	P95ElapsedMs   int64 `json:"p95ElapsedMs"`
}

// VersionStatus values for AgentVersion.Status.
const (
	VersionStatusPending  = "pending"
	VersionStatusAccepted = "accepted"
)

var (
	ErrNotFound          = errors.New("agent: not found")
	ErrNameDuplicate     = errors.New("agent: name already exists")
	ErrNoPending         = errors.New("agent: no pending version")
	ErrNoActiveVersion   = errors.New("agent: no active version")
	ErrToolsAgentRef     = errors.New("agent: tools cannot reference another agent (ag_ prefix forbidden)")
	ErrExecutionNotFound = errors.New("agent: execution not found")        // mirrors function.ErrExecutionNotFound
	ErrVersionNotFound   = errors.New("agent: version not found")          // for revert to a non-existent/unaccepted version
)

// Repository is the persistence port for the Agent domain.
//
// Repository 是 Agent domain 的持久化端口。
type Repository interface {
	Create(ctx context.Context, a *Agent) error
	Get(ctx context.Context, id string) (*Agent, error)
	GetByName(ctx context.Context, name string) (*Agent, error)
	List(ctx context.Context, userID string, limit int, cursor string) ([]*Agent, string, error)
	Update(ctx context.Context, a *Agent) error
	SoftDelete(ctx context.Context, id string) error

	// Version management.
	CreateVersion(ctx context.Context, v *AgentVersion) error
	GetVersion(ctx context.Context, versionID string) (*AgentVersion, error)
	GetVersionByNumber(ctx context.Context, agentID string, version int) (*AgentVersion, error) // revert target lookup
	GetPending(ctx context.Context, agentID string) (*AgentVersion, error)
	ListVersions(ctx context.Context, agentID string) ([]*AgentVersion, error)
	AcceptVersion(ctx context.Context, agentID, versionID string) error
	SetActiveVersion(ctx context.Context, agentID, versionID string) error // revert: flip active to an accepted version
	SetNeedsAttention(ctx context.Context, agentID string, val bool) error

	// Executions — method names mirror function.ExecutionRepository 1:1.
	SaveExecution(ctx context.Context, e *AgentExecution) error
	GetExecutionByID(ctx context.Context, id string) (*AgentExecution, error)
	ListExecutions(ctx context.Context, filter ExecutionFilter) ([]*AgentExecution, string, error)
	ComputeAggregates(ctx context.Context, filter ExecutionFilter) (ExecutionAggregates, error)
}
