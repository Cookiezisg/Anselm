// Package sandbox is the application layer of PluginSandbox v2 — the unified
// runtime/env service consumed by forge / mcp / skill / conversation. The
// service orchestrates four collaborators:
//
//   - infra/sandbox extracts the embedded mise binary and exposes
//     RuntimeInstaller + EnvManager implementations.
//   - infra/store/sandbox persists the manifest tables (sandbox_runtimes +
//     sandbox_envs).
//   - domain/sandbox supplies entity types, value objects, ports, and
//     sentinel errors. *Service implements sandboxdomain.ToolRegistry so
//     EnvManagers can resolve support tools (uv / pnpm / mvn / etc.) lazily.
//   - main.go wires concrete installers + env managers at boot time.
//
// Service hides all four behind a small façade: EnsureRuntime / EnsureEnv /
// Spawn / Destroy. Bootstrap failure is non-fatal — the service stays up in
// "degraded mode" (IsReady() == false) so chat-only path keeps working;
// callers attempting runtime ops get sandboxdomain.ErrRuntimeInstallFailed
// wrapped with the bootstrap reason.
//
// Three packages share `package sandbox`:
//
//	domain/sandbox  → sandboxdomain
//	app/sandbox     → sandboxapp     ← this file
//	infra/sandbox   → sandboxinfra
//
// Package sandbox 是 PluginSandbox v2 的 application 层——forge / mcp / skill /
// conversation 共用的统一 runtime/env 服务。Service 协调四个伙伴：
//
//   - infra/sandbox 解 embed mise 二进制 + 暴露 RuntimeInstaller + EnvManager
//     实现。
//   - infra/store/sandbox 持久化 manifest 表（sandbox_runtimes + sandbox_envs）。
//   - domain/sandbox 提供实体类型、值对象、端口、sentinel 错误。*Service 实现
//     sandboxdomain.ToolRegistry，让 EnvManager 懒解析支持工具
//     （uv / pnpm / mvn 等）。
//   - main.go 启动时装配具体 installer + env manager。
//
// Service 把四者藏在小 façade 后：EnsureRuntime / EnsureEnv / Spawn / Destroy。
// Bootstrap 失败不致命——service 仍起进入"degraded mode"（IsReady()==false），
// chat-only 路径仍工作；试图调 runtime ops 的调用方拿
// sandboxdomain.ErrRuntimeInstallFailed 包装的 bootstrap 原因。
//
// 三个包共享 `package sandbox`，调用方按 §S13 起别名。
package sandbox

import (
	"context"
	"errors"
	"fmt"
	"path/filepath"
	"sync"
	"sync/atomic"
	"time"

	"go.uber.org/zap"
	"gorm.io/gorm"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
	sandboxinfra "github.com/sunweilin/forgify/backend/internal/infra/sandbox"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
)

