package orm

import (
	"context"
	"testing"
)

// seedNamed creates one widget with an explicit name (the string keyset column for PageAsc).
//
// seedNamed 建一个带显式 name 的 widget（PageAsc 的字符串 keyset 列）。
func seedNamed(t *testing.T, r *Repo[widget], ctx context.Context, id, name string) {
	t.Helper()
	if err := r.Create(ctx, &widget{ID: id, Name: name}); err != nil {
		t.Fatalf("seed %s: %v", id, err)
	}
}

// TestPageAsc_NOCASEOrderAndTiebreaker proves PageAsc orders a STRING keyset ascending and
// case-INSENSITIVELY, with the pk as the same-key tiebreaker. The seed is a binary-vs-NOCASE
// discriminator: under SQLite's default binary collation uppercase "Banana" (B=66) sorts BEFORE
// lowercase "apple" (a=97); only COLLATE NOCASE puts it between apple and cherry. Two "delta" rows
// tie on the keyset, so the pk (id ASC) breaks it: w_d1 before w_d2.
//
// TestPageAsc_NOCASEOrderAndTiebreaker 证明 PageAsc 按字符串 keyset 升序且**大小写不敏感**排序、pk 为同键
// tiebreaker。播种是 binary-vs-NOCASE 判别器：SQLite 默认 binary collation 下大写 "Banana"(B=66) 排在小写
// "apple"(a=97) 前，唯有 COLLATE NOCASE 才把它放到 apple 与 cherry 之间。两条 "delta" 在 keyset 上相等，故 pk
// （id 升序）破并：w_d1 在 w_d2 前。
func TestPageAsc_NOCASEOrderAndTiebreaker(t *testing.T) {
	db, ctx := newTestDB(t)
	r := widgets(db)
	seedNamed(t, r, ctx, "w_cherry", "cherry")
	seedNamed(t, r, ctx, "w_banana", "Banana") // capital B: NOCASE places between apple/cherry
	seedNamed(t, r, ctx, "w_apple", "apple")
	seedNamed(t, r, ctx, "w_d1", "delta")
	seedNamed(t, r, ctx, "w_d2", "delta")

	rows, next, err := r.Query().PageKeyset("name").PageAsc(ctx, "", 0)
	if err != nil {
		t.Fatalf("pageasc: %v", err)
	}
	if next != "" {
		t.Errorf("unexpected next cursor: %q", next)
	}
	want := []string{"w_apple", "w_banana", "w_cherry", "w_d1", "w_d2"}
	got := make([]string, len(rows))
	for i, w := range rows {
		got[i] = w.ID
	}
	for i := range want {
		if i >= len(got) || got[i] != want[i] {
			t.Fatalf("PageAsc order = %v, want %v", got, want)
		}
	}
}

// TestPageAsc_CursorWalk proves the ascending string cursor walks the full NOCASE order with no
// skip/duplicate, and that the same-key tiebreaker survives a page boundary: with limit=2 the two
// "delta" rows split across pages 2 and 3 (w_d1 ends page 2, w_d2 opens page 3), so the cursor's
// expanded keyset comparison (name NOCASE = key AND id > cursorID) is exercised at the boundary.
//
// TestPageAsc_CursorWalk 证明升序字符串游标按完整 NOCASE 序行进、不漏/不重，且同键 tiebreaker 跨页存活：
// limit=2 时两条 "delta" 分到第 2、3 页（w_d1 收尾第 2 页、w_d2 开第 3 页），故游标的展开式 keyset 比较
// （name NOCASE = key AND id > cursorID）在边界被触发。
func TestPageAsc_CursorWalk(t *testing.T) {
	db, ctx := newTestDB(t)
	r := widgets(db)
	seedNamed(t, r, ctx, "w_cherry", "cherry")
	seedNamed(t, r, ctx, "w_banana", "Banana")
	seedNamed(t, r, ctx, "w_apple", "apple")
	seedNamed(t, r, ctx, "w_d1", "delta")
	seedNamed(t, r, ctx, "w_d2", "delta")

	want := []string{"w_apple", "w_banana", "w_cherry", "w_d1", "w_d2"}
	var got []string
	seen := map[string]bool{}
	cursor := ""
	pages := 0
	for {
		rows, next, err := r.Query().PageKeyset("name").PageAsc(ctx, cursor, 2)
		if err != nil {
			t.Fatalf("page %d: %v", pages, err)
		}
		if len(rows) > 2 {
			t.Fatalf("page returned %d rows, limit was 2", len(rows))
		}
		for _, w := range rows {
			if seen[w.ID] {
				t.Errorf("duplicate %s across pages", w.ID)
			}
			seen[w.ID] = true
			got = append(got, w.ID)
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
	for i := range want {
		if i >= len(got) || got[i] != want[i] {
			t.Fatalf("walked order = %v, want %v (NOCASE keyset + id tiebreaker across boundary)", got, want)
		}
	}
	if len(got) != len(want) {
		t.Fatalf("walked %d rows, want %d", len(got), len(want))
	}
	if pages != 3 {
		t.Errorf("5 rows / page 2 → want 3 pages, got %d", pages)
	}
}
