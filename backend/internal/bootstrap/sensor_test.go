package bootstrap

import (
	"context"
	"errors"
	"testing"

	functiondomain "github.com/sunweilin/anselm/backend/internal/domain/function"
	handlerdomain "github.com/sunweilin/anselm/backend/internal/domain/handler"
)

type fakeFuncGetter struct{ ok bool }

func (f fakeFuncGetter) Get(_ context.Context, id string) (*functiondomain.Function, error) {
	if f.ok {
		return &functiondomain.Function{ID: id}, nil
	}
	return nil, errors.New("not found")
}

type fakeHandlerGetter struct{ ok bool }

func (f fakeHandlerGetter) Get(_ context.Context, id string) (*handlerdomain.Handler, error) {
	if f.ok {
		return &handlerdomain.Handler{ID: id}, nil
	}
	return nil, errors.New("not found")
}

type fakeMCPResolver struct{ ok bool }

func (f fakeMCPResolver) ResolveServerID(_ context.Context, token string) (string, error) {
	if f.ok {
		return token, nil
	}
	return "", errors.New("not found")
}

// TestSensorTargetValidator_Routing — F102: the validator routes each target kind to its existence
// lookup (function/handler Get, mcp ResolveServerID); a missing target or an unknown kind errors.
func TestSensorTargetValidator_Routing(t *testing.T) {
	ctx := context.Background()

	ok := NewSensorTargetValidator(fakeFuncGetter{true}, fakeHandlerGetter{true}, fakeMCPResolver{true})
	for _, k := range []string{"function", "handler", "mcp"} {
		if err := ok.ValidateSensorTarget(ctx, k, "x_1", "m"); err != nil {
			t.Errorf("kind %s with an existing target must pass, got %v", k, err)
		}
	}

	missing := NewSensorTargetValidator(fakeFuncGetter{false}, fakeHandlerGetter{false}, fakeMCPResolver{false})
	for _, k := range []string{"function", "handler", "mcp"} {
		if err := missing.ValidateSensorTarget(ctx, k, "x_ghost", "m"); err == nil {
			t.Errorf("kind %s with a missing target must fail", k)
		}
	}

	if err := ok.ValidateSensorTarget(ctx, "bogus", "x", ""); err == nil {
		t.Error("an unknown target kind must error")
	}
}
