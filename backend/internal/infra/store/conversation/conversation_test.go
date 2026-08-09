package conversation

import (
	"context"
	"database/sql"
	"errors"
	"testing"
	"time"

	_ "github.com/glebarez/go-sqlite"

	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	documentdomain "github.com/sunweilin/anselm/backend/internal/domain/document"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	paginationpkg "github.com/sunweilin/anselm/backend/internal/pkg/pagination"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func newStore(t *testing.T) *Store {
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
	return New(ormpkg.Open(sqlDB))
}

func ctxWS(id string) context.Context {
	return reqctxpkg.SetWorkspaceID(context.Background(), id)
}

// seed inserts a conversation then pins created_at to `at` (same driver as Create, so the
// stored value round-trips) — making List ordering deterministic regardless of clock resolution.
//
// seed 插入对话后把 created_at 钉到 `at`（同 Create 的驱动、存储值可往返）——使 List 排序与时钟
// 精度无关、可确定断言。
func seed(t *testing.T, s *Store, ctx context.Context, id, title string, pinned, archived bool, at time.Time) {
	t.Helper()
	c := &conversationdomain.Conversation{ID: id, Title: title, Pinned: pinned, Archived: archived}
	if err := s.Insert(ctx, c); err != nil {
		t.Fatalf("insert %s: %v", id, err)
	}
	// Set both created_at and last_message_at to `at`: last_message_at is the List sort/cursor key,
	// created_at backs other assertions. (Seeding bypasses the app layer, so set them explicitly.)
	// created_at 与 last_message_at 都设为 at：last_message_at 是 List 排序/游标键，created_at 撑其他断言。
	if _, err := s.db.Exec(ctx, "UPDATE conversations SET created_at = ?, last_message_at = ? WHERE id = ?", at.UTC(), at.UTC(), id); err != nil {
		t.Fatalf("seed time %s: %v", id, err)
	}
}

func ids(rows []*conversationdomain.Conversation) []string {
	out := make([]string, len(rows))
	for i, c := range rows {
		out[i] = c.ID
	}
	return out
}

func equal(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

var (
	t1 = time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	t2 = time.Date(2026, 2, 1, 0, 0, 0, 0, time.UTC)
	t3 = time.Date(2026, 3, 1, 0, 0, 0, 0, time.UTC)
)

func TestInsertGet_RoundTrip(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	if err := s.Insert(ctx, &conversationdomain.Conversation{ID: "cv_1", Title: "Hello"}); err != nil {
		t.Fatalf("insert: %v", err)
	}
	got, err := s.Get(ctx, "cv_1")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if got.Title != "Hello" || got.WorkspaceID != "ws_1" {
		t.Errorf("round-trip: %+v", got)
	}
	if got.CreatedAt.IsZero() || got.UpdatedAt.IsZero() {
		t.Error("timestamps not auto-stamped")
	}
}

func TestGet_NotFound(t *testing.T) {
	s := newStore(t)
	if _, err := s.Get(ctxWS("ws_1"), "cv_x"); !errors.Is(err, conversationdomain.ErrNotFound) {
		t.Errorf("err = %v, want ErrNotFound", err)
	}
}

func TestModelOverride_AndAttachedJSONRoundTrip(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	ref := &modeldomain.ModelRef{APIKeyID: "aki_1", ModelID: "claude-sonnet-4", Options: map[string]string{"reasoning_effort": "high"}}
	in := &conversationdomain.Conversation{
		ID:                "cv_1",
		ModelOverride:     ref,
		AttachedDocuments: []documentdomain.AttachedDocument{{DocumentID: "doc_1"}},
	}
	if err := s.Insert(ctx, in); err != nil {
		t.Fatalf("insert: %v", err)
	}
	got, err := s.Get(ctx, "cv_1")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if got.ModelOverride == nil || got.ModelOverride.APIKeyID != "aki_1" ||
		got.ModelOverride.ModelID != "claude-sonnet-4" || got.ModelOverride.Options["reasoning_effort"] != "high" {
		t.Errorf("override round-trip: %+v", got.ModelOverride)
	}
	if len(got.AttachedDocuments) != 1 || got.AttachedDocuments[0].DocumentID != "doc_1" {
		t.Errorf("attached round-trip: %+v", got.AttachedDocuments)
	}
}

func TestList_PinnedFirstThenNewest(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	seed(t, s, ctx, "cv_old_pin", "old pinned", true, false, t1)
	seed(t, s, ctx, "cv_mid", "mid", false, false, t2)
	seed(t, s, ctx, "cv_new", "new", false, false, t3)
	rows, next, err := s.List(ctx, conversationdomain.ListFilter{})
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if next != "" {
		t.Errorf("unexpected next cursor: %q", next)
	}
	// pinned first (despite oldest created_at), then unpinned newest→oldest.
	if got := ids(rows); !equal(got, []string{"cv_old_pin", "cv_new", "cv_mid"}) {
		t.Errorf("order = %v, want [cv_old_pin cv_new cv_mid]", got)
	}
}

// TestList_ArchivedFilter covers all three ArchiveScope values: default/ArchiveActive (active only),
// ArchiveArchived (archived only), and ArchiveAll (both — the rail's "show archived" mode). cv_active
// is newer than cv_arch so ArchiveAll's recency order is deterministic.
//
// TestList_ArchivedFilter 覆盖三个 ArchiveScope：默认/ArchiveActive（仅活跃）、ArchiveArchived（仅归档）、
// ArchiveAll（两者——rail「显示已归档」）。cv_active 比 cv_arch 新，故 ArchiveAll 的活跃序确定。
func TestList_ArchivedFilter(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	seed(t, s, ctx, "cv_active", "a", false, false, t2)
	seed(t, s, ctx, "cv_arch", "b", false, true, t1)

	rows, _, _ := s.List(ctx, conversationdomain.ListFilter{}) // zero value → ArchiveActive (active only)
	if got := ids(rows); !equal(got, []string{"cv_active"}) {
		t.Errorf("default(active) = %v, want [cv_active]", got)
	}
	rows, _, _ = s.List(ctx, conversationdomain.ListFilter{Archive: conversationdomain.ArchiveArchived})
	if got := ids(rows); !equal(got, []string{"cv_arch"}) {
		t.Errorf("archived-only = %v, want [cv_arch]", got)
	}
	rows, _, _ = s.List(ctx, conversationdomain.ListFilter{Archive: conversationdomain.ArchiveActive})
	if got := ids(rows); !equal(got, []string{"cv_active"}) {
		t.Errorf("active-only = %v, want [cv_active]", got)
	}
	// ArchiveAll returns BOTH, recency-ordered (cv_active newer than cv_arch).
	rows, _, _ = s.List(ctx, conversationdomain.ListFilter{Archive: conversationdomain.ArchiveAll})
	if got := ids(rows); !equal(got, []string{"cv_active", "cv_arch"}) {
		t.Errorf("all = %v, want [cv_active cv_arch] (both, recency order)", got)
	}
}

// TestCount_MirrorsListAxes proves the rail's total header uses the same archive, pin, residency, search,
// and workspace filters as the paged rows. A count that ignores the pinned partition or soft-delete scope
// makes the section head contradict the rows it owns.
//
// TestCount_MirrorsListAxes 证明 rail 总数头与分页行使用同一归档、置顶、驻地、搜索和 workspace 过滤。忽略置顶分区或
// 软删范围的计数会让段头与它实际拥有的行互相矛盾。
func TestCount_MirrorsListAxes(t *testing.T) {
	s := newStore(t)
	ws1 := ctxWS("ws_1")
	seed(t, s, ws1, "cv_pin", "Alpha pin", true, false, t1)
	seed(t, s, ws1, "cv_unpin", "Alpha unpin", false, false, t2)
	seed(t, s, ws1, "cv_arch_pin", "Archived pin", true, true, t3)
	seed(t, s, ws1, "cv_arch", "Beta archive", false, true, t1)
	seed(t, s, ws1, "cv_dir", "Directory match", false, false, t2)
	dirRow, err := s.Get(ws1, "cv_dir")
	if err != nil {
		t.Fatalf("get workdir row: %v", err)
	}
	dirRow.WorkDir = "/tmp/anselm-count"
	if err := s.Update(ws1, dirRow); err != nil {
		t.Fatalf("update workdir: %v", err)
	}
	if err := s.Insert(ctxWS("ws_2"), &conversationdomain.Conversation{ID: "cv_other", Title: "Other workspace"}); err != nil {
		t.Fatalf("insert other workspace: %v", err)
	}

	tests := []struct {
		name   string
		filter conversationdomain.ListFilter
		want   int
	}{
		{name: "active any", filter: conversationdomain.ListFilter{}, want: 3},
		{name: "active pinned", filter: conversationdomain.ListFilter{Pinned: conversationdomain.PinPinned}, want: 1},
		{name: "active unpinned", filter: conversationdomain.ListFilter{Pinned: conversationdomain.PinUnpinned}, want: 2},
		{name: "archived any", filter: conversationdomain.ListFilter{Archive: conversationdomain.ArchiveArchived}, want: 2},
		{name: "all", filter: conversationdomain.ListFilter{Archive: conversationdomain.ArchiveAll}, want: 5},
		{name: "workdir", filter: conversationdomain.ListFilter{WorkDir: stringPtr("/tmp/anselm-count")}, want: 1},
		{name: "search", filter: conversationdomain.ListFilter{Search: "alpha"}, want: 2},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got, err := s.Count(ws1, tt.filter); err != nil || got != tt.want {
				t.Fatalf("Count(%+v) = %d, %v; want %d", tt.filter, got, err, tt.want)
			}
		})
	}
}

