package media

import (
	"context"
	"testing"

	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func TestStore_SeparatesWorkspacesAndSweepsOnlyUnreferencedDerivatives(t *testing.T) {
	s := New(t.TempDir())
	ctx1 := reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")
	ctx2 := reqctxpkg.SetWorkspaceID(context.Background(), "ws_2")
	sha1, err := s.Put(ctx1, []byte("proxy-one"))
	if err != nil {
		t.Fatal(err)
	}
	sha2, err := s.Put(ctx1, []byte("proxy-two"))
	if err != nil {
		t.Fatal(err)
	}
	if _, err := s.Put(ctx2, []byte("proxy-two")); err != nil {
		t.Fatal(err)
	}
	if removed, err := s.Sweep(ctx1, map[string]bool{sha1: true}); err != nil || removed != 1 {
		t.Fatalf("sweep = (%d, %v), want one removed", removed, err)
	}
	if _, err := s.Get(ctx1, sha1); err != nil {
		t.Fatalf("kept derivative missing: %v", err)
	}
	if _, err := s.Get(ctx1, sha2); err == nil {
		t.Fatal("orphan derivative survived sweep")
	}
	if _, err := s.Get(ctx2, sha2); err != nil {
		t.Fatalf("workspace isolation lost derivative: %v", err)
	}
}
