// repository.go — Repository port for flowrun persistence. Implemented
// in infra/store/flowrun (GORM-backed). Service layer holds it as
// interface so unit tests can fake it.
//
// repository.go —— flowrun 持久化的 Repository port;infra/store/flowrun
// GORM 实现。Service 持接口,单测可 fake。

package flowrun

import (
	"context"
	"time"
)

// Repository is the persistence port for FlowRun + Node.
//
// Repository 是 FlowRun + Node 的持久化端口。
type Repository interface {
	// ── FlowRun CRUD ─────────────────────────────────────────────────────

	// Create persists a fresh FlowRun (status=running, no ended_at). Used
	// by scheduler.StartRun at run start.
	//
	// Create 持久化新 FlowRun(status=running)。scheduler.StartRun 起跑时调。
	Create(ctx context.Context, run *FlowRun) error

	// Get fetches by id, scoped to caller. ErrNotFound on miss.
	//
	// Get 按 id 查;未命中返 ErrNotFound。
	Get(ctx context.Context, id string) (*FlowRun, error)

	// List paginates FlowRuns by filter (workflow_id / status / trigger_kind).
	// Order: started_at DESC, id DESC.
	//
	// List 按 filter 分页;按 started_at DESC + id DESC 排序。
	List(ctx context.Context, filter ListFilter) ([]*FlowRun, string, error)

	// UpdateStatus transitions a FlowRun's status (running → paused / running
	// → completed|failed|cancelled). Also writes ended_at + elapsed_ms +
	// output + error_code + error_message when transitioning to a terminal
	// state. Pass empty / nil for non-applicable fields.
	//
	// UpdateStatus 转 status;转终态时同时写 ended_at + elapsed_ms + output
	// + error 字段(不适用的传空)。
	UpdateStatus(ctx context.Context, runID, status string, output any, errCode, errMsg string, endedAt *time.Time, elapsedMs int64) error

	// SetPausedState writes paused_state JSON (approval/wait persist).
	// Pair with UpdateStatus to flip status=paused atomically.
	//
	// SetPausedState 写 paused_state(approval/wait 持久化)。需配合
	// UpdateStatus 转 status=paused。
	SetPausedState(ctx context.Context, runID string, ps *PausedState) error

	// ClearPausedState removes the paused_state blob (resume path).
	//
	// ClearPausedState 清 paused_state(resume 路径)。
	ClearPausedState(ctx context.Context, runID string) error

	// ListPaused returns all paused FlowRuns for current user. Called at
	// boot by Scheduler.RehydrateOnBoot (Plan 05 §6.1).
	//
	// ListPaused 返当前用户所有 paused FlowRun;Scheduler.RehydrateOnBoot 用。
	ListPaused(ctx context.Context) ([]*FlowRun, error)

	// CountRunning returns the number of running FlowRuns for a workflow.
	// Used by Scheduler.StartRun's serial-concurrency check (Plan 05 §6.3).
	//
	// CountRunning 返某 workflow 当前 running FlowRun 数;serial 并发检查用。
	CountRunning(ctx context.Context, workflowID string) (int, error)

	// HardDeleteOldest hard-deletes FlowRuns beyond the retention limit per
	// Plan 05 §6.7. Order by created_at ASC and keep `keep` newest.
	//
	// HardDeleteOldest 物理删超出 keep 个最旧的 FlowRun(§6.7 保留策略)。
	HardDeleteOldest(ctx context.Context, workflowID string, keep int) error

	// ── Node CRUD ────────────────────────────────────────────────────────

	// CreateNode persists a Node row (terminal write, §S9 detached ctx
	// expected at call site for caller-cancel resilience).
	//
	// CreateNode 写一行 Node(终态写;调用方按 §S9 用 detached ctx)。
	CreateNode(ctx context.Context, node *Node) error

	// GetNode fetches a Node by id. ErrNodeNotFound on miss.
	//
	// GetNode 按 id 取 Node;未命中返 ErrNodeNotFound。
	GetNode(ctx context.Context, id string) (*Node, error)

	// ListNodes paginates Nodes by filter (flowrun_id / node_type / status).
	// Order: started_at ASC (chronological execution trace).
	//
	// ListNodes 按 filter 分页 Node;按 started_at ASC 排序(时间顺序)。
	ListNodes(ctx context.Context, filter NodeFilter) ([]*Node, string, error)
}