func stringPtr(v string) *string { return &v }

func TestList_SearchTitle(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	seed(t, s, ctx, "cv_1", "Quarterly report", false, false, t1)
	seed(t, s, ctx, "cv_2", "Random chat", false, false, t2)
	rows, _, err := s.List(ctx, conversationdomain.ListFilter{Search: "report"})
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if got := ids(rows); !equal(got, []string{"cv_1"}) {
		t.Errorf("search = %v, want [cv_1]", got)
	}
}

func TestList_CursorPaging(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	seed(t, s, ctx, "cv_a", "a", false, false, t1)
	seed(t, s, ctx, "cv_b", "b", false, false, t2)
	seed(t, s, ctx, "cv_c", "c", false, false, t3)
	p1, next, err := s.List(ctx, conversationdomain.ListFilter{Limit: 2})
	if err != nil {
		t.Fatalf("page1: %v", err)
	}
	if got := ids(p1); !equal(got, []string{"cv_c", "cv_b"}) {
		t.Errorf("page1 = %v, want [cv_c cv_b]", got)
	}
	if next == "" {
		t.Fatal("expected next cursor")
	}
	p2, next2, err := s.List(ctx, conversationdomain.ListFilter{Limit: 2, Cursor: next})
	if err != nil {
		t.Fatalf("page2: %v", err)
	}
	if got := ids(p2); !equal(got, []string{"cv_a"}) {
		t.Errorf("page2 = %v, want [cv_a]", got)
	}
	if next2 != "" {
		t.Errorf("unexpected next2: %q", next2)
	}
}

