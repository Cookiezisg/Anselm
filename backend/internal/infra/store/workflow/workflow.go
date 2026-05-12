// Package workflow (infra/store/workflow) is the GORM-backed implementation
// of the domain workflow Repository port. All methods scope by ctx userID —
// callers MUST run InjectUserID middleware first.
//
// Shares its name with domain/workflow by design; importers alias as
// `workflowstore`.
//
// Package workflow(infra/store/workflow)是 domain workflow Repository 的
// GORM 实现。所有方法按 ctx userID 过滤;调用方先跑 InjectUserID 中间件。
// 包名跟 domain/workflow 同名是刻意的;外部 import 起别名 workflowstore。
package workflow

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"gorm.io/gorm"

	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
	paginationpkg "github.com/sunweilin/forgify/backend/internal/pkg/pagination"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// Store is the GORM implementation of workflowdomain.Repository.
//
// Store 是 workflowdomain.Repository 的 GORM 实现。
type Store struct {
	db *gorm.DB
}

// New constructs a Store bound to the given *gorm.DB.
//
// New 基于给定 *gorm.DB 构造 Store。
func New(db *gorm.DB) *Store {
	return &Store{db: db}
}

// Compile-time interface assertion.
//
// 编译期接口兼容性断言。
var _ workflowdomain.Repository = (*Store)(nil)

// AutoMigrateModels returns the GORM models to register in db.AutoMigrate
// (called from cmd/server/main.go).
//
// AutoMigrateModels 返回 cmd/server/main.go 注册 AutoMigrate 用的 GORM models。
func AutoMigrateModels() []interface{} {
	return []interface{}{
		&workflowdomain.Workflow{},
		&workflowdomain.Version{},
	}
}

// ── Workflow CRUD ─────────────────────────────────────────────────────────────

// SaveWorkflow upserts by primary key. UNIQUE violation on (user_id, name)
// WHERE deleted_at IS NULL → ErrDuplicateName.
//
// SaveWorkflow 按主键 upsert;name 重复(partial UNIQUE)返 ErrDuplicateName。
func (s *Store) SaveWorkflow(ctx context.Context, w *workflowdomain.Workflow) error {
	if err := s.db.WithContext(ctx).Save(w).Error; err != nil {
		if isWorkflowDuplicateName(err) {
			return workflowdomain.ErrDuplicateName
		}
		return fmt.Errorf("workflowstore.SaveWorkflow: %w", err)
	}
	return nil
}

// GetWorkflow fetches by id, scoped to caller. ErrNotFound on miss.
//
// GetWorkflow 按 id 查,按调用者过滤;未命中返 ErrNotFound。
func (s *Store) GetWorkflow(ctx context.Context, id string) (*workflowdomain.Workflow, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	var w workflowdomain.Workflow
	res := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, uid).First(&w)
	if errors.Is(res.Error, gorm.ErrRecordNotFound) {
		return nil, workflowdomain.ErrNotFound
	}
	if res.Error != nil {
		return nil, fmt.Errorf("workflowstore.GetWorkflow: %w", res.Error)
	}
	return &w, nil
}

// GetWorkflowByName fetches by name, scoped to caller. ErrNotFound on miss.
//
// GetWorkflowByName 按 name 查;未命中返 ErrNotFound。
func (s *Store) GetWorkflowByName(ctx context.Context, name string) (*workflowdomain.Workflow, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	var w workflowdomain.Workflow
	res := s.db.WithContext(ctx).Where("user_id = ? AND name = ?", uid, name).First(&w)
	if errors.Is(res.Error, gorm.ErrRecordNotFound) {
		return nil, workflowdomain.ErrNotFound
	}
	if res.Error != nil {
		return nil, fmt.Errorf("workflowstore.GetWorkflowByName: %w", res.Error)
	}
	return &w, nil
}

