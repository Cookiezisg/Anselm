// Package trigger is the orm-backed triggerdomain.Repository: triggers (soft-deleted) +
// trigger_firings (durable inbox, dedup-unique per D3) + trigger_activations (append-only
// action log, no deleted_at per D1). Workspace isolation is automatic (orm ,ws tag).
//
// Package trigger 是 triggerdomain.Repository 的 orm 实现：triggers（软删）+ trigger_firings
// （durable 收件箱，dedup 唯一，D3）+ trigger_activations（只增动作日志，无 deleted_at，D1）。
// workspace 隔离自动（orm ,ws tag）。
package trigger

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// Schema is the trigger tables' DDL (idempotent, ordered) for bootstrap to collect via
// db.Migrate. triggers carry a free-form config JSON; firings dedup on
// (workflow_id, trigger_id, dedup_key) (D3 idx_trf_dedup); activations are an append-only log.
//
// Schema 是 trigger 三表 DDL（幂等、按序）。triggers 带自由 config JSON；firings 按
// (workflow_id, trigger_id, dedup_key) 去重（D3）；activations 只增日志。
var Schema = []string{
	`CREATE TABLE IF NOT EXISTS triggers (
		id           TEXT PRIMARY KEY,
		workspace_id TEXT NOT NULL,
		name         TEXT NOT NULL,
		description  TEXT NOT NULL DEFAULT '',
		kind         TEXT NOT NULL CHECK (kind IN ('cron','webhook','fsnotify','sensor')),
		config       TEXT NOT NULL DEFAULT '{}',
		outputs      TEXT NOT NULL DEFAULT '[]',
		created_at   DATETIME NOT NULL,
		updated_at   DATETIME NOT NULL,
		deleted_at   DATETIME
	)`,
	`CREATE UNIQUE INDEX IF NOT EXISTS idx_triggers_ws_name ON triggers(workspace_id, name) WHERE deleted_at IS NULL`,
	`CREATE INDEX IF NOT EXISTS idx_triggers_ws_created ON triggers(workspace_id, created_at DESC, id DESC) WHERE deleted_at IS NULL`,

	// Column evolution — persisted pause switch (scheduler 工单⑦) + misfire watermark (工单⑨).
	// ADD COLUMN (not baked into the CREATE) so an existing install gains them on next boot; re-runs
	// rely on db.Migrate treating "duplicate column name" as already-applied (same precedent as
	// flowruns origin, 工单①).
	//
	// 列演化——持久化暂停开关（scheduler 工单⑦）+ misfire 水位（工单⑨）。用 ADD COLUMN（不并进 CREATE）
	// 使已有安装下次启动补列；重复执行靠 db.Migrate 把 "duplicate column name" 视作已应用（同 flowruns
	// origin 先例，工单①）。
	`ALTER TABLE triggers ADD COLUMN paused INTEGER NOT NULL DEFAULT 0`,
	`ALTER TABLE triggers ADD COLUMN missed_checked_at DATETIME`,

	`CREATE TABLE IF NOT EXISTS trigger_firings (
		id            TEXT PRIMARY KEY,
		workspace_id  TEXT NOT NULL,
		trigger_id    TEXT NOT NULL,
		workflow_id   TEXT NOT NULL,
		activation_id TEXT NOT NULL DEFAULT '',
		payload       TEXT NOT NULL DEFAULT '{}',
		dedup_key     TEXT NOT NULL,
		status        TEXT NOT NULL CHECK (status IN ('pending','claimed','started','skipped','superseded','shed','missed')),
		flowrun_id    TEXT NOT NULL DEFAULT '',
		created_at    DATETIME NOT NULL,
		updated_at    DATETIME NOT NULL
	)`,
	`CREATE UNIQUE INDEX IF NOT EXISTS idx_trf_dedup ON trigger_firings(workflow_id, trigger_id, dedup_key)`,
	`CREATE INDEX IF NOT EXISTS idx_trf_pending ON trigger_firings(status, created_at) WHERE status = 'pending'`,

	`CREATE TABLE IF NOT EXISTS trigger_activations (
		id           TEXT PRIMARY KEY,
		workspace_id TEXT NOT NULL,
		trigger_id   TEXT NOT NULL,
		kind         TEXT NOT NULL,
		fired        INTEGER NOT NULL DEFAULT 0,
		return_value TEXT NOT NULL DEFAULT '{}',
		payload      TEXT NOT NULL DEFAULT '{}',
		error        TEXT NOT NULL DEFAULT '',
		detail       TEXT NOT NULL DEFAULT '',
		firing_count INTEGER NOT NULL DEFAULT 0,
		created_at   DATETIME NOT NULL
	)`,
	`CREATE INDEX IF NOT EXISTS idx_tra_ws_trigger ON trigger_activations(workspace_id, trigger_id, created_at DESC, id DESC)`,
}

