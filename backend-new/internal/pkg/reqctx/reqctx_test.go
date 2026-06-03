package reqctx

import (
	"context"
	"testing"
)

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
