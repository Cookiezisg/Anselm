package scheduler

import (
	"context"
	"errors"
	"testing"
	"time"

	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
)

func TestHTTPDispatcher_MissingURL(t *testing.T) {
	d := NewHTTPDispatcher(nil)
	out := d.Dispatch(context.Background(), mkInput(
		workflowdomain.NodeSpec{ID: "h", Type: workflowdomain.NodeTypeHTTP, Config: map[string]any{}},
		&flowrundomain.FlowRun{ID: "fr1"}))
	if out.Error == nil || !contains(out.Error.Error(), "url required") {
		t.Errorf("expected url-required error, got %v", out.Error)
	}
}

func TestHTTPDispatcher_SSRFBlocksLoopback(t *testing.T) {
	d := NewHTTPDispatcher(nil)
	out := d.Dispatch(context.Background(), mkInput(
		workflowdomain.NodeSpec{ID: "h", Type: workflowdomain.NodeTypeHTTP,
			Config: map[string]any{"url": "http://127.0.0.1:9999/admin"}},
		&flowrundomain.FlowRun{ID: "fr1"}))
	if out.Error == nil || !contains(out.Error.Error(), "ssrf guard") {
		t.Errorf("expected ssrf guard error, got %v", out.Error)
	}
}

func TestHTTPDispatcher_SSRFBlocksLocalhost(t *testing.T) {
	d := NewHTTPDispatcher(nil)
	out := d.Dispatch(context.Background(), mkInput(
		workflowdomain.NodeSpec{ID: "h", Type: workflowdomain.NodeTypeHTTP,
			Config: map[string]any{"url": "http://localhost:9999/x"}},
		&flowrundomain.FlowRun{ID: "fr1"}))
	if out.Error == nil || !contains(out.Error.Error(), "blocked") {
		t.Errorf("expected blocked error, got %v", out.Error)
	}
}

// ConditionDispatcher now uses CEL (not text/template). Tests updated to use CEL syntax.
func TestConditionDispatcher_Truthy(t *testing.T) {
	d := NewConditionDispatcher()
	in := mkInput(workflowdomain.NodeSpec{ID: "c", Type: workflowdomain.NodeTypeCondition,
		Config: map[string]any{"condition": `payload.x == "yes"`}},
		&flowrundomain.FlowRun{ID: "fr1"})
	in.NodeIn = map[string]any{"x": "yes"}

	out := d.Dispatch(context.Background(), in)
	if out.Error != nil {
		t.Fatalf("Error: %v", out.Error)
	}
	if out.NextPort != "true" {
		t.Errorf("NextPort = %q, want true", out.NextPort)
	}
}

func TestConditionDispatcher_Falsy(t *testing.T) {
	d := NewConditionDispatcher()
	in := mkInput(workflowdomain.NodeSpec{ID: "c", Type: workflowdomain.NodeTypeCondition,
		Config: map[string]any{"condition": `false`}},
		&flowrundomain.FlowRun{ID: "fr1"})

	out := d.Dispatch(context.Background(), in)
	if out.NextPort != "false" {
		t.Errorf("NextPort = %q, want false", out.NextPort)
	}
}

func TestConditionDispatcher_MissingCondition(t *testing.T) {
	d := NewConditionDispatcher()
	in := mkInput(workflowdomain.NodeSpec{ID: "c", Type: workflowdomain.NodeTypeCondition,
		Config: map[string]any{}}, &flowrundomain.FlowRun{ID: "fr1"})
	out := d.Dispatch(context.Background(), in)
	if out.Error == nil || !contains(out.Error.Error(), "condition required") {
		t.Errorf("expected condition-required error, got %v", out.Error)
	}
}

func TestVariableDispatcher_Set(t *testing.T) {
	d := NewVariableDispatcher()
	in := mkInput(workflowdomain.NodeSpec{ID: "v", Type: workflowdomain.NodeTypeVariable,
		Config: map[string]any{"operation": "set", "name": "x", "value": "hello"}},
		&flowrundomain.FlowRun{ID: "fr1"})

	out := d.Dispatch(context.Background(), in)
	if out.Error != nil {
		t.Fatalf("Error: %v", out.Error)
	}
	if in.ExecCtx.Variables["x"] != "hello" {
		t.Errorf("var not set: %v", in.ExecCtx.Variables["x"])
	}
}

func TestVariableDispatcher_Unset(t *testing.T) {
	d := NewVariableDispatcher()
	in := mkInput(workflowdomain.NodeSpec{ID: "v", Type: workflowdomain.NodeTypeVariable,
		Config: map[string]any{"operation": "unset", "name": "x"}},
		&flowrundomain.FlowRun{ID: "fr1"})
	in.ExecCtx.Variables["x"] = "stored"

	d.Dispatch(context.Background(), in)
	if _, ok := in.ExecCtx.Variables["x"]; ok {
		t.Errorf("var not unset")
	}
}

