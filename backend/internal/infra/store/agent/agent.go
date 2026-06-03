// Package agent is the GORM-backed store for the Agent domain (quadrinity 4th entity).
//
// Package agent 是 Agent domain 的 GORM store（quadrinity 第四元）。
package agent

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strings"
	"time"

	"gorm.io/gorm"

	agentdomain "github.com/sunweilin/forgify/backend/internal/domain/agent"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
	paginationpkg "github.com/sunweilin/forgify/backend/internal/pkg/pagination"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

type Store struct {
	db *gorm.DB
}

func New(db *gorm.DB) *Store { return &Store{db: db} }

// AutoMigrateModels returns all agent models for registration in db.AutoMigrate.
func AutoMigrateModels() []interface{} {
	return []interface{}{
		&agentdomain.Agent{},
		&agentdomain.AgentVersion{},
		&agentdomain.AgentExecution{},
	}
}

func (s *Store) Create(ctx context.Context, a *agentdomain.Agent) error {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return err
	}
	if a.ID == "" {
		a.ID = idgenpkg.New("ag")
	}
	a.UserID = uid
	if err := s.db.WithContext(ctx).Create(a).Error; err != nil {
		if isUniqueViolation(err) {
			return agentdomain.ErrNameDuplicate
		}
		return fmt.Errorf("agentstore.Create: %w", err)
	}
	return nil
}

func (s *Store) Get(ctx context.Context, id string) (*agentdomain.Agent, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	var a agentdomain.Agent
	if err := s.db.WithContext(ctx).
		Where("id = ? AND user_id = ?", id, uid).First(&a).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, agentdomain.ErrNotFound
		}
		return nil, fmt.Errorf("agentstore.Get: %w", err)
	}
	return &a, nil
}

func (s *Store) GetByName(ctx context.Context, name string) (*agentdomain.Agent, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, err
	}
	var a agentdomain.Agent
	if err := s.db.WithContext(ctx).
		Where("name = ? AND user_id = ?", name, uid).First(&a).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, agentdomain.ErrNotFound
		}
		return nil, fmt.Errorf("agentstore.GetByName: %w", err)
	}
	return &a, nil
}

func (s *Store) List(ctx context.Context, userID string, limit int, cursor string) ([]*agentdomain.Agent, string, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	q := s.db.WithContext(ctx).Where("user_id = ?", userID).Order("name asc").Limit(limit + 1)
	if cursor != "" {
		q = q.Where("name > ?", cursor)
	}
	var rows []*agentdomain.Agent
	if err := q.Find(&rows).Error; err != nil {
		return nil, "", fmt.Errorf("agentstore.List: %w", err)
	}
	var next string
	if len(rows) > limit {
		next = rows[limit].Name
		rows = rows[:limit]
	}
	return rows, next, nil
}

func (s *Store) Update(ctx context.Context, a *agentdomain.Agent) error {
	if err := s.db.WithContext(ctx).Save(a).Error; err != nil {
		return fmt.Errorf("agentstore.Update: %w", err)
	}
	return nil
}

func (s *Store) SoftDelete(ctx context.Context, id string) error {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return err
	}
	if err := s.db.WithContext(ctx).
		Where("id = ? AND user_id = ?", id, uid).
		Delete(&agentdomain.Agent{}).Error; err != nil {
		return fmt.Errorf("agentstore.SoftDelete: %w", err)
	}
	return nil
}

func (s *Store) CreateVersion(ctx context.Context, v *agentdomain.AgentVersion) error {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return err
	}
	if v.ID == "" {
		v.ID = idgenpkg.New("agv")
	}
	v.UserID = uid
	if v.Status == "" {
		v.Status = agentdomain.VersionStatusPending
	}
	if err := s.db.WithContext(ctx).Create(v).Error; err != nil {
		return fmt.Errorf("agentstore.CreateVersion: %w", err)
	}
	return nil
}

func (s *Store) GetVersion(ctx context.Context, versionID string) (*agentdomain.AgentVersion, error) {
	var v agentdomain.AgentVersion
	if err := s.db.WithContext(ctx).Where("id = ?", versionID).First(&v).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, agentdomain.ErrNotFound
		}
		return nil, fmt.Errorf("agentstore.GetVersion: %w", err)
	}
	return &v, nil
}

func (s *Store) GetPending(ctx context.Context, agentID string) (*agentdomain.AgentVersion, error) {
	var v agentdomain.AgentVersion
	if err := s.db.WithContext(ctx).
		Where("agent_id = ? AND status = ?", agentID, agentdomain.VersionStatusPending).
		Order("created_at desc").First(&v).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, agentdomain.ErrNoPending
		}
		return nil, fmt.Errorf("agentstore.GetPending: %w", err)
	}
	return &v, nil
}

