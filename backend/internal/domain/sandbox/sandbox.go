// Package sandbox is the domain layer for the unified PluginSandbox v2 —
// the runtime / env manifest used by forge, mcp, skill, and conversation
// scratch envs alike.
//
// Two persisted entities live here:
//
//   - Runtime: one installed (kind, version) tuple on disk (e.g. python
//     3.12.5, node 22.5.0). Shared across all envs of the same kind.
//   - Env: one per-owner package-isolation directory (venv / node_modules /
//     etc.) bound to a Runtime. Owner is one of forge / mcp / skill /
//     conversation; UNIQUE(owner_kind, owner_id) — a plugin instance has
//     at most one env at a time.
//
// Supporting value objects (Owner, RuntimeSpec, EnvSpec, SpawnOpts,
// ExecutionResult, LongLivedHandle, ProgressFunc) describe inputs to
// EnsureRuntime / EnsureEnv / Spawn. Sentinels surface install / spawn
// failures to the app + transport layers.
//
// Two open/closed extension ports (RuntimeInstaller, EnvManager) live in
// installer.go — adding a new runtime kind is one Installer/Manager pair
// plus one main.go registration line, with zero changes to sandbox core.
//
// Package sandbox 是统一 PluginSandbox v2 的 domain 层——forge / mcp / skill /
// 对话 scratch env 共用的 runtime / env 清单。
//
// 两个持久化实体：
//   - Runtime：磁盘上一份已装的 (kind, version)（如 python 3.12.5、node 22.5.0），
//     同 kind 的所有 env 共享。
//   - Env：per-owner 的包隔离目录（venv / node_modules / 等），绑定到一个 Runtime。
//     Owner 取 forge / mcp / skill / conversation 之一；UNIQUE(owner_kind, owner_id)
//     ——一个 plugin 实例同时最多一份 env。
//
// 支持值对象（Owner / RuntimeSpec / EnvSpec / SpawnOpts / ExecutionResult /
// LongLivedHandle / ProgressFunc）描述 EnsureRuntime / EnsureEnv / Spawn 的入参。
// Sentinels 把 install / spawn 失败上抛到 app + transport 层。
//
// 两个开闭扩展端口（RuntimeInstaller / EnvManager）放在 installer.go——加新
// runtime kind = 写一对 Installer/Manager + main.go 一行注册，sandbox 核心 0 修改。
package sandbox

import (
	"context"
	"errors"
	"io"
	"time"
)

// ── Owner ─────────────────────────────────────────────────────────────────────

// OwnerKind enumerates the four kinds of env owners. Stable strings — DB
// values + JSON wire values use these directly, so renames require a
// migration.
//
// OwnerKind 枚举四种 env 所有者类型。稳定字符串——DB 值 + JSON wire 值直接使用，
// 改名需迁移。
const (
	OwnerKindForge        = "forge"
	OwnerKindMCP          = "mcp"
	OwnerKindSkill        = "skill"
	OwnerKindConversation = "conversation"
)

// Owner identifies who owns an Env. ID semantics depend on Kind:
//
//   - forge:        EnvID hash (deps-content addressed; multiple forge
//                   versions sharing same deps share one env)
//   - mcp:          server name (e.g. "playwright")
//   - skill:        skill name
//   - conversation: "<conv_id>:<runtime_kind>" (e.g. "cv_abc:python")
//
// Name is for UI display only; not part of identity.
//
// Owner 标识 Env 的所有者。ID 语义依 Kind 而定（见上）。Name 仅用于 UI 显示，
// 不参与身份判断。
type Owner struct {
	Kind string `json:"kind"`
	ID   string `json:"id"`
	Name string `json:"name,omitempty"`
}

// ── Runtime ───────────────────────────────────────────────────────────────────

