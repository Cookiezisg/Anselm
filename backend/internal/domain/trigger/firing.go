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

// FiringFilter queries the firing inbox (newest first) — the "why didn't it run" surface:
// skipped/superseded/shed/missed dispositions are invisible on the activation log (it only counts
// the fan-out). All filters compose with AND, and EVERY one is optional: an empty TriggerID spans
// the whole workspace (a firing is a workspace-level log row — trigger × workflow × activation —
// so "all triggers" is a first-class question, the Overview's 24h schedule track being the caller
// that asks it). Status is closed-set (an out-of-enum value is a loud 422, never a silent empty
// page — F168-M2), and the created_at window is half-open [CreatedAfter, CreatedBefore) so adjacent
// windows tile without overlap (zero time = that bound unset) — the flowrun ListFilter grammar
// VERBATIM (scheduler 工单⑭), because two spellings of "a log page in a time window" is one
// spelling too many.
//
// Cursor/Limit are the page's alone: CountFirings ignores them (a count is not a page), so the
// SAME filter drives both the "错过 N" KPI number and the list its click deep-links to — they
// cannot disagree, because they are the same predicates.
//
// FiringFilter 查 firing 收件箱（最新优先）——「为什么没跑」的可见面：skipped/superseded/shed/missed
// 处置在 activation 日志上不可见（它只记扇出数）。所有过滤 AND 组合、且**每一项都可选**：TriggerID 为空
// 即跨整个 workspace（firing 是 **workspace 级**日志行——trigger × workflow × activation——故「所有
// trigger」是一等问题，Overview 的 24h 调度轨道就是问它的调用方）。Status 是封闭集（枚举外值 422 大声拒、
// 绝不静默空页——F168-M2）；created_at 窗口是**半开区间** [CreatedAfter, CreatedBefore)——相邻窗口无缝
// 拼接不重叠（零值时间 = 该端不设界）——**逐字**沿用 flowrun ListFilter 的文法（scheduler 工单⑭），
// 因为「时间窗里的一页日志」有两套拼法就是多了一套。
//
// Cursor/Limit 只属于分页：CountFirings 忽略它们（计数不是一页），故**同一个** filter 同时驱动
// 「错过 N」KPI 数字与它点击深链过去的那个列表——两者不可能不一致，因为它们就是同一组谓词。
type FiringFilter struct {
	TriggerID     string
	Status        string
	CreatedAfter  time.Time // inclusive lower bound on created_at. created_at 含下界。
	CreatedBefore time.Time // exclusive upper bound on created_at. created_at 不含上界。
	Cursor        string
	Limit         int
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

// ErrInvalidFiringFilter: a firing list filter value outside its grammar — ?createdAfter /
// ?createdBefore not RFC3339 (scheduler 工单⑭). The trigger-domain twin of the flowrun list's
// ErrInvalidListFilter, and a separate code from it on purpose: answering a bad ?createdAfter on
// /firings with FLOWRUN_LIST_INVALID_FILTER ("invalid flowrun list filter value") would name the
// wrong resource — the client is not listing flowruns. Same loud-422 stance as ErrInvalidFiringStatus
// (F168-M2): Details carry the offending param + got so the caller self-corrects instead of reading
// a silent empty page as "nothing was missed".
//
// ErrInvalidFiringFilter：firing 列表过滤值出文法——?createdAfter/?createdBefore 非 RFC3339
// （scheduler 工单⑭）。flowrun 列表 ErrInvalidListFilter 的 trigger 域孪生，且**刻意**与它分码：拿
// FLOWRUN_LIST_INVALID_FILTER（「invalid flowrun list filter value」）去答 /firings 上一个坏的
// ?createdAfter，报的是**错的资源**——调用方并没在列 flowrun。与 ErrInvalidFiringStatus 同一 422 大声拒
// 立场（F168-M2）：Details 带出错参数 + 原值，让调用方自纠、而非把静默空页读作「什么都没错过」。
var ErrInvalidFiringFilter = errorspkg.New(errorspkg.KindUnprocessable, "TRIGGER_FIRING_INVALID_FILTER", "invalid firing list filter value")
