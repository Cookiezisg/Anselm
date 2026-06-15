package reqctx

import (
	"context"
	"testing"

	agentstatepkg "github.com/sunweilin/foryx/backend/internal/pkg/agentstate"
)

func TestGetAgentState_Missing(t *testing.T) {
	_, ok := GetAgentState(context.Background())
	if ok {
		t.Fatalf("GetAgentState on bare ctx = ok=true; want false (fail-closed)")
	}
}

func TestWithAgentState_RoundTrip(t *testing.T) {
	s := agentstatepkg.New()
	ctx := WithAgentState(context.Background(), s)
	got, ok := GetAgentState(ctx)
	if !ok {
		t.Fatalf("GetAgentState after WithAgentState = ok=false")
	}
	if got != s {
		t.Fatalf("GetAgentState returned different pointer")
	}
}

func TestWithAgentState_Nil_TreatedAsAbsent(t *testing.T) {
	// Seeding nil must surface as ok=false — otherwise Write/Edit would deref
	// a nil pointer thinking the guard is in place.
	//
	// seed nil 必须呈现 ok=false——否则 Write/Edit 会以为守卫到位却对 nil 解引用。
	ctx := WithAgentState(context.Background(), nil)
	if _, ok := GetAgentState(ctx); ok {
		t.Fatalf("GetAgentState with nil seed = ok=true; want false")
	}
}
