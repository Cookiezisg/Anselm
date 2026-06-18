package trigger

import (
	"context"
	"errors"
	"fmt"

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

// SupersedeAllButNewestPending collapses a workflow's PENDING firings to the latest — buffer_one's
// "keep only the latest waiting" disposition. It finds the newest pending firing (created_at, then id,
// DESC for a deterministic same-instant tiebreak) and marks every OTHER pending firing for that
// workflow superseded, returning the survivor's id ("" if none pending) and the count superseded.
// Order-independent: whichever firing the drain happens to process, only the newest is ever a run
// candidate — so an older waiting firing can never escape the policy by being evaluated when nothing
// is in flight. Workspace-isolated by the orm from ctx.
//
// SupersedeAllButNewestPending 把某 workflow 的 PENDING firing 收敛到最新一条——buffer_one「只留最新待处理」
// 处置。找最新待处理 firing（created_at、再 id，DESC 使同刻确定 tiebreak），把该 workflow **其余**每条待处理
// firing 标 superseded，返存活者 id（无待处理则 ""）与被 supersede 数。与处理顺序无关：无论 drain 先处理哪条，
// 只有最新一条会成为 run 候选——故更早的待处理 firing 不会因「评估时恰无 run 在途」而漏过策略。orm 据 ctx 隔离。
func (s *Store) SupersedeAllButNewestPending(ctx context.Context, workflowID string) (string, int64, error) {
	newest, err := s.frs.WhereEq("workflow_id", workflowID).
		WhereEq("status", triggerdomain.FiringPending).
		Order("created_at DESC, id DESC").First(ctx)
	if err != nil {
		if errors.Is(err, ormpkg.ErrNotFound) {
			return "", 0, nil // nothing pending for this workflow
		}
		return "", 0, fmt.Errorf("triggerstore.SupersedeAllButNewestPending: newest: %w", err)
	}
	n, err := s.frs.WhereEq("workflow_id", workflowID).
		WhereEq("status", triggerdomain.FiringPending).
		Where("id != ?", newest.ID).
		Update(ctx, "status", triggerdomain.FiringSuperseded)
	if err != nil {
		return "", 0, fmt.Errorf("triggerstore.SupersedeAllButNewestPending: %w", err)
	}
	return newest.ID, n, nil
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