// Service is the sandbox application façade. Field set is fixed at
// construction; installers / managers register after Bootstrap succeeds.
//
// Service 是 sandbox 应用 façade。字段集构造后固定；installer / manager 在
// Bootstrap 成功后注册。
type Service struct {
	repo        sandboxdomain.Repository
	sandboxRoot string // absolute path: <dataDir>/sandbox/
	dataDir     string // absolute path: <dataDir>/ (parent of sandbox/)
	log         *zap.Logger

	// miseBin is set by Bootstrap on success. Empty until then.
	// miseBin 由 Bootstrap 成功设置。之前为空。
	miseBin string

	// bootstrapped flips true after Bootstrap returns nil; bootstrapErr
	// holds the most recent failure (atomic so degraded-mode probes are
	// lock-free).
	//
	// bootstrapped 在 Bootstrap 返 nil 后翻 true；bootstrapErr 持最近一次
	// 失败（atomic 让 degraded-mode 探测无锁）。
	bootstrapped atomic.Bool
	bootstrapErr atomic.Pointer[error]

	// regMu guards installers + envManagers maps during registration.
	// Read-side access from EnsureRuntime / EnsureEnv / EnsureTool is also
	// guarded so a registration mid-request can't tear maps.
	//
	// regMu 注册期保护 installers + envManagers map。EnsureRuntime /
	// EnsureEnv / EnsureTool 的读侧也加锁防请求中注册撕裂。
	regMu       sync.RWMutex
	installers  map[string]sandboxdomain.RuntimeInstaller
	envManagers map[string]sandboxdomain.EnvManager

	// installLocks per-kind serialize concurrent EnsureRuntime calls for
	// the same kind (so two parallel "install python 3.12" don't race to
	// write the same disk dir or Runtime DB row).
	//
	// installLocks per-kind 序列化同 kind 的并发 EnsureRuntime（两个并发
	// "install python 3.12" 不会争同磁盘目录 / Runtime DB 行）。
	installLocks sync.Map // map[runtimeKind]*sync.Mutex

	// envLocks per-(ownerKind, ownerID) serialize concurrent EnsureEnv.
	// envLocks per-(ownerKind, ownerID) 序列化并发 EnsureEnv。
	envLocks sync.Map // map["<ownerKind>:<ownerID>"]*sync.Mutex

	// activeHandles tracks LongLived spawn handles for Service.Shutdown
	// (Layer A leak prevention). nextHandleID hands out unique IDs so
	// trackedHandle can un-register itself on Wait/Kill.
	//
	// activeHandles 跟踪 LongLived spawn handle 给 Service.Shutdown（层 A
	// leak 防御）用。nextHandleID 发唯一 ID 让 trackedHandle 能在 Wait/Kill
	// 时反注册。
	activeHandles sync.Map      // map[uint64]*trackedHandle
	nextHandleID  atomic.Uint64 // monotonic ID source
}

// New constructs a Service bound to the given repository, data directory,
// and logger. Bootstrap must run successfully before EnsureRuntime / Spawn.
//
// New 构造 Service 绑给定 repository、数据目录、logger。EnsureRuntime / Spawn
// 前必须先 Bootstrap 成功。
func New(repo sandboxdomain.Repository, dataDir string, log *zap.Logger) *Service {
	if log == nil {
		panic("sandboxapp.New: nil logger")
	}
	return &Service{
		repo:        repo,
		dataDir:     dataDir,
		sandboxRoot: filepath.Join(dataDir, "sandbox"),
		log:         log,
		installers:  make(map[string]sandboxdomain.RuntimeInstaller),
		envManagers: make(map[string]sandboxdomain.EnvManager),
	}
}

// SandboxRoot returns the absolute path Service uses as its file-system
// root (`<dataDir>/sandbox/`). Useful for installers / env managers
// registered from main.go that need to know the layout.
//
// SandboxRoot 返 Service 用作文件系统根的绝对路径
// （`<dataDir>/sandbox/`）。main.go 里注册的 installer / env manager 知
// layout 用。
func (s *Service) SandboxRoot() string { return s.sandboxRoot }

// MiseBin returns the absolute path to the extracted mise binary, or
// empty string if Bootstrap hasn't succeeded.
//
// MiseBin 返已抽取 mise 二进制绝对路径；Bootstrap 未成功返空串。
func (s *Service) MiseBin() string { return s.miseBin }

// IsReady reports whether Bootstrap has succeeded. False during initial
// startup and after a bootstrap failure (degraded mode).
//
// IsReady 报告 Bootstrap 是否成功。初始启动时和 bootstrap 失败后（degraded
// mode）为 false。
func (s *Service) IsReady() bool { return s.bootstrapped.Load() }

// BootstrapError returns the most recent Bootstrap failure (or nil if no
// failure yet / last call succeeded). Used by HTTP /sandbox/bootstrap-status
// to surface the reason for degraded mode.
//
// BootstrapError 返最近 Bootstrap 失败（无失败 / 最近一次成功返 nil）。
// HTTP /sandbox/bootstrap-status 用来暴露 degraded mode 原因。
func (s *Service) BootstrapError() error {
	if e := s.bootstrapErr.Load(); e != nil {
		return *e
	}
	return nil
}

