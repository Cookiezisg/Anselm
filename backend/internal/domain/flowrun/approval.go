package flowrun

import (
	"time"

	"gorm.io/gorm"
)

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
	FlowrunID   string         `gorm:"not null;type:text;index" json:"flowrunId"`
	NodeID      string         `gorm:"not null;type:text" json:"nodeId"`
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
