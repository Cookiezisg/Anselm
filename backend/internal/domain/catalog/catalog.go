package catalog

import (
	"context"

	errorspkg "github.com/sunweilin/foryx/backend/internal/pkg/errors"
)

// Catalog is the derived capability overview: Summary is the grouped menu text
// injected into the system prompt; Coverage is the structured source→ids map for
// HTTP inspection. Built on demand, never persisted, never cached.
//
// Catalog 是派生的能力概览：Summary 是注入 system prompt 的分组菜单文本；Coverage 是供
// HTTP 巡检的结构化 source→ids 映射。按需构建、不持久化、不缓存。
type Catalog struct {
	Summary  string              `json:"summary"`
	Coverage map[string][]string `json:"coverage"`
}

// SystemPromptProvider is the narrow interface chat consumes to fetch the menu text.
//
// SystemPromptProvider 是 chat 取菜单文本的窄接口。
type SystemPromptProvider interface {
	GetForSystemPrompt(ctx context.Context) string
}

// ErrAllSourcesFailed is returned when every registered source errored — a system
// fault (e.g. DB unreachable), not a user error; mapped to 503.
//
// ErrAllSourcesFailed 所有已注册 source 都报错时返回——系统故障（如 DB 不可达），非用户
// 错误；映射 503。
var ErrAllSourcesFailed = errorspkg.New(errorspkg.KindUnavailable, "CATALOG_ALL_SOURCES_FAILED", "all catalog sources failed")
