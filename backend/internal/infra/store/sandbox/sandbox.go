// Package sandbox (infra/store/sandbox) is the GORM-backed implementation of
// sandboxdomain.Repository — the persistence layer for the sandbox manifest
// tables (sandbox_runtimes + sandbox_envs).
//
// Sandbox state is system-level (not per-user): runtimes and envs are owned
// by the local install, not by an authenticated user. Repository methods
// therefore do NOT scope by reqctx userID — unlike forge / chat / etc.
//
// The package shares its name with domain/sandbox by design; external callers
// alias at import: `sandboxstore "…/infra/store/sandbox"`.
//
// Package sandbox（infra/store/sandbox）是 sandboxdomain.Repository 的 GORM 实现
// ——sandbox manifest 表（sandbox_runtimes + sandbox_envs）的持久化层。
//
// Sandbox 状态是系统级（非 per-user）：runtime 和 env 属于本地安装，不属任何
// 登录用户。因此 Repository 方法**不**按 reqctx userID 过滤——与 forge / chat
// 等不同。
//
// 本包与 domain/sandbox 同名是刻意的；外部调用方 import 时起别名，
// 如 `sandboxstore "…/infra/store/sandbox"`。
package sandbox

import (
	"context"
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

// Store is the GORM implementation of sandboxdomain.Repository.
//
// Store 是 sandboxdomain.Repository 的 GORM 实现。
type Store struct {
	db *gorm.DB
}

// New constructs a Store bound to the given *gorm.DB.
//
// New 基于给定 *gorm.DB 构造 Store。
func New(db *gorm.DB) *Store {
	return &Store{db: db}
}

// ── Runtime CRUD ──────────────────────────────────────────────────────────────

// CreateRuntime inserts a new Runtime row. UNIQUE(kind, version) collisions
// surface as the underlying gorm error — caller decides retry / report.
//
// CreateRuntime 插入新 Runtime 行。UNIQUE(kind, version) 冲突直接上抛底层
// gorm 错误——由调用方决定重试 / 上报。
func (s *Store) CreateRuntime(ctx context.Context, r *sandboxdomain.Runtime) error {
	if err := s.db.WithContext(ctx).Create(r).Error; err != nil {
		return fmt.Errorf("sandboxstore.CreateRuntime: %w", err)
	}
	return nil
}

// GetRuntime fetches a single Runtime by id. Returns ErrEnvNotFound's
// runtime sibling — there is no dedicated ErrRuntimeNotFound sentinel; we
// surface a wrapped gorm.ErrRecordNotFound so the app layer can choose.
//
// GetRuntime 按 id 查单条 Runtime。无专属 ErrRuntimeNotFound——直接包装
// gorm.ErrRecordNotFound 上抛，让 app 层决定。
func (s *Store) GetRuntime(ctx context.Context, id string) (*sandboxdomain.Runtime, error) {
	var r sandboxdomain.Runtime
	err := s.db.WithContext(ctx).Where("id = ?", id).First(&r).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, gorm.ErrRecordNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("sandboxstore.GetRuntime: %w", err)
	}
	return &r, nil
}

// FindRuntime looks up a Runtime by exact (kind, version) — the UNIQUE pair.
// Returns gorm.ErrRecordNotFound if not installed.
//
// FindRuntime 按精确 (kind, version)（UNIQUE 对）查 Runtime。
// 未安装返 gorm.ErrRecordNotFound。
func (s *Store) FindRuntime(ctx context.Context, kind, version string) (*sandboxdomain.Runtime, error) {
	var r sandboxdomain.Runtime
	err := s.db.WithContext(ctx).
		Where("kind = ? AND version = ?", kind, version).
		First(&r).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, gorm.ErrRecordNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("sandboxstore.FindRuntime: %w", err)
	}
	return &r, nil
}

// ListRuntimes returns all installed runtimes ordered by kind then version.
// Used by the sandbox status / debug endpoint and the UI runtimes panel.
//
// ListRuntimes 返回所有已装 runtime，按 kind 再 version 排序。
// 供 sandbox 状态 / debug 端点和 UI runtimes 面板用。
func (s *Store) ListRuntimes(ctx context.Context) ([]*sandboxdomain.Runtime, error) {
	var rows []*sandboxdomain.Runtime
	if err := s.db.WithContext(ctx).
		Order("kind, version").
		Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("sandboxstore.ListRuntimes: %w", err)
	}
	return rows, nil
}

// UpdateRuntime persists changes to an existing Runtime row by primary key.
// Used to flip IsDefault / refresh SizeBytes after disk usage recompute.
//
// UpdateRuntime 按主键持久化 Runtime 修改。用于翻 IsDefault / 重算磁盘后刷
// SizeBytes。
func (s *Store) UpdateRuntime(ctx context.Context, r *sandboxdomain.Runtime) error {
	if err := s.db.WithContext(ctx).Save(r).Error; err != nil {
		return fmt.Errorf("sandboxstore.UpdateRuntime: %w", err)
	}
	return nil
}

