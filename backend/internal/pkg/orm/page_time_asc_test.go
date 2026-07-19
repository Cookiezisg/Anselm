package orm

import (
	"fmt"
	"testing"

	paginationpkg "github.com/sunweilin/anselm/backend/internal/pkg/pagination"
)

// TestPageTimeAsc_Cursor proves PageTimeAsc walks the time keyset FORWARD (oldest-first),
// respects the limit, terminates, and never duplicates a row across pages — the ascending mirror
// of TestPage_Cursor.
//
// TestPageTimeAsc_Cursor 证明 PageTimeAsc 沿时间 keyset 向前走（最旧在前）、守 limit、会终止、
// 跨页零重复——TestPage_Cursor 的升序镜像。
func TestPageTimeAsc_Cursor(t *testing.T) {
	db, ctx := newTestDB(t)
	r := widgets(db)
	for i := 1; i <= 5; i++ {
		mustCreate(t, r, ctx, fmt.Sprintf("w_%d", i), "x", i)
	}

	var order []string
	cursor := ""
	pages := 0
	for {
		rows, next, err := r.Query().PageTimeAsc(ctx, cursor, 2)
		if err != nil {
			t.Fatalf("page: %v", err)
		}
		if len(rows) > 2 {
			t.Fatalf("page returned %d rows, limit was 2", len(rows))
		}
		for _, w := range rows {
			order = append(order, w.ID)
		}
		pages++
		if pages > 10 {
			t.Fatal("pagination did not terminate")
		}
		if next == "" {
			break
		}
		cursor = next
	}
	want := []string{"w_1", "w_2", "w_3", "w_4", "w_5"}
	if len(order) != len(want) {
		t.Fatalf("paged %d rows, want %d (%v)", len(order), len(want), order)
	}
	for i := range want {
		if order[i] != want[i] {
			t.Fatalf("ascending order = %v, want %v", order, want)
		}
	}
	if pages != 3 {
		t.Errorf("5 rows / page 2 → want 3 pages, got %d", pages)
	}
}

// TestPageTimeAsc_PartitionsAroundPivot proves the around-window contract: the SAME pivot cursor
// fed to Page yields strictly-older rows (DESC) and fed to PageTimeAsc yields strictly-newer rows
// (ASC) — the pivot row itself lands in neither half.
//
// TestPageTimeAsc_PartitionsAroundPivot 证明 around 窗口契约：同一枚支点游标喂 Page 得严格更旧
// （降序）、喂 PageTimeAsc 得严格更新（升序）——支点行本身不落任何一半。
func TestPageTimeAsc_PartitionsAroundPivot(t *testing.T) {
	db, ctx := newTestDB(t)
	r := widgets(db)
	for i := 1; i <= 5; i++ {
		mustCreate(t, r, ctx, fmt.Sprintf("w_%d", i), "x", i)
	}
	pivotRow, err := r.Get(ctx, "w_3")
	if err != nil {
		t.Fatalf("get pivot: %v", err)
	}
	pivot, err := paginationpkg.EncodeCursor(paginationpkg.Cursor{Key: pivotRow.CreatedAt, ID: pivotRow.ID})
	if err != nil {
		t.Fatalf("encode pivot: %v", err)
	}

	older, _, err := r.Query().Page(ctx, pivot, 10)
	if err != nil {
		t.Fatalf("older half: %v", err)
	}
	newer, _, err := r.Query().PageTimeAsc(ctx, pivot, 10)
	if err != nil {
		t.Fatalf("newer half: %v", err)
	}

	if got, want := ids(older), []string{"w_2", "w_1"}; !equal(got, want) {
		t.Errorf("older half = %v, want %v", got, want)
	}
	if got, want := ids(newer), []string{"w_4", "w_5"}; !equal(got, want) {
		t.Errorf("newer half = %v, want %v", got, want)
	}
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