// TestList_CursorRejectsChangedQueryAxes proves a cursor is bound to the complete list query, not
// only its row key. Reusing one after changing sort/archive/search/pin/workDir would otherwise return
// a 200 page that silently starts in the wrong result set.
//
// TestList_CursorRejectsChangedQueryAxes 证明 cursor 绑定完整列表查询而不只是行键。切换排序/归档/搜索/置顶/驻地后
// 若仍复用它，旧实现会返回 200 却从错误结果集开始，形成静默漏行。
func TestList_CursorRejectsChangedQueryAxes(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	seed(t, s, ctx, "cv_alpha", "alpha", false, false, t1)
	seed(t, s, ctx, "cv_beta", "beta", false, false, t2)
	seed(t, s, ctx, "cv_archived", "archived", false, true, t3)
	workDir := "/tmp/ep143-cursor-workdir"
	if _, err := s.db.Exec(ctx, "UPDATE conversations SET work_dir = ? WHERE id = ?", workDir, "cv_beta"); err != nil {
		t.Fatalf("set work dir: %v", err)
	}
	_, cursor, err := s.List(ctx, conversationdomain.ListFilter{Limit: 1})
	if err != nil || cursor == "" {
		t.Fatalf("seed cursor: err=%v cursor=%q", err, cursor)
	}

	workDirEmpty := ""
	for _, tt := range []struct {
		name   string
		filter conversationdomain.ListFilter
	}{
		{name: "sort", filter: conversationdomain.ListFilter{Sort: conversationdomain.ListSortCreated}},
		{name: "archive", filter: conversationdomain.ListFilter{Archive: conversationdomain.ArchiveAll}},
		{name: "search", filter: conversationdomain.ListFilter{Search: "alpha"}},
		{name: "pin", filter: conversationdomain.ListFilter{Pinned: conversationdomain.PinPinned}},
		{name: "workdir", filter: conversationdomain.ListFilter{WorkDir: &workDirEmpty}},
	} {
		t.Run(tt.name, func(t *testing.T) {
			tt.filter.Cursor = cursor
			tt.filter.Limit = 1
			_, _, err := s.List(ctx, tt.filter)
			if !errors.Is(err, paginationpkg.ErrMalformedCursor) {
				t.Fatalf("changed %s query error = %v, want ErrMalformedCursor", tt.name, err)
			}
		})
	}
}