// FiringsMissedMarker / FiringsCheckRebuild: the status CHECK gained 'missed' (scheduler 工单⑨),
// and SQLite cannot ALTER a CHECK — an existing install must REBUILD the table. bootstrap runs
// this through db.MigrateRebuild, which is idempotent BY OUTCOME: it rebuilds only while the live
// sqlite_master DDL lacks the marker, so a fresh install (CREATE above already carries 'missed')
// and every post-rebuild boot are no-ops. Data is copied column-for-column; the two indexes drop
// with the old table and are recreated.
//
// FiringsMissedMarker / FiringsCheckRebuild：status CHECK 加词 'missed'（scheduler 工单⑨），而
// SQLite 无法 ALTER CHECK——已有安装必须**重建**该表。bootstrap 经 db.MigrateRebuild 执行，靠
// **结果幂等**：仅当 sqlite_master 里的现行 DDL 缺该标记词才重建，故全新安装（上方 CREATE 已含
// 'missed'）与重建后的每次启动都是 no-op。数据逐列拷贝；两索引随旧表落、重建时重建。
var (
	FiringsMissedMarker = "'missed'"

	FiringsCheckRebuild = []string{
		`CREATE TABLE trigger_firings_rebuild (
			id            TEXT PRIMARY KEY,
			workspace_id  TEXT NOT NULL,
			trigger_id    TEXT NOT NULL,
			workflow_id   TEXT NOT NULL,
			activation_id TEXT NOT NULL DEFAULT '',
			payload       TEXT NOT NULL DEFAULT '{}',
			dedup_key     TEXT NOT NULL,
			status        TEXT NOT NULL CHECK (status IN ('pending','claimed','started','skipped','superseded','shed','missed')),
			flowrun_id    TEXT NOT NULL DEFAULT '',
			created_at    DATETIME NOT NULL,
			updated_at    DATETIME NOT NULL
		)`,
		// Target columns spelled out: a bare INSERT … SELECT is POSITIONAL, so a column added to the
		// CREATE above (or reordered) would silently copy values into the wrong columns of a real
		// user's table. Naming both sides makes the copy fail loudly instead. rebuild_test.go proves
		// the rebuilt shape is byte-for-byte the shape a fresh install gets.
		//
		// 目标列写全：裸 INSERT … SELECT 是**按位**的，上面 CREATE 加一列（或换序）就会把值静默灌进真实
		// 用户表的错误列里。两侧都点名，则拷贝会大声失败而非错位。rebuild_test.go 证明重建出的形状与全新
		// 安装拿到的形状逐列相同。
		`INSERT INTO trigger_firings_rebuild
			(id, workspace_id, trigger_id, workflow_id, activation_id, payload, dedup_key, status, flowrun_id, created_at, updated_at)
			SELECT id, workspace_id, trigger_id, workflow_id, activation_id, payload, dedup_key, status, flowrun_id, created_at, updated_at
			FROM trigger_firings`,
		`DROP TABLE trigger_firings`,
		`ALTER TABLE trigger_firings_rebuild RENAME TO trigger_firings`,
		`CREATE UNIQUE INDEX idx_trf_dedup ON trigger_firings(workflow_id, trigger_id, dedup_key)`,
		`CREATE INDEX idx_trf_pending ON trigger_firings(status, created_at) WHERE status = 'pending'`,
	}
)

// Store implements triggerdomain.Repository over pkg/orm.
type Store struct {
	db   *ormpkg.DB
	trgs *ormpkg.Repo[triggerdomain.Trigger]
	frs  *ormpkg.Repo[triggerdomain.Firing]
	acts *ormpkg.Repo[triggerdomain.Activation]
}