// Bootstrap extracts the embedded mise binary to <sandboxRoot>/bin/mise
// and flips IsReady() to true on success. Idempotent — re-runs no-op when
// the on-disk mise hash matches the embedded version. Failure is logged
// and recorded in bootstrapErr; Service stays alive in degraded mode.
//
// Bootstrap 把 embed mise 二进制抽到 <sandboxRoot>/bin/mise，成功后翻
// IsReady()=true。幂等——盘上 mise hash 匹配 embed 版本时重跑 no-op。
// 失败 log 并记 bootstrapErr；Service 保活进入 degraded mode。
func (s *Service) Bootstrap(ctx context.Context) error {
	miseBin, err := sandboxinfra.ExtractMiseBinary(ctx, s.dataDir, s.log)
	if err != nil {
		s.log.Warn("sandbox bootstrap failed (degraded mode active)", zap.Error(err))
		captured := err
		s.bootstrapErr.Store(&captured)
		s.bootstrapped.Store(false)
		return err
	}
	s.miseBin = miseBin
	s.bootstrapErr.Store(nil)
	s.bootstrapped.Store(true)
	s.log.Info("sandbox bootstrap ready", zap.String("mise_bin", miseBin))
	return nil
}

// RetryBootstrap re-runs Bootstrap. Triggered by POST /sandbox:retry-bootstrap
// after the user has fixed whatever blocked the first attempt.
//
// RetryBootstrap 重跑 Bootstrap。用户修了首次失败原因后由
// POST /sandbox:retry-bootstrap 触发。
func (s *Service) RetryBootstrap(ctx context.Context) error {
	return s.Bootstrap(ctx)
}

// RegisterInstaller adds a RuntimeInstaller for some kind. Idempotent —
// registering the same kind twice replaces the previous installer.
//
// RegisterInstaller 给某 kind 加 RuntimeInstaller。幂等——同 kind 注册两次
// 替换之前 installer。
func (s *Service) RegisterInstaller(installer sandboxdomain.RuntimeInstaller) {
	s.regMu.Lock()
	defer s.regMu.Unlock()
	s.installers[installer.Kind()] = installer
}

// RegisterEnvManager binds an EnvManager to its kind. EnvManagers that
// need support tools (PythonEnvManager → uv, etc.) accept a
// sandboxdomain.ToolRegistry at construction; main.go passes Service
// itself (which implements ToolRegistry).
//
// RegisterEnvManager 把 EnvManager 绑到它的 kind。需要支持工具的 EnvManager
// （PythonEnvManager → uv 等）构造时接 sandboxdomain.ToolRegistry；main.go
// 传 Service 自己（Service 实现 ToolRegistry）。
func (s *Service) RegisterEnvManager(manager sandboxdomain.EnvManager) {
	s.regMu.Lock()
	defer s.regMu.Unlock()
	s.envManagers[manager.Kind()] = manager
}

// EnsureTool implements sandboxdomain.ToolRegistry. Resolves (kind,
// version) to an absolute binary path, lazily installing the runtime if
// absent. EnvManagers call this to find support tools (uv / pnpm / mvn /
// etc.) on first use.
//
// EnsureTool 实现 sandboxdomain.ToolRegistry。把 (kind, version) 解析为
// 绝对二进制路径，缺则懒装 runtime。EnvManager 用它在首次使用时找支持
// 工具（uv / pnpm / mvn 等）。
func (s *Service) EnsureTool(ctx context.Context, kind, version string) (string, error) {
	rt, err := s.EnsureRuntime(ctx, sandboxdomain.RuntimeSpec{Kind: kind, Version: version}, nil)
	if err != nil {
		return "", err
	}
	s.regMu.RLock()
	installer, ok := s.installers[kind]
	s.regMu.RUnlock()
	if !ok {
		return "", fmt.Errorf("sandboxapp.EnsureTool %s: %w", kind, sandboxdomain.ErrRuntimeNotSupported)
	}
	bin, err := installer.Locate(rt.Version, s.sandboxRoot)
	if err != nil {
		return "", fmt.Errorf("sandboxapp.EnsureTool %s: %w", kind, err)
	}
	return bin, nil
}

// ListRuntimes returns all installed runtimes (manifest read).
//
// ListRuntimes 返所有已装 runtime（manifest 读）。
func (s *Service) ListRuntimes(ctx context.Context) ([]*sandboxdomain.Runtime, error) {
	return s.repo.ListRuntimes(ctx)
}

// ListEnvs returns envs for the given owner kind.
//
// ListEnvs 返指定 owner kind 的 env。
func (s *Service) ListEnvs(ctx context.Context, ownerKind string) ([]*sandboxdomain.Env, error) {
	return s.repo.ListEnvsByOwnerKind(ctx, ownerKind)
}

