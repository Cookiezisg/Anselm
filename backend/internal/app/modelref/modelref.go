// Package modelref centralizes the write-time validation a model selection (modeldomain.ModelRef)
// must pass before any of the three persistence paths — agent override, conversation override,
// workspace scenario default — stores it. Before F153 each path did structure-only validation and
// the two agent/conversation checks were verbatim clones; this collapses them to one func and adds
// the missing piece: confirming the referenced apiKeyId names a REAL key, so a dangling key is
// rejected at write (API_KEY_NOT_FOUND) instead of only surfacing at invoke. The home is the app
// layer because the domain (domain/model) may not import apikey (#3); the existence check arrives via
// a narrow injected port.
//
// Package modelref 把一个模型选择（modeldomain.ModelRef）在三条持久化路径——agent override /
// conversation override / workspace scenario default——落库前必须过的写时校验收口到一处。F153 前各
// 路径只做结构校验、agent/conversation 两份还逐字重复；这里收成一个函数，并补上缺失的一块：确认引用的
// apiKeyId 命中**真实** key，使悬挂 key 在写时即被拒（API_KEY_NOT_FOUND），而非只在 invoke 时浮现。落
// app 层是因 domain（domain/model）不可 import apikey（#3）；存在性检查经一个窄注入端口到达。
package modelref

import (
	"context"
	"strings"

	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
)

// KeyExistenceChecker confirms an apiKeyId names a real (workspace-scoped) api key — nil if it exists,
// apikeydomain.ErrNotFound (API_KEY_NOT_FOUND) if absent. A pure existence probe (no decrypt).
// Implemented by *apikeyapp.Service.KeyExists; the consumer defines the port (DIP).
//
// KeyExistenceChecker 确认某 apiKeyId 命中真实（workspace 隔离）api key——存在返 nil，不存在返
// apikeydomain.ErrNotFound（API_KEY_NOT_FOUND）。纯存在性探针（不解密）。由 *apikeyapp.Service.KeyExists
// 实现；消费方定义端口（DIP）。
type KeyExistenceChecker interface {
	KeyExists(ctx context.Context, apiKeyID string) error
}

// Validate checks a model selection before it is persisted (F153). A nil ref (unset / clear) passes —
// nothing to validate. A set ref must carry both apiKeyId and modelId (structural; the caller supplies
// its own entity-specific structErr so the existing per-entity wire codes are preserved). When a
// checker is wired, the apiKeyId must name a real key — surfacing API_KEY_NOT_FOUND at WRITE time, the
// same code invoke would return, rather than letting it dangle until invoke. A nil checker skips the
// existence probe (nil-tolerant, for partial wiring / unit tests).
//
// modelId is DELIBERATELY NOT validated for spelling: there is no authoritative model catalog (it is
// per-key, probe-derived, and empty for un-probed keys), so a hard check would false-reject valid
// models. A typo'd modelId stays fail-loud at invoke by design (F153).
//
// Validate 在落库前校验一个模型选择（F153）。nil ref（未设/清除）放行——无可校。已设 ref 须同时带 apiKeyId
// 和 modelId（结构；调用方传自己的实体专属 structErr，保留各实体既有 wire code）。接了 checker 时 apiKeyId
// 须命中真实 key——在**写**时浮出 API_KEY_NOT_FOUND（与 invoke 同码），而非悬挂到 invoke。nil checker 跳过
// 存在性探针（nil 容忍，供 partial wiring / 单测）。modelId **刻意不**校拼写：无权威 model 目录（per-key、
// probe 派生、未探测 key 为空），硬校会误拒合法模型；拼错的 modelId 设计上留 fail-loud-at-invoke（F153）。
func Validate(ctx context.Context, ref *modeldomain.ModelRef, structErr error, keys KeyExistenceChecker) error {
	if ref == nil {
		return nil
	}
	if strings.TrimSpace(ref.APIKeyID) == "" || strings.TrimSpace(ref.ModelID) == "" {
		return structErr
	}
	if keys == nil {
		return nil
	}
	return keys.KeyExists(ctx, ref.APIKeyID)
}
