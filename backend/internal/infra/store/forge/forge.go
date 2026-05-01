// Package tool (infra/store/tool) is the GORM-backed implementation of the
// domain tool Repository port. Every method scopes queries to the userID
// carried in ctx — callers MUST have run the InjectUserID middleware.
//
// The package shares its name with domain/tool and app/tool by design;
// external callers alias at import: `forgestore "…/infra/store/tool"`.
//
// Package tool（infra/store/tool）是 domain tool Repository port 的 GORM 实现。
// 所有方法按 ctx 中的 userID 过滤——调用方必须先经过 InjectUserID 中间件。
//
// 本包与 domain/tool、app/tool 同名是刻意的；外部调用方 import 时起别名，
// 如 `forgestore "…/infra/store/tool"`。
package forge

import (
	"context"
	"errors"
	"fmt"

	"gorm.io/gorm"

	forgedomain "github.com/sunweilin/forgify/backend/internal/domain/forge"
	paginationpkg "github.com/sunweilin/forgify/backend/internal/pkg/pagination"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// Store is the GORM implementation of forgedomain.Repository.
//
// Store 是 forgedomain.Repository 的 GORM 实现。
type Store struct {
	db *gorm.DB
}

// New constructs a Store bound to the given *gorm.DB.
//
// New 基于给定 *gorm.DB 构造 Store。
func New(db *gorm.DB) *Store {
	return &Store{db: db}
}


// ── Forge CRUD ─────────────────────────────────────────────────────────────────

// SaveForge inserts or updates a Forge by primary key.
//
// SaveForge 按主键插入或更新 Forge。
func (s *Store) SaveForge(ctx context.Context, t *forgedomain.Forge) error {
	if err := s.db.WithContext(ctx).Save(t).Error; err != nil {
		return fmt.Errorf("forgestore.SaveForge: %w", err)
	}
	return nil
}

// GetForge fetches a single live Forge by id for the current user.
//
// GetForge 按 id 查当前用户的单条活跃 Forge。
func (s *Store) GetForge(ctx context.Context, id string) (*forgedomain.Forge, error) {
	userID, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	var t forgedomain.Forge
	err = s.db.WithContext(ctx).
		Where("id = ? AND user_id = ?", id, userID).
		First(&t).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, forgedomain.ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("forgestore.GetForge: %w", err)
	}
	return &t, nil
}

// GetForgesByIDs fetches multiple live Forges by id slice, preserving the
// input order. IDs that don't exist or belong to another user are silently omitted.
//
// GetForgesByIDs 按 id 切片批量查活跃 Forge，保持输入顺序。
// 不存在或属于其他用户的 ID 静默忽略。
func (s *Store) GetForgesByIDs(ctx context.Context, ids []string) ([]*forgedomain.Forge, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	userID, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	var rows []*forgedomain.Forge
	if err = s.db.WithContext(ctx).
		Where("id IN ? AND user_id = ?", ids, userID).
		Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("forgestore.GetForgesByIDs: %w", err)
	}
	// Re-order to match the requested id slice.
	// 按请求的 id 顺序重排。
	idx := make(map[string]*forgedomain.Forge, len(rows))
	for _, r := range rows {
		idx[r.ID] = r
	}
	ordered := make([]*forgedomain.Forge, 0, len(ids))
	for _, id := range ids {
		if t, ok := idx[id]; ok {
			ordered = append(ordered, t)
		}
	}
	return ordered, nil
}

// ListForges returns a cursor-paginated page of live tools for the current user,
// ordered by created_at DESC with id as tiebreaker.
//
// ListForges 返回当前用户活跃工具的 cursor 分页结果，按 created_at DESC 排序。
func (s *Store) ListForges(ctx context.Context, filter forgedomain.ListFilter) ([]*forgedomain.Forge, string, error) {
	userID, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, "", err
	}
	limit := filter.Limit
	if limit <= 0 {
		limit = 50
	}
	q := s.db.WithContext(ctx).Where("user_id = ?", userID)
	if filter.Cursor != "" {
		var c paginationpkg.Cursor
		if err := paginationpkg.DecodeCursor(filter.Cursor, &c); err != nil {
			return nil, "", fmt.Errorf("forgestore.ListForges: %w", err)
		}
		q = q.Where("(created_at, id) < (?, ?)", c.CreatedAt, c.ID)
	}
	var rows []*forgedomain.Forge
	if err = q.Order("created_at DESC, id DESC").Limit(limit + 1).Find(&rows).Error; err != nil {
		return nil, "", fmt.Errorf("forgestore.ListForges: %w", err)
	}
	var next string
	if len(rows) > limit {
		last := rows[limit-1]
		next, err = paginationpkg.EncodeCursor(paginationpkg.Cursor{CreatedAt: last.CreatedAt, ID: last.ID})
		if err != nil {
			return nil, "", fmt.Errorf("forgestore.ListForges: %w", err)
		}
		rows = rows[:limit]
	}
	return rows, next, nil
}

