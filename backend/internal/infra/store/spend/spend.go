// Package spend is the orm-backed implementation of spenddomain.Repository plus the gen_spend
// DDL. A LOG table (D1): no deleted_at, no update path, and deliberately no retention line —
// the rationale lives on the domain package.
//
// Package spend 是 spenddomain.Repository 的 orm 实现 + gen_spend 表 DDL。Log 表(D1):无
// deleted_at、无更新路径、且刻意无保留线——理由在 domain 包上。
package spend

import (
	"context"
	"fmt"
	"time"

	spenddomain "github.com/sunweilin/anselm/backend/internal/domain/spend"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// Schema is the gen_spend DDL. idx_gsp_day backs the daily aggregation walk; there is no other
// read shape, so there is no other index.
//
// Schema 是 gen_spend 表 DDL。idx_gsp_day 支撑按日聚合;没有别的读形态,故没有别的索引。
var Schema = []string{
	`CREATE TABLE IF NOT EXISTS gen_spend (
		id              TEXT PRIMARY KEY,
		workspace_id    TEXT NOT NULL,
		provider        TEXT NOT NULL,
		model           TEXT NOT NULL DEFAULT '',
		category        TEXT NOT NULL CHECK (category IN ('image','speech','video','voice')),
		units           INTEGER NOT NULL,
		est_pusd        INTEGER NOT NULL DEFAULT 0,
		conversation_id TEXT NOT NULL DEFAULT '',
		tool_call_id    TEXT NOT NULL DEFAULT '',
		created_at      DATETIME NOT NULL
	)`,
	`CREATE INDEX IF NOT EXISTS idx_gsp_day ON gen_spend(workspace_id, created_at)`,
}

// Store implements spenddomain.Repository over pkg/orm.
//
// Store 基于 pkg/orm 实现 spenddomain.Repository。
type Store struct {
	repo *ormpkg.Repo[spenddomain.Entry]
	db   *ormpkg.DB
}

// New builds a Store bound to the gen_spend table.
//
// New 构造绑定 gen_spend 表的 Store。
func New(db *ormpkg.DB) *Store {
	return &Store{repo: ormpkg.For[spenddomain.Entry](db, "gen_spend"), db: db}
}

var _ spenddomain.Repository = (*Store)(nil)

// Record appends one entry.
//
// Record 追加一行。
func (s *Store) Record(ctx context.Context, e *spenddomain.Entry) error {
	if err := s.repo.Create(ctx, e); err != nil {
		return fmt.Errorf("spendstore.Record: %w", err)
	}
	return nil
}

// AggregateDaily groups by calendar day (UTC — created_at is stored UTC, and a stable grouping
// beats a locale-correct one that shifts rows between days when the machine's zone changes).
//
// AggregateDaily 按日历日聚合(UTC——created_at 以 UTC 落盘,而一个**稳定**的分组胜过一个机器时区
// 一变、行就在两天之间搬家的「本地正确」分组)。
func (s *Store) AggregateDaily(ctx context.Context, since time.Time) ([]spenddomain.DayRow, error) {
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return nil, fmt.Errorf("spendstore.AggregateDaily: %w", err)
	}
	rows, err := s.db.Query(ctx, `
		SELECT date(created_at) AS day, category, provider, model,
		       SUM(units), SUM(est_pusd)
		FROM gen_spend
		WHERE workspace_id = ? AND created_at >= ?
		GROUP BY day, category, provider, model
		ORDER BY day DESC, category, provider, model`,
		wsID, since.UTC(),
	)
	if err != nil {
		return nil, fmt.Errorf("spendstore.AggregateDaily: %w", err)
	}
	defer rows.Close()
	var out []spenddomain.DayRow
	for rows.Next() {
		var r spenddomain.DayRow
		if err := rows.Scan(&r.Date, &r.Category, &r.Provider, &r.Model, &r.Units, &r.EstPUSD); err != nil {
			return nil, fmt.Errorf("spendstore.AggregateDaily scan: %w", err)
		}
		out = append(out, r)
	}
	return out, rows.Err()
}
