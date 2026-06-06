// Package trigger (infra root) defines the shared listener contract for the four source
// kinds (cron / webhook / fsnotify / sensor). A Listener watches its source and reports
// every action via ReportFunc; the app turns each report into an Activation and, when the
// action fired, fans it out into one durable Firing per listening workflow.
//
// Package trigger（infra 根）定义 4 种 source listener 的共享契约。Listener 监视其 source，
// 每次动作经 ReportFunc 报告；app 把每条报告变成 Activation，动作触发时再按监听 workflow 扇成 Firing。
package trigger

// Activity is one report of a trigger doing something — fired or NOT. The app writes an
// Activation row from every report, and (only when Fired) fans out one Firing per listening
// workflow. Sensor reports EVERY probe (Fired may be false; ReturnValue/Error/Detail explain
// why it didn't fire); cron/webhook/fsnotify report only when they actually fire (Fired=true).
// This is what makes "why didn't it fire?" answerable.
//
// Activity 是 trigger 一次动作的报告——触没触发都报。app 据每条报告写一行 Activation，且（仅 Fired 时）
// 按监听 workflow 扇出 Firing。sensor 每次探测都报（Fired 可 false，ReturnValue/Error/Detail 说明没触发的原因）；
// cron/webhook/fsnotify 仅真正 fire 时报（Fired=true）。这让「为什么没触发」可查。
type Activity struct {
	Fired       bool
	Payload     map[string]any // the fire payload (meaningful when Fired)
	ReturnValue map[string]any // sensor probe return value (kept even when not fired, for debugging)
	Error       string         // probe/invoke error (empty on success)
	Detail      string         // human-readable note, e.g. "condition evaluated false"
	DedupKey    string         // source's idempotency key ("" → app derives a per-fire key)
}

// ReportFunc is called by a listener on EVERY action. The app turns it into an Activation
// (+ Firings when Fired). A listener never knows about workflows — fan-out is the app's job.
//
// ReportFunc 在每次动作时被 listener 调用。app 把它变成 Activation（Fired 时加 Firing）。
// listener 永远不知道 workflow——扇出是 app 的事。
type ReportFunc func(triggerID string, act Activity)

// Listener is one source kind's runtime, keyed by triggerID (reference-counted by the app:
// registered while ≥1 active workflow listens, unregistered when the count hits 0). Start is
// called once at boot (cron starts its scheduler; push listeners no-op). Stop on shutdown.
//
// Listener 是某 source 种类的运行时，按 triggerID 键（app 引用计数：≥1 个 active workflow 监听时
// 注册，归 0 时注销）。Start 开机调一次（cron 启调度器；push 型 no-op）。Stop 关机调。
type Listener interface {
	// Register starts watching for triggerID. workspaceID is the trigger's owning workspace —
	// the sensor listener uses it to invoke function/handler under the right isolation; the
	// push listeners (cron/webhook/fsnotify) ignore it (the app resolves workspace at report time).
	//
	// Register 开始监听 triggerID。workspaceID 是 trigger 所属 workspace——sensor 用它在正确隔离下
	// 调 function/handler；push 型 listener 忽略（app 在 report 时解析 workspace）。
	Register(triggerID, workspaceID string, config map[string]any) error
	Unregister(triggerID string)
	Start()
	Stop()
}
