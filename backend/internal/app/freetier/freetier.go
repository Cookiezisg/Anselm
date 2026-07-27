// Package freetier provisions the built-in free-tier credential: it ensures every workspace has a
// managed api_key row pointing at the Anselm gateway, registering its device proof key on first run, AND
// seeds the managed model as the workspace's default for all three scenarios (dialogue/utility/agent)
// so everything resolves out of the box. Seeding fills only UNSET scenarios (SeedDefaultsIfUnset), so
// a user's explicit pick — once the frontend model-picker exists — is never clobbered by the boot
// self-heal. Until that picker ships, the managed model IS the sensible default (there is no other
// configured model). Everything is best-effort so a degraded free tier never breaks boot or onboarding.
//
// Package freetier 开通内置免费档凭证：确保每个 workspace 有一条指向 Anselm 网关的受管 api_key 行（首次
// 运行登记设备公钥），并把受管模型播成 workspace 三 scenario（dialogue/utility/agent）的默认，使
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
	"strings"

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
	displayName  = "Anselm Free"
	clientID     = "anselm-desktop"
)

// Installer registers a free-tier device identity; *llm.InstallClient satisfies it.
//
// Installer 登记免费档设备身份；*llm.InstallClient 满足它。
type Installer interface {
	Install(ctx context.Context, baseURL, fingerprintHash, client string) (llminfra.InstallResult, error)
}

// Keys is the apikey port the provisioner needs (a subset of *apikeyapp.Service), injected at wiring.
//
// Keys 是 provisioner 所需的 apikey 端口（*apikeyapp.Service 的子集），装配时注入。
type Keys interface {
	List(ctx context.Context, filter apikeydomain.ListFilter) ([]*apikeydomain.APIKey, string, error)
	CreateManaged(ctx context.Context, in apikeyapp.ManagedCreateInput) (*apikeydomain.APIKey, error)
	// Test probes the key's provider and writes the LIVE response back as the key's capability
	// archive. Provisioning seeds a hard-coded placeholder so the app is usable offline on first
	// boot; without this refresh that placeholder would be the ONLY thing the capability catalogue
	// ever sees, and every real route profile the gateway publishes would be invisible.
	//
	// Test 探测该 key 的 provider,并把 **live** 响应写回作为该 key 的能力档案。开通时先播一份硬编码占位,
	// 使首启离线也能用;没有这次刷新,那份占位就会是能力目录**唯一**见过的东西,网关真实发布的每一份
	// route profile 都到不了这里。
	Test(ctx context.Context, id string) (*apikeyapp.TestResult, error)
	// RotateManagedCredential swaps the managed row's secret in place (same row id) — the heal seam
	// for an install the gateway no longer recognizes. See ProvisionNow.
	//
	// RotateManagedCredential 就地更换受管行的秘密(行 id 不变)——网关不再认该 install 时的修复缝。
	// 见 ProvisionNow。
	RotateManagedCredential(ctx context.Context, id, newKey, testResponse string) error
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
	// Branch FIRST on whether a row exists: the fresh path already probes once inside
	// EnsureForWorkspace (refreshCapabilities), so running the heal probe there too would knock on
	// the gateway twice per provision for nothing.
	// 先按有无行分流:全新路径在 EnsureForWorkspace 内已探测一次(refreshCapabilities),再跑自愈探针
	// 等于每次开通白敲网关两下。
	existing, _, err := p.keys.List(ctx, apikeydomain.ListFilter{Provider: providerName, Limit: 1})
	if err != nil {
		return false, fmt.Errorf("freetier.ProvisionNow: list: %w", err)
	}
	if len(existing) > 0 {
		p.seedDefaults(ctx, existing[0].ID) // same self-heal EnsureForWorkspace runs on this path 与 ensure 同款自愈
		p.healIfInstallDead(ctx, existing[0].ID)
		return true, nil
	}
	if err := p.EnsureForWorkspace(ctx); err != nil {
		return false, err
	}
	after, _, err := p.keys.List(ctx, apikeydomain.ListFilter{Provider: providerName, Limit: 1})
	if err != nil {
		return false, fmt.Errorf("freetier.ProvisionNow: list: %w", err)
	}
	return len(after) > 0, nil
}