// Runtime is one installed (kind, version) on disk. Shared across all envs
// of the same kind — there is exactly one row per (kind, version) pair
// (UNIQUE constraint). IsDefault marks the kind's default version (the one
// EnsureEnv resolves an empty Version spec to).
//
// Insertion is all-or-nothing: EnsureRuntime only inserts after Install
// succeeds. Failed installs leave no row — caller retries from scratch.
//
// Runtime 是磁盘上一份已装的 (kind, version)，同 kind 所有 env 共享——
// 每对 (kind, version) 仅一行（UNIQUE）。IsDefault 标记该 kind 的默认版本
// （EnsureEnv 收到空 Version spec 时解析到这个）。
//
// 插入 all-or-nothing：EnsureRuntime 仅在 Install 成功后插行。失败不留行——
// 调用方从头重试。
type Runtime struct {
	ID          string    `gorm:"primaryKey;type:text"                                            json:"id"` // sr_<16hex>
	Kind        string    `gorm:"not null;type:text;uniqueIndex:uniq_sr_kind_version,priority:1;index:idx_sr_kind_def,priority:1" json:"kind"`
	Version     string    `gorm:"not null;type:text;uniqueIndex:uniq_sr_kind_version,priority:2"   json:"version"`
	Path        string    `gorm:"not null;type:text"                                               json:"path"`
	SizeBytes   int64     `json:"sizeBytes"`
	IsDefault   bool      `gorm:"index:idx_sr_kind_def,priority:2"                                 json:"isDefault"`
	InstalledAt time.Time `json:"installedAt"`
	UpdatedAt   time.Time `json:"updatedAt"`
}

// TableName pins the SQLite table name.
// TableName 钉死 SQLite 表名。
func (Runtime) TableName() string { return "sandbox_runtimes" }

// ── Env ───────────────────────────────────────────────────────────────────────

// EnvStatus enumerates the installation lifecycle of an Env row. Stable
// strings — DB CHECK constraint enforces the whitelist; renames require
// a migration.
//
// EnvStatus 枚举 Env 行的装机生命周期。稳定字符串——DB CHECK 约束执行白名单；
// 改名需迁移。
const (
	EnvStatusInstalling = "installing"
	EnvStatusReady      = "ready"
	EnvStatusFailed     = "failed"
)

// Env is one per-owner package-isolation directory bound to a Runtime.
// UNIQUE(owner_kind, owner_id) — one plugin instance has at most one env
// at a time. Path is relative to the sandbox envs root. Status tracks
// install lifecycle; ErrorMsg holds the captured failure text when Status
// is "failed".
//
// Env 是 per-owner 的包隔离目录，绑定到一个 Runtime。UNIQUE(owner_kind,
// owner_id)——一个 plugin 实例同时最多一份 env。Path 相对 sandbox envs 根目录。
// Status 追装机生命周期；Status="failed" 时 ErrorMsg 存捕获的失败文本。
type Env struct {
	ID         string    `gorm:"primaryKey;type:text"                                      json:"id"` // se_<16hex>
	OwnerKind  string    `gorm:"not null;type:text;uniqueIndex:uniq_se_owner,priority:1;index:idx_se_owner,priority:1;check:owner_kind IN ('forge','mcp','skill','conversation')" json:"ownerKind"`
	OwnerID    string    `gorm:"not null;type:text;uniqueIndex:uniq_se_owner,priority:2;index:idx_se_owner,priority:2" json:"ownerId"`
	OwnerName  string    `gorm:"type:text"                                                 json:"ownerName,omitempty"`
	RuntimeID  string    `gorm:"not null;type:text;index"                                  json:"runtimeId"`
	Deps       []string  `gorm:"serializer:json"                                           json:"deps"`
	Extras     []string  `gorm:"serializer:json"                                           json:"extras,omitempty"`
	Path       string    `gorm:"not null;type:text"                                        json:"path"`
	SizeBytes  int64     `json:"sizeBytes"`
	Status     string    `gorm:"not null;type:text;default:ready;check:status IN ('installing','ready','failed')" json:"status"`
	ErrorMsg   string    `gorm:"type:text"                                                 json:"errorMsg,omitempty"`
	CreatedAt  time.Time `json:"createdAt"`
	LastUsedAt time.Time `gorm:"index"                                                     json:"lastUsedAt"`
	UpdatedAt  time.Time `json:"updatedAt"`

	// RunningPID > 0 means a long-lived process from this env was alive
	// at last manifest write. Service.Bootstrap scans for these on boot
	// and kills any survivors (Layer B leak prevention; covers app crashes
	// that bypass Layer A's graceful Shutdown). 0 = no tracked process.
	//
	// RunningPID > 0 表示上次 manifest 写时该 env 有长生命周期进程活着。
	// Service.Bootstrap 启动扫这些 + 杀残留（层 B leak 防御；防 app crash
	// 绕过层 A 优雅 Shutdown）。0 = 无跟踪进程。
	// Note: explicit `column:running_pid` tag — GORM's default NamingStrategy
	// would otherwise produce "running_p_id" from the RunningPID field name
	// (it doesn't recognize PID as an acronym).
	//
	// 注：显式 `column:running_pid` tag——GORM 默认 NamingStrategy 否则
	// 会把 RunningPID 字段名转成 "running_p_id"（不识别 PID 是缩略词）。
	RunningPID       int       `gorm:"column:running_pid;default:0;index"  json:"runningPid,omitempty"`
	RunningStartedAt time.Time `                                            json:"runningStartedAt,omitempty"`
}

