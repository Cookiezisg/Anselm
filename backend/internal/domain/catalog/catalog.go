// Package catalog is the domain layer for the Capability Catalog injected into chat system prompts.
//
// Package catalog 是注入 chat system prompt 的能力清单的 domain 层。
package catalog

import (
	"context"
	"errors"
	"time"
)

// Catalog is the derived view injected into chat system prompts; built on demand, never cached.
//
// Catalog 是注入 chat system prompt 的派生视图，按需构建、不缓存。
type Catalog struct {
	Summary     string              `json:"summary"`
	Coverage    map[string][]string `json:"coverage"`
	GeneratedAt time.Time           `json:"generatedAt"`
	GeneratedBy string              `json:"generatedBy"` // 恒为 "mechanical"
}

// ErrAllSourcesFailed is returned when every registered source errored; mapped to 503 in errmap.
//
// ErrAllSourcesFailed 所有 source 报错时返回；errmap 映射 503。
var ErrAllSourcesFailed = errors.New("catalog: all sources failed")

// SystemPromptProvider is the narrow interface chat.runner consumes to fetch the catalog text.
//
// SystemPromptProvider 是 chat.runner 取 catalog 文本的窄接口。
type SystemPromptProvider interface {
	GetForSystemPrompt(ctx context.Context) string
}
