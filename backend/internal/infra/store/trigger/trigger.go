// Package trigger is the GORM-backed durable trigger layer: the firings inbox + schedules +
// polling cursors (17 §1, Theme 3). Persist-before-act: a firing is written before any flowrun
// starts, and claimed in a single transaction (ADR-021) so there is never a claimed-but-no-flowrun
// strand.
//
// Package trigger 是 durable 触发层 store:收件箱 + 调度 + polling 游标;先持久化再动作。
package trigger

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"

	triggerdomain "github.com/sunweilin/forgify/backend/internal/domain/trigger"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
)

// ErrFiringNotPending aliases the domain sentinel — the claim lost the race (idempotent: the winner
// already created the flowrun). Kept as a store-level alias for existing callers/tests.
var ErrFiringNotPending = triggerdomain.ErrFiringNotPending

type Store struct {
	db *gorm.DB
}

func New(db *gorm.DB) *Store { return &Store{db: db} }

// AutoMigrateModels returns the durable-trigger models to register in db.AutoMigrate.
//
// AutoMigrateModels 返 AutoMigrate 用的 durable 触发 model。
func AutoMigrateModels() []interface{} {
	return []interface{}{
		&triggerdomain.TriggerSchedule{},
		&triggerdomain.TriggerFiring{},
		&triggerdomain.PollingState{},
	}
}

// AppendFiring writes a pending firing. UNIQUE(workflow_id, trigger_node_id, dedup_key) makes
// re-materialization (crash between append→bump, catchup re-compute) idempotent: a duplicate
// returns the existing firing (not-lost + not-duplicated, A-3).
//
// AppendFiring 写一条 pending firing;dedup_key UNIQUE 让重复材化幂等(不丢且不重)。
func (s *Store) AppendFiring(ctx context.Context, f *triggerdomain.TriggerFiring) (*triggerdomain.TriggerFiring, error) {
	if f.ID == "" {
		f.ID = idgenpkg.New("trf")
	}
	if f.Status == "" {
		f.Status = triggerdomain.FiringPending
	}
	if f.EnqueuedAt.IsZero() {
		f.EnqueuedAt = time.Now().UTC()
	}
	out := f
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(f).Error; err != nil {
			if isUniqueViolation(err) {
				var existing triggerdomain.TriggerFiring
				if gErr := tx.Where("workflow_id = ? AND trigger_node_id = ? AND dedup_key = ?",
					f.WorkflowID, f.TriggerNodeID, f.DedupKey).First(&existing).Error; gErr != nil {
					return gErr
				}
				out = &existing
				return nil
			}
			return err
		}
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("triggerstore.AppendFiring: %w", err)
	}
	return out, nil
}

// ListPending returns pending firings for the dispatcher to consume, oldest first.
//
// ListPending 返 pending firing 供派发器消费,按入队序。
func (s *Store) ListPending(ctx context.Context, limit int) ([]triggerdomain.TriggerFiring, error) {
	var fs []triggerdomain.TriggerFiring
	q := s.db.WithContext(ctx).Where("status = ?", triggerdomain.FiringPending).Order("enqueued_at asc")
	if limit > 0 {
		q = q.Limit(limit)
	}
	if err := q.Find(&fs).Error; err != nil {
		return nil, fmt.Errorf("triggerstore.ListPending: %w", err)
	}
	return fs, nil
}

// ClaimFiring atomically claims a pending firing and creates its flowrun in ONE transaction
// (ADR-021): claim (pending→claimed, only if still pending) → create(tx) builds the flowrun →
// backfill flowrun_id + status=started. Crash before commit rolls back (firing stays pending);
// crash after commit leaves status=started + the flowrun (boot replays it). There is no
// claimed-but-no-flowrun intermediate state. Returns ErrFiringNotPending if the claim lost the race.
//
// ClaimFiring 单事务原子认领 + 建 flowrun(ADR-021):无 "claimed 但无 flowrun" 中间态。
func (s *Store) ClaimFiring(ctx context.Context, firingID string, create func(tx *gorm.DB) (flowrunID string, err error)) (string, error) {
	var flowrunID string
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		res := tx.Model(&triggerdomain.TriggerFiring{}).
			Where("id = ? AND status = ?", firingID, triggerdomain.FiringPending).
			Update("status", triggerdomain.FiringClaimed)
		if res.Error != nil {
			return res.Error
		}
		if res.RowsAffected == 0 {
			return ErrFiringNotPending
		}
		fid, cErr := create(tx)
		if cErr != nil {
			return cErr
		}
		flowrunID = fid
		return tx.Model(&triggerdomain.TriggerFiring{}).Where("id = ?", firingID).
			Updates(map[string]any{"status": triggerdomain.FiringStarted, "flowrun_id": fid}).Error
	})
	if err != nil {
		if errors.Is(err, ErrFiringNotPending) {
			return "", err
		}
		return "", fmt.Errorf("triggerstore.ClaimFiring: %w", err)
	}
	return flowrunID, nil
}

// MarkOutcome sets a non-started terminal status on a firing (skipped/superseded/shed) — never
// silently dropped (every firing reaches a terminal status, 17 §6).
//
// MarkOutcome 给 firing 置非 started 终态(skipped/superseded/shed),绝不静默丢。
func (s *Store) MarkOutcome(ctx context.Context, firingID, status string) error {
	if err := s.db.WithContext(ctx).Model(&triggerdomain.TriggerFiring{}).
		Where("id = ?", firingID).Update("status", status).Error; err != nil {
		return fmt.Errorf("triggerstore.MarkOutcome: %w", err)
	}
	return nil
}

