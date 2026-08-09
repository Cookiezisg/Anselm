package sandbox

import (
	"context"
	"errors"
	"testing"

	"go.uber.org/zap"

	sandboxdomain "github.com/sunweilin/anselm/backend/internal/domain/sandbox"
)

type fakeOwnerNameResolver struct {
	names map[string]string
	err   error
}

func (f fakeOwnerNameResolver) NamesByOwnerIDs(context.Context, []string) (map[string]string, error) {
	if f.err != nil {
		return nil, f.err
	}
	return f.names, nil
}

func TestHydrateOwnerNames_OverlaysCurrentNameAndPreservesFallback(t *testing.T) {
	svc := &Service{
		log: zap.NewNop(),
		ownerNameResolvers: map[string]OwnerNameResolver{
			sandboxdomain.OwnerKindFunction: fakeOwnerNameResolver{
				names: map[string]string{"fn_a_fnenv_v1": "inventory sync"},
			},
		},
	}
	envs := []*sandboxdomain.Env{
		{OwnerKind: sandboxdomain.OwnerKindFunction, OwnerID: "fn_a_fnenv_v1"},
		{OwnerKind: sandboxdomain.OwnerKindFunction, OwnerID: "fn_missing_fnenv_v1", OwnerName: "stored fallback"},
	}

	svc.hydrateOwnerNames(context.Background(), envs)
	if envs[0].OwnerName != "inventory sync" {
		t.Fatalf("resolved owner name = %q, want current entity name", envs[0].OwnerName)
	}
	if envs[1].OwnerName != "stored fallback" {
		t.Fatalf("missing resolver name erased persisted fallback: %q", envs[1].OwnerName)
	}
}

func TestHydrateOwnerNames_ResolverFailureIsVisibleButNonFatal(t *testing.T) {
	svc := &Service{
		log: zap.NewNop(),
		ownerNameResolvers: map[string]OwnerNameResolver{
			sandboxdomain.OwnerKindFunction: fakeOwnerNameResolver{err: errors.New("lookup unavailable")},
		},
	}
	env := &sandboxdomain.Env{
		OwnerKind: sandboxdomain.OwnerKindFunction,
		OwnerID:   "fn_a_fnenv_v1",
		OwnerName: "persisted name",
	}

	svc.hydrateOwnerNames(context.Background(), []*sandboxdomain.Env{env})
	if env.OwnerName != "persisted name" {
		t.Fatalf("resolver failure changed persisted name: %q", env.OwnerName)
	}
}

func TestEnsureEnv_RefreshesPersistedOwnerName(t *testing.T) {
	svc, owner := newServiceWithEnv(t, "fake-py")
	owner.Name = "inventory_sync"

	if _, err := svc.EnsureEnv(context.Background(), owner, sandboxdomain.EnvSpec{
		Runtime: sandboxdomain.RuntimeSpec{Kind: "fake-py", Version: "1.0"},
	}, nil); err != nil {
		t.Fatalf("EnsureEnv: %v", err)
	}
	env, err := svc.repo.GetEnv(context.Background(), "se_test")
	if err != nil {
		t.Fatalf("GetEnv: %v", err)
	}
	if env.OwnerName != "inventory_sync" {
		t.Fatalf("persisted owner name = %q, want refreshed name", env.OwnerName)
	}
}