// New constructs a Store bound to the three trigger tables.
func New(db *ormpkg.DB) *Store {
	return &Store{
		db:   db,
		trgs: ormpkg.For[triggerdomain.Trigger](db, "triggers"),
		frs:  ormpkg.For[triggerdomain.Firing](db, "trigger_firings"),
		acts: ormpkg.For[triggerdomain.Activation](db, "trigger_activations"),
	}
}

var _ triggerdomain.Repository = (*Store)(nil)

// --- triggers --------------------------------------------------------------

func (s *Store) SaveTrigger(ctx context.Context, t *triggerdomain.Trigger) error {
	if err := s.trgs.Save(ctx, t); err != nil {
		if errors.Is(err, ormpkg.ErrConflict) {
			return triggerdomain.ErrDuplicateName
		}
		return fmt.Errorf("triggerstore.SaveTrigger: %w", err)
	}
	return nil
}

// EditTrigger patches only the author-editable entity columns — see the port's contract for WHY a
// whole-row Save is wrong here (it would carry Edit's stale read-time copies of the runtime columns
// back to disk, silently undoing a concurrent :pause). config/outputs are marshalled by hand:
// Updates hands raw values to the driver, the orm only serialises `,json` fields on Create/Save
// (agentstore.UpdateMeta precedent). 0 rows matched = no such trigger (the orm's workspace +
// soft-delete filters apply) → ErrNotFound.
//
// EditTrigger 只改作者可编辑的实体列——**为什么**整行 Save 在此是错的见端口契约（它会把 Edit 读时的
// 陈旧运行时列拷贝写回盘，静默抹掉并发的 `:pause`）。config/outputs 手工 marshal：Updates 把裸值直送
// driver，orm 只在 Create/Save 上序列化 `,json` 字段（agentstore.UpdateMeta 先例）。匹配 0 行 = 无此
// trigger（orm 的 workspace + 软删过滤生效）→ ErrNotFound。
func (s *Store) EditTrigger(ctx context.Context, t *triggerdomain.Trigger) error {
	cfg, err := json.Marshal(t.Config)
	if err != nil {
		return fmt.Errorf("triggerstore.EditTrigger: marshal config: %w", err)
	}
	outs, err := json.Marshal(t.Outputs)
	if err != nil {
		return fmt.Errorf("triggerstore.EditTrigger: marshal outputs: %w", err)
	}
	n, err := s.trgs.WhereEq("id", t.ID).Updates(ctx, map[string]any{
		"name":        t.Name,
		"description": t.Description,
		"config":      string(cfg),
		"outputs":     string(outs),
	})
	if err != nil {
		if errors.Is(err, ormpkg.ErrConflict) {
			return triggerdomain.ErrDuplicateName
		}
		return fmt.Errorf("triggerstore.EditTrigger: %w", err)
	}
	if n == 0 {
		return triggerdomain.ErrNotFound
	}
	return nil
}

func (s *Store) GetTrigger(ctx context.Context, id string) (*triggerdomain.Trigger, error) {
	t, err := s.trgs.Get(ctx, id)
	if errors.Is(err, ormpkg.ErrNotFound) {
		return nil, triggerdomain.ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("triggerstore.GetTrigger: %w", err)
	}
	return t, nil
}

// TriggerKind resolves a trigger's source kind for the scheduler's run-provenance stamp
// (FiringInbox port). A soft-deleted trigger reads as not-found — its in-flight firings then run
// with a NULL origin (best-effort at the caller), which is honest: the source is gone.
//
// TriggerKind 为 scheduler 的 run 溯源盖章解析 trigger 的 source kind（FiringInbox 端口）。软删的
// trigger 读作 not-found——其在途 firing 以 NULL origin 跑（调用侧 best-effort），诚实：源已不在。
func (s *Store) TriggerKind(ctx context.Context, id string) (string, error) {
	t, err := s.GetTrigger(ctx, id)
	if err != nil {
		return "", err
	}
	return t.Kind, nil
}

func (s *Store) GetTriggerByName(ctx context.Context, name string) (*triggerdomain.Trigger, error) {
	t, err := s.trgs.WhereEq("name", name).First(ctx)
	if errors.Is(err, ormpkg.ErrNotFound) {
		return nil, triggerdomain.ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("triggerstore.GetTriggerByName: %w", err)
	}
	return t, nil
}

