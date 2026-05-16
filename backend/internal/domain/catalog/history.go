package catalog

import (
	"context"
	"time"

	"gorm.io/gorm"
)

// HistoryEntry is one persisted catalog version row (§4.7). Cap kept to ~50
// recent versions; older rows pruned by Repository on every Save.
//
// HistoryEntry 是一次持久化的 catalog 版本(§4.7)。只留近 ~50 版,旧的由
// Repository 在 Save 时清。
type HistoryEntry struct {
	ID          string               `gorm:"primaryKey;type:text" json:"id"` // ch_<16hex>
	Version     int                  `gorm:"not null;index" json:"version"`
	Summary     string               `gorm:"type:text" json:"summary"`
	Coverage    map[string][]string  `gorm:"serializer:json;type:text" json:"coverage"`
	Fingerprint string               `gorm:"type:text;index" json:"fingerprint"`
	GeneratedBy string               `gorm:"type:text" json:"generatedBy"`
	SourcesAt   map[string]time.Time `gorm:"serializer:json;type:text" json:"sourcesAt"`
	GeneratedAt time.Time            `gorm:"not null;index:idx_ch_generated,sort:desc" json:"generatedAt"`
	CreatedAt   time.Time            `json:"createdAt"`
	DeletedAt   gorm.DeletedAt       `gorm:"index" json:"-"`
}

func (HistoryEntry) TableName() string { return "catalog_history" }

// HistoryRepository persists catalog versions for diff inspection.
//
// HistoryRepository 持久化 catalog 版本供 diff 查看。
type HistoryRepository interface {
	Save(ctx context.Context, h *HistoryEntry) error
	ListRecent(ctx context.Context, limit int) ([]*HistoryEntry, error)
	GetByVersion(ctx context.Context, version int) (*HistoryEntry, error)
}