// TotalDiskUsage sums size_bytes across runtimes + envs (UI badge).
//
// TotalDiskUsage 求 runtime + env 的 size_bytes 之和（UI 徽章）。
func (s *Service) TotalDiskUsage(ctx context.Context) (int64, error) {
	return s.repo.TotalSizeBytes(ctx)
}

// EnsureRuntime is sandbox.md §8 EnsureRuntime: install the runtime if
// absent, return existing manifest row otherwise. Per-kind install lock
// prevents racing duplicates; double-checks the DB after acquiring the
// lock (someone may have installed during the wait).
//
// EnsureRuntime 是 sandbox.md §8 EnsureRuntime：缺则装 runtime，否则返已
// 有 manifest 行。Per-kind install 锁防 race 重复；获锁后双重检查 DB
// （等待期间别人可能装了）。
func (s *Service) EnsureRuntime(ctx context.Context, spec sandboxdomain.RuntimeSpec, stream sandboxdomain.ProgressFunc) (*sandboxdomain.Runtime, error) {
	if !s.IsReady() {
		return nil, fmt.Errorf("sandboxapp.EnsureRuntime: %w", sandboxdomain.ErrRuntimeInstallFailed)
	}

	s.regMu.RLock()
	installer, ok := s.installers[spec.Kind]
	s.regMu.RUnlock()
	if !ok {
		return nil, fmt.Errorf("sandboxapp.EnsureRuntime %s: %w", spec.Kind, sandboxdomain.ErrRuntimeNotSupported)
	}

	version := spec.Version
	if version == "" {
		v, err := installer.ResolveDefault(ctx)
		if err != nil {
			return nil, fmt.Errorf("sandboxapp.EnsureRuntime: resolve default %s: %w", spec.Kind, err)
		}
		version = v
	}

	// First check (no lock): hot path for already-installed runtimes.
	// 第一次检查（无锁）：已装 runtime 的热路径。
	if existing, err := s.repo.FindRuntime(ctx, spec.Kind, version); err == nil {
		return existing, nil
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, fmt.Errorf("sandboxapp.EnsureRuntime: lookup %s@%s: %w", spec.Kind, version, err)
	}

	// Take per-kind install lock.
	// 拿 per-kind install 锁。
	lock := s.kindLock(spec.Kind)
	lock.Lock()
	defer lock.Unlock()

	// Double-check after acquiring lock.
	// 获锁后双重检查。
	if existing, err := s.repo.FindRuntime(ctx, spec.Kind, version); err == nil {
		return existing, nil
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, fmt.Errorf("sandboxapp.EnsureRuntime: re-lookup %s@%s: %w", spec.Kind, version, err)
	}

	relPath, err := installer.Install(ctx, version, s.sandboxRoot, stream)
	if err != nil {
		return nil, fmt.Errorf("sandboxapp.EnsureRuntime: %w", err)
	}

	runtime := &sandboxdomain.Runtime{
		ID:          idgenpkg.New("sr"),
		Kind:        spec.Kind,
		Version:     version,
		Path:        relPath,
		SizeBytes:   computeDirSize(filepath.Join(s.sandboxRoot, relPath)),
		IsDefault:   spec.Version == "",
		InstalledAt: time.Now(),
		UpdatedAt:   time.Now(),
	}
	if err := s.repo.CreateRuntime(ctx, runtime); err != nil {
		return nil, fmt.Errorf("sandboxapp.EnsureRuntime: persist %s@%s: %w", spec.Kind, version, err)
	}
	return runtime, nil
}