// GetWorkflowsByIDs fetches multiple Workflows by ID slice, preserving
// input order. Skips IDs not found (caller handles missing).
//
// GetWorkflowsByIDs 批量按 id 查,保留输入顺序;未命中跳过(调用方处理)。
func (s *Store) GetWorkflowsByIDs(ctx context.Context, ids []string) ([]*workflowdomain.Workflow, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	if len(ids) == 0 {
		return []*workflowdomain.Workflow{}, nil
	}
	var rows []workflowdomain.Workflow
	if err := s.db.WithContext(ctx).Where("user_id = ? AND id IN ?", uid, ids).Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("workflowstore.GetWorkflowsByIDs: %w", err)
	}
	byID := make(map[string]*workflowdomain.Workflow, len(rows))
	for i := range rows {
		byID[rows[i].ID] = &rows[i]
	}
	out := make([]*workflowdomain.Workflow, 0, len(ids))
	for _, id := range ids {
		if w := byID[id]; w != nil {
			out = append(out, w)
		}
	}
	return out, nil
}

// ListWorkflows returns a cursor-paginated page. Order: updated_at DESC, id
// DESC (deterministic tie-breaker). EnabledOnly filters out disabled.
//
// ListWorkflows 返 cursor 分页;updated_at DESC + id DESC 确定排序。
// EnabledOnly=true 过滤掉 disabled。
func (s *Store) ListWorkflows(ctx context.Context, filter workflowdomain.ListFilter) ([]*workflowdomain.Workflow, string, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, "", err
	}
	limit := filter.Limit
	if limit <= 0 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}
	tx := s.db.WithContext(ctx).Where("user_id = ?", uid)
	if filter.EnabledOnly {
		tx = tx.Where("enabled = ?", true)
	}
	if filter.Cursor != "" {
		var c paginationpkg.Cursor
		if err := paginationpkg.DecodeCursor(filter.Cursor, &c); err != nil {
			return nil, "", fmt.Errorf("workflowstore.ListWorkflows: %w", err)
		}
		tx = tx.Where("(updated_at, id) < (?, ?)", c.CreatedAt, c.ID)
	}
	var rows []workflowdomain.Workflow
	if err := tx.Order("updated_at DESC, id DESC").Limit(limit + 1).Find(&rows).Error; err != nil {
		return nil, "", fmt.Errorf("workflowstore.ListWorkflows: %w", err)
	}
	next := ""
	if len(rows) > limit {
		last := rows[limit-1]
		var err error
		next, err = paginationpkg.EncodeCursor(paginationpkg.Cursor{CreatedAt: last.UpdatedAt, ID: last.ID})
		if err != nil {
			return nil, "", fmt.Errorf("workflowstore.ListWorkflows: %w", err)
		}
		rows = rows[:limit]
	}
	out := make([]*workflowdomain.Workflow, len(rows))
	for i := range rows {
		out[i] = &rows[i]
	}
	return out, next, nil
}

// ListAllWorkflows returns every live workflow for current user, no
// pagination. Used by SearchWorkflow (LLM ranking) + future scheduler.
//
// ListAllWorkflows 返当前用户全部活跃 workflow,无分页;SearchWorkflow + 未来
// scheduler 用。
func (s *Store) ListAllWorkflows(ctx context.Context) ([]*workflowdomain.Workflow, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	var rows []workflowdomain.Workflow
	if err := s.db.WithContext(ctx).Where("user_id = ?", uid).
		Order("updated_at DESC, id DESC").Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("workflowstore.ListAllWorkflows: %w", err)
	}
	out := make([]*workflowdomain.Workflow, len(rows))
	for i := range rows {
		out[i] = &rows[i]
	}
	return out, nil
}

// DeleteWorkflow soft-deletes by id, scoped to caller. ErrNotFound on miss.
//
// DeleteWorkflow 按 id 软删,按调用者过滤;未命中返 ErrNotFound。
func (s *Store) DeleteWorkflow(ctx context.Context, id string) error {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return err
	}
	res := s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, uid).
		Delete(&workflowdomain.Workflow{})
	if res.Error != nil {
		return fmt.Errorf("workflowstore.DeleteWorkflow: %w", res.Error)
	}
	if res.RowsAffected == 0 {
		return workflowdomain.ErrNotFound
	}
	return nil
}

