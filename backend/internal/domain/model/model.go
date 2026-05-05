// Package model is the domain layer for LLM model strategy: records which
// (provider, modelID) the user picked per scenario. Two ports — Repository
// (→ infra/store/model) and ModelPicker (→ app/model).
//
// Package model 是 LLM 模型策略 domain 层：记录用户为各 scenario 选定的
// (provider, modelID)。两个 port——Repository（→ infra/store/model）+
// ModelPicker（→ app/model）。
package model

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

// ModelConfig records the user's (provider, modelID) for one scenario.
// At most one active row per (user_id, scenario), enforced by a partial
// UNIQUE index in schema_extras.go.
//
// ModelConfig 记录用户某 scenario 下的 (provider, modelID)。
// 每对 (user_id, scenario) 最多一条活跃行——schema_extras.go 的
// partial UNIQUE 索引保证。
type ModelConfig struct {
	ID        string         `gorm:"primaryKey;type:text" json:"id"`
	UserID    string         `gorm:"not null;type:text;uniqueIndex:idx_mc_user_scenario,priority:1" json:"-"`
	Scenario  string         `gorm:"not null;type:text;uniqueIndex:idx_mc_user_scenario,priority:2" json:"scenario"`
	Provider  string         `gorm:"not null;type:text" json:"provider"`
	ModelID   string         `gorm:"not null;type:text" json:"modelId"`
	CreatedAt time.Time      `json:"createdAt"`
	UpdatedAt time.Time      `json:"updatedAt"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (ModelConfig) TableName() string { return "model_configs" }

// Scenario constants. New scenarios appended here as Phases introduce them.
// App-layer validation (not DB CHECK) so adding scenarios needs no migration.
//
// Scenario 常量。后续 Phase 在此追加。校验在 app 层（非 DB CHECK），
// 新增不需 schema 迁移。
const (
	ScenarioChat       = "chat"
	ScenarioWebSummary = "web_summary"
)

// IsValidScenario reports whether s is a recognised scenario name.
//
// IsValidScenario 报告 s 是否合法 scenario。
func IsValidScenario(s string) bool {
	switch s {
	case ScenarioChat, ScenarioWebSummary:
		return true
	default:
		return false
	}
}

// ListScenarios returns every recognised scenario. Backs the contract test
// asserting ListScenarios ≡ IsValidScenario; production code does not call it.
//
// ListScenarios 返所有合法 scenario。支撑 ListScenarios ≡ IsValidScenario
// 契约测试；生产不调。
func ListScenarios() []string {
	return []string{ScenarioChat, ScenarioWebSummary}
}

var (
	ErrNotConfigured    = errors.New("model: not configured for scenario")
	ErrInvalidScenario  = errors.New("model: invalid scenario")
	ErrProviderRequired = errors.New("model: provider is required")
	ErrModelIDRequired  = errors.New("model: model id is required")
)

// Repository is the storage contract for ModelConfig. Scoped to ctx userID;
// caller must run InjectUserID middleware first.
//
// Repository 是 ModelConfig 存储契约。按 ctx userID 过滤；调用方先跑 InjectUserID。
type Repository interface {
	// GetByScenario returns active config for (ctx user, scenario);
	// ErrNotConfigured if none.
	// GetByScenario 返 (ctx 用户, scenario) 的活跃配置；无则 ErrNotConfigured。
	GetByScenario(ctx context.Context, scenario string) (*ModelConfig, error)

	// List returns every active config for current user, ordered by scenario.
	// No pagination — at most ~6 entries.
	// List 返当前用户所有活跃配置，按 scenario 排序；不分页（最多 ~6 条）。
	List(ctx context.Context) ([]*ModelConfig, error)

	// Upsert creates or updates by (user_id, scenario). Caller fills UserID + Scenario.
	// Upsert 按 (user_id, scenario) 创建或更新；调用方先填 UserID + Scenario。
	Upsert(ctx context.Context, m *ModelConfig) error
}

// ModelPicker is the cross-domain port for LLM-using services. Implemented
// by app/model.Service.
//
// ModelPicker 是跨 domain 端口，由 app/model.Service 实现。
type ModelPicker interface {
	// PickForChat returns (provider, modelID) for the chat scenario;
	// ErrNotConfigured when unset.
	// PickForChat 返 chat scenario 的 (provider, modelID)；未配置返 ErrNotConfigured。
	PickForChat(ctx context.Context) (provider, modelID string, err error)

	// PickForWebSummary returns (provider, modelID) for WebFetch summary;
	// ErrNotConfigured when unset (caller MUST fall back to PickForChat so
	// summarisation works out of the box).
	//
	// PickForWebSummary 返 WebFetch 摘要的 (provider, modelID)；未配置返
	// ErrNotConfigured，调用方必须 fallback 到 PickForChat（保证开箱即用）。
	PickForWebSummary(ctx context.Context) (provider, modelID string, err error)
}