// EnsureEnv is sandbox.md §8 EnsureEnv: idempotent per-(ownerKind,ownerID)
// env materialization. Existing env with matching deps + status=ready
// short-circuits; mismatched deps trigger Destroy + rebuild. Status
// transitions: installing → ready (or failed).
//
// EnsureEnv 是 sandbox.md §8 EnsureEnv：per-(ownerKind, ownerID) 幂等的
// env 物化。已存在 env + deps 一致 + status=ready 短路；deps 不一致触发
// Destroy + 重建。Status 转换：installing → ready（或 failed）。
func (s *Service) EnsureEnv(ctx context.Context, owner sandboxdomain.Owner, spec sandboxdomain.EnvSpec, stream sandboxdomain.ProgressFunc) (*sandboxdomain.Env, error) {
	if !s.IsReady() {
		return nil, fmt.Errorf("sandboxapp.EnsureEnv: %w", sandboxdomain.ErrEnvCreateFailed)
	}
	if owner.Kind == "" || owner.ID == "" {
		return nil, fmt.Errorf("sandboxapp.EnsureEnv: missing owner.Kind or owner.ID")
	}

	envLock := s.ownerLock(owner)
	envLock.Lock()
	defer envLock.Unlock()

	// Reuse existing env when deps match.
	// deps 一致时复用已存在 env。
	if existing, err := s.repo.FindEnvByOwner(ctx, owner.Kind, owner.ID); err == nil {
		if existing.Status == sandboxdomain.EnvStatusReady && depsEqual(existing.Deps, spec.Deps) && depsEqual(existing.Extras, spec.Extras) {
			s.touchLastUsed(ctx, existing)
			return existing, nil
		}
		// Deps drift → destroy stale env + rebuild.
		// deps 漂移 → 删旧 env + 重建。
		if err := s.destroyLocked(ctx, owner, existing); err != nil {
			return nil, fmt.Errorf("sandboxapp.EnsureEnv: destroy stale: %w", err)
		}
	} else if !errors.Is(err, sandboxdomain.ErrEnvNotFound) {
		return nil, fmt.Errorf("sandboxapp.EnsureEnv: lookup %s/%s: %w", owner.Kind, owner.ID, err)
	}

	// Install runtime.
	// 装 runtime。
	rt, err := s.EnsureRuntime(ctx, spec.Runtime, stream)
	if err != nil {
		return nil, fmt.Errorf("sandboxapp.EnsureEnv: %w", err)
	}

	s.regMu.RLock()
	em, ok := s.envManagers[spec.Runtime.Kind]
	s.regMu.RUnlock()
	if !ok {
		return nil, fmt.Errorf("sandboxapp.EnsureEnv %s: no env manager registered: %w", spec.Runtime.Kind, sandboxdomain.ErrRuntimeNotSupported)
	}

	envID := idgenpkg.New("se")
	envRel := filepath.Join("envs", owner.Kind, owner.ID)
	envPath := filepath.Join(s.sandboxRoot, envRel)

	now := time.Now()
	env := &sandboxdomain.Env{
		ID:         envID,
		OwnerKind:  owner.Kind,
		OwnerID:    owner.ID,
		OwnerName:  owner.Name,
		RuntimeID:  rt.ID,
		Deps:       spec.Deps,
		Extras:     spec.Extras,
		Path:       envRel,
		Status:     sandboxdomain.EnvStatusInstalling,
		CreatedAt:  now,
		LastUsedAt: now,
		UpdatedAt:  now,
	}
	if err := s.repo.CreateEnv(ctx, env); err != nil {
		return nil, fmt.Errorf("sandboxapp.EnsureEnv: persist row: %w", err)
	}

	runtimePath := filepath.Join(s.sandboxRoot, rt.Path)
	if err := em.CreateEnv(ctx, runtimePath, envPath); err != nil {
		s.markEnvFailed(ctx, env, err)
		return nil, fmt.Errorf("sandboxapp.EnsureEnv create: %w", err)
	}
	if err := em.InstallDeps(ctx, runtimePath, envPath, spec.Deps, stream); err != nil {
		s.markEnvFailed(ctx, env, err)
		return nil, fmt.Errorf("sandboxapp.EnsureEnv deps: %w", err)
	}
	if len(spec.Extras) > 0 {
		if err := em.InstallExtras(ctx, runtimePath, envPath, spec.Extras, stream); err != nil {
			s.markEnvFailed(ctx, env, err)
			return nil, fmt.Errorf("sandboxapp.EnsureEnv extras: %w", err)
		}
	}

	env.Status = sandboxdomain.EnvStatusReady
	env.SizeBytes = computeDirSize(envPath)
	env.UpdatedAt = time.Now()
	if err := s.repo.UpdateEnv(ctx, env); err != nil {
		return nil, fmt.Errorf("sandboxapp.EnsureEnv: persist ready: %w", err)
	}
	return env, nil
}

