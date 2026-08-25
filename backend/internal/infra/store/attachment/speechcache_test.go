package attachment

import (
	"context"
	"database/sql"
	"errors"
	"testing"
	"time"

	_ "github.com/glebarez/go-sqlite"

	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func newSpeechCacheStore(t *testing.T) *SpeechCacheStore {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range SpeechCacheSchema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	return NewSpeechCache(ormpkg.Open(sqlDB))
}

func speechCacheContext(id string) context.Context {
	return reqctxpkg.SetWorkspaceID(context.Background(), id)
}

func TestSpeechCachePut_StampsNewEntryAsRecentlyUsed(t *testing.T) {
	store := newSpeechCacheStore(t)
	ctx := speechCacheContext("ws_1")
	entry := &attachmentdomain.SpeechCacheEntry{
		ID:           "spc_3333333333333333",
		CacheKey:     "fresh-cache-key",
		AttachmentID: "att_ws_1",
		SizeBytes:    3,
	}
	before := time.Now().UTC()
	if _, err := store.Put(ctx, entry, attachmentdomain.SpeechCacheBudget); err != nil {
		t.Fatalf("put: %v", err)
	}
	after := time.Now().UTC()
	if entry.LastUsedAt.IsZero() || entry.LastUsedAt.Before(before) || entry.LastUsedAt.After(after) {
		t.Fatalf("new cache entry last_used_at = %v, want a timestamp within the Put call", entry.LastUsedAt)
	}

	persisted, err := store.repo.WhereEq("id", entry.ID).First(ctx)
	if err != nil {
		t.Fatalf("read persisted entry: %v", err)
	}
	if persisted.LastUsedAt.IsZero() {
		t.Fatal("persisted new cache entry has zero last_used_at")
	}
}

func TestRepairLegacyRecency_BackfillsZeroTimestampsIdempotently(t *testing.T) {
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range SpeechCacheSchema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	db := ormpkg.Open(sqlDB)
	createdAt := "2026-08-13 01:21:28.482817+00:00"
	if _, err := db.Exec(context.Background(), `
		INSERT INTO speech_cache
			(id, workspace_id, cache_key, attachment_id, size_bytes, created_at, last_used_at)
		VALUES (?, ?, ?, ?, ?, ?, ?)
	`, "spc_4444444444444444", "ws_1", "legacy-key", "att_ws_1", 3, createdAt, "0001-01-01 00:00:00+00:00"); err != nil {
		t.Fatalf("insert legacy row: %v", err)
	}
	var persistedCreated string
	if err := db.QueryRow(context.Background(), `SELECT created_at FROM speech_cache WHERE id = ?`, "spc_4444444444444444").Scan(&persistedCreated); err != nil {
		t.Fatalf("read created_at: %v", err)
	}

	repaired, err := RepairLegacyRecency(context.Background(), db)
	if err != nil {
		t.Fatalf("repair: %v", err)
	}
	if repaired != 1 {
		t.Fatalf("repaired rows = %d, want 1", repaired)
	}
	var lastUsed string
	if err := db.QueryRow(context.Background(), `SELECT last_used_at FROM speech_cache WHERE id = ?`, "spc_4444444444444444").Scan(&lastUsed); err != nil {
		t.Fatalf("read repaired row: %v", err)
	}
	if lastUsed != persistedCreated {
		t.Fatalf("repaired last_used_at = %q, want created_at %q", lastUsed, persistedCreated)
	}

	repaired, err = RepairLegacyRecency(context.Background(), db)
	if err != nil {
		t.Fatalf("repeat repair: %v", err)
	}
	if repaired != 0 {
		t.Fatalf("repeat repaired rows = %d, want 0", repaired)
	}
}

func TestSpeechCacheDelete_IsWorkspaceScopedAndIdempotent(t *testing.T) {
	store := newSpeechCacheStore(t)
	key := "cache-key"
	for _, tc := range []struct {
		workspace string
		id        string
	}{
		{workspace: "ws_1", id: "spc_1111111111111111"},
		{workspace: "ws_2", id: "spc_2222222222222222"},
	} {
		if _, err := store.Put(speechCacheContext(tc.workspace), &attachmentdomain.SpeechCacheEntry{
			ID:           tc.id,
			CacheKey:     key,
			AttachmentID: "att_" + tc.workspace,
			SizeBytes:    3,
		}, attachmentdomain.SpeechCacheBudget); err != nil {
			t.Fatalf("put %s: %v", tc.workspace, err)
		}
	}

	if err := store.Delete(speechCacheContext("ws_1"), key); err != nil {
		t.Fatalf("delete ws_1: %v", err)
	}
	if _, err := store.Lookup(speechCacheContext("ws_1"), key); !errors.Is(err, attachmentdomain.ErrNotFound) {
		t.Fatalf("ws_1 lookup after delete = %v, want ErrNotFound", err)
	}
	if _, err := store.Lookup(speechCacheContext("ws_2"), key); err != nil {
		t.Fatalf("ws_2 mapping was removed by another workspace: %v", err)
	}
	if err := store.Delete(speechCacheContext("ws_1"), key); err != nil {
		t.Fatalf("repeated delete: %v", err)
	}
}

func TestSpeechCachePut_EvictsOnlyTheCurrentWorkspace(t *testing.T) {
	store := newSpeechCacheStore(t)
	ctx1 := speechCacheContext("ws_1")
	ctx2 := speechCacheContext("ws_2")
	const budget int64 = 10

	old := &attachmentdomain.SpeechCacheEntry{
		ID:           "spc_5555555555555555",
		CacheKey:     "old-ws-1",
		AttachmentID: "att_old_ws_1",
		SizeBytes:    6,
	}
	if _, err := store.Put(ctx1, old, budget); err != nil {
		t.Fatalf("put old ws_1 entry: %v", err)
	}
	other := &attachmentdomain.SpeechCacheEntry{
		ID:           "spc_6666666666666666",
		CacheKey:     "other-ws-2",
		AttachmentID: "att_ws_2",
		SizeBytes:    9,
	}
	if _, err := store.Put(ctx2, other, budget); err != nil {
		t.Fatalf("put ws_2 entry: %v", err)
	}

	newEntry := &attachmentdomain.SpeechCacheEntry{
		ID:           "spc_7777777777777777",
		CacheKey:     "new-ws-1",
		AttachmentID: "att_new_ws_1",
		SizeBytes:    6,
	}
	evicted, err := store.Put(ctx1, newEntry, budget)
	if err != nil {
		t.Fatalf("put new ws_1 entry: %v", err)
	}
	if len(evicted) != 1 || evicted[0] != old.AttachmentID {
		t.Fatalf("evicted attachments = %v, want only %q", evicted, old.AttachmentID)
	}
	if _, err := store.Lookup(ctx1, old.CacheKey); !errors.Is(err, attachmentdomain.ErrNotFound) {
		t.Fatalf("old ws_1 entry after eviction = %v, want ErrNotFound", err)
	}
	if _, err := store.Lookup(ctx1, newEntry.CacheKey); err != nil {
		t.Fatalf("new ws_1 entry after eviction: %v", err)
	}
	if _, err := store.Lookup(ctx2, other.CacheKey); err != nil {
		t.Fatalf("ws_2 entry was evicted by ws_1 budget: %v", err)
	}
}
