// Package flowrun is the workflow execution-record domain. A FlowRun
// is one trigger-fired (or manually-fired) execution of a Workflow's
// active version — it captures the version pinned at start time, the
// trigger source, status (5 values), terminal output, and an optional
// PausedState JSON snapshot for approval/wait nodes that need to
// survive process restart (Plan 05 §6.1).
//
// See documents/version-1.2/adhoc-topic-documents/forge_redesign/05-execution-plane.md §5.1
// + 08-executions.md §4.5 (FlowRunNode schema).
//
// Package flowrun 是 workflow 执行记录域。FlowRun 是 trigger 触发(或手动)
// 的一次执行,固定起跑时的版本 + 触发源 + 状态(5 值)+ 终态输出 + 可选
// PausedState JSON 快照(approval/wait 节点跨进程重启恢复用)。
package flowrun

import (
	"errors"
	"time"

	"gorm.io/gorm"
)

// FlowRun status enumeration (5 terminal+non-terminal states). Note:
// V1 has no run-level timeout state. Node-level timeout causing run
// failure is recorded as `failed` with error_code=NODE_TIMEOUT.
//
// FlowRun 状态枚举(5 值)。V1 没 run-level timeout 状态;节点 timeout 导致
// run 失败时 status=failed + error_code=NODE_TIMEOUT。
const (
	StatusRunning   = "running"
	StatusPaused    = "paused"
	StatusCompleted = "completed"
	StatusFailed    = "failed"
	StatusCancelled = "cancelled"
)

// Trigger kinds (4 values). Mirrors triggerdomain.Kind* constants but
// kept here too so flowrun store layer can validate without circular
// import on the trigger domain.
//
// Trigger 种类(4 值)。镜像 triggerdomain.Kind*;独立常量避免 store 校验时
// 跨域 import 循环。
const (
	TriggerKindCron     = "cron"
	TriggerKindFsnotify = "fsnotify"
	TriggerKindWebhook  = "webhook"
	TriggerKindManual   = "manual"
)

// DefaultRetentionLimit caps FlowRun rows per workflow per Plan 05 §6.7.
// HardDeleteOldest trims after each finalizeRun.
//
// DefaultRetentionLimit 每 workflow 保留上限(Plan 05 §6.7);finalizeRun
// 后异步 trim 最旧的。
const DefaultRetentionLimit = 200

// PausedState is the persisted ExecutionContext snapshot for an approval
// or wait node — survives process restart so the scheduler can rehydrate
// and resume execution (Plan 05 §6.1).
//
// PausedState 是 approval/wait 节点暂停时持久化的 ExecutionContext 快照,
// 跨进程重启 scheduler 用来 rehydrate 继续执行(Plan 05 §6.1)。
type PausedState struct {
	NodeID    string                    `json:"nodeId"`
	Variables map[string]any            `json:"variables"`
	Outputs   map[string]map[string]any `json:"outputs"`
	Position  []string                  `json:"position"`
	PausedAt  time.Time                 `json:"pausedAt"`
}

// FlowRun is one execution record of a Workflow's active version. The
// version_id field pins which Version was active at start (so accept-
// pending mid-run can't change what's executing). status follows the
// 5-value state machine (running ↔ paused → completed|failed|cancelled).
//
// FlowRun 是 Workflow 一次执行记录。version_id 锁起跑时的 Version(防 active
// 切换影响进行中的 run)。status 走 5 值状态机。
type FlowRun struct {
	ID           string         `gorm:"primaryKey;type:text" json:"id"`
	UserID       string         `gorm:"not null;index:idx_flowruns_user_id;type:text" json:"userId"`
	WorkflowID   string         `gorm:"not null;type:text;index:idx_flowruns_workflow,priority:1" json:"workflowId"`
	VersionID    string         `gorm:"not null;type:text" json:"versionId"`
	TriggerKind  string         `gorm:"not null;check:trigger_kind IN ('cron','fsnotify','webhook','manual');type:text" json:"triggerKind"`
	TriggerInput map[string]any `gorm:"serializer:json;type:text;default:'{}'" json:"triggerInput"`
	Status       string         `gorm:"not null;check:status IN ('running','paused','completed','failed','cancelled');index:idx_flowruns_workflow,priority:2;type:text" json:"status"`
	StartedAt    time.Time      `gorm:"not null;index:idx_flowruns_workflow,priority:3,sort:desc" json:"startedAt"`
	EndedAt      *time.Time     `json:"endedAt,omitempty"`
	ElapsedMs    int64          `gorm:"not null;default:0" json:"elapsedMs"`
	Output       any            `gorm:"serializer:json;type:text" json:"output,omitempty"`
	ErrorCode    string         `gorm:"type:text;default:''" json:"errorCode,omitempty"`
	ErrorMessage string         `gorm:"type:text;default:''" json:"errorMessage,omitempty"`
	PausedState  *PausedState   `gorm:"serializer:json;type:text" json:"pausedState,omitempty"`

	CreatedAt time.Time      `json:"createdAt"`
	UpdatedAt time.Time      `json:"updatedAt"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

// TableName pins the table name (GORM would pluralize FlowRun → flow_runs
// otherwise — we want `flowruns`).
//
// TableName 显式指定表名(防 GORM 复数化为 flow_runs)。
func (FlowRun) TableName() string { return "flowruns" }

// ListFilter is the query shape for Repository.ListFlowRuns.
//
// ListFilter 是 ListFlowRuns 查询形状。
type ListFilter struct {
	WorkflowID  string
	Status      string
	TriggerKind string
	Cursor      string
	Limit       int
}

// Sentinel errors. Wire codes registered in transport/httpapi/response/errmap.go.
// errors.Is must unwrap through fmt.Errorf("flowrunstore.Method: %w", err)
// chains back to these sentinels (§S16).
//
// 哨兵错误。Wire code 在 errmap.go 登记。
var (
	ErrNotFound                = errors.New("flowrun: not found")
	ErrNotCancellable          = errors.New("flowrun: not cancellable")
	ErrNotPaused               = errors.New("flowrun: not paused")
	ErrApprovalNodeNotFound    = errors.New("flowrun: approval node not found in paused state")
	ErrApprovalDecisionInvalid = errors.New("flowrun: approval decision invalid")
)
