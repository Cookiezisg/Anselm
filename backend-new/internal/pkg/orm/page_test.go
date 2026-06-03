package orm

import (
	"fmt"
	"testing"
)

func TestPage_Cursor(t *testing.T) {
	db, ctx := newTestDB(t)
	r := widgets(db)
	for i := 1; i <= 5; i++ {
		mustCreate(t, r, ctx, fmt.Sprintf("w_%d", i), "x", i)
	}

	seen := map[string]bool{}
	cursor := ""
	pages := 0
	for {
		rows, next, err := r.Query().Page(ctx, cursor, 2)
		if err != nil {
			t.Fatalf("page: %v", err)
		}
		if len(rows) > 2 {
			t.Fatalf("page returned %d rows, limit was 2", len(rows))
		}
		for _, w := range rows {
			if seen[w.ID] {
				t.Errorf("duplicate %s across pages", w.ID)
			}
			seen[w.ID] = true
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
	if len(seen) != 5 {
		t.Errorf("paged %d distinct rows, want 5", len(seen))
	}
	if pages != 3 {
		t.Errorf("5 rows / page 2 → want 3 pages, got %d", pages)
	}
}
