// Package freetier provisions the built-in free-tier credential: it ensures every workspace has a
// managed api_key row pointing at the Anselm gateway, minting a gwk_ install token on first run, AND
// seeds the managed model as the workspace's default for all three scenarios (dialogue/utility/agent)
// so everything resolves out of the box. Seeding fills only UNSET scenarios (SeedDefaultsIfUnset), so
// a user's explicit pick — once the frontend model-picker exists — is never clobbered by the boot
// self-heal. Until that picker ships, the managed model IS the sensible default (there is no other
// configured model). Everything is best-effort so a degraded free tier never breaks boot or onboarding.
//
// Package freetier 开通内置免费档凭证：确保每个 workspace 有一条指向 Anselm 网关的受管 api_key 行（首次
// 运行铸 gwk_ install token），并把受管模型播成 workspace 三 scenario（dialogue/utility/agent）的默认，使
// 一切开箱即解析。播种只填未设的 scenario（SeedDefaultsIfUnset），故用户显式选择——待前端模型选择器上线后
// ——绝不被 boot 自愈覆盖。在该选择器上线前，受管模型就是合理默认（本无其他已配模型）。所有动作 best-effort，
// 降级的免费档绝不挂 boot 或 onboarding。
package freetier

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"

	"go.uber.org/zap"

	apikeyapp "github.com/sunweilin/anselm/backend/internal/app/apikey"
	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
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

// Defaults is the workspace port for seeding scenario defaults (a subset of *workspaceapp.Service),
// injected at wiring; nil → seeding skipped. Fills only unset scenarios (never clobbers a user pick).
//
// Defaults 是播种 scenario 默认的 workspace 端口（*workspaceapp.Service 的子集），装配时注入；nil → 跳过
// 播种。只填未设 scenario（绝不覆盖用户选择）。
type Defaults interface {
	SeedDefaultsIfUnset(ctx context.Context, ref modeldomain.ModelRef) error
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
	defaults  Defaults
	installer Installer
	fp        Fingerprint
	log       *zap.Logger
}

// NewProvisioner wires dependencies; panics on nil logger. defaults may be nil (seeding skipped).
//
// NewProvisioner 装配依赖；nil logger panic。defaults 可为 nil（跳过播种）。
func NewProvisioner(keys Keys, defaults Defaults, installer Installer, fp Fingerprint, log *zap.Logger) *Provisioner {
	if log == nil {
		panic("freetier.NewProvisioner: logger is nil")
	}
	return &Provisioner{keys: keys, defaults: defaults, installer: installer, fp: fp, log: log.Named("freetierapp")}
}

// EnsureForWorkspace idempotently guarantees the workspace has a managed anselm credential. It is
// best-effort by contract: every failure path logs and returns nil, so a degraded free tier never
// breaks boot or workspace creation. ctx MUST carry the workspace (the managed row is
// workspace-scoped — orm stamps workspace_id on Save and filters List).
//
// ProvisionNow is the user-facing variant (POST /freetier:provision, WRK-062 S-7): same idempotent
// ensure, but it REPORTS — true when a managed row exists afterwards (pre-existing or just created),
// false when provisioning degraded (offline / gateway down / no fingerprint). Never errors for the
// degraded paths (they are states, not faults); only a store failure propagates.
//
// ProvisionNow 是用户侧变体(POST /freetier:provision,S-7):同一幂等 ensure,但**报告结果**——之后存在
// 受管行(原有或新建)返 true,开通降级(离线/网关挂/无指纹)返 false。降级路径不是错误、不抛;仅存储失败冒泡。
func (p *Provisioner) ProvisionNow(ctx context.Context) (bool, error) {
	if err := p.EnsureForWorkspace(ctx); err != nil {
		return false, err
	}
	existing, _, err := p.keys.List(ctx, apikeydomain.ListFilter{Provider: providerName, Limit: 1})
	if err != nil {
		return false, fmt.Errorf("freetier.ProvisionNow: list: %w", err)
	}
	return len(existing) > 0, nil
}

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
		// Already provisioned — still seed defaults (self-heal a workspace whose key predates the
		// seeding, or whose defaults were cleared). SeedDefaultsIfUnset is a no-op when all three are set.
		p.seedDefaults(ctx, existing[0].ID)
		return nil
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

	k, err := p.keys.CreateManaged(ctx, apikeyapp.ManagedCreateInput{
		Provider:     providerName,
		DisplayName:  displayName,
		Key:          res.Token,
		BaseURL:      llminfra.AnselmBaseURL,
		TestResponse: llminfra.AnselmProbeBody(),
	})
	if err != nil {
		// A display-name UNIQUE conflict means a concurrent provision won the race → idempotent no-op
		// (that winner — or the next boot's self-heal above — seeds the defaults).
		if errors.Is(err, apikeydomain.ErrDisplayNameConflict) {
			return nil
		}
		p.log.Warn("free-tier provision: persisting managed key failed", zap.Error(err))
		return nil
	}
	p.log.Info("free-tier provisioned (managed anselm key created)")
	p.seedDefaults(ctx, k.ID)
	return nil
}

// seedDefaults points the workspace's unset scenario defaults at the managed model (best-effort). It
// runs on BOTH the fresh-create and already-provisioned paths so a workspace whose key predates the
// seeding still self-heals on the next boot. nil defaults port / empty key → no-op.
//
// seedDefaults 把 workspace 未设的 scenario 默认指向受管模型（best-effort）。在新建与已开通两条路径都跑，
// 使 key 早于播种的 workspace 也在下次 boot 自愈。defaults 端口 nil / key 空 → no-op。
func (p *Provisioner) seedDefaults(ctx context.Context, keyID string) {
	if p.defaults == nil || keyID == "" {
		return
	}
	ref := modeldomain.ModelRef{APIKeyID: keyID, ModelID: llminfra.AnselmModelID}
	if err := p.defaults.SeedDefaultsIfUnset(ctx, ref); err != nil {
		p.log.Warn("free-tier: seeding workspace default models failed", zap.Error(err))
	}
}