// ListAllForges returns all live tools for the current user without pagination.
//
// ListAllForges 返回当前用户全部活跃工具，不分页。
func (s *Store) ListAllForges(ctx context.Context) ([]*forgedomain.Forge, error) {
	userID, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	var rows []*forgedomain.Forge
	if err = s.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("created_at DESC").
		Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("forgestore.ListAllForges: %w", err)
	}
	return rows, nil
}

// DeleteForge soft-deletes a tool by id for the current user.
//
// DeleteForge 软删除当前用户的指定工具。
func (s *Store) DeleteForge(ctx context.Context, id string) error {
	userID, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return err
	}
	if err = s.db.WithContext(ctx).
		Where("id = ? AND user_id = ?", id, userID).
		Delete(&forgedomain.Forge{}).Error; err != nil {
		return fmt.Errorf("forgestore.DeleteForge: %w", err)
	}
	return nil
}

// ── Versions (including pending) ──────────────────────────────────────────────

// SaveVersion inserts a ForgeVersion record.
//
// SaveVersion 插入一条 ForgeVersion 记录。
func (s *Store) SaveVersion(ctx context.Context, v *forgedomain.ForgeVersion) error {
	if err := s.db.WithContext(ctx).Create(v).Error; err != nil {
		return fmt.Errorf("forgestore.SaveVersion: %w", err)
	}
	return nil
}

// GetVersion fetches the accepted ForgeVersion with the given version number.
//
// GetVersion 查询指定版本号的已接受版本记录。
func (s *Store) GetVersion(ctx context.Context, forgeID string, version int) (*forgedomain.ForgeVersion, error) {
	userID, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	var v forgedomain.ForgeVersion
	err = s.db.WithContext(ctx).
		Where("forge_id = ? AND user_id = ? AND version = ? AND status = ?",
			forgeID, userID, version, forgedomain.VersionStatusAccepted).
		First(&v).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, forgedomain.ErrVersionNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("forgestore.GetVersion: %w", err)
	}
	return &v, nil
}

// GetActivePending returns the pending ForgeVersion for the tool.
//
// GetActivePending 返回工具当前的 pending ForgeVersion。
func (s *Store) GetActivePending(ctx context.Context, forgeID string) (*forgedomain.ForgeVersion, error) {
	userID, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	var v forgedomain.ForgeVersion
	err = s.db.WithContext(ctx).
		Where("forge_id = ? AND user_id = ? AND status = ?",
			forgeID, userID, forgedomain.VersionStatusPending).
		First(&v).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, forgedomain.ErrPendingNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("forgestore.GetActivePending: %w", err)
	}
	return &v, nil
}

// ListAcceptedVersions returns all accepted versions for a tool, newest first.
//
// ListAcceptedVersions 返回工具所有已接受版本，最新在前。
func (s *Store) ListAcceptedVersions(ctx context.Context, forgeID string) ([]*forgedomain.ForgeVersion, error) {
	userID, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	var rows []*forgedomain.ForgeVersion
	if err = s.db.WithContext(ctx).
		Where("forge_id = ? AND user_id = ? AND status = ?",
			forgeID, userID, forgedomain.VersionStatusAccepted).
		Order("version DESC").
		Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("forgestore.ListAcceptedVersions: %w", err)
	}
	return rows, nil
}

// UpdateVersionStatus updates the status and optionally the version number.
//
// UpdateVersionStatus 更新 status 字段，可选分配版本号。
func (s *Store) UpdateVersionStatus(ctx context.Context, id, status string, version *int) error {
	updates := map[string]any{"status": status}
	if version != nil {
		updates["version"] = *version
	}
	if err := s.db.WithContext(ctx).
		Model(&forgedomain.ForgeVersion{}).
		Where("id = ?", id).
		Updates(updates).Error; err != nil {
		return fmt.Errorf("forgestore.UpdateVersionStatus: %w", err)
	}
	return nil
}