// TableName pins the SQLite table name.
// TableName 钉死 SQLite 表名。
func (Env) TableName() string { return "sandbox_envs" }

// ── Specs / Spawn / Result ────────────────────────────────────────────────────

// RuntimeSpec describes a runtime requirement. Empty Version means "use
// the kind's default" (resolved via RuntimeInstaller.ResolveDefault).
//
// RuntimeSpec 描述一个 runtime 需求。Version 为空表示"用该 kind 默认版本"
// （通过 RuntimeInstaller.ResolveDefault 解析）。
type RuntimeSpec struct {
	Kind    string `json:"kind"`
	Version string `json:"version,omitempty"`
}

// EnvSpec describes the env an owner wants. Deps are package names per the
// runtime's native package manager (pip / npm / cargo / etc.); Extras name
// post-install steps (e.g. "browsers/chromium" for Playwright).
//
// EnvSpec 描述 owner 需要的 env。Deps 是按 runtime 包管理器原生命名的包名
// （pip / npm / cargo / 等）；Extras 是装后步骤的引用（如 Playwright 的
// "browsers/chromium"）。
type EnvSpec struct {
	Runtime RuntimeSpec `json:"runtime"`
	Deps    []string    `json:"deps,omitempty"`
	Extras  []string    `json:"extras,omitempty"`
}

// SpawnOpts is one spawn-process order. LongLived=false returns
// ExecutionResult (one-shot subprocess); LongLived=true returns a
// LongLivedHandle so caller drives stdin/stdout/wait.
//
// SpawnOpts 是一份 spawn 进程指令。LongLived=false 返 ExecutionResult
// （一次性子进程）；LongLived=true 返 LongLivedHandle，由调用方驱动
// stdin/stdout/wait。
type SpawnOpts struct {
	Cmd       string            `json:"cmd"`
	Args      []string          `json:"args,omitempty"`
	Env       map[string]string `json:"env,omitempty"`
	Stdin     []byte            `json:"-"`
	Timeout   time.Duration     `json:"timeoutMs,omitempty"`
	LongLived bool              `json:"longLived,omitempty"`
}

// ExecutionResult is the one-shot Spawn return shape.
// ExecutionResult 是一次性 Spawn 的返回形状。
type ExecutionResult struct {
	Ok       bool          `json:"ok"`
	Stdout   []byte        `json:"-"`
	Stderr   []byte        `json:"-"`
	ExitCode int           `json:"exitCode"`
	Duration time.Duration `json:"durationMs"`
}

// LongLivedHandle is the long-running spawn return shape — caller owns the
// process lifecycle and must call Wait or Kill to release resources.
//
// LongLivedHandle 是长生命周期 spawn 的返回——调用方拥有进程生命周期，
// 必须调 Wait 或 Kill 释放资源。
type LongLivedHandle interface {
	Stdin() io.WriteCloser
	Stdout() io.ReadCloser
	Stderr() io.ReadCloser
	Wait() error
	Kill() error
	PID() int
}

