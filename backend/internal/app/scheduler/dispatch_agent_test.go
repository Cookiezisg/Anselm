package scheduler

import (
	"context"
	"errors"
	"testing"

	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// ctxCapturingResolver records the userID present in the ctx it receives, then errors to
// short-circuit Dispatch before the LLM path.
type ctxCapturingResolver struct{ gotUID string }

func (r *ctxCapturingResolver) GetAgentConfig(ctx context.Context, _ string) (string, int, []string, string, error) {
	r.gotUID, _ = reqctxpkg.GetUserID(ctx)
	return "", 0, nil, "", errors.New("stop-before-llm")
}

// TestAgentDispatch_PassesUserCtxToResolver is the regression guard for the agentRef bug: the
// dispatcher must pass the run ctx (carrying userID) to GetAgentConfig, NOT context.Background().
// The agent store scopes Get by user_id, so Background() made every agentRef node fail with
// "missing user id". Before the fix gotUID == "" (Background); after, it is the run's userID.
// Reuses fakeAgentPicker/fakeKeyProvider (dispatchers_capability_test.go) so the nil-guard passes
// and Dispatch reaches the resolver.
func TestAgentDispatch_PassesUserCtxToResolver(t *testing.T) {
	d := NewAgentDispatcher(&fakeAgentPicker{}, fakeKeyProvider{}, llminfra.NewFactory(), nil, nil, nil)
	res := &ctxCapturingResolver{}
	d.SetAgentResolver(res)

	ctx := reqctxpkg.SetUserID(context.Background(), "u_test")
	out := d.Dispatch(ctx, DispatchInput{
		Node: workflowdomain.NodeSpec{
			ID:     "a",
			Type:   workflowdomain.NodeTypeAgent,
			Config: map[string]any{"agentRef": "ag_x"},
		},
	})

	if res.gotUID != "u_test" {
		t.Errorf("resolver received userID %q, want u_test — dispatcher passed Background() instead of the run ctx", res.gotUID)
	}
	if out.Error == nil {
		t.Errorf("expected the resolver error to propagate as the dispatch error")
	}
}