func (s *Store) GetTriggersByIDs(ctx context.Context, ids []string) ([]*triggerdomain.Trigger, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	rows, err := s.trgs.WhereIn("id", toAny(ids)...).Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("triggerstore.GetTriggersByIDs: %w", err)
	}
	byID := make(map[string]*triggerdomain.Trigger, len(rows))
	for _, r := range rows {
		byID[r.ID] = r
	}
	out := make([]*triggerdomain.Trigger, 0, len(ids))
	for _, id := range ids {
		if r, ok := byID[id]; ok {
			out = append(out, r)
		}
	}
	return out, nil
}

func (s *Store) ListTriggers(ctx context.Context, filter triggerdomain.ListFilter) ([]*triggerdomain.Trigger, string, error) {
	rows, next, err := s.trgs.Query().Page(ctx, filter.Cursor, filter.Limit)
	if err != nil {
		return nil, "", fmt.Errorf("triggerstore.ListTriggers: %w", err)
	}
	return rows, next, nil
}

func (s *Store) ListAllTriggers(ctx context.Context) ([]*triggerdomain.Trigger, error) {
	rows, err := s.trgs.Order("created_at DESC, id DESC").Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("triggerstore.ListAllTriggers: %w", err)
	}
	return rows, nil
}

// SetTriggerPaused flips the persisted pause switch alone (scheduler 工单⑦) — a targeted UPDATE
// (orm stamps updated_at), never a whole-row Save, so it composes with concurrent Edits. 0 rows
// matched = the trigger doesn't exist (workspace-scoped soft-delete filter applies) → ErrNotFound.
//
// SetTriggerPaused 只翻持久化暂停开关（scheduler 工单⑦）——定点 UPDATE（orm 盖 updated_at）、绝不整行
// Save，与并发 Edit 可组合。匹配 0 行 = trigger 不存在（workspace 隔离 + 软删过滤生效）→ ErrNotFound。
func (s *Store) SetTriggerPaused(ctx context.Context, id string, paused bool) error {
	n, err := s.trgs.WhereEq("id", id).Update(ctx, "paused", paused)
	if err != nil {
		return fmt.Errorf("triggerstore.SetTriggerPaused: %w", err)
	}
	if n == 0 {
		return triggerdomain.ErrNotFound
	}
	return nil
}

// AdvanceMissedWatermark moves missed_checked_at forward monotonically (scheduler 工单⑨). Raw SQL
// on purpose: the orm Updates path always bumps updated_at, and the watermark advances on EVERY
// cron fan-out — churning updated_at would turn the row's edit timestamp into noise. The guard
// `missed_checked_at < ?` keeps out-of-order writers (fan-out vs sweep vs resume) from regressing
// the watermark. 0 rows matched (missing/soft-deleted row, or an older `at`) is a harmless no-op.
//
// AdvanceMissedWatermark 单调推进 missed_checked_at（scheduler 工单⑨）。刻意用裸 SQL：orm 的 Updates
// 一律刷 updated_at，而水位在**每次** cron 扇出时推进——搅动 updated_at 会让行的编辑时间成噪声。
// `missed_checked_at < ?` 守卫使乱序写者（扇出/sweep/resume）不会把水位倒退。匹配 0 行（行不存在/
// 软删、或 `at` 更旧）为无害 no-op。
func (s *Store) AdvanceMissedWatermark(ctx context.Context, id string, at time.Time) error {
	ws, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return err
	}
	if _, err := s.db.Exec(ctx,
		`UPDATE triggers SET missed_checked_at = ?
		 WHERE id = ? AND workspace_id = ? AND deleted_at IS NULL
		   AND (missed_checked_at IS NULL OR missed_checked_at < ?)`,
		at.UTC(), id, ws, at.UTC()); err != nil {
		return fmt.Errorf("triggerstore.AdvanceMissedWatermark: %w", err)
	}
	return nil
}

func (s *Store) DeleteTrigger(ctx context.Context, id string) error {
	ok, err := s.trgs.Delete(ctx, id) // soft-delete (triggers has deleted_at)
	if err != nil {
		return fmt.Errorf("triggerstore.DeleteTrigger: %w", err)
	}
	if !ok {
		return triggerdomain.ErrNotFound
	}
	return nil
}

func toAny(ss []string) []any {
	out := make([]any, len(ss))
	for i, v := range ss {
		out[i] = v
	}
	return out
}
