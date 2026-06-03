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

func TestLocale(t *testing.T) {
	if l := GetLocale(context.Background()); l != DefaultLocale {
		t.Fatalf("default locale = %q, want %q", l, DefaultLocale)
	}
	if l := GetLocale(SetLocale(context.Background(), LocaleEn)); l != LocaleEn {
		t.Fatalf("locale = %q, want en", l)
	}
	if l := GetLocale(SetLocale(context.Background(), Locale("fr"))); l != DefaultLocale {
		t.Fatalf("unsupported locale = %q, want default %q", l, DefaultLocale)
	}
}