// TestList_PinnedPartitionCursorDoesNotDropPins proves that pinned-first remains a complete
// keyset walk even when the pinned partition itself spans a page. A cursor that only carries the
// secondary time/id key lets an unpinned row with a newer timestamp disappear after the last pinned
// row; the cursor must carry which partition it is still walking.
//
// TestList_PinnedPartitionCursorDoesNotDropPins 证明置顶优先在**置顶分区自身跨页**时仍是完整 keyset
// 遍历。若游标只带次键时间/id，最后一条置顶之后带更晚时间的未置顶行会凭空消失；故游标必须带正在走的分区。
func TestList_PinnedPartitionCursorDoesNotDropPins(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	seed(t, s, ctx, "cv_pin_1", "pin 1", true, false, t1)
	seed(t, s, ctx, "cv_pin_2", "pin 2", true, false, t2)
	seed(t, s, ctx, "cv_pin_3", "pin 3", true, false, t3)
	// This row is newer than the oldest pinned row but must still come after all pins.
	seed(t, s, ctx, "cv_unpin", "unpin", false, false, t3)

	var got []string
	cursor := ""
	for {
		rows, next, err := s.List(ctx, conversationdomain.ListFilter{Limit: 2, Cursor: cursor})
		if err != nil {
			t.Fatalf("page cursor=%q: %v", cursor, err)
		}
		got = append(got, ids(rows)...)
		if next == "" {
			break
		}
		cursor = next
	}

	want := []string{"cv_pin_3", "cv_pin_2", "cv_pin_1", "cv_unpin"}
	if !equal(got, want) {
		t.Fatalf("full pinned-first walk = %v, want %v", got, want)
	}
}

// TestList_RecencySortByLastMessage decorrelates id-order from activity-order to prove the list
// keys on last_message_at, not id or created_at: ids descend (cv_z > cv_m > cv_a) OPPOSITE to
// recency (cv_a most recent). A regression that sorted by id/created_at would flip the result and
// the keyset cursor would skip/duplicate. Also exercises the cursor across the boundary.
//
// TestList_RecencySortByLastMessage 把 id 序与活跃序解耦，证明列表按 last_message_at 而非 id/created_at：
// id 降序(cv_z>cv_m>cv_a)与活跃度(cv_a 最近)相反。若回归成按 id/created_at 排，结果会翻转、游标会漏/重。
func TestList_RecencySortByLastMessage(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	// id order (z>m>a) is the REVERSE of recency (cv_a newest t3, cv_m t2, cv_z oldest t1).
	seed(t, s, ctx, "cv_z", "z", false, false, t1)
	seed(t, s, ctx, "cv_m", "m", false, false, t2)
	seed(t, s, ctx, "cv_a", "a", false, false, t3)
	rows, _, err := s.List(ctx, conversationdomain.ListFilter{})
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if got := ids(rows); !equal(got, []string{"cv_a", "cv_m", "cv_z"}) {
		t.Fatalf("recency order = %v, want [cv_a cv_m cv_z] (most-recent last_message_at first)", got)
	}
	// Keyset cursor must walk last_message_at, not id: page 1 = [cv_a], page 2 = [cv_m].
	p1, next, err := s.List(ctx, conversationdomain.ListFilter{Limit: 1})
	if err != nil || len(p1) != 1 || p1[0].ID != "cv_a" || next == "" {
		t.Fatalf("page1 = %v next=%q err=%v, want [cv_a] with cursor", ids(p1), next, err)
	}
	p2, _, err := s.List(ctx, conversationdomain.ListFilter{Limit: 1, Cursor: next})
	if err != nil || len(p2) != 1 || p2[0].ID != "cv_m" {
		t.Fatalf("page2 = %v err=%v, want [cv_m] (cursor walks last_message_at, not id)", ids(p2), err)
	}
}

// seedTimes inserts a conversation with INDEPENDENT created_at and last_message_at, so a test can
// decorrelate the two sort orders.
//
// seedTimes 插入 created_at 与 last_message_at 各自独立的对话，使测试能解耦两种排序序。
func seedTimes(t *testing.T, s *Store, ctx context.Context, id string, created, lastMsg time.Time) {
	t.Helper()
	if err := s.Insert(ctx, &conversationdomain.Conversation{ID: id, Title: id}); err != nil {
		t.Fatalf("insert %s: %v", id, err)
	}
	if _, err := s.db.Exec(ctx, "UPDATE conversations SET created_at = ?, last_message_at = ? WHERE id = ?", created.UTC(), lastMsg.UTC(), id); err != nil {
		t.Fatalf("seed times %s: %v", id, err)
	}
}

