package notification

import (
	"context"
	"database/sql"
	"testing"
	"time"

	_ "github.com/glebarez/go-sqlite"

	notificationdomain "github.com/sunweilin/anselm/backend/internal/domain/notification"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
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

func ctxWS(id string) context.Context { return reqctxpkg.SetWorkspaceID(context.Background(), id) }

// seed inserts a notification with an explicit created_at (Save preserves a non-zero created column) — the
// store test controls the timeline so it can pin the half-open window against exact instants.
func seed(t *testing.T, s *Store, ctx context.Context, id string, createdAt time.Time) {
	t.Helper()
	if err := s.Save(ctx, &notificationdomain.Notification{
		ID:        id,
		Type:      "function.created",
		CreatedAt: createdAt,
	}); err != nil {
		t.Fatalf("seed %s: %v", id, err)
	}
}

func unreadIDs(t *testing.T, s *Store, ctx context.Context) []string {
	t.Helper()
	rows, _, err := s.List(ctx, "", 100)
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	var ids []string
	for _, r := range rows {
		if r.ReadAt == nil {
			ids = append(ids, r.ID)
		}
	}
	return ids
}

// TestMarkAllRead_Window pins the half-open [After, Before) semantics: only rows inside the window flip,
// rows outside stay untouched, and an unbounded window (both zero) still marks the whole ledger.
func TestMarkAllRead_Window(t *testing.T) {
	ctx := ctxWS("ws_1")
	// A three-day timeline (all UTC): earlier / yesterday / today.
	today := time.Date(2026, 7, 20, 0, 0, 0, 0, time.UTC)
	yesterday := today.AddDate(0, 0, -1)

	t.Run("window marks only in-window rows", func(t *testing.T) {
		s := newStore(t)
		seed(t, s, ctx, "n_earlier", yesterday.Add(-3*time.Hour))   // before the yesterday floor → earlier
		seed(t, s, ctx, "n_yesterday", yesterday.Add(10*time.Hour)) // inside [yesterday, today)
		seed(t, s, ctx, "n_today", today.Add(9*time.Hour))          // inside [today, ∞)
		// Mark just the "yesterday" group.
		if err := s.MarkAllRead(ctx, notificationdomain.MarkAllWindow{After: yesterday, Before: today}); err != nil {
			t.Fatalf("MarkAllRead window: %v", err)
		}
		got := unreadIDs(t, s, ctx)
		// n_yesterday flipped to read; the other two stay unread.
		if len(got) != 2 || !contains(got, "n_earlier") || !contains(got, "n_today") {
			t.Fatalf("only the yesterday row should flip; unread = %v", got)
		}
	})

	t.Run("after-only floor leaves earlier rows unread", func(t *testing.T) {
		s := newStore(t)
		seed(t, s, ctx, "n_earlier", yesterday.Add(-3*time.Hour))
		seed(t, s, ctx, "n_today", today.Add(9*time.Hour))
		// Today = [today, ∞): the earlier row is below the floor and must survive.
		if err := s.MarkAllRead(ctx, notificationdomain.MarkAllWindow{After: today}); err != nil {
			t.Fatalf("MarkAllRead after-only: %v", err)
		}
		got := unreadIDs(t, s, ctx)
		if len(got) != 1 || got[0] != "n_earlier" {
			t.Fatalf("after-only floor must leave only n_earlier unread; got %v", got)
		}
	})

	t.Run("before-only ceiling is exclusive at the boundary", func(t *testing.T) {
		s := newStore(t)
		seed(t, s, ctx, "n_below", yesterday.Add(-time.Hour))
		seed(t, s, ctx, "n_at_ceiling", yesterday) // created_at == Before → EXCLUDED (half-open)
		// Earlier = (-∞, yesterday): only strictly-below rows flip.
		if err := s.MarkAllRead(ctx, notificationdomain.MarkAllWindow{Before: yesterday}); err != nil {
			t.Fatalf("MarkAllRead before-only: %v", err)
		}
		got := unreadIDs(t, s, ctx)
		if len(got) != 1 || got[0] != "n_at_ceiling" {
			t.Fatalf("the row AT the exclusive ceiling must stay unread; got %v", got)
		}
	})

	t.Run("unbounded window marks the whole ledger (backward compatible)", func(t *testing.T) {
		s := newStore(t)
		seed(t, s, ctx, "n_earlier", yesterday.Add(-3*time.Hour))
		seed(t, s, ctx, "n_today", today.Add(9*time.Hour))
		if err := s.MarkAllRead(ctx, notificationdomain.MarkAllWindow{}); err != nil {
			t.Fatalf("MarkAllRead unbounded: %v", err)
		}
		if got := unreadIDs(t, s, ctx); len(got) != 0 {
			t.Fatalf("unbounded mark-all-read must clear everything; unread = %v", got)
		}
	})
}

// TestMarkAllUnread_Window mirrors the read case: the window scopes which read rows flip back to unread.
func TestMarkAllUnread_Window(t *testing.T) {
	ctx := ctxWS("ws_2")
	today := time.Date(2026, 7, 20, 0, 0, 0, 0, time.UTC)
	yesterday := today.AddDate(0, 0, -1)

	s := newStore(t)
	seed(t, s, ctx, "n_yesterday", yesterday.Add(10*time.Hour))
	seed(t, s, ctx, "n_today", today.Add(9*time.Hour))
	// First read the whole ledger, then re-unread only the "today" window.
	if err := s.MarkAllRead(ctx, notificationdomain.MarkAllWindow{}); err != nil {
		t.Fatalf("MarkAllRead: %v", err)
	}
	if got := unreadIDs(t, s, ctx); len(got) != 0 {
		t.Fatalf("precondition: everything should be read; unread = %v", got)
	}
	if err := s.MarkAllUnread(ctx, notificationdomain.MarkAllWindow{After: today}); err != nil {
		t.Fatalf("MarkAllUnread window: %v", err)
	}
	got := unreadIDs(t, s, ctx)
	if len(got) != 1 || got[0] != "n_today" {
		t.Fatalf("only the today row should flip back to unread; got %v", got)
	}
}

func contains(xs []string, x string) bool {
	for _, v := range xs {
		if v == x {
			return true
		}
	}
	return false
}
