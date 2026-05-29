package model

import (
	"context"
	"time"

	"gorm.io/gorm"
)

// ModelCapOverride is a user's manual correction of a model's capability,
// used when the static catalog (modelcaps) is stale. Only set fields apply.
//
// ModelCapOverride 是用户对某模型能力的手动纠正，目录陈旧时用；只覆盖设了的字段。
type ModelCapOverride struct {
	ID            string         `gorm:"primaryKey;type:text" json:"id"`
	UserID        string         `gorm:"not null;type:text;uniqueIndex:uq_mco,priority:1" json:"userId"`
	Provider      string         `gorm:"not null;type:text;uniqueIndex:uq_mco,priority:2" json:"provider"`
	ModelID       string         `gorm:"not null;type:text;uniqueIndex:uq_mco,priority:3" json:"modelId"`
	ThinkingShape *string        `gorm:"type:text" json:"thinkingShape,omitempty"` // "none"|"effort"|"budget"|"toggle"
	ContextWindow *int           `gorm:"type:integer" json:"contextWindow,omitempty"`
	MaxOutput     *int           `gorm:"type:integer" json:"maxOutput,omitempty"`
	CreatedAt     time.Time      `json:"createdAt"`
	UpdatedAt     time.Time      `json:"updatedAt"`
	DeletedAt     gorm.DeletedAt `gorm:"index" json:"-"`
}

func (ModelCapOverride) TableName() string { return "model_cap_overrides" }

// CapOverrideRepository is the storage contract for ModelCapOverride, scoped by userID.
//
// CapOverrideRepository 是 ModelCapOverride 的存储契约，按 userID 过滤。
type CapOverrideRepository interface {
	// Upsert inserts or replaces by (userID, provider, modelID) unique triple.
	//
	// Upsert 按 (userID, provider, modelID) 唯一三元组插入或替换。
	Upsert(ctx context.Context, o *ModelCapOverride) error

	// Get returns nil, nil when no override exists for the triple.
	//
	// Get 在三元组无覆盖时返回 nil, nil。
	Get(ctx context.Context, userID, provider, modelID string) (*ModelCapOverride, error)

	// List returns all active overrides for the user.
	//
	// List 返回该用户所有活跃覆盖。
	List(ctx context.Context, userID string) ([]*ModelCapOverride, error)

	// Delete soft-deletes the override for the triple; no-op if absent.
	//
	// Delete 软删该三元组的覆盖；不存在时无操作。
	Delete(ctx context.Context, userID, provider, modelID string) error
}
