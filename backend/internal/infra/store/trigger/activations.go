package trigger

import (
	"context"
	"errors"
	"fmt"
	"time"

	triggerdomain "github.com/sunweilin/forgify/backend/internal/domain/trigger"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
	ormpkg "github.com/sunweilin/forgify/backend/internal/pkg/orm"
)

// AppendActivation writes one action-log row (fired or not). Append-only (D1, no delete).
//
// AppendActivation 写一条动作日志（触没触发都写）。只增（D1，不删）。
func (s *Store) AppendActivation(ctx context.Context, a *triggerdomain.Activation) error {
	if a.ID == "" {
		a.ID = idgenpkg.New("tra")
	}
	if err := s.acts.Create(ctx, a); err != nil {
		return fmt.Errorf("triggerstore.AppendActivation: %w", err)
	}
	return nil
}

// LastFiredAt returns the created_at of the trigger's most recent fired activation (nil = never
// fired). One indexed First over idx_tra_ws_trigger(workspace_id, trigger_id, created_at DESC).
//
// LastFiredAt 返该 trigger 最近一条已触发 activation 的 created_at（nil = 从未触发）。一次走
// idx_tra_ws_trigger(workspace_id, trigger_id, created_at DESC) 索引的 First。
func (s *Store) LastFiredAt(ctx context.Context, triggerID string) (*time.Time, error) {
	a, err := s.acts.Query().WhereEq("trigger_id", triggerID).WhereEq("fired", true).Order("created_at DESC, id DESC").First(ctx)
	if errors.Is(err, ormpkg.ErrNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("triggerstore.LastFiredAt: %w", err)
	}
	return &a.CreatedAt, nil
}

func (s *Store) GetActivation(ctx context.Context, id string) (*triggerdomain.Activation, error) {
	a, err := s.acts.Get(ctx, id)
	if errors.Is(err, ormpkg.ErrNotFound) {
		return nil, triggerdomain.ErrActivationNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("triggerstore.GetActivation: %w", err)
	}
	return a, nil
}

// SearchActivations pages a trigger's action log newest-first; FiredOnly narrows to hits.
//
// SearchActivations 分页某 trigger 的动作日志（最新优先）；FiredOnly 只看触发的。
func (s *Store) SearchActivations(ctx context.Context, filter triggerdomain.ActivationFilter) ([]*triggerdomain.Activation, string, error) {
	q := s.acts.Query()
	if filter.TriggerID != "" {
		q = q.WhereEq("trigger_id", filter.TriggerID)
	}
	if filter.FiredOnly {
		q = q.WhereEq("fired", true)
	}
	rows, next, err := q.Page(ctx, filter.Cursor, filter.Limit)
	if err != nil {
		return nil, "", fmt.Errorf("triggerstore.SearchActivations: %w", err)
	}
	return rows, next, nil
}
