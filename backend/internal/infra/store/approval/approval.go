// Package approval is the GORM-backed approvals projection (17 §9). The journal is the execution
// truth (signal_awaited / signal_received); these rows are the UI inbox + audit trail the frontend
// approval banner/queue reads to learn WHICH node is parked and to record who decided + why.
//
// Package approval 是 approvals 投影 store;journal 是执行真相,本表供前端 inbox/审计。
package approval

import (
	"context"
	"fmt"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

type Store struct {
	db *gorm.DB
}

func New(db *gorm.DB) *Store { return &Store{db: db} }

// AutoMigrateModels returns the approvals model (also migrated in main.go's list; provided for tests).
func AutoMigrateModels() []interface{} {
	return []interface{}{&flowrundomain.Approval{}}
}

// Park upserts a parked row when the interpreter parks at an approval. Idempotent on replay:
// UNIQUE(flowrun_id, node_id) + DoNothing means the first park wins and a re-walk is a no-op.
//
// Park 在 interpreter park 时插入 parked 行;重放幂等(UNIQUE + DoNothing,首次胜、重走无操作)。
func (s *Store) Park(ctx context.Context, a *flowrundomain.Approval) error {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return err
	}
	if a.ID == "" {
		a.ID = idgenpkg.New("apr")
	}
	a.UserID = uid
	if a.Status == "" {
		a.Status = flowrundomain.ApprovalParked
	}
	if err := s.db.WithContext(ctx).Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "flowrun_id"}, {Name: "node_id"}},
		DoNothing: true,
	}).Create(a).Error; err != nil {
		return fmt.Errorf("approvalstore.Park: %w", err)
	}
	return nil
}

// Decide flips the still-parked row to approved/rejected with reason + decided_at. RowsAffected==0
// (already decided / no row) is not an error — the journal signal is the truth, this is a projection.
//
// Decide 把 parked 行翻成 approved/rejected(+reason/decided_at);RowsAffected==0 不算错(投影)。
func (s *Store) Decide(ctx context.Context, flowrunID, nodeID, status, reason string) error {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return err
	}
	now := time.Now().UTC()
	if err := s.db.WithContext(ctx).Model(&flowrundomain.Approval{}).
		Where("flowrun_id = ? AND node_id = ? AND user_id = ? AND status = ?", flowrunID, nodeID, uid, flowrundomain.ApprovalParked).
		Updates(map[string]any{"status": status, "reason": reason, "decided_at": now}).Error; err != nil {
		return fmt.Errorf("approvalstore.Decide: %w", err)
	}
	return nil
}

// CancelParked flips every still-parked row of a flowrun to cancelled (flowrun cancel, 07).
//
// CancelParked 把一个 flowrun 所有仍 parked 的行翻成 cancelled(flowrun 取消时)。
func (s *Store) CancelParked(ctx context.Context, flowrunID string) error {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return err
	}
	now := time.Now().UTC()
	if err := s.db.WithContext(ctx).Model(&flowrundomain.Approval{}).
		Where("flowrun_id = ? AND user_id = ? AND status = ?", flowrunID, uid, flowrundomain.ApprovalParked).
		Updates(map[string]any{"status": flowrundomain.ApprovalCancelled, "decided_at": now}).Error; err != nil {
		return fmt.Errorf("approvalstore.CancelParked: %w", err)
	}
	return nil
}

// ListParked returns the ctx user's currently-parked approvals, oldest first (frontend inbox).
//
// ListParked 返当前用户所有 parked approval,按入队序(前端 inbox)。
func (s *Store) ListParked(ctx context.Context) ([]*flowrundomain.Approval, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	var out []*flowrundomain.Approval
	if err := s.db.WithContext(ctx).
		Where("user_id = ? AND status = ?", uid, flowrundomain.ApprovalParked).
		Order("created_at asc").Find(&out).Error; err != nil {
		return nil, fmt.Errorf("approvalstore.ListParked: %w", err)
	}
	return out, nil
}

// ListExpired returns all parked approvals whose deadline is non-nil and past. Used by the expiry
// checker goroutine in the scheduler to auto-decide approval nodes whose timeout elapsed.
//
// ListExpired 返所有 deadline 非 nil 且已过期的 parked approval,供 scheduler 到期检查器自动决策。
func (s *Store) ListExpired(ctx context.Context) ([]*flowrundomain.Approval, error) {
	now := time.Now().UTC()
	var out []*flowrundomain.Approval
	if err := s.db.WithContext(ctx).
		Where("status = ? AND deadline IS NOT NULL AND deadline < ?", flowrundomain.ApprovalParked, now).
		Order("deadline asc").Find(&out).Error; err != nil {
		return nil, fmt.Errorf("approvalstore.ListExpired: %w", err)
	}
	return out, nil
}