// DeleteRuntime hard-deletes a Runtime row by id. No soft-delete — sandbox
// state mirrors disk; if the runtime dir is gone the row should also go.
// Caller is responsible for ensuring no Env still references this runtime
// (FK; SQLite enforces with PRAGMA foreign_keys=ON).
//
// DeleteRuntime 按 id 硬删 Runtime 行。不软删——sandbox 状态镜像磁盘，
// 目录没了行就该删。调用方负责确保没 Env 还引用此 runtime（FK；SQLite 在
// PRAGMA foreign_keys=ON 下会强制）。
func (s *Store) DeleteRuntime(ctx context.Context, id string) error {
	if err := s.db.WithContext(ctx).
		Where("id = ?", id).
		Delete(&sandboxdomain.Runtime{}).Error; err != nil {
		return fmt.Errorf("sandboxstore.DeleteRuntime: %w", err)
	}
	return nil
}

// ── Env CRUD ──────────────────────────────────────────────────────────────────

// CreateEnv inserts a new Env row. UNIQUE(owner_kind, owner_id) collisions
// surface as the underlying gorm error.
//
// CreateEnv 插入新 Env 行。UNIQUE(owner_kind, owner_id) 冲突直接上抛底层
// gorm 错误。
func (s *Store) CreateEnv(ctx context.Context, e *sandboxdomain.Env) error {
	if err := s.db.WithContext(ctx).Create(e).Error; err != nil {
		return fmt.Errorf("sandboxstore.CreateEnv: %w", err)
	}
	return nil
}

// GetEnv fetches a single Env by id. Returns ErrEnvNotFound on miss.
//
// GetEnv 按 id 查单条 Env。未命中返 ErrEnvNotFound。
func (s *Store) GetEnv(ctx context.Context, id string) (*sandboxdomain.Env, error) {
	var e sandboxdomain.Env
	err := s.db.WithContext(ctx).Where("id = ?", id).First(&e).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, sandboxdomain.ErrEnvNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("sandboxstore.GetEnv: %w", err)
	}
	return &e, nil
}

// FindEnvByOwner looks up an Env by (owner_kind, owner_id) — the UNIQUE pair.
// Returns ErrEnvNotFound on miss. The hot path for EnsureEnv idempotency.
//
// FindEnvByOwner 按 (owner_kind, owner_id)（UNIQUE 对）查 Env。
// 未命中返 ErrEnvNotFound。EnsureEnv 幂等的热路径。
func (s *Store) FindEnvByOwner(ctx context.Context, ownerKind, ownerID string) (*sandboxdomain.Env, error) {
	var e sandboxdomain.Env
	err := s.db.WithContext(ctx).
		Where("owner_kind = ? AND owner_id = ?", ownerKind, ownerID).
		First(&e).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, sandboxdomain.ErrEnvNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("sandboxstore.FindEnvByOwner: %w", err)
	}
	return &e, nil
}

// ListEnvsByRuntime returns all envs that reference the given runtime — used
// by Runtime GC to check "is anyone still using this?" before delete.
//
// ListEnvsByRuntime 返回所有引用该 runtime 的 env——Runtime GC 删前查
// "还有人用吗？"用。
func (s *Store) ListEnvsByRuntime(ctx context.Context, runtimeID string) ([]*sandboxdomain.Env, error) {
	var rows []*sandboxdomain.Env
	if err := s.db.WithContext(ctx).
		Where("runtime_id = ?", runtimeID).
		Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("sandboxstore.ListEnvsByRuntime: %w", err)
	}
	return rows, nil
}

// ListEnvsByOwnerKind returns all envs owned by a given kind (forge / mcp /
// skill / conversation) — used by the UI envs panel and per-kind GC.
//
// ListEnvsByOwnerKind 返回某 kind（forge / mcp / skill / conversation）拥有的
// 所有 env——UI envs 面板和 per-kind GC 用。
func (s *Store) ListEnvsByOwnerKind(ctx context.Context, ownerKind string) ([]*sandboxdomain.Env, error) {
	var rows []*sandboxdomain.Env
	if err := s.db.WithContext(ctx).
		Where("owner_kind = ?", ownerKind).
		Order("last_used_at DESC").
		Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("sandboxstore.ListEnvsByOwnerKind: %w", err)
	}
	return rows, nil
}

// UpdateEnv persists changes to an existing Env row by primary key. Used to
// flip Status (installing → ready → failed) and bump LastUsedAt on use.
//
// UpdateEnv 按主键持久化 Env 修改。用于翻 Status（installing → ready →
// failed）和使用时更新 LastUsedAt。
func (s *Store) UpdateEnv(ctx context.Context, e *sandboxdomain.Env) error {
	if err := s.db.WithContext(ctx).Save(e).Error; err != nil {
		return fmt.Errorf("sandboxstore.UpdateEnv: %w", err)
	}
	return nil
}