func TestWaitDispatcher_DurationMs(t *testing.T) {
	d := NewWaitDispatcher()
	start := time.Now()
	out := d.Dispatch(context.Background(), mkInput(
		workflowdomain.NodeSpec{ID: "w", Type: workflowdomain.NodeTypeWait,
			Config: map[string]any{"duration": float64(120)}},
		&flowrundomain.FlowRun{ID: "fr1"}))
	if out.Error != nil {
		t.Fatalf("Error: %v", out.Error)
	}
	if time.Since(start) < 100*time.Millisecond {
		t.Errorf("did not sleep at least 100ms; elapsed %v", time.Since(start))
	}
}

func TestWaitDispatcher_CtxCancel(t *testing.T) {
	d := NewWaitDispatcher()
	ctx, cancel := context.WithCancel(context.Background())
	go func() {
		time.Sleep(20 * time.Millisecond)
		cancel()
	}()
	out := d.Dispatch(ctx, mkInput(
		workflowdomain.NodeSpec{ID: "w", Type: workflowdomain.NodeTypeWait,
			Config: map[string]any{"duration": float64(10_000)}},
		&flowrundomain.FlowRun{ID: "fr1"}))
	if !errors.Is(out.Error, context.Canceled) {
		t.Errorf("expected canceled error, got %v", out.Error)
	}
}

func TestWaitDispatcher_MissingBoth(t *testing.T) {
	d := NewWaitDispatcher()
	out := d.Dispatch(context.Background(), mkInput(
		workflowdomain.NodeSpec{ID: "w", Type: workflowdomain.NodeTypeWait,
			Config: map[string]any{}}, &flowrundomain.FlowRun{ID: "fr1"}))
	if out.Error == nil || !contains(out.Error.Error(), "duration or until required") {
		t.Errorf("expected duration-required error, got %v", out.Error)
	}
}

func TestApprovalDispatcher_EmitsSentinel(t *testing.T) {
	d := NewApprovalDispatcher()
	out := d.Dispatch(context.Background(), mkInput(
		workflowdomain.NodeSpec{ID: "a", Type: workflowdomain.NodeTypeApproval,
			Config: map[string]any{"prompt": "Approve?"}},
		&flowrundomain.FlowRun{ID: "fr1"}))
	if !errors.Is(out.Error, ErrApprovalRequired) {
		t.Errorf("expected ErrApprovalRequired, got %v", out.Error)
	}
}

func TestLoopDispatcher_EmitsItems(t *testing.T) {
	// nil svc OK: no body → passthrough doesn't touch the scheduler back-ref.
	// nil svc OK：无 body 透传不调 scheduler。
	d := NewLoopDispatcher(nil)
	out := d.Dispatch(context.Background(), mkInput(
		workflowdomain.NodeSpec{ID: "l", Type: workflowdomain.NodeTypeLoop,
			Config: map[string]any{"items": []any{"a", "b", "c"}}},
		&flowrundomain.FlowRun{ID: "fr1"}))
	if out.Error != nil {
		t.Fatalf("Error: %v", out.Error)
	}
	if out.Outputs["count"] != 3 {
		t.Errorf("count = %v", out.Outputs["count"])
	}
}

func TestLoopDispatcher_BodyWithoutSchedulerRefIsError(t *testing.T) {
	// V1: body subgraph requires svc back-ref; passing nil reports a wiring bug.
	// V1: body 子图需要 svc 回指；传 nil 报装配 bug。
	d := NewLoopDispatcher(nil)
	out := d.Dispatch(context.Background(), mkInput(
		workflowdomain.NodeSpec{ID: "l", Type: workflowdomain.NodeTypeLoop,
			Config: map[string]any{
				"items": []any{"a"},
				"body":  map[string]any{"nodes": []any{map[string]any{"id": "b1", "type": "variable"}}},
			}},
		&flowrundomain.FlowRun{ID: "fr1"}))
	if out.Error == nil {
		t.Errorf("expected error when body set + nil svc, got nil")
	}
}

func TestParallelDispatcher_PassThrough(t *testing.T) {
	d := NewParallelDispatcher()
	out := d.Dispatch(context.Background(), mkInput(
		workflowdomain.NodeSpec{ID: "p", Type: workflowdomain.NodeTypeParallel,
			Config: map[string]any{}}, &flowrundomain.FlowRun{ID: "fr1"}))
	if out.Error != nil {
		t.Fatalf("Error: %v", out.Error)
	}
}

func TestParallelDispatcher_BranchesUnsupported(t *testing.T) {
	d := NewParallelDispatcher()
	out := d.Dispatch(context.Background(), mkInput(
		workflowdomain.NodeSpec{ID: "p", Type: workflowdomain.NodeTypeParallel,
			Config: map[string]any{"branches": []any{"b1"}}},
		&flowrundomain.FlowRun{ID: "fr1"}))
	if !errors.Is(out.Error, ErrParallelBranchNotSupported) {
		t.Errorf("expected ErrParallelBranchNotSupported, got %v", out.Error)
	}
}