// UpsertSchedule persists a trigger registration (insert-or-update by PK), seeding LastFiredAt so
// cron can detect missed ticks across process restarts. Called on RegisterTrigger.
//
// UpsertSchedule 持久化 trigger 注册(主键 upsert),为 LastFiredAt 种值使 cron 跨重启补漏跑刻度。
func (s *Store) UpsertSchedule(ctx context.Context, sched *triggerdomain.TriggerSchedule) error {
	if err := s.db.WithContext(ctx).
		Where(triggerdomain.TriggerSchedule{WorkflowID: sched.WorkflowID, TriggerNodeID: sched.TriggerNodeID}).
		Assign(*sched).
		FirstOrCreate(sched).Error; err != nil {
		return fmt.Errorf("triggerstore.UpsertSchedule: %w", err)
	}
	return nil
}

// GetSchedule loads a persisted schedule row; returns nil,nil when not found.
//
// GetSchedule 加载已持久化的 schedule 行;未找到时返 nil,nil。
func (s *Store) GetSchedule(ctx context.Context, workflowID, nodeID string) (*triggerdomain.TriggerSchedule, error) {
	var row triggerdomain.TriggerSchedule
	err := s.db.WithContext(ctx).
		Where("workflow_id = ? AND trigger_node_id = ?", workflowID, nodeID).
		First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("triggerstore.GetSchedule: %w", err)
	}
	return &row, nil
}

// UpdateLastFiredAt stamps the last-fired timestamp so cron can detect missed ticks across restarts.
//
// UpdateLastFiredAt 更新 last_fired_at,供 cron 跨重启侦测漏跑刻度。
func (s *Store) UpdateLastFiredAt(ctx context.Context, workflowID, nodeID string, t time.Time) error {
	if err := s.db.WithContext(ctx).
		Model(&triggerdomain.TriggerSchedule{}).
		Where("workflow_id = ? AND trigger_node_id = ?", workflowID, nodeID).
		Update("last_fired_at", t).Error; err != nil {
		return fmt.Errorf("triggerstore.UpdateLastFiredAt: %w", err)
	}
	return nil
}

// IncrementConsecutiveFailures atomically increments the failure counter and returns the new value.
// Used to track repeated trigger failures toward workflow deactivation.
//
// IncrementConsecutiveFailures 原子递增失败计数器，返新值。
func (s *Store) IncrementConsecutiveFailures(ctx context.Context, workflowID, nodeID string) (int, error) {
	if err := s.db.WithContext(ctx).
		Model(&triggerdomain.TriggerSchedule{}).
		Where("workflow_id = ? AND trigger_node_id = ?", workflowID, nodeID).
		Update("consecutive_failures", gorm.Expr("consecutive_failures + 1")).Error; err != nil {
		return 0, fmt.Errorf("triggerstore.IncrementConsecutiveFailures: %w", err)
	}
	row, err := s.GetSchedule(ctx, workflowID, nodeID)
	if err != nil || row == nil {
		return 0, err
	}
	return row.ConsecutiveFailures, nil
}

// ResetConsecutiveFailures resets the failure counter to 0 after a successful fire.
//
// ResetConsecutiveFailures 成功 fire 后重置失败计数器。
func (s *Store) ResetConsecutiveFailures(ctx context.Context, workflowID, nodeID string) error {
	if err := s.db.WithContext(ctx).
		Model(&triggerdomain.TriggerSchedule{}).
		Where("workflow_id = ? AND trigger_node_id = ?", workflowID, nodeID).
		Update("consecutive_failures", 0).Error; err != nil {
		return fmt.Errorf("triggerstore.ResetConsecutiveFailures: %w", err)
	}
	return nil
}

// GetPollingCursor returns the persisted cursor for a polling trigger; empty string when not found.
//
// GetPollingCursor 返 polling trigger 的持久化 cursor；未找到时返 ""。
func (s *Store) GetPollingCursor(ctx context.Context, workflowID, nodeID string) (string, error) {
	var row triggerdomain.PollingState
	err := s.db.WithContext(ctx).
		Where("workflow_id = ? AND node_id = ?", workflowID, nodeID).
		First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return "", nil
	}
	if err != nil {
		return "", fmt.Errorf("triggerstore.GetPollingCursor: %w", err)
	}
	return row.Cursor, nil
}

// UpdatePollingCursor upserts the cursor for a polling trigger (insert-or-update by PK).
//
// UpdatePollingCursor 用主键 upsert 更新 polling trigger cursor。
func (s *Store) UpdatePollingCursor(ctx context.Context, workflowID, nodeID, cursor string) error {
	row := triggerdomain.PollingState{WorkflowID: workflowID, NodeID: nodeID, Cursor: cursor}
	if err := s.db.WithContext(ctx).
		Where(triggerdomain.PollingState{WorkflowID: workflowID, NodeID: nodeID}).
		Assign(triggerdomain.PollingState{Cursor: cursor}).
		FirstOrCreate(&row).Error; err != nil {
		return fmt.Errorf("triggerstore.UpdatePollingCursor: %w", err)
	}
	if row.Cursor != cursor {
		if err := s.db.WithContext(ctx).
			Model(&triggerdomain.PollingState{}).
			Where("workflow_id = ? AND node_id = ?", workflowID, nodeID).
			Update("cursor", cursor).Error; err != nil {
			return fmt.Errorf("triggerstore.UpdatePollingCursor(update): %w", err)
		}
	}
	return nil
}

func isUniqueViolation(err error) bool {
	return err != nil && strings.Contains(err.Error(), "UNIQUE constraint failed")
}
