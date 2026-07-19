package search

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// TestGlob_Execute_RespectsCtxCancel proves Glob no longer hangs the turn on a cancelled ctx. The
// real bug (Phase 4 attsub HIGH, found via live goroutine dump): doublestar.Glob walks the whole tree
// stuck in os.ReadDir, ignoring ctx, so a "**" from a huge root ran PAST ChatTurnSec (turn-cap cancels
// ctx but os.ReadDir doesn't check it) → message never finalized, isGenerating stuck true, goroutine
// leaked, shutdown blocked. Execute now runs the walk off-goroutine and returns on ctx — this asserts
// it returns promptly (never hangs) on a cancelled ctx, whichever select branch wins.
func TestGlob_Execute_RespectsCtxCancel(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "a.go"), []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel() // already cancelled
	done := make(chan struct{})
	go func() {
		_, _ = newGlob().Execute(ctx, `{"pattern":"**/*.go","path":"`+dir+`"}`)
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		t.Fatal("Glob.Execute hung on a cancelled ctx — the doublestar walk is not bounded by ctx")
	}
}

// TestGrep_collectCandidates_RespectsCtxCancel proves the stdlib fallback's WalkDir aborts on a
// cancelled ctx (previously it ignored ctx like Glob's doublestar walk). filepath.WalkDir fires the
// callback for the root first, so a cancelled ctx aborts before crawling any subtree.
func TestGrep_collectCandidates_RespectsCtxCancel(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "a.txt"), []byte("hi"), 0o644); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	done := make(chan []string, 1)
	go func() {
		got, _ := collectCandidates(ctx, grepArgs{Path: dir}, true)
		done <- got
	}()
	select {
	case got := <-done:
		if len(got) != 0 {
			t.Fatalf("cancelled ctx must abort the walk before collecting candidates, got %d", len(got))
		}
	case <-time.After(3 * time.Second):
		t.Fatal("collectCandidates hung on a cancelled ctx — WalkDir callback does not check ctx")
	}
}
