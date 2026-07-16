package trigger

import (
	"time"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// Firing is the durable inbox row — persist-before-act: written the moment a trigger
// fires, before any flowrun starts. A single fire fans out to one Firing per listening
// workflow. The scheduler drains pending firings, claiming each in one tx
// (pending→claimed→started) so there is never a claimed-but-no-flowrun strand.
// Terminal status IS the outcome ("every firing reaches a terminal status").
//
// Firing 是 durable 收件箱行——先持久化再动作：trigger fire 的瞬间就写，早于任何 flowrun。
// 一次 fire 按监听的 workflow 扇出成多条 Firing。scheduler 排空 pending、单事务 claim
// 每条（pending→claimed→started），无 claimed-但-无-flowrun 残留态。终态 status 即 outcome。
type Firing struct {
	ID           string         `db:"id,pk"               json:"id"`
	WorkspaceID  string         `db:"workspace_id,ws"     json:"-"`
	TriggerID    string         `db:"trigger_id"          json:"triggerId"`
	WorkflowID   string         `db:"workflow_id"         json:"workflowId"`
	ActivationID string         `db:"activation_id"       json:"activationId"`
	Payload      map[string]any `db:"payload,json"        json:"payload,omitempty"`
	DedupKey     string         `db:"dedup_key"           json:"dedupKey"`
	Status       string         `db:"status"              json:"status"`
	FlowrunID    string         `db:"flowrun_id"          json:"flowrunId,omitempty"`
	CreatedAt    time.Time      `db:"created_at,created"  json:"createdAt"` // enqueue time — drained oldest-first
	UpdatedAt    time.Time      `db:"updated_at,updated"  json:"updatedAt"`
}

// FiringFilter queries one trigger's firing inbox (newest first), optionally one status —
// the "why didn't it run" surface: skipped/superseded/shed dispositions are invisible on
// the activation log (it only counts the fan-out).
//
// FiringFilter 查某 trigger 的 firing 收件箱（最新优先），可限定单一 status——「为什么没跑」
// 的可见面：skipped/superseded/shed 处置在 activation 日志上不可见（它只记扇出数）。
type FiringFilter struct {
	TriggerID string
	Status    string
	Cursor    string
	Limit     int
}

// Firing lifecycle+disposition — a single status enum, no separate outcome column.
//
// Firing 生命周期+处置——单一 status 枚举，无独立 outcome 列。
const (
	FiringPending    = "pending"    // written, awaiting scheduler claim
	FiringClaimed    = "claimed"    // claimed in the single tx (transient, inside the claim)
	FiringStarted    = "started"    // claimed + flowrun created (terminal-ok)
	FiringSkipped    = "skipped"    // overlap policy Skip
	FiringSuperseded = "superseded" // overlap policy buffer_one dropped this older waiting firing
	FiringShed       = "shed"       // resource cap
	// FiringMissed is the misfire disposition (scheduler 工单⑨, 判决⑥): a cron tick that was due
	// while the app was not running (sleep / shutdown). Recorded by the misfire sweep, NEVER re-run
	// (default policy skip) — a neutral "did not execute" ledger row, not an error. dedup_key is the
	// tick itself, so a tick that actually fired dedups against its live row instead of double-booking.
	//
	// FiringMissed 是 misfire 处置态（scheduler 工单⑨，判决⑥）：app 未运行（睡眠/关机）期间到期的
	// cron 刻度。由 misfire sweep 记账、**绝不补跑**（默认 skip）——中性「未执行」台账行、非错误。
	// dedup_key 就是刻度本身，故真 fire 过的刻度会与其活行去重、不会重复记账。
	FiringMissed = "missed"
)

// FiringStatuses is the closed firing-status enum — used to reject an illegal SearchFirings filter
// value (an out-of-set status would otherwise silently match zero rows, the F168-M2 bug extended to
// the firing inbox, F175-M7).
//
// FiringStatuses 是 firing 状态封闭集——用于拒非法 SearchFirings 过滤值（非集内状态否则静默匹配 0 行，
// F168-M2 之病延伸到 firing 收件箱，F175-M7）。
var FiringStatuses = []string{FiringPending, FiringClaimed, FiringStarted, FiringSkipped, FiringSuperseded, FiringShed, FiringMissed}

// ErrInvalidFiringStatus: a SearchFirings filter passed a status outside FiringStatuses — 422 with the
// allowed set in Details, never a misleading empty page.
//
// ErrInvalidFiringStatus：SearchFirings 过滤传了 FiringStatuses 外的状态——422 + Details 带允许集，
// 绝不返误导性空页。
var ErrInvalidFiringStatus = errorspkg.New(errorspkg.KindUnprocessable, "TRIGGER_FIRING_INVALID_STATUS", "firing status filter must be one of: pending, claimed, started, skipped, superseded, shed, missed")