// CountAcceptedVersions returns the number of accepted versions for a tool.
//
// CountAcceptedVersions 返回工具已接受版本数。
func (s *Store) CountAcceptedVersions(ctx context.Context, forgeID string) (int64, error) {
	var n int64
	if err := s.db.WithContext(ctx).Model(&forgedomain.ForgeVersion{}).
		Where("forge_id = ? AND status = ?", forgeID, forgedomain.VersionStatusAccepted).
		Count(&n).Error; err != nil {
		return 0, fmt.Errorf("forgestore.CountAcceptedVersions: %w", err)
	}
	return n, nil
}

// DeleteOldestAcceptedVersion hard-deletes the accepted version with the
// lowest version number for the given tool.
//
// DeleteOldestAcceptedVersion 硬删除指定工具版本号最小的已接受版本。
func (s *Store) DeleteOldestAcceptedVersion(ctx context.Context, forgeID string) error {
	var v forgedomain.ForgeVersion
	err := s.db.WithContext(ctx).
		Where("forge_id = ? AND status = ?", forgeID, forgedomain.VersionStatusAccepted).
		Order("version ASC").
		First(&v).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("forgestore.DeleteOldestAcceptedVersion: find: %w", err)
	}
	if err = s.db.WithContext(ctx).Delete(&v).Error; err != nil {
		return fmt.Errorf("forgestore.DeleteOldestAcceptedVersion: delete: %w", err)
	}
	return nil
}

// ── Test cases ────────────────────────────────────────────────────────────────

// SaveTestCase inserts a ForgeTestCase.
//
// SaveTestCase 插入 ForgeTestCase。
func (s *Store) SaveTestCase(ctx context.Context, tc *forgedomain.ForgeTestCase) error {
	if err := s.db.WithContext(ctx).Create(tc).Error; err != nil {
		return fmt.Errorf("forgestore.SaveTestCase: %w", err)
	}
	return nil
}

// GetTestCase fetches a test case by id.
//
// GetTestCase 按 id 查测试用例。
func (s *Store) GetTestCase(ctx context.Context, id string) (*forgedomain.ForgeTestCase, error) {
	userID, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	var tc forgedomain.ForgeTestCase
	err = s.db.WithContext(ctx).
		Where("id = ? AND user_id = ?", id, userID).
		First(&tc).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, forgedomain.ErrTestCaseNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("forgestore.GetTestCase: %w", err)
	}
	return &tc, nil
}

// ListTestCases returns all test cases for the given tool, ordered by created_at ASC.
//
// ListTestCases 返回指定工具所有测试用例，按 created_at ASC 排序。
func (s *Store) ListTestCases(ctx context.Context, forgeID string) ([]*forgedomain.ForgeTestCase, error) {
	userID, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	var rows []*forgedomain.ForgeTestCase
	if err = s.db.WithContext(ctx).
		Where("forge_id = ? AND user_id = ?", forgeID, userID).
		Order("created_at ASC").
		Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("forgestore.ListTestCases: %w", err)
	}
	return rows, nil
}

// DeleteTestCase hard-deletes a test case by id.
//
// DeleteTestCase 硬删除测试用例。
func (s *Store) DeleteTestCase(ctx context.Context, id string) error {
	userID, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return err
	}
	if err = s.db.WithContext(ctx).
		Where("id = ? AND user_id = ?", id, userID).
		Delete(&forgedomain.ForgeTestCase{}).Error; err != nil {
		return fmt.Errorf("forgestore.DeleteTestCase: %w", err)
	}
	return nil
}

// ── Run history ───────────────────────────────────────────────────────────────

// SaveRunHistory inserts a ForgeRunHistory record.
//
// SaveRunHistory 插入 ForgeRunHistory 记录。
func (s *Store) SaveRunHistory(ctx context.Context, h *forgedomain.ForgeRunHistory) error {
	if err := s.db.WithContext(ctx).Create(h).Error; err != nil {
		return fmt.Errorf("forgestore.SaveRunHistory: %w", err)
	}
	return nil
}

// ListRunHistory returns the most recent limit records, ordered by created_at DESC.
//
// ListRunHistory 返回最近 limit 条运行历史，按 created_at DESC。
func (s *Store) ListRunHistory(ctx context.Context, forgeID string, limit int) ([]*forgedomain.ForgeRunHistory, error) {
	userID, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	var rows []*forgedomain.ForgeRunHistory
	if err = s.db.WithContext(ctx).
		Where("forge_id = ? AND user_id = ?", forgeID, userID).
		Order("created_at DESC").
		Limit(limit).
		Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("forgestore.ListRunHistory: %w", err)
	}
	return rows, nil
}