// TestList_SortParam proves the sort selector flips both the order AND the keyset cursor column.
// Data decorrelates the two keys: cv_early_active is created oldest but most recently active, so the
// two sorts yield OPPOSITE orders — and the created-sort cursor must walk created_at, not
// last_message_at.
//
// TestList_SortParam 证明 sort 选择器同时翻转排序序与 keyset 游标列。数据解耦两键：cv_early_active
// 创建最早却最近活跃，故两种排序结果相反——且 created 排序的游标须走 created_at 而非 last_message_at。
func TestList_SortParam(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	seedTimes(t, s, ctx, "cv_early_active", t1, t3) // created oldest, active newest
	seedTimes(t, s, ctx, "cv_late_idle", t3, t1)    // created newest, active oldest

	if rows, _, err := s.List(ctx, conversationdomain.ListFilter{}); err != nil {
		t.Fatalf("activity list: %v", err)
	} else if got := ids(rows); !equal(got, []string{"cv_early_active", "cv_late_idle"}) {
		t.Errorf("default(activity) = %v, want [cv_early_active cv_late_idle]", got)
	}
	if rows, _, err := s.List(ctx, conversationdomain.ListFilter{Sort: conversationdomain.ListSortCreated}); err != nil {
		t.Fatalf("created list: %v", err)
	} else if got := ids(rows); !equal(got, []string{"cv_late_idle", "cv_early_active"}) {
		t.Errorf("sort=created = %v, want [cv_late_idle cv_early_active] (opposite of activity)", got)
	}
	// Cursor under created sort walks created_at: page1 = cv_late_idle, page2 = cv_early_active.
	p1, next, err := s.List(ctx, conversationdomain.ListFilter{Sort: conversationdomain.ListSortCreated, Limit: 1})
	if err != nil || len(p1) != 1 || p1[0].ID != "cv_late_idle" || next == "" {
		t.Fatalf("created page1 = %v next=%q err=%v, want [cv_late_idle] with cursor", ids(p1), next, err)
	}
	p2, _, err := s.List(ctx, conversationdomain.ListFilter{Sort: conversationdomain.ListSortCreated, Limit: 1, Cursor: next})
	if err != nil || len(p2) != 1 || p2[0].ID != "cv_early_active" {
		t.Fatalf("created page2 = %v err=%v, want [cv_early_active] (cursor walks created_at)", ids(p2), err)
	}
}

// TestList_SortByName_Order proves sort=name is pinned-first, then title A–Z case-INSENSITIVELY,
// with id ASC as the same-title tiebreaker. The data is a binary-vs-NOCASE discriminator: under
// SQLite's default binary collation uppercase "Banana" (B=66) sorts BEFORE lowercase "apple"
// (a=97); under the required COLLATE NOCASE it sorts between apple and cherry. A regression that
// dropped NOCASE would surface Banana first. cv_zpin (title "zzz", last alphabetically) is pinned to
// prove the pinned partition wins over alpha order.
//
// TestList_SortByName_Order 证明 sort=name 置顶优先、再 title A–Z **大小写不敏感**、id 升序为同名 tiebreaker。
// 数据是 binary-vs-NOCASE 判别器：SQLite 默认 binary collation 下大写 "Banana"(B=66) 排在小写 "apple"(a=97) 前，
// 而所需 COLLATE NOCASE 下它落在 apple 与 cherry 之间。若回归丢了 NOCASE，Banana 会冒到最前。cv_zpin（title "zzz"、
// 字母序最末）置顶以证置顶分区压过字母序。
func TestList_SortByName_Order(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	seed(t, s, ctx, "cv_zpin", "zzz", true, false, t1) // pinned, alpha-last → must still lead
	seed(t, s, ctx, "cv_cherry", "cherry", false, false, t1)
	seed(t, s, ctx, "cv_banana", "Banana", false, false, t2) // capital B: NOCASE places between apple/cherry
	seed(t, s, ctx, "cv_apple", "apple", false, false, t3)
	seed(t, s, ctx, "cv_d1", "delta", false, false, t1) // same title as cv_d2 → id ASC tiebreaker
	seed(t, s, ctx, "cv_d2", "delta", false, false, t2)

	rows, next, err := s.List(ctx, conversationdomain.ListFilter{Sort: conversationdomain.ListSortName})
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if next != "" {
		t.Errorf("unexpected next cursor: %q", next)
	}
	want := []string{"cv_zpin", "cv_apple", "cv_banana", "cv_cherry", "cv_d1", "cv_d2"}
	if got := ids(rows); !equal(got, want) {
		t.Errorf("sort=name order = %v, want %v", got, want)
	}
}

