package reqctx

import (
	"context"
	"errors"
	"testing"
)

func TestWorkspaceID(t *testing.T) {
	ctx := context.Background()

	if _, ok := GetWorkspaceID(ctx); ok {
		t.Fatal("empty ctx must report no workspace id")
	}
	if _, err := RequireWorkspaceID(ctx); !errors.Is(err, ErrMissingWorkspaceID) {
		t.Fatalf("RequireWorkspaceID(empty) err = %v, want ErrMissingWorkspaceID", err)
	}

	ctx = SetWorkspaceID(ctx, "ws_123")
	if id, ok := GetWorkspaceID(ctx); !ok || id != "ws_123" {
		t.Fatalf("GetWorkspaceID = %q,%v, want ws_123,true", id, ok)
	}
	if id, err := RequireWorkspaceID(ctx); err != nil || id != "ws_123" {
		t.Fatalf("RequireWorkspaceID = %q,%v, want ws_123,nil", id, err)
	}

	// An explicitly empty id is treated as missing — guards against silently-empty wiring.
	if _, ok := GetWorkspaceID(SetWorkspaceID(context.Background(), "")); ok {
		t.Fatal("empty workspace id must report ok=false")
	}
}
