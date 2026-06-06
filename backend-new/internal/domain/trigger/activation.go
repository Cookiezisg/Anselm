package trigger

import "time"

// Activation is the per-action audit log — ONE row every time a trigger does something,
// fired or NOT. This is what makes "why didn't it fire?" answerable: for a sensor that
// probed but didn't trigger, ReturnValue records what the function/handler returned and
// Error/Detail says why (condition false vs invoke error). Firing is only the fired path;
// Activation is the whole story. A non-fired Activation produces 0 Firings; a fired one
// produces FiringCount (fan-out width).
//
// Activation 是逐动作审计日志——trigger 每做一次事就一行，**触没触发都记**。这让「为什么没触发」
// 可查：sensor 探测但没触发时，ReturnValue 记下 function/handler 返回了什么、Error/Detail 说明
// 原因（条件 false 还是调用出错）。Firing 只是触发路径；Activation 是全程。没触发的 Activation
// 产 0 条 Firing，触发的产 FiringCount 条（扇出宽度）。
type Activation struct {
	ID          string         `db:"id,pk"`
	WorkspaceID string         `db:"workspace_id,ws"`
	TriggerID   string         `db:"trigger_id"`
	Kind        string         `db:"kind"`
	Fired       bool           `db:"fired"`
	ReturnValue map[string]any `db:"return_value,json"`  // sensor: what the probe returned (kept even when not fired)
	Payload     map[string]any `db:"payload,json"`       // the payload fired out (empty when not fired)
	Error       string         `db:"error"`              // invoke/probe error (empty on success)
	Detail      string         `db:"detail"`             // human-readable note, e.g. "condition evaluated false"
	FiringCount int            `db:"firing_count"`       // how many workflows it fanned out to
	CreatedAt   time.Time      `db:"created_at,created"` // when the action occurred
}

// ActivationFilter queries the activation log for one trigger (newest first), optionally
// only the misses (FiredOnly is the opposite — only the hits).
//
// ActivationFilter 查某 trigger 的 activation 日志（最新优先），FiredOnly 只看触发的。
type ActivationFilter struct {
	TriggerID string
	FiredOnly bool
	Cursor    string
	Limit     int
}