// ProgressFunc is the install/sync progress callback. Stage is the coarse
// phase ("downloading" / "extracting" / "installing-deps"); message is a
// human-readable detail; percent is 0-100 (use -1 when unknown).
//
// ProgressFunc 是装机/同步进度 callback。Stage 是粗阶段（"downloading" /
// "extracting" / "installing-deps"）；message 人类可读细节；percent 取 0-100
// （未知用 -1）。
type ProgressFunc func(stage, message string, percent int)

// ── Sentinels ─────────────────────────────────────────────────────────────────

// Sandbox sentinels. The transport layer maps each to an HTTP status via
// errmap (§S17); app layer wraps with `fmt.Errorf("<pkg>.<Method>: %w", err)`
// per §S16 so errors.Is walks back to these.
//
// Sandbox sentinels。transport 层通过 errmap 映射到 HTTP 状态（§S17）；
// app 层按 §S16 用 `fmt.Errorf("<pkg>.<Method>: %w", err)` 包装，errors.Is
// 可以走回这些。
var (
	ErrRuntimeNotSupported  = errors.New("sandbox: runtime kind not registered")
	ErrRuntimeInstallFailed = errors.New("sandbox: runtime install failed")
	ErrEnvNotFound          = errors.New("sandbox: env not found")
	ErrEnvCreateFailed      = errors.New("sandbox: env create failed")
	ErrDepInstallFailed     = errors.New("sandbox: dependency install failed")
	ErrSpawnFailed          = errors.New("sandbox: spawn process failed")
	ErrSpawnTimeout         = errors.New("sandbox: spawn process timeout")
	ErrEnvInUse             = errors.New("sandbox: env in use; cannot destroy")
)

// ── Repository ────────────────────────────────────────────────────────────────

// Repository is the persistence contract for sandbox manifest tables
// (sandbox_runtimes + sandbox_envs). Implemented by infra/store/sandbox.
//
// Repository 是 sandbox manifest 表（sandbox_runtimes + sandbox_envs）的
// 持久化契约。由 infra/store/sandbox 实现。
type Repository interface {
	// Runtime CRUD
	CreateRuntime(ctx context.Context, r *Runtime) error
	GetRuntime(ctx context.Context, id string) (*Runtime, error)
	FindDefaultRuntime(ctx context.Context, kind string) (*Runtime, error)
	FindRuntime(ctx context.Context, kind, version string) (*Runtime, error)
	ListRuntimes(ctx context.Context) ([]*Runtime, error)
	UpdateRuntime(ctx context.Context, r *Runtime) error
	DeleteRuntime(ctx context.Context, id string) error

	// Env CRUD
	CreateEnv(ctx context.Context, e *Env) error
	GetEnv(ctx context.Context, id string) (*Env, error)
	FindEnvByOwner(ctx context.Context, ownerKind, ownerID string) (*Env, error)
	ListEnvsByRuntime(ctx context.Context, runtimeID string) ([]*Env, error)
	ListEnvsByOwnerKind(ctx context.Context, ownerKind string) ([]*Env, error)
	UpdateEnv(ctx context.Context, e *Env) error
	DeleteEnv(ctx context.Context, id string) error

	// Aggregate queries — UI disk-usage display + GC candidate selection.
	// 聚合查询——UI 显示磁盘占用 + GC 候选筛选。
	TotalSizeBytes(ctx context.Context) (int64, error)
	ListEnvsLastUsedBefore(ctx context.Context, t time.Time) ([]*Env, error)

	// Layer B leak prevention: track + scan running PIDs.
	// 层 B leak 防御：跟踪 + 扫描 running PID。
	SetEnvRunningPID(ctx context.Context, envID string, pid int) error
	ClearEnvRunningPID(ctx context.Context, envID string) error
	ListEnvsWithRunningPID(ctx context.Context) ([]*Env, error)
}
