package mcp

import (
	"context"
	"time"
)

// HealthSnapshot is one point-in-time health probe result; appended-only,
// no soft-delete (history is meant to age out via retention policy).
//
// HealthSnapshot 是一次时间点健康探测结果；只追加不软删，靠保留策略 age out。
type HealthSnapshot struct {
	ID         string    `gorm:"primaryKey;type:text" json:"id"` // mch_<16hex>
	UserID     string    `gorm:"not null;type:text;index:idx_mch_user_server,priority:1" json:"userId"`
	ServerName string    `gorm:"not null;type:text;index:idx_mch_user_server,priority:2" json:"serverName"`
	Healthy    bool      `gorm:"not null" json:"healthy"`
	LatencyMs  int       `gorm:"not null;default:0" json:"latencyMs"`
	ToolCount  int       `gorm:"not null;default:0" json:"toolCount"`
	ErrorMsg   string    `gorm:"type:text;default:''" json:"errorMsg,omitempty"`
	CheckedAt  time.Time `gorm:"not null;index:idx_mch_user_server,priority:3,sort:desc" json:"checkedAt"`
}

func (HealthSnapshot) TableName() string { return "mcp_health_history" }

// HealthHistoryRepository stores append-only health-check snapshots.
//
// HealthHistoryRepository 存只追加的健康探测快照。
type HealthHistoryRepository interface {
	Insert(ctx context.Context, snap *HealthSnapshot) error
	ListSince(ctx context.Context, userID, serverName string, since time.Time) ([]*HealthSnapshot, error)
}
