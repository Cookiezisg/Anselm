package blob

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"os"
	"testing"

	reqctxpkg "github.com/sunweilin/foryx/backend/internal/pkg/reqctx"
)

func ctxWS(id string) context.Context {
	return reqctxpkg.SetWorkspaceID(context.Background(), id)
}

func sha(data []byte) string {
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}

func TestPutGet_RoundTrip(t *testing.T) {
	s := New(t.TempDir())
	ctx := ctxWS("ws_1")
	data := []byte("hello blob")
	h := sha(data)
	if err := s.Put(ctx, h, data); err != nil {
		t.Fatalf("put: %v", err)
	}
	got, err := s.Get(ctx, h)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if !bytes.Equal(got, data) {
		t.Errorf("round-trip mismatch: %q", got)
	}
}

func TestPut_DedupIdempotent(t *testing.T) {
	s := New(t.TempDir())
	ctx := ctxWS("ws_1")
	data := []byte("same bytes")
	h := sha(data)
	if err := s.Put(ctx, h, data); err != nil {
		t.Fatalf("put1: %v", err)
	}
	if err := s.Put(ctx, h, data); err != nil { // second put = no-op
		t.Fatalf("put2: %v", err)
	}
	got, err := s.Get(ctx, h)
	if err != nil || !bytes.Equal(got, data) {
		t.Errorf("after dedup put: %q %v", got, err)
	}
}

func TestPut_InvalidSHA(t *testing.T) {
	s := New(t.TempDir())
	if err := s.Put(ctxWS("ws_1"), "not-a-sha", []byte("x")); err == nil {
		t.Error("expected error for invalid sha")
	}
}

func TestGet_Missing(t *testing.T) {
	s := New(t.TempDir())
	if _, err := s.Get(ctxWS("ws_1"), sha([]byte("absent"))); !errors.Is(err, os.ErrNotExist) {
		t.Errorf("err = %v, want os.ErrNotExist", err)
	}
}

func TestExists(t *testing.T) {
	s := New(t.TempDir())
	ctx := ctxWS("ws_1")
	data := []byte("present")
	h := sha(data)
	if ok, _ := s.Exists(ctx, h); ok {
		t.Error("exists before put")
	}
	_ = s.Put(ctx, h, data)
	if ok, err := s.Exists(ctx, h); err != nil || !ok {
		t.Errorf("exists after put = %v, %v", ok, err)
	}
}

func TestSweep_RemovesOrphans(t *testing.T) {
	s := New(t.TempDir())
	ctx := ctxWS("ws_1")
	a, b := []byte("keep me"), []byte("orphan me")
	ha, hb := sha(a), sha(b)
	_ = s.Put(ctx, ha, a)
	_ = s.Put(ctx, hb, b)

	removed, err := s.Sweep(ctx, map[string]bool{ha: true})
	if err != nil {
		t.Fatalf("sweep: %v", err)
	}
	if removed != 1 {
		t.Errorf("removed = %d, want 1", removed)
	}
	if ok, _ := s.Exists(ctx, ha); !ok {
		t.Error("kept blob was removed")
	}
	if ok, _ := s.Exists(ctx, hb); ok {
		t.Error("orphan blob survived")
	}
}

func TestSweep_EmptyDirNoop(t *testing.T) {
	s := New(t.TempDir())
	if n, err := s.Sweep(ctxWS("ws_fresh"), nil); err != nil || n != 0 {
		t.Errorf("sweep fresh = %d, %v", n, err)
	}
}

func TestWorkspaceIsolation(t *testing.T) {
	s := New(t.TempDir())
	data := []byte("ws1 only")
	h := sha(data)
	_ = s.Put(ctxWS("ws_1"), h, data)
	if ok, _ := s.Exists(ctxWS("ws_2"), h); ok {
		t.Error("ws_2 sees ws_1's blob")
	}
	if ok, _ := s.Exists(ctxWS("ws_1"), h); !ok {
		t.Error("ws_1 lost its own blob")
	}
}

func TestRequiresWorkspace(t *testing.T) {
	s := New(t.TempDir())
	if err := s.Put(context.Background(), sha([]byte("x")), []byte("x")); err == nil {
		t.Error("expected error without workspace in ctx")
	}
}