// TestList_SortByName_CursorPaging proves the title keyset cursor walks the same NOCASE-collated
// title order with no skip/duplicate, and crucially that the same-title id tiebreaker survives a page
// boundary: limit=4 splits the two "delta" rows (cv_d1 ends page 1, cv_d2 must be the sole page-2
// row — not skipped, not re-served). No pins here keeps this test focused on the title/id keyset;
// the partition-aware pinned-first boundary is covered by TestList_PinnedPartitionCursorAllSorts.
//
// TestList_SortByName_CursorPaging 证明 title keyset 游标按同一 NOCASE 序行进、不漏/不重，关键是同名 id
// tiebreaker 跨页存活：limit=4 把两条 "delta" 切开（cv_d1 收尾首页，cv_d2 须为第二页唯一行——不漏、不重发）。
// 此处无置顶，专注 title/id keyset；置顶分区边界由 TestList_PinnedPartitionCursorAllSorts 覆盖。
func TestList_SortByName_CursorPaging(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	seed(t, s, ctx, "cv_cherry", "cherry", false, false, t1)
	seed(t, s, ctx, "cv_banana", "Banana", false, false, t2)
	seed(t, s, ctx, "cv_apple", "apple", false, false, t3)
	seed(t, s, ctx, "cv_d1", "delta", false, false, t1)
	seed(t, s, ctx, "cv_d2", "delta", false, false, t2)

	p1, next, err := s.List(ctx, conversationdomain.ListFilter{Sort: conversationdomain.ListSortName, Limit: 4})
	if err != nil {
		t.Fatalf("page1: %v", err)
	}
	if got := ids(p1); !equal(got, []string{"cv_apple", "cv_banana", "cv_cherry", "cv_d1"}) {
		t.Fatalf("page1 = %v, want [cv_apple cv_banana cv_cherry cv_d1] (NOCASE: Banana between apple/cherry)", got)
	}
	if next == "" {
		t.Fatal("expected next cursor")
	}
	p2, next2, err := s.List(ctx, conversationdomain.ListFilter{Sort: conversationdomain.ListSortName, Limit: 4, Cursor: next})
	if err != nil {
		t.Fatalf("page2: %v", err)
	}
	if got := ids(p2); !equal(got, []string{"cv_d2"}) {
		t.Fatalf("page2 = %v, want [cv_d2] (same-title id tiebreaker walks the page boundary)", got)
	}
	if next2 != "" {
		t.Errorf("unexpected next2: %q", next2)
	}
}

// TestList_PinnedPartitionCursorAllSorts proves that a pinned partition crossing a page boundary
// remains complete for every public sort. The unpinned row deliberately has a newer activity/created
// key than the oldest pinned row; it must still appear after every pinned row, not disappear behind a
// cursor that only knows the secondary key.
//
// TestList_PinnedPartitionCursorAllSorts 证明置顶分区跨页时，所有公开排序都能完整遍历。未置顶行刻意拥有比最老
// 置顶行更新的 activity/created 键，但仍必须排在所有置顶行之后，不能被只知道次键的旧游标吞掉。
func TestList_PinnedPartitionCursorAllSorts(t *testing.T) {
	tests := []struct {
		name string
		sort conversationdomain.ListSort
		want []string
	}{
		{name: "activity", sort: conversationdomain.ListSortActivity, want: []string{"cv_pin_3", "cv_pin_2", "cv_pin_1", "cv_unpin"}},
		{name: "created", sort: conversationdomain.ListSortCreated, want: []string{"cv_pin_3", "cv_pin_2", "cv_pin_1", "cv_unpin"}},
		{name: "name", sort: conversationdomain.ListSortName, want: []string{"cv_pin_1", "cv_pin_2", "cv_pin_3", "cv_unpin"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			s := newStore(t)
			ctx := ctxWS("ws_1")
			seedTimes(t, s, ctx, "cv_pin_1", t1, t1)
			seedTimes(t, s, ctx, "cv_pin_2", t2, t2)
			seedTimes(t, s, ctx, "cv_pin_3", t3, t3)
			seedTimes(t, s, ctx, "cv_unpin", t3, t3)
			for _, id := range []string{"cv_pin_1", "cv_pin_2", "cv_pin_3"} {
				if _, err := s.db.Exec(ctx, "UPDATE conversations SET pinned = 1 WHERE id = ?", id); err != nil {
					t.Fatalf("pin %s: %v", id, err)
				}
			}
			if _, err := s.db.Exec(ctx, "UPDATE conversations SET title = CASE id WHEN 'cv_pin_1' THEN 'alpha' WHEN 'cv_pin_2' THEN 'bravo' WHEN 'cv_pin_3' THEN 'charlie' ELSE 'zulu' END"); err != nil {
				t.Fatalf("titles: %v", err)
			}

			var got []string
			cursor := ""
			for {
				rows, next, err := s.List(ctx, conversationdomain.ListFilter{Sort: tt.sort, Limit: 2, Cursor: cursor})
				if err != nil {
					t.Fatalf("page cursor=%q: %v", cursor, err)
				}
				got = append(got, ids(rows)...)
				if next == "" {
					break
				}
				cursor = next
			}
			if !equal(got, tt.want) {
				t.Fatalf("full %s walk = %v, want %v", tt.name, got, tt.want)
			}
		})
	}
}

