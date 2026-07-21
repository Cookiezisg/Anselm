package freetier

import (
	"context"
	"fmt"

	"go.uber.org/zap"

	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// ErrNotProvisioned signals the workspace has no managed anselm credential yet (in-memory / test
// mode, or provisioning still pending) — so there is no install id to read a quota for. The
// settings UI hides the free-tier gauge on this rather than rendering a misleading zero.
//
// ErrNotProvisioned 表示该 workspace 尚无受管 anselm 凭证（in-memory / 测试模式，或 provision 仍 pending）
// ——故无 install id 可读配额。设置页据此隐藏免费档仪表，而非渲染误导性的清零。
var ErrNotProvisioned = errorspkg.New(errorspkg.KindNotFound, "FREETIER_NOT_PROVISIONED", "free tier not provisioned for this workspace")

// QuotaKeys is the apikey port the quota reader needs: List to locate the managed anselm row, and
// ResolveCredentialsByID to read its managed public install id. A subset of *apikeyapp.Service.
//
// QuotaKeys 是配额读取所需的 apikey 端口：List 定位受管 anselm 行，
// ResolveCredentialsByID 读取其公开 install id。*apikeyapp.Service 的子集。
type QuotaKeys interface {
	List(ctx context.Context, filter apikeydomain.ListFilter) ([]*apikeydomain.APIKey, string, error)
	ResolveCredentialsByID(ctx context.Context, apiKeyID string) (apikeydomain.Credentials, error)
}

// QuotaFetcher reads live quota from the gateway by proof-bound install id; *llm.QuotaClient satisfies it.
//
// QuotaFetcher 用设备证明绑定的 install id 从网关读 live 配额；*llm.QuotaClient 满足它。
type QuotaFetcher interface {
	Fetch(ctx context.Context, baseURL, installID string) (llminfra.QuotaResult, error)
}

// Quota is the app-level free-tier quota view (mirrors the gateway, decoupled from the infra type so
// the transport layer stays infra-free).
//
// Quota 是 app 级免费档配额视图（镜像网关，与 infra 类型解耦，使 transport 层不碰 infra）。
type Quota struct {
	Limit     int64
	Used      int64
	Remaining int64
	ResetAt   string
	Available bool
}

// QuotaReader resolves the workspace's managed anselm credential and proxies a live quota read to the
// gateway. Read-only and per-request: it holds no state and never mutates the credential (a stale
// id surfaces as the gateway's auth error, not a flipped local row). The client cannot read /quota
// directly, so the proof-owning backend proxies it.
//
// QuotaReader 解析 workspace 的受管 anselm 凭证、把 live 配额读代理给网关。只读、每请求一次：不持状态、
// 绝不改凭证（失效 install id 现为网关鉴权错误、而非本地翻行）。客户端无法直读 /quota，
// 故持设备私钥的后端代理之。
type QuotaReader struct {
	keys    QuotaKeys
	fetcher QuotaFetcher
	log     *zap.Logger
}

// NewQuotaReader wires dependencies; panics on nil logger.
//
// NewQuotaReader 装配依赖；nil logger panic。
func NewQuotaReader(keys QuotaKeys, fetcher QuotaFetcher, log *zap.Logger) *QuotaReader {
	if log == nil {
		panic("freetier.NewQuotaReader: logger is nil")
	}
	return &QuotaReader{keys: keys, fetcher: fetcher, log: log.Named("freetierapp.quota")}
}

// Read resolves the managed anselm key for the ctx workspace, reads its install id, and proxies
// a live quota read. ErrNotProvisioned when no managed row exists; the gateway's own error (auth /
// rate-limit / provider) propagates verbatim otherwise. ctx MUST carry the workspace (the managed row
// is workspace-scoped — orm filters List by workspace_id).
//
// Read 解析 ctx workspace 的受管 anselm key、读取其 install id、代理一次 live 配额读。无受管行时返
// ErrNotProvisioned；否则网关自身错误（鉴权/限流/provider）原样冒泡。ctx 必须携带 workspace（受管行按
// workspace 隔离——orm 据 workspace_id 过滤 List）。
func (r *QuotaReader) Read(ctx context.Context) (Quota, error) {
	keys, _, err := r.keys.List(ctx, apikeydomain.ListFilter{Provider: providerName, Limit: 1})
	if err != nil {
		return Quota{}, fmt.Errorf("freetier.QuotaReader.Read: list: %w", err)
	}
	if len(keys) == 0 {
		return Quota{}, ErrNotProvisioned
	}

	creds, err := r.keys.ResolveCredentialsByID(ctx, keys[0].ID)
	if err != nil {
		return Quota{}, fmt.Errorf("freetier.QuotaReader.Read: resolve credentials: %w", err)
	}

	res, err := r.fetcher.Fetch(ctx, creds.BaseURL, creds.Key)
	if err != nil {
		return Quota{}, fmt.Errorf("freetier.QuotaReader.Read: fetch quota: %w", err)
	}
	return Quota{
		Limit:     res.Limit,
		Used:      res.Used,
		Remaining: res.Remaining,
		ResetAt:   res.ResetAt,
		Available: res.Available,
	}, nil
}