// DeleteEnv hard-deletes an Env row by id. No soft-delete (see DeleteRuntime
// rationale).
//
// DeleteEnv 按 id 硬删 Env 行。不软删（同 DeleteRuntime 理由）。
func (s *Store) DeleteEnv(ctx context.Context, id string) error {
	if err := s.db.WithContext(ctx).
		Where("id = ?", id).
		Delete(&sandboxdomain.Env{}).Error; err != nil {
		return fmt.Errorf("sandboxstore.DeleteEnv: %w", err)
	}
	return nil
}

// ── Aggregate queries ─────────────────────────────────────────────────────────

// TotalSizeBytes returns the sum of size_bytes across both manifest tables
// (runtimes + envs) — drives the UI "sandbox is using NN MB" badge.
//
// TotalSizeBytes 返回两个 manifest 表（runtimes + envs）size_bytes 之和——
// 驱动 UI "沙箱占用 NN MB" 徽章。
func (s *Store) TotalSizeBytes(ctx context.Context) (int64, error) {
	var rtTotal, envTotal int64
	if err := s.db.WithContext(ctx).
		Model(&sandboxdomain.Runtime{}).
		Select("COALESCE(SUM(size_bytes), 0)").
		Scan(&rtTotal).Error; err != nil {
		return 0, fmt.Errorf("sandboxstore.TotalSizeBytes: runtimes: %w", err)
	}
	if err := s.db.WithContext(ctx).
		Model(&sandboxdomain.Env{}).
		Select("COALESCE(SUM(size_bytes), 0)").
		Scan(&envTotal).Error; err != nil {
		return 0, fmt.Errorf("sandboxstore.TotalSizeBytes: envs: %w", err)
	}
	return rtTotal + envTotal, nil
}

// ListEnvsLastUsedBefore returns envs whose last_used_at is older than t —
// candidates for manual GC. Returned ordered by last_used_at ascending so
// the oldest are first.
//
// ListEnvsLastUsedBefore 返回 last_used_at 早于 t 的 env——手动 GC 候选。
// 按 last_used_at 升序返回（最旧的先）。
func (s *Store) ListEnvsLastUsedBefore(ctx context.Context, t time.Time) ([]*sandboxdomain.Env, error) {
	var rows []*sandboxdomain.Env
	if err := s.db.WithContext(ctx).
		Where("last_used_at < ?", t).
		Order("last_used_at ASC").
		Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("sandboxstore.ListEnvsLastUsedBefore: %w", err)
	}
	return rows, nil
}

// ── Layer B leak prevention ───────────────────────────────────────────────────

// SetEnvRunningPID records that a long-lived process is alive in this
// env. Service.SpawnLongLived calls this right after Start succeeds, so
// a subsequent crash leaves a manifest trail for boot-time scan.
//
// SetEnvRunningPID 记录该 env 有长生命周期进程活着。
// Service.SpawnLongLived 在 Start 成功后立刻调，让后续 crash 留下
// manifest 痕迹给启动扫描用。
func (s *Store) SetEnvRunningPID(ctx context.Context, envID string, pid int) error {
	if err := s.db.WithContext(ctx).
		Model(&sandboxdomain.Env{}).
		Where("id = ?", envID).
		Update("running_pid", pid).Error; err != nil {
		return fmt.Errorf("sandboxstore.SetEnvRunningPID %s: %w", envID, err)
	}
	return nil
}

// ClearEnvRunningPID resets running_pid to 0. trackedHandle.Wait/Kill
// calls this on graceful exit so the boot-time scan doesn't try to
// re-kill an already-dead PID.
//
// ClearEnvRunningPID 把 running_pid 重置为 0。trackedHandle.Wait/Kill
// 优雅退出时调，让启动扫描不试图再 kill 已死 PID。
func (s *Store) ClearEnvRunningPID(ctx context.Context, envID string) error {
	if err := s.db.WithContext(ctx).
		Model(&sandboxdomain.Env{}).
		Where("id = ?", envID).
		Update("running_pid", 0).Error; err != nil {
		return fmt.Errorf("sandboxstore.ClearEnvRunningPID %s: %w", envID, err)
	}
	return nil
}

// ListEnvsWithRunningPID returns envs whose running_pid > 0 — the boot-
// time scan iterates these to detect + kill survivors of the previous
// run that bypassed Layer A's graceful Shutdown.
//
// ListEnvsWithRunningPID 返 running_pid > 0 的 env——启动扫描遍历这些
// 检测 + 杀掉绕过层 A 优雅 Shutdown 的上次运行残留。
func (s *Store) ListEnvsWithRunningPID(ctx context.Context) ([]*sandboxdomain.Env, error) {
	var rows []*sandboxdomain.Env
	if err := s.db.WithContext(ctx).
		Where("running_pid > ?", 0).
		Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("sandboxstore.ListEnvsWithRunningPID: %w", err)
	}
	return rows, nil
}