// TestList_PinScopesPageIndependently proves the exact pinned/unpinned filters retain their own
// complete keyset walks. These are the two queries the grouped rail uses, so neither may inherit the
// old assumption that the opposite partition fits on page one.
//
// TestList_PinScopesPageIndependently 证明 pinned/unpinned 精确过滤各自完整分页。分组 rail 正是用这两条查询，不能
// 再继承「另一分区能放进首页」的旧假设。
func TestList_PinScopesPageIndependently(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	seed(t, s, ctx, "cv_pin_1", "pin 1", true, false, t1)
	seed(t, s, ctx, "cv_pin_2", "pin 2", true, false, t2)
	seed(t, s, ctx, "cv_pin_3", "pin 3", true, false, t3)
	seed(t, s, ctx, "cv_unpin_1", "unpin 1", false, false, t1)
	seed(t, s, ctx, "cv_unpin_2", "unpin 2", false, false, t2)
	seed(t, s, ctx, "cv_unpin_3", "unpin 3", false, false, t3)

	for _, tt := range []struct {
		name  string
		scope conversationdomain.PinScope
		want  []string
	}{
		{name: "pinned", scope: conversationdomain.PinPinned, want: []string{"cv_pin_3", "cv_pin_2", "cv_pin_1"}},
		{name: "unpinned", scope: conversationdomain.PinUnpinned, want: []string{"cv_unpin_3", "cv_unpin_2", "cv_unpin_1"}},
	} {
		t.Run(tt.name, func(t *testing.T) {
			var got []string
			cursor := ""
			for {
				rows, next, err := s.List(ctx, conversationdomain.ListFilter{Pinned: tt.scope, Limit: 2, Cursor: cursor})
				if err != nil {
					t.Fatalf("page cursor=%q: %v", cursor, err)
				}
				got = append(got, ids(rows)...)
				if next == "" {
					break
				}
				cursor = next
			}
			if !equal(got, tt.want) {
				t.Fatalf("full %s walk = %v, want %v", tt.name, got, tt.want)
			}
		})
	}
}

// TestUnread_TouchFlagsAndMarkSeenClears proves the unread watermark column: a fresh thread is seen,
// a completed-finalize touch (unread=true) flags it, a user-send touch (unread=false) keeps it seen,
// and MarkSeen clears it WITHOUT moving last_message_at (opening a thread must never reorder the list).
// The persisted column means hasUnread survives a restart (Get re-reads it straight from the row).
//
// TestUnread_TouchFlagsAndMarkSeenClears 证明未读 watermark 列：新线程已读、完成终态 touch（unread=true）标记之、
// 用户发送 touch（unread=false）保持已读，且 MarkSeen 清未读时**不动 last_message_at**（打开线程绝不重排）。持久列
// 意味着 hasUnread 重启照样在（Get 直接从行读回）。
func TestUnread_TouchFlagsAndMarkSeenClears(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	seed(t, s, ctx, "cv_1", "thread", false, false, t1)

	// Fresh thread (Insert column default) is NOT unread.
	if c, _ := s.Get(ctx, "cv_1"); c.Unread {
		t.Fatal("a brand-new conversation must not be unread")
	}
	// A completed assistant finalize (unread=true) flags it.
	if err := s.TouchLastMessage(ctx, "cv_1", t2, true); err != nil {
		t.Fatalf("touch(unread=true): %v", err)
	}
	afterTouch, _ := s.Get(ctx, "cv_1")
	if !afterTouch.Unread {
		t.Fatal("a completed-finalize touch (unread=true) must flag the thread unread")
	}
	// MarkSeen clears unread and leaves last_message_at exactly where the touch left it (no reorder).
	if err := s.MarkSeen(ctx, "cv_1"); err != nil {
		t.Fatalf("markseen: %v", err)
	}
	afterSeen, _ := s.Get(ctx, "cv_1")
	if afterSeen.Unread {
		t.Fatal("MarkSeen must clear unread")
	}
	if !afterSeen.LastMessageAt.Equal(afterTouch.LastMessageAt) {
		t.Errorf("MarkSeen must NOT change last_message_at (no reorder): %v != %v", afterSeen.LastMessageAt, afterTouch.LastMessageAt)
	}
	// A user-send touch (unread=false) keeps it seen even as it bumps recency.
	if err := s.TouchLastMessage(ctx, "cv_1", t3, false); err != nil {
		t.Fatalf("touch(unread=false): %v", err)
	}
	if c, _ := s.Get(ctx, "cv_1"); c.Unread {
		t.Fatal("a user-send touch (unread=false) must keep the thread seen")
	}
}

