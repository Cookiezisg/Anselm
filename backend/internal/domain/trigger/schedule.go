package trigger

import (
	"time"

	"gorm.io/gorm"
)

// trigger_firings.status — single lifecycle+disposition enum (17 §1; no separate outcome column).
const (
	FiringPending    = "pending"
	FiringClaimed    = "claimed"
	FiringStarted    = "started"
	FiringSkipped    = "skipped"
	FiringSuperseded = "superseded"
	FiringShed       = "shed" // resource cap (C10)
)

// TriggerSchedule persists listener registration + retry state (17 §1, ADR-022),
// replacing the old in-memory gorm:"-" LastFiredAt. Keyed by (workflow_id, trigger_node_id).
//
// TriggerSchedule 持久化 listener 注册 + retry 计数;取代旧内存 LastFiredAt。
type TriggerSchedule struct {
	WorkflowID          string         `gorm:"primaryKey;type:text" json:"workflowId"`
	TriggerNodeID       string         `gorm:"primaryKey;type:text" json:"triggerNodeId"`
	Kind                string         `gorm:"not null;type:text" json:"kind"`
	Spec                map[string]any `gorm:"serializer:json;type:text;default:'{}'" json:"spec"`
	LastFiredAt         *time.Time     `json:"lastFiredAt,omitempty"`
	CatchupWindow       string         `gorm:"not null;default:'latest';check:catchup_window IN ('none','latest','window');type:text" json:"catchupWindow"`
	OverlapPolicy       string         `gorm:"not null;default:'BufferOne';check:overlap_policy IN ('Skip','BufferOne','BufferAll','AllowAll');type:text" json:"overlapPolicy"`
	RetryPolicy         map[string]any `gorm:"serializer:json;type:text;default:'{}'" json:"retryPolicy"`
	ConsecutiveFailures int            `gorm:"not null;default:0" json:"consecutiveFailures"`
	CreatedAt           time.Time      `json:"createdAt"`
	UpdatedAt           time.Time      `json:"updatedAt"`
	DeletedAt           gorm.DeletedAt `gorm:"index" json:"-"`
}

func (TriggerSchedule) TableName() string { return "trigger_schedules" }

// TriggerFiring is the durable inbox row — persist-before-act, claimed in a single tx (ADR-021).
// Terminal status IS the outcome ("every firing has an outcome" = every firing reaches a terminal status).
//
// TriggerFiring 是 durable 收件箱;先持久化再动作,单事务 claim;终态 status 即 outcome。
type TriggerFiring struct {
	ID            string         `gorm:"primaryKey;type:text" json:"id"`
	WorkflowID    string         `gorm:"not null;type:text;uniqueIndex:idx_trf_dedup,priority:1" json:"workflowId"`
	TriggerNodeID string         `gorm:"not null;type:text;uniqueIndex:idx_trf_dedup,priority:2" json:"triggerNodeId"`
	TriggerKind   string         `gorm:"not null;type:text;default:'manual'" json:"triggerKind"`
	Payload       map[string]any `gorm:"serializer:json;type:text;default:'{}'" json:"payload"`
	DedupKey      string         `gorm:"not null;type:text;uniqueIndex:idx_trf_dedup,priority:3" json:"dedupKey"`
	Status        string         `gorm:"not null;check:status IN ('pending','claimed','started','skipped','superseded','shed');type:text;index" json:"status"`
	ScheduledAt   *time.Time     `json:"scheduledAt,omitempty"`
	EnqueuedAt    time.Time      `json:"enqueuedAt"`
	FlowrunID     string         `gorm:"type:text;default:''" json:"flowrunId,omitempty"`
	CreatedAt     time.Time      `json:"createdAt"`
	UpdatedAt     time.Time      `json:"updatedAt"`
	DeletedAt     gorm.DeletedAt `gorm:"index" json:"-"`
}

func (TriggerFiring) TableName() string { return "trigger_firings" }

// PollingState persists the business cursor per polling trigger (17 §1); stopgap self-heal.
type PollingState struct {
	WorkflowID string         `gorm:"primaryKey;type:text" json:"workflowId"`
	NodeID     string         `gorm:"primaryKey;type:text" json:"nodeId"`
	Cursor     string         `gorm:"type:text;default:''" json:"cursor"`
	CreatedAt  time.Time      `json:"createdAt"`
	UpdatedAt  time.Time      `json:"updatedAt"`
	DeletedAt  gorm.DeletedAt `gorm:"index" json:"-"`
}

func (PollingState) TableName() string { return "polling_states" }
