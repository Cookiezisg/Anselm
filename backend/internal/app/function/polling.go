package function

import (
	"context"
	"fmt"
	"time"

	functiondomain "github.com/sunweilin/forgify/backend/internal/domain/function"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// PollingAdapter exposes a function's polling capability to the trigger layer (doc 01 §polling):
// resolve the active-version poll cadence (Interval) and run poll(lastCursor) (Poll). It satisfies
// the trigger polling listener's PollingFunction port structurally — no infra import here, keeping
// the dependency one-directional (trigger → function, never the reverse).
//
// PollingAdapter 把 function 的 polling 能力暴露给 trigger 层：解析间隔 + 跑 poll(lastCursor)。
type PollingAdapter struct{ svc *Service }

func NewPollingAdapter(svc *Service) PollingAdapter { return PollingAdapter{svc: svc} }

// Interval reads the function's active-version PollingInterval and confirms Kind=polling. A non-polling
// active version (e.g. the user reverted to a normal version) is an error — the trigger registration
// then fails loudly (surfaced via the trigger State endpoint), matching the 01 capability-check intent.
//
// Interval 读 active version 的 PollingInterval 并确认 Kind=polling；非 polling 报错（注册失败、State 暴露）。
func (a PollingAdapter) Interval(ctx context.Context, userID, functionID string) (time.Duration, error) {
	ctx = reqctxpkg.SetUserID(ctx, userID)
	v, err := a.svc.ActiveVersion(ctx, functionID)
	if err != nil {
		return 0, fmt.Errorf("functionapp.PollingAdapter.Interval: %w", err)
	}
	if v.Kind != functiondomain.KindPolling {
		return 0, fmt.Errorf("functionapp.PollingAdapter.Interval: function %s active version is kind=%q, not polling", functionID, v.Kind)
	}
	if v.PollingInterval == "" {
		return 60 * time.Second, nil // sane default when a polling version omits the interval
	}
	d, perr := time.ParseDuration(v.PollingInterval)
	if perr != nil {
		return 0, fmt.Errorf("functionapp.PollingAdapter.Interval: pollingInterval %q invalid: %w", v.PollingInterval, perr)
	}
	return d, nil
}

// Poll runs the polling function's poll(lastCursor); the input key matches the fixed signature
// `def poll(lastCursor)` (doc 01). Returns the raw output map ({events, nextCursor}).
//
// Poll 跑 poll(lastCursor)；input key 对齐固定签名，返原始输出 map（{events, nextCursor}）。
func (a PollingAdapter) Poll(ctx context.Context, userID, functionID, lastCursor string) (map[string]any, error) {
	ctx = reqctxpkg.SetUserID(ctx, userID)
	res, err := a.svc.RunFunction(ctx, RunInput{
		FunctionID:  functionID,
		Input:       map[string]any{"lastCursor": lastCursor},
		TriggeredBy: "polling_trigger",
	})
	if err != nil {
		return nil, fmt.Errorf("functionapp.PollingAdapter.Poll: %w", err)
	}
	if !res.OK {
		return nil, fmt.Errorf("functionapp.PollingAdapter.Poll: poll() failed: %s", res.ErrorMsg)
	}
	if m, ok := res.Output.(map[string]any); ok {
		return m, nil
	}
	return map[string]any{"output": res.Output}, nil
}