// TestMarkSeen_UnknownIdIdempotent: MarkSeen on an unknown/soft-deleted id is a nil no-op (matches the
// :seen action's idempotent 204 — the client only :seens a thread it is viewing).
//
// TestMarkSeen_UnknownIdIdempotent：MarkSeen 对未知/已删 id 是 nil no-op（对应 :seen 动作的幂等 204）。
func TestMarkSeen_UnknownIdIdempotent(t *testing.T) {
	s := newStore(t)
	if err := s.MarkSeen(ctxWS("ws_1"), "cv_missing"); err != nil {
		t.Errorf("MarkSeen on unknown id must be a nil no-op, got %v", err)
	}
}

func TestSoftDelete_NotFoundAndExcluded(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	seed(t, s, ctx, "cv_1", "x", false, false, t1)
	if err := s.SoftDelete(ctx, "cv_1"); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if _, err := s.Get(ctx, "cv_1"); !errors.Is(err, conversationdomain.ErrNotFound) {
		t.Errorf("get after delete = %v, want ErrNotFound", err)
	}
	if rows, _, _ := s.List(ctx, conversationdomain.ListFilter{}); len(rows) != 0 {
		t.Errorf("list after delete = %v, want empty", ids(rows))
	}
	if err := s.SoftDelete(ctx, "cv_1"); !errors.Is(err, conversationdomain.ErrNotFound) {
		t.Errorf("re-delete = %v, want ErrNotFound", err)
	}
}

func TestSoftDelete_Unknown(t *testing.T) {
	s := newStore(t)
	if err := s.SoftDelete(ctxWS("ws_1"), "cv_x"); !errors.Is(err, conversationdomain.ErrNotFound) {
		t.Errorf("err = %v, want ErrNotFound", err)
	}
}

func TestWorkspaceIsolation(t *testing.T) {
	s := newStore(t)
	ws1, ws2 := ctxWS("ws_1"), ctxWS("ws_2")
	seed(t, s, ws1, "cv_1", "in ws1", false, false, t1)
	if _, err := s.Get(ws2, "cv_1"); !errors.Is(err, conversationdomain.ErrNotFound) {
		t.Errorf("cross-ws get = %v, want ErrNotFound", err)
	}
	if rows, _, _ := s.List(ws2, conversationdomain.ListFilter{}); len(rows) != 0 {
		t.Errorf("ws2 list = %v, want empty", ids(rows))
	}
	if rows, _, _ := s.List(ws1, conversationdomain.ListFilter{}); !equal(ids(rows), []string{"cv_1"}) {
		t.Errorf("ws1 list = %v, want [cv_1]", ids(rows))
	}
}

func TestGetBatch(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	seed(t, s, ctx, "cv_1", "one", false, false, t1)
	seed(t, s, ctx, "cv_2", "two", false, false, t2)
	rows, err := s.GetBatch(ctx, []string{"cv_1", "cv_2", "cv_missing"})
	if err != nil {
		t.Fatalf("batch: %v", err)
	}
	if len(rows) != 2 {
		t.Errorf("batch len = %d, want 2", len(rows))
	}
	if r, err := s.GetBatch(ctx, nil); err != nil || r != nil {
		t.Errorf("empty batch = %v, %v", r, err)
	}
}