// healIfInstallDead probes the existing managed key and, ONLY when the gateway answers
// INVALID_INSTALL, re-registers the device and swaps the credential in place.
//
// Why this exists: the managed row is immutable to the user and EnsureForWorkspace no-ops on an
// existing row, so a workspace whose install vanished on the gateway side (its database wiped, the
// install revoked) was permanently dead — every managed call 401s and nothing in the product could
// repair it. Found live during E acceptance (0725): the operator had cleared the gateway database.
//
// Why the trigger is this narrow: a probe can fail for a dozen transient reasons — offline, gateway
// restarting, rate limit — and rotating the credential on any of them would DESTROY a working
// install because the network blinked. INVALID_INSTALL is the gateway's structured wire code for
// "this identity does not exist here" (a closed public set, same contract quotaExhaustedCode leans
// on), which is precisely the one state where re-registering is the only way forward. Matching the
// code inside the probe's message is deliberate: the probe archives the upstream body verbatim, and
// the code is a stable wire constant, not display prose.
//
// Best-effort like everything else in this package: a failed heal logs and leaves the row as it was
// — the next explicit provision retries.
//
// healIfInstallDead 探测既有受管 key,**仅当**网关答 INVALID_INSTALL 时重新登记设备并就地换秘。
//
// 为什么需要它:受管行对用户不可变、EnsureForWorkspace 见行即空操作,于是 install 在网关侧消失的
// workspace(网关库被清、install 被吊销)会永久死结——每次受管调用 401,产品内无任何修复路径。
// E 真机验收(0725)实地撞上:操作者清过一次网关库。
//
// 为什么触发条件收这么窄:探测失败有一打瞬时原因——离线、网关重启、限流——在其中任何一种上轮换凭证,
// 等于因为网络眨了下眼就**毁掉**一个好端端的 install。INVALID_INSTALL 是网关「此身份在我这里不存在」的
// 结构化线缆码(封闭公开集,与 quotaExhaustedCode 依赖同一契约),恰是「重新登记是唯一出路」的那一种状态。
// 在探测消息里匹配该码是刻意的:探针原样存档上游 body,而码是稳定线缆常量、不是展示文案。
//
// 与本包其余一切同为 best-effort:自愈失败只留日志、行保持原样——下次显式 provision 再试。
func (p *Provisioner) healIfInstallDead(ctx context.Context, keyID string) {
	res, err := p.keys.Test(ctx, keyID)
	if err != nil || res == nil || res.OK {
		return // healthy, or a failure with no verdict — never rotate on those 健康,或无结论的失败——都不轮换
	}
	if !strings.Contains(res.Message, "INVALID_INSTALL") {
		return
	}
	raw, err := p.fp()
	if err != nil {
		p.log.Warn("free-tier heal skipped: no machine fingerprint", zap.Error(err))
		return
	}
	sum := sha256.Sum256([]byte(raw))
	inst, err := p.installer.Install(ctx, llminfra.AnselmGatewayBase(), hex.EncodeToString(sum[:]), clientID)
	if err != nil {
		p.log.Warn("free-tier heal skipped: re-install failed", zap.Error(err))
		return
	}
	if err := p.keys.RotateManagedCredential(ctx, keyID, inst.InstallID, llminfra.AnselmProbeBody()); err != nil {
		p.log.Warn("free-tier heal: rotating managed credential failed", zap.Error(err))
		return
	}
	p.log.Info("free-tier healed: gateway no longer knew the install; re-registered and rotated in place",
		zap.String("key_id", keyID))
	p.refreshCapabilities(ctx, keyID)
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

	res, err := p.installer.Install(ctx, llminfra.AnselmGatewayBase(), fpHash, clientID)
	if err != nil {
		p.log.Warn("free-tier provision skipped: install failed", zap.Error(err))
		return nil
	}

	k, err := p.keys.CreateManaged(ctx, apikeyapp.ManagedCreateInput{
		Provider:     providerName,
		DisplayName:  displayName,
		Key:          res.InstallID,
		BaseURL:      llminfra.AnselmGatewayBase(),
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
	p.refreshCapabilities(ctx, k.ID)
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

// refreshCapabilities replaces the seeded placeholder archive with the gateway's LIVE `/v1/models`
// answer, so the managed key's published limits/modalities are the gateway's truth rather than a
// constant compiled into this binary.
//
// Best-effort ON PURPOSE: first boot may be offline, and a managed key that works with placeholder
// capabilities is far better than a provisioning step that fails because the network was down. But
// the degradation is LOGGED — a silent fallback to hard-coded numbers is exactly how a desktop ends
// up quietly governing itself by values the gateway no longer publishes.
//
// refreshCapabilities 用网关 **live** 的 `/v1/models` 应答替换开通时播下的占位档案,使受管 key 公布的
// 上限/模态是**网关的真相**,而不是编进本二进制的一个常量。
//
// **刻意**做成 best-effort:首启可能离线,而「带占位能力但能用的受管 key」远好过「因为断网而失败的开通」。
// 但降级要**留日志**——静默退回硬编码数字,正是桌面端悄悄按网关早已不再公布的值自治的那条路。
func (p *Provisioner) refreshCapabilities(ctx context.Context, keyID string) {
	if p.keys == nil || keyID == "" {
		return
	}
	if _, err := p.keys.Test(ctx, keyID); err != nil {
		p.log.Warn("free-tier: live capability probe failed; keeping the seeded placeholder archive "+
			"(published limits may lag the gateway until the next successful probe)",
			zap.Error(err))
	}
}
