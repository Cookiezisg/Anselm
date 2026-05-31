package flowrun

import (
	"context"
	"time"

	"gorm.io/gorm"
)

// ApprovalRepository is the persistence port for the approvals projection (17 §9). The journal is the
// execution truth (signal_awaited / signal_received); this row is the UI inbox + audit trail that the
// frontend approval banner/queue reads to learn WHICH node is parked.
//
// ApprovalRepository 是 approvals 投影的持久化端口;journal 是执行真相,本行供前端 inbox/审计读。
type ApprovalRepository interface {
	// Park upserts a parked approval row on interpreter park (idempotent on replay via UNIQUE).
	Park(ctx context.Context, a *Approval) error
	// Decide flips the parked row to approved/rejected with reason + decided_at on resume.
	Decide(ctx context.Context, flowrunID, nodeID, status, reason string) error
	// CancelParked flips all still-parked rows of a flowrun to cancelled (flowrun cancel, 07).
	CancelParked(ctx context.Context, flowrunID string) error
	// ListParked returns the ctx user's currently-parked approvals (frontend inbox).
	ListParked(ctx context.Context) ([]*Approval, error)
}

const (
	ApprovalParked    = "parked"
	ApprovalApproved  = "approved"
	ApprovalRejected  = "rejected"
	ApprovalTimedOut  = "timed_out"
	ApprovalFailed    = "failed"
	ApprovalCancelled = "cancelled" // flowrun cancelled while parked (17 §1, +cancelled)
)

// Approval is the durable parked state of an approval node (17 §1/§9). The decision
// itself is journaled as a signal_received event; this row carries the audit trail.
//
// Approval 是 approval 节点的 durable 挂起态;决策本身是 journal 的 signal_received 事件。
type Approval struct {
	ID          string         `gorm:"primaryKey;type:text" json:"id"`
	UserID      string         `gorm:"not null;type:text;index" json:"userId"`
	FlowrunID   string         `gorm:"not null;type:text;uniqueIndex:idx_approval_flowrun_node,priority:1" json:"flowrunId"`
	NodeID      string         `gorm:"not null;type:text;uniqueIndex:idx_approval_flowrun_node,priority:2" json:"nodeId"`
	Prompt      string         `gorm:"type:text" json:"prompt"`
	Payload     any            `gorm:"serializer:json;type:text" json:"payload,omitempty"`
	Status      string         `gorm:"not null;check:status IN ('parked','approved','rejected','timed_out','failed','cancelled');type:text" json:"status"`
	AllowReason bool           `gorm:"not null;default:false" json:"allowReason"`
	Reason      string         `gorm:"type:text;default:''" json:"reason,omitempty"`
	DecidedAt   *time.Time     `json:"decidedAt,omitempty"`
	CreatedAt   time.Time      `json:"createdAt"`
	UpdatedAt   time.Time      `json:"updatedAt"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Approval) TableName() string { return "approvals" }