// SetActiveVersion atomically updates Workflow.ActiveVersionID. Used by
// accept-pending and revert.
//
// SetActiveVersion 原子更新 ActiveVersionID(accept / revert 时用)。
func (s *Store) SetActiveVersion(ctx context.Context, workflowID, versionID string) error {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return err
	}
	res := s.db.WithContext(ctx).Model(&workflowdomain.Workflow{}).
		Where("id = ? AND user_id = ?", workflowID, uid).
		Update("active_version_id", versionID)
	if res.Error != nil {
		return fmt.Errorf("workflowstore.SetActiveVersion: %w", res.Error)
	}
	if res.RowsAffected == 0 {
		return workflowdomain.ErrNotFound
	}
	return nil
}

// SetNeedsAttention atomically updates NeedsAttention + AttentionReason.
// Service uses this when D20 capability deletion or LLM accept-pending fixes
// state.
//
// SetNeedsAttention 原子更新 NeedsAttention + AttentionReason(D20)。
func (s *Store) SetNeedsAttention(ctx context.Context, workflowID string, needs bool, reason string) error {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return err
	}
	res := s.db.WithContext(ctx).Model(&workflowdomain.Workflow{}).
		Where("id = ? AND user_id = ?", workflowID, uid).
		Updates(map[string]any{
			"needs_attention":  needs,
			"attention_reason": reason,
		})
	if res.Error != nil {
		return fmt.Errorf("workflowstore.SetNeedsAttention: %w", res.Error)
	}
	if res.RowsAffected == 0 {
		return workflowdomain.ErrNotFound
	}
	return nil
}

// ── Versions ─────────────────────────────────────────────────────────────────

// SaveVersion upserts a WorkflowVersion by primary key.
//
// SaveVersion 按主键 upsert WorkflowVersion。
func (s *Store) SaveVersion(ctx context.Context, v *workflowdomain.Version) error {
	if err := s.db.WithContext(ctx).Save(v).Error; err != nil {
		return fmt.Errorf("workflowstore.SaveVersion: %w", err)
	}
	return nil
}

// GetVersion fetches by version id. ErrVersionNotFound if absent.
//
// GetVersion 按 version id 查;未命中返 ErrVersionNotFound。
func (s *Store) GetVersion(ctx context.Context, versionID string) (*workflowdomain.Version, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, err
	}
	var v workflowdomain.Version
	res := s.db.WithContext(ctx).Where("id = ?", versionID).First(&v)
	if errors.Is(res.Error, gorm.ErrRecordNotFound) {
		return nil, workflowdomain.ErrVersionNotFound
	}
	if res.Error != nil {
		return nil, fmt.Errorf("workflowstore.GetVersion: %w", res.Error)
	}
	if err := s.assertVersionUser(ctx, &v); err != nil {
		return nil, err
	}
	return &v, nil
}

// GetVersionByNumber fetches by workflow id + integer version.
//
// GetVersionByNumber 按 workflow + 整数版本查。
func (s *Store) GetVersionByNumber(ctx context.Context, workflowID string, versionN int) (*workflowdomain.Version, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	// Confirm workflow ownership first.
	var wf workflowdomain.Workflow
	if err := s.db.WithContext(ctx).Select("id").Where("id = ? AND user_id = ?", workflowID, uid).
		First(&wf).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, workflowdomain.ErrNotFound
		}
		return nil, fmt.Errorf("workflowstore.GetVersionByNumber: %w", err)
	}
	var v workflowdomain.Version
	res := s.db.WithContext(ctx).Where("workflow_id = ? AND version = ?", workflowID, versionN).First(&v)
	if errors.Is(res.Error, gorm.ErrRecordNotFound) {
		return nil, workflowdomain.ErrVersionNotFound
	}
	if res.Error != nil {
		return nil, fmt.Errorf("workflowstore.GetVersionByNumber: %w", res.Error)
	}
	return &v, nil
}