func (s *Store) ListVersions(ctx context.Context, agentID string) ([]*agentdomain.AgentVersion, error) {
	var rows []*agentdomain.AgentVersion
	if err := s.db.WithContext(ctx).
		Where("agent_id = ?", agentID).
		Order("created_at desc").Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("agentstore.ListVersions: %w", err)
	}
	return rows, nil
}

func (s *Store) AcceptVersion(ctx context.Context, agentID, versionID string) error {
	now := time.Now().UTC()
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// Flip version to accepted.
		// Get next version number.
		var maxV int
		tx.Model(&agentdomain.AgentVersion{}).
			Where("agent_id = ? AND status = ?", agentID, agentdomain.VersionStatusAccepted).
			Select("COALESCE(MAX(version), 0)").Scan(&maxV)
		nextV := maxV + 1
		if err := tx.Model(&agentdomain.AgentVersion{}).
			Where("id = ?", versionID).
			Updates(map[string]any{
				"status":      agentdomain.VersionStatusAccepted,
				"accepted_at": now,
				"version":     nextV,
			}).Error; err != nil {
			return fmt.Errorf("agentstore.AcceptVersion: flip version: %w", err)
		}
		// Update agent.active_version_id.
		if err := tx.Model(&agentdomain.Agent{}).
			Where("id = ?", agentID).
			Update("active_version_id", versionID).Error; err != nil {
			return fmt.Errorf("agentstore.AcceptVersion: update agent: %w", err)
		}
		return nil
	})
}

func (s *Store) SetNeedsAttention(ctx context.Context, agentID string, val bool) error {
	if err := s.db.WithContext(ctx).
		Model(&agentdomain.Agent{}).
		Where("id = ?", agentID).
		Update("needs_attention", val).Error; err != nil {
		return fmt.Errorf("agentstore.SetNeedsAttention: %w", err)
	}
	return nil
}

// GetVersionByNumber resolves an accepted version by its 1-based number (revert target lookup).
//
// GetVersionByNumber 按 1-起版本号取已 accepted 版本（revert 目标）。
func (s *Store) GetVersionByNumber(ctx context.Context, agentID string, version int) (*agentdomain.AgentVersion, error) {
	var v agentdomain.AgentVersion
	err := s.db.WithContext(ctx).
		Where("agent_id = ? AND version = ? AND status = ?", agentID, version, agentdomain.VersionStatusAccepted).
		First(&v).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, agentdomain.ErrVersionNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("agentstore.GetVersionByNumber: %w", err)
	}
	return &v, nil
}

// SetActiveVersion flips agent.active_version_id to an existing accepted version (revert; no renumber).
//
// SetActiveVersion 把 active_version_id 切到一个已 accepted 版本（revert，不重排号）。
func (s *Store) SetActiveVersion(ctx context.Context, agentID, versionID string) error {
	if err := s.db.WithContext(ctx).
		Model(&agentdomain.Agent{}).
		Where("id = ?", agentID).
		Update("active_version_id", versionID).Error; err != nil {
		return fmt.Errorf("agentstore.SetActiveVersion: %w", err)
	}
	return nil
}

// SaveExecution inserts one AgentExecution row (mirrors functionstore.SaveExecution).
//
// SaveExecution 插入一行 AgentExecution。
func (s *Store) SaveExecution(ctx context.Context, e *agentdomain.AgentExecution) error {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return fmt.Errorf("agentstore.SaveExecution: %w", err)
	}
	if e.ID == "" {
		e.ID = idgenpkg.New("agx")
	}
	e.UserID = uid
	if err := s.db.WithContext(ctx).Create(e).Error; err != nil {
		return fmt.Errorf("agentstore.SaveExecution: %w", err)
	}
	return nil
}

// GetExecutionByID returns one execution by id; ErrExecutionNotFound if absent (user-scoped).
//
// GetExecutionByID 按 id 取 execution（按 user scope）；未命中返 ErrExecutionNotFound。
func (s *Store) GetExecutionByID(ctx context.Context, id string) (*agentdomain.AgentExecution, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, fmt.Errorf("agentstore.GetExecutionByID: %w", err)
	}
	var row agentdomain.AgentExecution
	err = s.db.WithContext(ctx).Where("id = ? AND user_id = ?", id, uid).First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, agentdomain.ErrExecutionNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("agentstore.GetExecutionByID: %w", err)
	}
	return &row, nil
}

