package reqctx_test

import (
	"context"
	"testing"

	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

func TestModelOverride_RoundTrip(t *testing.T) {
	ref := &modeldomain.ModelRef{APIKeyID: "aki_xxx", ModelID: "sonnet"}
	ctx := reqctxpkg.WithModelOverride(context.Background(), ref)
	got := reqctxpkg.GetModelOverride(ctx)
	if got == nil || got.APIKeyID != "aki_xxx" || got.ModelID != "sonnet" {
		t.Fatalf("round-trip failed: %+v", got)
	}
}

func TestModelOverride_NilInput_NoOp(t *testing.T) {
	ctx := reqctxpkg.WithModelOverride(context.Background(), nil)
	if got := reqctxpkg.GetModelOverride(ctx); got != nil {
		t.Fatalf("nil input should not set anything, got %+v", got)
	}
}

func TestModelOverride_EmptyCtx_ReturnsNil(t *testing.T) {
	if got := reqctxpkg.GetModelOverride(context.Background()); got != nil {
		t.Fatalf("empty ctx should return nil, got %+v", got)
	}
}
