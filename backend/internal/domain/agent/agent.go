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

// AgentExecution is one trial run of an agent via run_agent.
//
// AgentExecution 是一次 run_agent 试跑记录。
type AgentExecution struct {
	ID          string         `gorm:"primaryKey;type:text" json:"id"`
	AgentID     string         `gorm:"not null;type:text;index" json:"agentId"`
	VersionID   string         `gorm:"not null;type:text" json:"versionId"`
	UserID      string         `gorm:"not null;type:text;index" json:"userId"`
	TriggeredBy string         `gorm:"not null;type:text" json:"triggeredBy"` // "chat" | "workflow" | "test"
	Input       map[string]any `gorm:"serializer:json;type:text;default:'{}'" json:"input"`
	Output      *string        `gorm:"type:text" json:"output,omitempty"`
	ErrorMsg    string         `gorm:"type:text;default:''" json:"errorMsg,omitempty"`
	Status      string         `gorm:"not null;check:status IN ('ok','failed','cancelled','timeout');type:text" json:"status"`
	ElapsedMs   int64          `gorm:"not null;default:0" json:"elapsedMs"`
	StartedAt   time.Time      `gorm:"not null" json:"startedAt"`
	EndedAt     time.Time      `gorm:"not null" json:"endedAt"`
	CreatedAt   time.Time      `json:"createdAt"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
}

func (AgentExecution) TableName() string { return "agent_executions" }

// VersionStatus values for AgentVersion.Status.
const (
	VersionStatusPending  = "pending"
	VersionStatusAccepted = "accepted"
)

var (
	ErrNotFound       = errors.New("agent: not found")
	ErrNameDuplicate  = errors.New("agent: name already exists")
	ErrNoPending      = errors.New("agent: no pending version")
	ErrNoActiveVersion = errors.New("agent: no active version")
	ErrToolsAgentRef  = errors.New("agent: tools cannot reference another agent (ag_ prefix forbidden)")
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
	GetPending(ctx context.Context, agentID string) (*AgentVersion, error)
	ListVersions(ctx context.Context, agentID string) ([]*AgentVersion, error)
	AcceptVersion(ctx context.Context, agentID, versionID string) error
	SetNeedsAttention(ctx context.Context, agentID string, val bool) error

	// Executions.
	CreateExecution(ctx context.Context, ex *AgentExecution) error
	GetExecution(ctx context.Context, id string) (*AgentExecution, error)
	ListExecutions(ctx context.Context, agentID string, limit int, cursor string) ([]*AgentExecution, string, error)
	UpdateExecution(ctx context.Context, ex *AgentExecution) error
}