// ListVersions returns cursor-paginated versions for a workflow, newest
// first. Filter.Status filters by pending / accepted / rejected.
//
// ListVersions 返某 workflow 版本 cursor 分页(新→旧),可按 status 过滤。
func (s *Store) ListVersions(ctx context.Context, workflowID string, filter workflowdomain.VersionListFilter) ([]*workflowdomain.Version, string, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, "", err
	}
	// Confirm workflow ownership first.
	var wf workflowdomain.Workflow
	if err := s.db.WithContext(ctx).Select("id").Where("id = ? AND user_id = ?", workflowID, uid).
		First(&wf).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, "", workflowdomain.ErrNotFound
		}
		return nil, "", fmt.Errorf("workflowstore.ListVersions: %w", err)
	}
	limit := filter.Limit
	if limit <= 0 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}
	tx := s.db.WithContext(ctx).Where("workflow_id = ?", workflowID)
	if filter.Status != "" {
		tx = tx.Where("status = ?", filter.Status)
	}
	if filter.Cursor != "" {
		var c paginationpkg.Cursor
		if err := paginationpkg.DecodeCursor(filter.Cursor, &c); err != nil {
			return nil, "", fmt.Errorf("workflowstore.ListVersions: %w", err)
		}
		tx = tx.Where("(created_at, id) < (?, ?)", c.CreatedAt, c.ID)
	}
	var rows []workflowdomain.Version
	if err := tx.Order("created_at DESC, id DESC").Limit(limit + 1).Find(&rows).Error; err != nil {
		return nil, "", fmt.Errorf("workflowstore.ListVersions: %w", err)
	}
	next := ""
	if len(rows) > limit {
		last := rows[limit-1]
		var err error
		next, err = paginationpkg.EncodeCursor(paginationpkg.Cursor{CreatedAt: last.CreatedAt, ID: last.ID})
		if err != nil {
			return nil, "", fmt.Errorf("workflowstore.ListVersions: %w", err)
		}
		rows = rows[:limit]
	}
	out := make([]*workflowdomain.Version, len(rows))
	for i := range rows {
		out[i] = &rows[i]
	}
	return out, next, nil
}

// GetPending returns the active pending version (at most one);
// ErrPendingNotFound if none.
//
// GetPending 返当前 pending(至多一个);无返 ErrPendingNotFound。
func (s *Store) GetPending(ctx context.Context, workflowID string) (*workflowdomain.Version, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	// Confirm workflow ownership.
	var wf workflowdomain.Workflow
	if err := s.db.WithContext(ctx).Select("id").Where("id = ? AND user_id = ?", workflowID, uid).
		First(&wf).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, workflowdomain.ErrNotFound
		}
		return nil, fmt.Errorf("workflowstore.GetPending: %w", err)
	}
	var v workflowdomain.Version
	res := s.db.WithContext(ctx).Where("workflow_id = ? AND status = ?",
		workflowID, workflowdomain.StatusPending).First(&v)
	if errors.Is(res.Error, gorm.ErrRecordNotFound) {
		return nil, workflowdomain.ErrPendingNotFound
	}
	if res.Error != nil {
		return nil, fmt.Errorf("workflowstore.GetPending: %w", res.Error)
	}
	return &v, nil
}

// UpdateVersionStatus transitions a version's status. versionN must be
// non-nil when transitioning to accepted; nil otherwise.
//
// UpdateVersionStatus 状态机转换;转 accepted 时 versionN 非 nil。
func (s *Store) UpdateVersionStatus(ctx context.Context, versionID, status string, versionN *int) error {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return err
	}
	updates := map[string]any{"status": status}
	if versionN != nil {
		updates["version"] = *versionN
	}
	res := s.db.WithContext(ctx).Model(&workflowdomain.Version{}).
		Where("id = ?", versionID).Updates(updates)
	if res.Error != nil {
		return fmt.Errorf("workflowstore.UpdateVersionStatus: %w", res.Error)
	}
	if res.RowsAffected == 0 {
		return workflowdomain.ErrVersionNotFound
	}
	return nil
}

