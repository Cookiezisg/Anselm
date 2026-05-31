package flowrun

import (
	"fmt"
	"time"
)

// Closed event-type enum (17 §1). Result + waiting + agent-substep + control are record-once
// (one partial unique index on dedup_key); node_started/node_failed are the append-many attempt
// trail (dedup_key='', excluded from that index).
const (
	EventNodeStarted        = "node_started"
	EventNodeCompleted      = "node_completed"
	EventNodeFailed         = "node_failed"
	EventBranchTaken        = "branch_taken"
	EventSignalAwaited      = "signal_awaited"
	EventSignalReceived     = "signal_received"
	EventTimerArmed         = "timer_armed"
	EventTimerFired         = "timer_fired"
	EventAgentStepStarted   = "agent_step_started"
	EventAgentStepCompleted = "agent_step_completed"
	EventFlowrunCancelled   = "flowrun_cancelled"
	EventReplayStarted      = "replay_started"
)

// FlowRunEvent is one append-only journal entry — the single source of replay truth (17 §1).
// No updated_at/deleted_at: the journal is append-only; GC is per-flowrun retention (07).
//
// FlowRunEvent 是 journal 一条 append-only 记账，重放唯一真相。
type FlowRunEvent struct {
	ID           string `gorm:"primaryKey;type:text" json:"id"`
	FlowrunID    string `gorm:"not null;type:text;index:idx_fre_flowrun,priority:1;uniqueIndex:idx_fre_seq,priority:1" json:"flowrunId"`
	Seq          int64  `gorm:"not null;uniqueIndex:idx_fre_seq,priority:2" json:"seq"`
	Type         string `gorm:"not null;check:type IN ('node_started','node_completed','node_failed','branch_taken','signal_awaited','signal_received','timer_armed','timer_fired','agent_step_started','agent_step_completed','flowrun_cancelled','replay_started');type:text" json:"type"`
	NodeID       string `gorm:"type:text;default:'';index:idx_fre_lookup,priority:2" json:"nodeId"`
	IterationKey int    `gorm:"not null;default:0;index:idx_fre_lookup,priority:3" json:"iterationKey"`
	Generation   int    `gorm:"not null;default:0;index:idx_fre_lookup,priority:4" json:"generation"`
	Attempt      int    `gorm:"not null;default:0" json:"attempt"`
	Turn         int    `gorm:"not null;default:0" json:"turn"`
	ToolCallID   string `gorm:"type:text;default:''" json:"toolCallId"`
	DedupKey     string `gorm:"not null;type:text;default:''" json:"-"`
	Result       any    `gorm:"serializer:json;type:text" json:"result,omitempty"`

	CreatedAt time.Time `json:"createdAt"`
}

func (FlowRunEvent) TableName() string { return "flowrun_events" }

// ComputeDedupKey is the record-once idempotency key (ADR-018). The partial unique index
// idx_fre_record_once covers (flowrun_id, dedup_key) WHERE type NOT IN the attempt types,
// so attempt-class events ('' key) append freely and everything else is recorded once.
//
// ComputeDedupKey 算 record-once 幂等键;attempt 类返 '' 被 partial 索引排除。
func (e *FlowRunEvent) ComputeDedupKey() string {
	switch e.Type {
	case EventNodeStarted, EventNodeFailed:
		return ""
	case EventAgentStepStarted, EventAgentStepCompleted:
		return fmt.Sprintf("%s|%d|%s|%d|%d|%s", e.NodeID, e.IterationKey, e.Type, e.Generation, e.Turn, e.ToolCallID)
	default:
		return fmt.Sprintf("%s|%d|%s|%d", e.NodeID, e.IterationKey, e.Type, e.Generation)
	}
}
