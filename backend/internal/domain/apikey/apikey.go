// Package apikey is the domain layer for credential management.
//
// Package apikey 是凭证管理的 domain 层。
package apikey

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

// APIKey is a user credential for one LLM provider.
//
// APIKey 是用户在某 provider 下的凭证。
type APIKey struct {
	ID           string         `gorm:"primaryKey;type:text" json:"id"`
	UserID       string         `gorm:"not null;index:idx_api_keys_user_id;index:idx_api_keys_user_provider,priority:1;type:text" json:"userId"`
	Provider     string         `gorm:"not null;index:idx_api_keys_user_provider,priority:2;type:text" json:"provider"`
	DisplayName  string         `gorm:"not null;type:text;default:''" json:"displayName"`
	KeyEncrypted string         `gorm:"not null;type:text" json:"-"`
	KeyMasked    string         `gorm:"not null;type:text" json:"keyMasked"`
	BaseURL      string         `gorm:"type:text;default:''" json:"baseUrl"`
	APIFormat    string         `gorm:"type:text;default:''" json:"apiFormat"`
	TestStatus   string         `gorm:"type:text;default:'pending'" json:"testStatus"`
	TestError    string         `gorm:"type:text;default:''" json:"testError"`
	LastTestedAt *time.Time     `json:"lastTestedAt"`
	ModelsFound  []string       `gorm:"serializer:json;type:text;default:'[]'" json:"modelsFound"`
	IsDefault    bool           `gorm:"not null;default:false" json:"isDefault"`
	CreatedAt    time.Time      `json:"createdAt"`
	UpdatedAt    time.Time      `json:"updatedAt"`
	DeletedAt    gorm.DeletedAt `gorm:"index" json:"-"`
}

func (APIKey) TableName() string { return "api_keys" }

const (
	TestStatusPending = "pending"
	TestStatusOK      = "ok"
	TestStatusError   = "error"
)

const (
	APIFormatAnthropicCompatible = "anthropic-compatible"
)

// Credentials is the per-call bundle returned to LLM consumers; Key is plaintext.
//
// Credentials 是返给 LLM 调用方的凭证包；Key 为明文，禁日志 / 禁持久化。
type Credentials struct {
	// Provider lets ByID callers re-derive display/transport hints from a key id.
	//
	// Provider 让按 id 解析的调用方仍能拿到 provider 名（供 llmclient.Bundle 派生用）。
	Provider string
	Key      string
	BaseURL  string
	// APIFormat is non-empty only for "custom" keys; carried to factory.Build so the
	// anthropic-compatible branch fires correctly.
	//
	// APIFormat 仅对 custom key 非空；传给 factory.Build 以正确分派 anthropic-compat 分支。
	APIFormat string
}

type ListFilter struct {
	Cursor   string
	Limit    int
	Provider string
}

var (
	ErrNotFound            = errors.New("apikey: not found")
	ErrNotFoundForProvider = errors.New("apikey: no key for provider")
	ErrInvalidProvider     = errors.New("apikey: invalid provider")
	ErrBaseURLRequired     = errors.New("apikey: base_url required for this provider")
	ErrAPIFormatRequired   = errors.New("apikey: api_format required for custom provider")
	ErrKeyRequired         = errors.New("apikey: key value is required")
	ErrDisplayNameConflict = errors.New("apikey: display name already in use")
	// ErrInUse: model_config / conv override / node override still reference this key.
	//
	// ErrInUse:被 model_config / conv override / node override 引用，不能删。
	ErrInUse = errors.New("apikey: in use by model_configs or model overrides")
)

// Repository is the storage contract for APIKey, scoped by ctx userID.
//
// Repository 是 APIKey 的存储契约，按 ctx userID 过滤。
type Repository interface {
	Get(ctx context.Context, id string) (*APIKey, error)
	List(ctx context.Context, filter ListFilter) ([]*APIKey, string, error)

	// GetByProvider picks best active key: test_status='ok' > last_tested_at DESC > created_at DESC.
	//
	// GetByProvider 挑最佳活跃 Key，无则返 ErrNotFoundForProvider。
	GetByProvider(ctx context.Context, provider string) (*APIKey, error)

	Save(ctx context.Context, k *APIKey) error
	Delete(ctx context.Context, id string) error
	UpdateTestResult(ctx context.Context, id, status, errMsg string, models []string) error

	// ClearDefaultForCategory unsets is_default on all of the user's keys whose
	// provider is in the given list (keeps "default" single-choice per category).
	ClearDefaultForCategory(ctx context.Context, providers []string) error

	// DefaultProvider returns the provider name of the user's is_default key among
	// the given providers, or "" if none.
	DefaultProvider(ctx context.Context, providers []string) (string, error)
}

// KeyProvider is the cross-domain port for resolving ready-to-use credentials.
//
// KeyProvider 是跨 domain 端口，消费方拿可用凭证而不接触 Repository。
type KeyProvider interface {
	ResolveCredentials(ctx context.Context, provider string) (Credentials, error)

	// ResolveCredentialsByID resolves by api_key id; cross-user lookups surface ErrNotFound.
	//
	// ResolveCredentialsByID 按 id 解析 credentials；跨用户走 ErrNotFound（隔离）。
	ResolveCredentialsByID(ctx context.Context, apiKeyID string) (Credentials, error)

	MarkInvalid(ctx context.Context, provider string, reason string) error

	// DefaultSearchProvider returns the provider name of the user's is_default search key,
	// or "" if none is marked. Used by WebSearch to put the preferred provider first.
	//
	// DefaultSearchProvider 返回当前用户标记为 is_default 的搜索 provider 名，无则返 ""。
	DefaultSearchProvider(ctx context.Context) string
}

// SearchProviderPriority is the order WebSearch tries BYOK keys; must match app/apikey/providers.go.
//
// SearchProviderPriority 是 WebSearch 多 key 尝试顺序，须与 app/apikey/providers.go 同步。
var SearchProviderPriority = []string{"brave", "serper", "tavily", "bocha"}