// ListExecutions returns cursor-paginated executions newest-first matching filter (mirrors function).
//
// ListExecutions 返按 filter 过滤的分页（新→旧）。
func (s *Store) ListExecutions(ctx context.Context, filter agentdomain.ExecutionFilter) ([]*agentdomain.AgentExecution, string, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, "", fmt.Errorf("agentstore.ListExecutions: %w", err)
	}
	q := s.applyExecutionFilter(s.db.WithContext(ctx).Model(&agentdomain.AgentExecution{}), uid, filter)

	limit := filter.Limit
	if limit <= 0 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}
	if filter.Cursor != "" {
		var cur paginationpkg.Cursor
		if err := paginationpkg.DecodeCursor(filter.Cursor, &cur); err != nil {
			return nil, "", fmt.Errorf("agentstore.ListExecutions: cursor: %w", err)
		}
		q = q.Where("(started_at, id) < (?, ?)", cur.CreatedAt, cur.ID)
	}

	var rows []*agentdomain.AgentExecution
	if err := q.Order("started_at DESC, id DESC").Limit(limit + 1).Find(&rows).Error; err != nil {
		return nil, "", fmt.Errorf("agentstore.ListExecutions: %w", err)
	}

	var nextCursor string
	if len(rows) > limit {
		last := rows[limit-1]
		cur, encErr := paginationpkg.EncodeCursor(paginationpkg.Cursor{CreatedAt: last.StartedAt, ID: last.ID})
		if encErr != nil {
			return nil, "", fmt.Errorf("agentstore.ListExecutions: encode cursor: %w", encErr)
		}
		nextCursor = cur
		rows = rows[:limit]
	}
	return rows, nextCursor, nil
}

// ComputeAggregates returns rollup counts + p95 (mirrors functionstore.ComputeAggregates).
//
// ComputeAggregates 返 filter 匹配行的聚合 + p95。
func (s *Store) ComputeAggregates(ctx context.Context, filter agentdomain.ExecutionFilter) (agentdomain.ExecutionAggregates, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return agentdomain.ExecutionAggregates{}, fmt.Errorf("agentstore.ComputeAggregates: %w", err)
	}
	type countsRow struct {
		OK        int
		Failed    int
		Cancelled int
		Timeout   int
		AvgMs     float64
	}
	var counts countsRow
	q := s.applyExecutionFilter(s.db.WithContext(ctx).Model(&agentdomain.AgentExecution{}), uid, filter)
	if err := q.Select(
		`SUM(CASE WHEN status = 'ok'        THEN 1 ELSE 0 END) AS ok,
		 SUM(CASE WHEN status = 'failed'    THEN 1 ELSE 0 END) AS failed,
		 SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled,
		 SUM(CASE WHEN status = 'timeout'   THEN 1 ELSE 0 END) AS timeout,
		 COALESCE(AVG(elapsed_ms), 0)                          AS avg_ms`,
	).Scan(&counts).Error; err != nil {
		return agentdomain.ExecutionAggregates{}, fmt.Errorf("agentstore.ComputeAggregates: %w", err)
	}

	var elapsedMsList []int64
	q2 := s.applyExecutionFilter(s.db.WithContext(ctx).Model(&agentdomain.AgentExecution{}), uid, filter)
	if err := q2.Order("elapsed_ms ASC").Limit(1000).Pluck("elapsed_ms", &elapsedMsList).Error; err != nil {
		return agentdomain.ExecutionAggregates{}, fmt.Errorf("agentstore.ComputeAggregates: p95: %w", err)
	}

	agg := agentdomain.ExecutionAggregates{
		OKCount:        counts.OK,
		FailedCount:    counts.Failed,
		CancelledCount: counts.Cancelled,
		TimeoutCount:   counts.Timeout,
		AvgElapsedMs:   int64(counts.AvgMs),
	}
	if len(elapsedMsList) > 0 {
		sort.Slice(elapsedMsList, func(i, j int) bool { return elapsedMsList[i] < elapsedMsList[j] })
		idx := (len(elapsedMsList) * 95) / 100
		if idx >= len(elapsedMsList) {
			idx = len(elapsedMsList) - 1
		}
		agg.P95ElapsedMs = elapsedMsList[idx]
	}
	return agg, nil
}

func (s *Store) applyExecutionFilter(q *gorm.DB, uid string, filter agentdomain.ExecutionFilter) *gorm.DB {
	q = q.Where("user_id = ?", uid)
	if filter.AgentID != "" {
		q = q.Where("agent_id = ?", filter.AgentID)
	}
	if filter.VersionID != "" {
		q = q.Where("version_id = ?", filter.VersionID)
	}
	if filter.Status != "" {
		q = q.Where("status = ?", filter.Status)
	}
	if filter.ConversationID != "" {
		q = q.Where("conversation_id = ?", filter.ConversationID)
	}
	if filter.FlowrunID != "" {
		q = q.Where("flowrun_id = ?", filter.FlowrunID)
	}
	if filter.Since != nil {
		q = q.Where("started_at >= ?", *filter.Since)
	}
	if filter.Until != nil {
		q = q.Where("started_at <= ?", *filter.Until)
	}
	return q
}

func isUniqueViolation(err error) bool {
	return err != nil && strings.Contains(err.Error(), "UNIQUE constraint failed")
}