// CountRunHistory returns the total run history count for a tool.
//
// CountRunHistory 返回工具运行历史总条数。
func (s *Store) CountRunHistory(ctx context.Context, forgeID string) (int64, error) {
	var n int64
	if err := s.db.WithContext(ctx).Model(&forgedomain.ForgeRunHistory{}).
		Where("forge_id = ?", forgeID).Count(&n).Error; err != nil {
		return 0, fmt.Errorf("forgestore.CountRunHistory: %w", err)
	}
	return n, nil
}

// DeleteOldestRunHistory hard-deletes the oldest run history record for a tool.
//
// DeleteOldestRunHistory 硬删除工具最早的运行历史记录。
func (s *Store) DeleteOldestRunHistory(ctx context.Context, forgeID string) error {
	var h forgedomain.ForgeRunHistory
	err := s.db.WithContext(ctx).
		Where("forge_id = ?", forgeID).
		Order("created_at ASC").
		First(&h).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("forgestore.DeleteOldestRunHistory: find: %w", err)
	}
	if err = s.db.WithContext(ctx).Delete(&h).Error; err != nil {
		return fmt.Errorf("forgestore.DeleteOldestRunHistory: delete: %w", err)
	}
	return nil
}

// ── Test history ──────────────────────────────────────────────────────────────

// SaveTestHistory inserts a ForgeTestHistory record.
//
// SaveTestHistory 插入 ForgeTestHistory 记录。
func (s *Store) SaveTestHistory(ctx context.Context, h *forgedomain.ForgeTestHistory) error {
	if err := s.db.WithContext(ctx).Create(h).Error; err != nil {
		return fmt.Errorf("forgestore.SaveTestHistory: %w", err)
	}
	return nil
}

// ListTestHistory returns the most recent limit records for a tool, DESC.
//
// ListTestHistory 返回工具最近 limit 条测试历史，按 created_at DESC。
func (s *Store) ListTestHistory(ctx context.Context, forgeID string, limit int) ([]*forgedomain.ForgeTestHistory, error) {
	userID, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	var rows []*forgedomain.ForgeTestHistory
	if err = s.db.WithContext(ctx).
		Where("forge_id = ? AND user_id = ?", forgeID, userID).
		Order("created_at DESC").
		Limit(limit).
		Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("forgestore.ListTestHistory: %w", err)
	}
	return rows, nil
}

// ListTestHistoryByBatch returns all records sharing a batchID, ordered ASC.
//
// ListTestHistoryByBatch 返回指定 batchID 的所有记录，按 created_at ASC。
func (s *Store) ListTestHistoryByBatch(ctx context.Context, batchID string) ([]*forgedomain.ForgeTestHistory, error) {
	var rows []*forgedomain.ForgeTestHistory
	if err := s.db.WithContext(ctx).
		Where("batch_id = ?", batchID).
		Order("created_at ASC").
		Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("forgestore.ListTestHistoryByBatch: %w", err)
	}
	return rows, nil
}

// CountTestHistory returns the total test history count for a tool.
//
// CountTestHistory 返回工具测试历史总条数。
func (s *Store) CountTestHistory(ctx context.Context, forgeID string) (int64, error) {
	var n int64
	if err := s.db.WithContext(ctx).Model(&forgedomain.ForgeTestHistory{}).
		Where("forge_id = ?", forgeID).Count(&n).Error; err != nil {
		return 0, fmt.Errorf("forgestore.CountTestHistory: %w", err)
	}
	return n, nil
}

// DeleteOldestTestHistory hard-deletes the oldest test history record for a tool.
//
// DeleteOldestTestHistory 硬删除工具最早的测试历史记录。
func (s *Store) DeleteOldestTestHistory(ctx context.Context, forgeID string) error {
	var h forgedomain.ForgeTestHistory
	err := s.db.WithContext(ctx).
		Where("forge_id = ?", forgeID).
		Order("created_at ASC").
		First(&h).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("forgestore.DeleteOldestTestHistory: find: %w", err)
	}
	if err = s.db.WithContext(ctx).Delete(&h).Error; err != nil {
		return fmt.Errorf("forgestore.DeleteOldestTestHistory: delete: %w", err)
	}
	return nil
}