// Destroy removes an env (DB row + on-disk dir). Idempotent — non-existent
// env is not an error.
//
// Destroy 删 env（DB 行 + 盘上目录）。幂等——env 不存在不是错。
func (s *Service) Destroy(ctx context.Context, owner sandboxdomain.Owner) error {
	envLock := s.ownerLock(owner)
	envLock.Lock()
	defer envLock.Unlock()

	existing, err := s.repo.FindEnvByOwner(ctx, owner.Kind, owner.ID)
	if errors.Is(err, sandboxdomain.ErrEnvNotFound) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("sandboxapp.Destroy: lookup %s/%s: %w", owner.Kind, owner.ID, err)
	}
	return s.destroyLocked(ctx, owner, existing)
}

// destroyLocked is the inner Destroy used by EnsureEnv when the lock is
// already held (avoids re-entrant lock acquisition).
//
// destroyLocked 是 EnsureEnv 已持锁时用的内部 Destroy（避免重入获锁）。
func (s *Service) destroyLocked(ctx context.Context, owner sandboxdomain.Owner, env *sandboxdomain.Env) error {
	envPath := filepath.Join(s.sandboxRoot, env.Path)
	if err := removeAll(envPath); err != nil {
		s.log.Warn("sandbox destroy: rm env dir failed (continuing to delete row)",
			zap.String("path", envPath), zap.Error(err))
	}
	if err := s.repo.DeleteEnv(ctx, env.ID); err != nil {
		return fmt.Errorf("sandboxapp.Destroy: delete row %s: %w", env.ID, err)
	}
	return nil
}

// markEnvFailed flips Status=failed + records err.Error() in ErrorMsg.
// Best-effort — if the update itself fails, we log and let the caller
// surface the original error.
//
// markEnvFailed 翻 Status=failed + 把 err.Error() 写 ErrorMsg。Best-effort
// ——更新失败 log 让调用方上报原错。
func (s *Service) markEnvFailed(ctx context.Context, env *sandboxdomain.Env, cause error) {
	env.Status = sandboxdomain.EnvStatusFailed
	env.ErrorMsg = cause.Error()
	env.UpdatedAt = time.Now()
	if err := s.repo.UpdateEnv(ctx, env); err != nil {
		s.log.Warn("sandbox: failed-status persist failed",
			zap.String("env_id", env.ID),
			zap.Error(err))
	}
}

// touchLastUsed bumps LastUsedAt on read-path env reuse. Best-effort.
//
// touchLastUsed 在读路径 env 复用时更新 LastUsedAt。Best-effort。
func (s *Service) touchLastUsed(ctx context.Context, env *sandboxdomain.Env) {
	env.LastUsedAt = time.Now()
	if err := s.repo.UpdateEnv(ctx, env); err != nil {
		s.log.Warn("sandbox: touch last_used_at failed",
			zap.String("env_id", env.ID),
			zap.Error(err))
	}
}

// kindLock returns the per-kind install mutex, creating it on first use.
//
// kindLock 返 per-kind install 互斥，首次使用时创建。
func (s *Service) kindLock(kind string) *sync.Mutex {
	mu, _ := s.installLocks.LoadOrStore(kind, &sync.Mutex{})
	return mu.(*sync.Mutex)
}

// ownerLock returns the per-owner env mutex, creating it on first use.
//
// ownerLock 返 per-owner env 互斥，首次使用时创建。
func (s *Service) ownerLock(owner sandboxdomain.Owner) *sync.Mutex {
	key := owner.Kind + ":" + owner.ID
	mu, _ := s.envLocks.LoadOrStore(key, &sync.Mutex{})
	return mu.(*sync.Mutex)
}

// depsEqual compares two dep slices order-insensitively. Both nil and
// both empty are equal.
//
// depsEqual 顺序无关比较两个 dep 切片。两 nil 与两空都相等。
func depsEqual(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	if len(a) == 0 {
		return true
	}
	seen := make(map[string]int, len(a))
	for _, d := range a {
		seen[d]++
	}
	for _, d := range b {
		seen[d]--
		if seen[d] < 0 {
			return false
		}
	}
	return true
}
