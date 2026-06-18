package trigger

import (
	"context"
	"errors"
	"fmt"
	"time"

	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

// AppendFiring writes a pending firing. UNIQUE(workflow_id, trigger_id, dedup_key) makes a
// re-materialized fire (cron missed-tick catch-up, crash retry) idempotent: a duplicate
// returns the existing row (not-lost + not-duplicated) instead of erroring.
//
// AppendFiring 写一条 pending firing；(workflow_id, trigger_id, dedup_key) UNIQUE 让重复材化
// 幂等（重复时返已存在行，不丢且不重）。
func (s *Store) AppendFiring(ctx context.Context, f *triggerdomain.Firing) (*triggerdomain.Firing, error) {
	if f.ID == "" {
		f.ID = idgenpkg.New("trf")
	}
	if f.Status == "" {
		f.Status = triggerdomain.FiringPending
	}
	if err := s.frs.Create(ctx, f); err != nil {
		if errors.Is(err, ormpkg.ErrConflict) {
			existing, gErr := s.frs.
				WhereEq("workflow_id", f.WorkflowID).
				WhereEq("trigger_id", f.TriggerID).
				WhereEq("dedup_key", f.DedupKey).
				First(ctx)
			if gErr != nil {
				return nil, fmt.Errorf("triggerstore.AppendFiring dedup-load: %w", gErr)
			}
			return existing, nil
		}
		return nil, fmt.Errorf("triggerstore.AppendFiring: %w", err)
	}
	return f, nil
}

// ListPendingFirings returns pending firings oldest-first for the scheduler to drain.
//
// ListPendingFirings 返 pending firing（最老优先）供 scheduler 排空。
func (s *Store) ListPendingFirings(ctx context.Context, limit int) ([]*triggerdomain.Firing, error) {
	q := s.frs.WhereEq("status", triggerdomain.FiringPending).Order("created_at ASC, id ASC")
	if limit > 0 {
		q = q.Limit(limit)
	}
	rows, err := q.Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("triggerstore.ListPendingFirings: %w", err)
	}
	return rows, nil
}

// SearchFirings pages one trigger's firing inbox newest-first (the disposition surface).
//
// SearchFirings 分页某 trigger 的 firing 收件箱（最新优先，处置面）。
func (s *Store) SearchFirings(ctx context.Context, filter triggerdomain.FiringFilter) ([]*triggerdomain.Firing, string, error) {
	q := s.frs.Query()
	if filter.TriggerID != "" {
		q = q.WhereEq("trigger_id", filter.TriggerID)
	}
	if filter.Status != "" {
		q = q.WhereEq("status", filter.Status)
	}
	rows, next, err := q.Page(ctx, filter.Cursor, filter.Limit)
	if err != nil {
		return nil, "", fmt.Errorf("triggerstore.SearchFirings: %w", err)
	}
	return rows, next, nil
}

// MarkFiringOutcome sets a non-started terminal status (skipped/superseded/shed) — every
// firing reaches a terminal status, never silently dropped. Best-effort on a missing row.
//
// MarkFiringOutcome 置非 started 终态（skipped/superseded/shed）——每条 firing 都有终态，绝不静默丢。
func (s *Store) MarkFiringOutcome(ctx context.Context, firingID, status string) error {
	if _, err := s.frs.WhereEq("id", firingID).Update(ctx, "status", status); err != nil {
		return fmt.Errorf("triggerstore.MarkFiringOutcome: %w", err)
	}
	return nil
}

// SupersedePendingOlderThan marks a workflow's PENDING firings created before `before` as superseded
// — buffer_one's "keep only the latest waiting" disposition: when a new firing defers behind an
// in-flight run, every earlier waiting firing for that workflow is dropped (superseded, never run),
// so only the newest pending survives. Workspace-isolated by the orm from ctx. Returns the count.
//
// SupersedePendingOlderThan 把某 workflow 在 `before` 之前创建的 PENDING firing 标 superseded——buffer_one
// 「只留最新待处理」处置：新 firing 在在途 run 后排队时，该 workflow 更早的每条待处理 firing 被丢弃
// （superseded、永不跑），只留最新待处理。orm 据 ctx 按 workspace 隔离。返被 supersede 数。
func (s *Store) SupersedePendingOlderThan(ctx context.Context, workflowID string, before time.Time) (int64, error) {
	// created_at is stored UTC; normalize the cutoff to UTC so the comparison can never be skewed by
	// a caller passing a local-zone time (production passes the firing's own UTC created_at).
	//
	// created_at 存 UTC；把截止时刻归一到 UTC，使比较不会因调用方传本地时区时间而偏（生产传 firing 自身 UTC created_at）。
	n, err := s.frs.WhereEq("workflow_id", workflowID).
		WhereEq("status", triggerdomain.FiringPending).
		Where("created_at < ?", before.UTC()).
		Update(ctx, "status", triggerdomain.FiringSuperseded)
	if err != nil {
		return 0, fmt.Errorf("triggerstore.SupersedePendingOlderThan: %w", err)
	}
	return n, nil
}

// ClaimFiring is store-concrete (NOT in the domain Repository): the single-transaction claim
// + flowrun build, consumed by the scheduler. It atomically claims the
// firing (pending→claimed only if still pending), runs create(tx) to build the flowrun in the
// SAME tx, then backfills started + flowrun_id. A crash before commit rolls back (firing stays
// pending); there is never a claimed-but-no-flowrun strand. ErrFiringNotPending = race lost.
//
// ClaimFiring 是 store 具体方法（不在 domain 接口）：单事务 claim + 建 flowrun，
// scheduler 消费。同事务内 claim（仅当仍 pending）→ create(tx) 建 flowrun → 回填 started+flowrun_id；
// commit 前崩溃则回滚（firing 仍 pending），无 claimed-但-无-flowrun 残留态。
func (s *Store) ClaimFiring(ctx context.Context, firingID string, create func(tx *ormpkg.DB) (string, error)) (string, error) {
	var flowrunID string
	err := s.db.Transaction(ctx, func(tx *ormpkg.DB) error {
		frs := ormpkg.For[triggerdomain.Firing](tx, "trigger_firings")
		n, uErr := frs.
			WhereEq("id", firingID).
			WhereEq("status", triggerdomain.FiringPending).
			Update(ctx, "status", triggerdomain.FiringClaimed)
		if uErr != nil {
			return uErr
		}
		if n == 0 {
			return triggerdomain.ErrFiringNotPending
		}
		fid, cErr := create(tx)
		if cErr != nil {
			return cErr
		}
		flowrunID = fid
		_, fErr := frs.WhereEq("id", firingID).Updates(ctx, map[string]any{
			"status":     triggerdomain.FiringStarted,
			"flowrun_id": fid,
		})
		return fErr
	})
	if err != nil {
		if errors.Is(err, triggerdomain.ErrFiringNotPending) {
			return "", err
		}
		return "", fmt.Errorf("triggerstore.ClaimFiring: %w", err)
	}
	return flowrunID, nil
}