// HardDeleteVersion physically deletes one Version row by ID. Used by
// Service.RejectPending after destroying the pending (D-redo-12 mirror).
//
// HardDeleteVersion 按 ID 物理删 Version 行。Service.RejectPending 用
// (镜像 D-redo-12)。
func (s *Store) HardDeleteVersion(ctx context.Context, versionID string) error {
	if err := s.db.WithContext(ctx).Where("id = ?", versionID).
		Delete(&workflowdomain.Version{}).Error; err != nil {
		return fmt.Errorf("workflowstore.HardDeleteVersion: %w", err)
	}
	return nil
}

// HardDeleteOldestAccepted keeps `keep` newest accepted versions per
// workflow and hard-deletes the rest. Called from service layer after
// each new accept.
//
// HardDeleteOldestAccepted 保留 keep 个最新 accepted 版本,其余 hard delete。
func (s *Store) HardDeleteOldestAccepted(ctx context.Context, workflowID string, keep int) error {
	if keep <= 0 {
		keep = workflowdomain.AcceptedVersionCap
	}
	var ids []string
	if err := s.db.WithContext(ctx).
		Model(&workflowdomain.Version{}).
		Where("workflow_id = ? AND status = ?", workflowID, workflowdomain.StatusAccepted).
		Order("created_at DESC, id DESC").
		Offset(keep).
		Pluck("id", &ids).Error; err != nil {
		return fmt.Errorf("workflowstore.HardDeleteOldestAccepted: %w", err)
	}
	if len(ids) == 0 {
		return nil
	}
	if err := s.db.WithContext(ctx).
		Where("id IN ?", ids).
		Delete(&workflowdomain.Version{}).Error; err != nil {
		return fmt.Errorf("workflowstore.HardDeleteOldestAccepted: %w", err)
	}
	return nil
}

// ── helpers ──────────────────────────────────────────────────────────────────

// assertVersionUser confirms the version's workflow belongs to the caller —
// cross-user reads return ErrVersionNotFound (deny by obscurity).
//
// assertVersionUser 验 version 的 workflow 归属调用者;跨用户返 ErrVersionNotFound。
func (s *Store) assertVersionUser(ctx context.Context, v *workflowdomain.Version) error {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return err
	}
	var wf workflowdomain.Workflow
	res := s.db.WithContext(ctx).Select("id", "user_id").
		Where("id = ?", v.WorkflowID).First(&wf)
	if errors.Is(res.Error, gorm.ErrRecordNotFound) || wf.UserID != uid {
		return workflowdomain.ErrVersionNotFound
	}
	if res.Error != nil {
		return fmt.Errorf("workflowstore.assertVersionUser: %w", res.Error)
	}
	return nil
}

// isWorkflowDuplicateName detects SQLite UNIQUE constraint violations on
// workflows(user_id, name) — either the partial UNIQUE index from
// schema_extras (idx_workflows_user_name_active) or the column-pair
// message SQLite emits for the same constraint. modernc.org/sqlite
// surfaces the latter form for partial indexes, hence both checks.
//
// isWorkflowDuplicateName 识别 SQLite UNIQUE 约束撞 partial UNIQUE。
// modernc 对 partial 索引的 error 文本是 "workflows.user_id, workflows.name"
// 形,两种都识。
func isWorkflowDuplicateName(err error) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	if !strings.Contains(msg, "UNIQUE constraint failed") {
		return false
	}
	return strings.Contains(msg, "idx_workflows_user_name_active") ||
		strings.Contains(msg, "workflows.user_id, workflows.name") ||
		strings.Contains(msg, "workflows.name, workflows.user_id")
}
