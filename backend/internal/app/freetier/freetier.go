// Package freetier provisions the built-in free-tier credential: it ensures every workspace has a
// managed api_key row pointing at the Anselm gateway, minting a gwk_ install token on first run. It
// deliberately does NOT set the row as a default model — routing prompts through the gateway needs
// explicit user consent (frontend), so default-wiring goes through the normal default-models
// endpoint after that consent. This package only guarantees the row (and thus the selectable model)
// exists; everything it does is best-effort so a degraded free tier never breaks boot or onboarding.
//
// Package freetier 开通内置免费档凭证：确保每个 workspace 有一条指向 Anselm 网关的受管 api_key 行，首次
// 运行铸 gwk_ install token。刻意不把它设为默认模型——把 prompt 经网关路由需用户显式同意（前端），故
// 默认 wiring 经同意后的常规 default-models 端点。本包只保证那条行（及由此可选的模型）存在；所有动作
// best-effort，降级的免费档绝不挂 boot 或 onboarding。
package freetier

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"

	"go.uber.org/zap"

	apikeyapp "github.com/sunweilin/anselm/backend/internal/app/apikey"
	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

// provider / display constants — "anselm" MUST match the apikey catalog key and the llm registry.
//
// provider / 展示常量——"anselm" 必须匹配 apikey 目录键与 llm 注册表。
const (
	providerName = "anselm"
	displayName  = "Anselm Free (DeepSeek)"
	clientID     = "anselm-desktop"
)

// Installer mints a free-tier install token; *llm.InstallClient satisfies it.
//
// Installer 铸免费档 install token；*llm.InstallClient 满足它。
type Installer interface {
	Install(ctx context.Context, baseURL, fingerprintHash, client string) (llminfra.InstallResult, error)
}

// Keys is the apikey port the provisioner needs (a subset of *apikeyapp.Service), injected at wiring.
//
// Keys 是 provisioner 所需的 apikey 端口（*apikeyapp.Service 的子集），装配时注入。
type Keys interface {
	List(ctx context.Context, filter apikeydomain.ListFilter) ([]*apikeydomain.APIKey, string, error)
	CreateManaged(ctx context.Context, in apikeyapp.ManagedCreateInput) (*apikeydomain.APIKey, error)
}

// Fingerprint returns a stable per-machine identifier (raw); the provisioner hashes it before it
// leaves the device. cryptoinfra.MachineFingerprint satisfies it; an error (in-memory / test mode)
// degrades the free tier to absent.
//
// Fingerprint 返回稳定 per-machine 标识（裸）；provisioner 在出本机前哈希它。cryptoinfra.MachineFingerprint
// 满足它；出错（in-memory / 测试模式）使免费档缺席降级。
type Fingerprint func() (string, error)

// Provisioner ensures the managed free-tier credential exists per workspace.
//
// Provisioner 确保每 workspace 有受管免费档凭证。
type Provisioner struct {
	keys      Keys
	installer Installer
	fp        Fingerprint
	log       *zap.Logger
}

// NewProvisioner wires dependencies; panics on nil logger.
//
// NewProvisioner 装配依赖；nil logger panic。
func NewProvisioner(keys Keys, installer Installer, fp Fingerprint, log *zap.Logger) *Provisioner {
	if log == nil {
		panic("freetier.NewProvisioner: logger is nil")
	}
	return &Provisioner{keys: keys, installer: installer, fp: fp, log: log.Named("freetierapp")}
}

// EnsureForWorkspace idempotently guarantees the workspace has a managed anselm credential. It is
// best-effort by contract: every failure path logs and returns nil, so a degraded free tier never
// breaks boot or workspace creation. ctx MUST carry the workspace (the managed row is
// workspace-scoped — orm stamps workspace_id on Save and filters List).
//
// EnsureForWorkspace 幂等确保 workspace 有受管 anselm 凭证。契约 best-effort：每个失败路径都 log 并返
// nil，使降级的免费档绝不挂 boot 或建 workspace。ctx 必须携带 workspace（受管行按 workspace 隔离——orm
// 在 Save 时盖 workspace_id、List 时过滤）。
func (p *Provisioner) EnsureForWorkspace(ctx context.Context) error {
	// Dedup at the app level — there is no (workspace_id, provider) UNIQUE, so a List is the check.
	existing, _, err := p.keys.List(ctx, apikeydomain.ListFilter{Provider: providerName, Limit: 1})
	if err != nil {
		p.log.Warn("free-tier provision skipped: list failed", zap.Error(err))
		return nil
	}
	if len(existing) > 0 {
		return nil // already provisioned
	}

	// Privacy: send a one-way hash of the machine fingerprint, never the raw serial. No stable
	// fingerprint (in-memory / test mode) → degrade to no free tier, never error.
	raw, err := p.fp()
	if err != nil {
		p.log.Info("free-tier provision skipped: no machine fingerprint", zap.Error(err))
		return nil
	}
	sum := sha256.Sum256([]byte(raw))
	fpHash := hex.EncodeToString(sum[:])

	res, err := p.installer.Install(ctx, llminfra.AnselmBaseURL, fpHash, clientID)
	if err != nil {
		p.log.Warn("free-tier provision skipped: install failed", zap.Error(err))
		return nil
	}

	if _, err := p.keys.CreateManaged(ctx, apikeyapp.ManagedCreateInput{
		Provider:     providerName,
		DisplayName:  displayName,
		Key:          res.Token,
		BaseURL:      llminfra.AnselmBaseURL,
		TestResponse: llminfra.AnselmProbeBody(),
	}); err != nil {
		// A display-name UNIQUE conflict means a concurrent provision won the race → idempotent no-op.
		if errors.Is(err, apikeydomain.ErrDisplayNameConflict) {
			return nil
		}
		p.log.Warn("free-tier provision: persisting managed key failed", zap.Error(err))
		return nil
	}
	p.log.Info("free-tier provisioned (managed anselm key created)")
	return nil
}
