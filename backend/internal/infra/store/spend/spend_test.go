package spend

import (
	"context"
	"database/sql"
	"testing"
	"time"

	_ "github.com/glebarez/go-sqlite"

	spenddomain "github.com/sunweilin/anselm/backend/internal/domain/spend"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func newStore(t *testing.T) (*Store, context.Context) {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	return New(ormpkg.Open(sqlDB)), reqctxpkg.SetWorkspaceID(context.Background(), "ws_1111111111111111")
}

func entry(cat, provider, model string, units, est int64, at time.Time) *spenddomain.Entry {
	return &spenddomain.Entry{
		ID: idgenpkg.New("gsp"), Provider: provider, Model: model, Category: cat,
		Units: units, EstPUSD: est, CreatedAt: at,
	}
}

// TestAggregateDaily_GroupsAndWindows: the projection sums units and estimates per day × category ×
// provider × model, and the `since` bound is what keeps an unbounded table a bounded response.
//
// TestAggregateDaily_GroupsAndWindows:投影按 日×品类×provider×model 求和,而 `since` 界正是让
// 一张无界的表给出有界响应的东西。
func TestAggregateDaily_GroupsAndWindows(t *testing.T) {
	s, ctx := newStore(t)
	now := time.Now().UTC()
	old := now.AddDate(0, 0, -40)

	for _, e := range []*spenddomain.Entry{
		entry(spenddomain.CategoryImage, "qwen", "qwen-image-2.0", 1, 35_000_000_000, now),
		entry(spenddomain.CategoryImage, "qwen", "qwen-image-2.0", 2, 70_000_000_000, now),
		entry(spenddomain.CategorySpeech, "qwen", "qwen3-tts-flash", 500, 7_000_000_000, now),
		entry(spenddomain.CategoryImage, "qwen", "qwen-image-2.0", 9, 9, old), // outside the window
	} {
		if err := s.Record(ctx, e); err != nil {
			t.Fatalf("record: %v", err)
		}
	}

	rows, err := s.AggregateDaily(ctx, now.AddDate(0, 0, -30))
	if err != nil {
		t.Fatalf("aggregate: %v", err)
	}
	if len(rows) != 2 {
		t.Fatalf("rows = %+v, want 2 cells (image + speech), the 40-day-old row excluded", rows)
	}
	var img spenddomain.DayRow
	for _, r := range rows {
		if r.Category == spenddomain.CategoryImage {
			img = r
		}
	}
	if img.Units != 3 || img.EstPUSD != 105_000_000_000 {
		t.Fatalf("image cell = %+v, want units 3 / est 105e9 (1+2 images summed)", img)
	}
}

// TestAggregateDaily_IsWorkspaceIsolated: the ledger is per workspace like every other table (D2),
// and the aggregation must not leak across — a spend panel showing another workspace's money would
// be the worst kind of wrong number.
//
// TestAggregateDaily_IsWorkspaceIsolated:台账与其余每张表一样按 workspace 隔离(D2),聚合绝不能
// 跨界——支出面板显示**别的 workspace 的钱**,是最坏的一种错数。
func TestAggregateDaily_IsWorkspaceIsolated(t *testing.T) {
	s, ctx := newStore(t)
	now := time.Now().UTC()
	if err := s.Record(ctx, entry(spenddomain.CategoryImage, "qwen", "m", 1, 1, now)); err != nil {
		t.Fatalf("record: %v", err)
	}
	other := reqctxpkg.SetWorkspaceID(context.Background(), "ws_2222222222222222")
	rows, err := s.AggregateDaily(other, now.AddDate(0, 0, -1))
	if err != nil {
		t.Fatalf("aggregate: %v", err)
	}
	if len(rows) != 0 {
		t.Fatalf("another workspace saw %d rows", len(rows))
	}
}

// TestSchema_RejectsAnUnknownCategory: the CHECK is the closed set's physical enforcement — a typo'd
// category would otherwise sit in the ledger forever, invisible to every aggregation that filters
// on the three known values.
//
// TestSchema_RejectsAnUnknownCategory:CHECK 是封闭集的物理执行——拼错的品类否则会永远躺在台账里,
// 对每一个按三个已知值过滤的聚合都不可见。
func TestSchema_RejectsAnUnknownCategory(t *testing.T) {
	s, ctx := newStore(t)
	if err := s.Record(ctx, entry("hologram", "qwen", "m", 1, 1, time.Now().UTC())); err == nil {
		t.Fatal("an unknown category was accepted")
	}
}
