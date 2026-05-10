// Package apikey is the domain layer for credential management:
// APIKey entity, sentinels, two ports — Repository (→ infra/store/apikey)
// and KeyProvider (→ app/apikey, consumed by chat / forge / web search /
// etc.) — and the SearchProviderPriority list (consumed by app/tool/web).
//
// Package apikey 是凭证管理的 domain 层：APIKey 实体、sentinel、两个 port
// （Repository → infra/store/apikey；KeyProvider → app/apikey，由 chat / forge
// / web 搜索等消费）+ SearchProviderPriority 列表（由 app/tool/web 消费）。
package apikey

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

// APIKey is a user credential for one LLM provider. KeyEncrypted = ciphertext
// "v1:..."; KeyMasked = display string like "sk-proj...abc4".
//
// APIKey 是用户在某 provider 下的凭证。KeyEncrypted 是密文 "v1:..."；
// KeyMasked 是展示字符串如 "sk-proj...abc4"。
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
	CreatedAt    time.Time      `json:"createdAt"`
	UpdatedAt    time.Time      `json:"updatedAt"`
	DeletedAt    gorm.DeletedAt `gorm:"index" json:"-"`
}

func (APIKey) TableName() string { return "api_keys" }

// TestStatus records the outcome of the most recent connectivity test —
// snapshot field, not a streaming state machine; tests are synchronous and
// write the outcome once.
//
// TestStatus 记录最近一次连通性测试的结果——快照字段而非流式状态机；
// 测试同步阻塞，完成后一次性写入。
const (
	TestStatusPending = "pending"
	TestStatusOK      = "ok"
	TestStatusError   = "error"
)

// APIFormat values for APIKey.APIFormat (custom provider only). Only
// AnthropicCompatible is referenced — the OpenAI shape is the default
// when APIFormat is empty (frontend dropdown / handler pass-through;
// see app/apikey/tester.go::Test).
//
// APIKey.APIFormat 取值（仅 custom provider）。仅 AnthropicCompatible 被引用——
// APIFormat 空时默认走 OpenAI 形状（前端 dropdown / handler 透传，详
// app/apikey/tester.go::Test）。
const (
	APIFormatAnthropicCompatible = "anthropic-compatible"
)

// Credentials is the per-call bundle returned to LLM consumers. Key is
// plaintext — treat as ephemeral; never log or persist.
//
// Credentials 是返给 LLM 调用方的凭证包。Key 是明文——短生命周期对待，
// 禁日志 / 禁持久化。
type Credentials struct {
	Key     string
	BaseURL string
}

// ListFilter is the query shape for Repository.List.
//
// ListFilter 是 Repository.List 的查询形状。
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
)

// Repository is the storage contract for APIKey. Scoped to ctx userID;
// caller must run InjectUserID middleware first.
//
// Repository 是 APIKey 的存储契约。按 ctx userID 过滤；调用方先跑
// InjectUserID 中间件。
type Repository interface {
	// Get fetches by id, scoped to ctx user. Returns ErrNotFound when absent.
	// Get 按 id 查询，按 ctx 用户过滤；未命中返 ErrNotFound。
	Get(ctx context.Context, id string) (*APIKey, error)

	// List paginates current user's keys with optional provider filter.
	// List 分页返当前用户 Key，可选按 provider 过滤。
	List(ctx context.Context, filter ListFilter) ([]*APIKey, string, error)

	// GetByProvider picks the best active key: test_status='ok' >
	// last_tested_at DESC > created_at DESC. Returns ErrNotFoundForProvider
	// when none exists.
	//
	// GetByProvider 挑最佳活跃 Key：test_status='ok' > last_tested_at DESC >
	// created_at DESC。无则返 ErrNotFoundForProvider。
	GetByProvider(ctx context.Context, provider string) (*APIKey, error)

	// Save inserts or updates based on k.ID. Caller sets UserID first.
	// Save 按 k.ID 插入或更新；调用方先填 UserID。
	Save(ctx context.Context, k *APIKey) error

	// Delete soft-deletes, scoped to ctx user.
	// Delete 软删除，按 ctx 用户过滤。
	Delete(ctx context.Context, id string) error

	// UpdateTestResult writes test_status / test_error / last_tested_at /
	// models_found atomically. Pass nil models when no model list applies
	// (e.g. MarkInvalid).
	//
	// UpdateTestResult 原子写 test_status / test_error / last_tested_at /
	// models_found。无模型列表（如 MarkInvalid）传 nil。
	UpdateTestResult(ctx context.Context, id, status, errMsg string, models []string) error
}

// KeyProvider is the cross-domain port consumed by chat / workflow /
// embedding to get ready-to-use credentials. They never see Repository or
// raw APIKey rows. Implemented by app/apikey.Service.
//
// KeyProvider 是跨 domain 端口，由 chat / workflow / embedding 消费拿可用
// 凭证。看不到 Repository 或原始 APIKey 行。由 app/apikey.Service 实现。
type KeyProvider interface {
	// ResolveCredentials returns the best (key, baseURL) for the user/provider.
	// Internally: pick best APIKey, decrypt, merge baseURL with provider default.
	// Returns ErrNotFoundForProvider when no active key.
	//
	// ResolveCredentials 返用户/provider 下最佳 (key, baseURL)。内部：挑 Key、
	// 解密、合并 baseURL 与 provider 默认值。无活跃 Key 返 ErrNotFoundForProvider。
	ResolveCredentials(ctx context.Context, provider string) (Credentials, error)

	// MarkInvalid is the feedback channel for 401/403 responses; updates
	// test_status to error and records reason for UI surfacing.
	//
	// MarkInvalid 是 401/403 的反馈通道；更新 test_status 为 error 并记原因。
	MarkInvalid(ctx context.Context, provider string, reason string) error
}

// SearchProviderPriority is the order WebSearch (app/tool/web) tries BYOK
// keys when multiple are configured. Domain-level so tool packages can
// import it without crossing into app/apikey. The names must match entries
// in app/apikey/providers.go (Category=CategorySearch); a contract test in
// app/apikey enforces sync.
//
// SearchProviderPriority 是 WebSearch（app/tool/web）配多 key 时尝试的顺序。
// 放 domain 层让 tool 包能 import 而不跨入 app/apikey。名字必须匹配
// app/apikey/providers.go 里 Category=CategorySearch 的条目；app/apikey 契约
// 测试强制同步。
var SearchProviderPriority = []string{"brave", "serper", "tavily", "bocha"}
