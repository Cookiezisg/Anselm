package modelref

import (
	"context"
	"errors"
	"testing"

	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
)

type fakeChecker struct{ known map[string]bool }

func (f fakeChecker) KeyExists(_ context.Context, id string) error {
	if f.known[id] {
		return nil
	}
	return apikeydomain.ErrNotFound
}

var errStruct = errors.New("structural")

// TestValidate pins F153's whole contract in one place: structure (per-entity structErr), nil/clear
// skip, nil-checker skip, apiKeyId existence (API_KEY_NOT_FOUND), and — load-bearing — that a typo'd
// modelId with a REAL key still PASSES (modelId is deliberately not validated; it stays fail-loud at
// invoke because there is no authoritative catalog).
func TestValidate(t *testing.T) {
	ctx := context.Background()
	checker := fakeChecker{known: map[string]bool{"aki_real": true}}

	// (a) nil ref (unset / clear) → nil, even with a checker wired.
	if err := Validate(ctx, nil, errStruct, checker); err != nil {
		t.Fatalf("nil ref must pass: %v", err)
	}
	// (b) set-but-incomplete → the caller's structural error (NOT API_KEY_NOT_FOUND).
	if err := Validate(ctx, &modeldomain.ModelRef{ModelID: "m"}, errStruct, checker); !errors.Is(err, errStruct) {
		t.Fatalf("missing apiKeyId must be structErr, got %v", err)
	}
	if err := Validate(ctx, &modeldomain.ModelRef{APIKeyID: "aki_real"}, errStruct, checker); !errors.Is(err, errStruct) {
		t.Fatalf("missing modelId must be structErr, got %v", err)
	}
	// (c) complete ref + nil checker → nil (nil-tolerant: existence not probed in partial wiring).
	if err := Validate(ctx, &modeldomain.ModelRef{APIKeyID: "aki_x", ModelID: "m"}, errStruct, nil); err != nil {
		t.Fatalf("nil checker must skip existence: %v", err)
	}
	// (d) complete ref + non-existent apiKeyId → API_KEY_NOT_FOUND at write (the F153 fix).
	if err := Validate(ctx, &modeldomain.ModelRef{APIKeyID: "aki_deadbeef", ModelID: "m"}, errStruct, checker); !errors.Is(err, apikeydomain.ErrNotFound) {
		t.Fatalf("dangling apiKeyId must reject with API_KEY_NOT_FOUND, got %v", err)
	}
	// (e) complete ref + real key + a TYPO'd modelId → PASSES (modelId is not validated; fail-loud at invoke).
	if err := Validate(ctx, &modeldomain.ModelRef{APIKeyID: "aki_real", ModelID: "deepseek-v9-ultra"}, errStruct, checker); err != nil {
		t.Fatalf("a typo'd modelId with a REAL key must still pass write-time validation (fail-loud at invoke by design), got %v", err)
	}
}
