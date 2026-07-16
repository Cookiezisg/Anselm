// Operational run statistics (scheduler 工单③) — a PURE READ PROJECTION over the two existing
// flowrun tables (no new table, no new column). One bounded batch answers the scheduler ocean's
// rail + Overview in a single round trip: workspace-wide totals plus a per-workflow health row
// for at most StatsMaxWorkflowIDs requested workflows (the rail feeds its current page of ids).
//
// 运营统计（scheduler 工单③）——flowrun 两张既有表上的**纯读投影**（零新表零新列）。一次有界批查
// 喂饱 scheduler 海洋的 rail + Overview：全 workspace 聚合 + 至多 StatsMaxWorkflowIDs 个请求
// workflow 的健康行（rail 逐页喂当页 ids）。
package flowrun

import (
	"time"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// Stats bounds. The id cap keeps the batch bounded (N4 pagination exemption rests on it); RecentN
// is the per-workflow status-bead window (rail bead strip), clamped like a page limit.
//
// 统计边界。id 上限让批查有界（N4 分页豁免的依据）；RecentN 是逐 workflow 的状态珠窗（rail 珠串），
// 像 page limit 一样钳制。
const (
	StatsMaxWorkflowIDs = 50
	StatsDefaultRecentN = 10
	StatsMaxRecentN     = 20
	// StatsDefaultWindow is the default `since` window unifying successRate / avgElapsedMs /
	// completedSince / failedSince (7d — the scheduler spec's single statistics-window law).
	// StatsDefaultWindow 是统一 successRate/avgElapsedMs/completedSince/failedSince 的默认
	// `since` 窗口（7d——scheduler 规范的统计窗口立法）。
	StatsDefaultWindow = 7 * 24 * time.Hour
)

// StatsQuery is the batch request. WorkflowIDs are deduplicated preserving order (≤ 50 after
// dedup, else ErrStatsTooManyIDs); RecentN ≤ 0 takes the default and > max clamps; a zero Since
// takes now-StatsDefaultWindow. Defaults are applied by the app service, not the store.
//
// StatsQuery 是批查请求。WorkflowIDs 保序去重（去重后 ≤50，否则 ErrStatsTooManyIDs）；RecentN ≤0
// 取默认、>上限钳制；Since 零值取 now-StatsDefaultWindow。默认由 app service 应用、非 store。
type StatsQuery struct {
	WorkflowIDs []string
	RecentN     int
	Since       time.Time
}

// StatsTotals is the workspace-wide aggregate — deliberately NOT limited to the requested
// WorkflowIDs (the Overview KPI cards count the whole workspace). completedSince/failedSince
// window on completed_at (when the run REACHED its terminal, not when it started — a long run
// failing now is a fresh failure). ParkedRuns counts RUNS awaiting a human: distinct runs that
// are still running and hold ≥1 parked node (a run parked on several approvals counts once; a
// parked row orphaned on an already-terminal run is not actionable and is excluded). The wire
// key stays `parkedNodes` per the ticket's fixed shape.
//
// StatsTotals 是全 workspace 聚合——刻意**不限**请求的 WorkflowIDs（Overview KPI 牌数整个
// workspace）。completedSince/failedSince 按 completed_at 开窗（run **落定**的时刻、非起跑——
// 跑了很久现在才失败的是新鲜失败）。ParkedRuns 数**等人处理的 run 数**：仍 running 且持 ≥1
// parked 节点的 run（一个 run park 在多个审批上只计 1；遗留在已终态 run 上的 parked 行不可
// 决策、不计）。线缆键按工单定形仍叫 `parkedNodes`。
type StatsTotals struct {
	Running        int `json:"running"`
	CompletedSince int `json:"completedSince"`
	FailedSince    int `json:"failedSince"`
	ParkedRuns     int `json:"parkedNodes"`
}

// WorkflowStats is one requested workflow's health row. Every requested id gets a row, in request
// order — an id with no runs (never ran / unknown / soft-deleted host) returns a ZERO row, never
// an absence: the endpoint is a pure flowruns projection and does not check workflow existence
// (orphan runs are first-class in the scheduler ocean; the client zips request→response 1:1).
//
// THE ONE LAW FOR cancelled, applied identically by every field below: cancelled is a NEUTRAL
// disposition — the "not executed" bucket, not an error and not an achievement. A hand-stopped or
// replace-superseded run says NOTHING about the workflow's health, so it joins NEITHER side
// anywhere: it never counts as a failure, and it never counts as proof of health. Operationally it
// behaves exactly like running (undecided): TRANSPARENT. Anything else is a lie the user pays for
// twice — count it as failure and a deliberate ⏹ reads as a fault; count it as health and one ⏹
// erases a real 3-run outage from the failing top-list, while `replace`-policy workflows (whose
// every superseded run is auto-cancelled) pin their streak at ~1 forever with zero user action.
//
//   - ParkedRuns: the workflow's runs awaiting a human — same semantics as the totals bucket
//     (distinct still-running runs holding ≥1 parked node) sliced per workflow; the rail's amber
//     dot reads it. Wire key `parkedNodes`, same as totals.
//   - Recent: the last RecentN runs' statuses, newest→oldest, ALL statuses including running —
//     the honest bead strip. [] when never ran.
//   - SuccessRate: completed / (completed+failed) over terminal runs whose completed_at ≥ since;
//     cancelled joins neither side (the law). nil (key absent) when the window has no
//     completed/failed run — "no data" must stay distinguishable from "0% (all failed)".
//   - AvgElapsedMs: mean completed_at−started_at over the window's COMPLETED, NEVER-REPLAYED runs.
//     Two exclusions, one reason — elapsed must answer "how long does this take", and a header's
//     completed_at−started_at only does when the run went start→finish once: a failed run's elapsed
//     is time-to-failure, and a REPLAYED run's spans the human's fix window (started_at is the
//     ORIGINAL start and :replay never moves it — it is the ordering key of every run list, matrix
//     column and streak walk, so moving it would rewrite history), making a 30-second run replayed
//     three days later report 3 days. nil when the window has no such run — honest absence over an
//     invented number, exactly like SuccessRate. KNOWN AND DELIBERATE: approval wait IS included
//     (an approval workflow's wall-clock genuinely is the human's; subtracting the parked segment
//     needs the 工单⑤ activity join, out of this bounded batch's reach) — this is wall-clock
//     trigger→done, and api.md says so.
//   - ConsecutiveFailures: walking the run sequence (started_at DESC, id DESC — the same order
//     every run list renders) newest→oldest, the count of consecutive failed runs. Only completed
//     stops the walk — that is what self-heal means: the workflow demonstrably worked. running and
//     cancelled are both SKIPPED, neither counting nor breaking (running is undecided — a streak
//     must not blink off while a fix attempt or a parked approval is in flight; cancelled is the
//     law above). Not bounded by RecentN or since: a streak is a streak however long ago it started.
//
// WorkflowStats 是一个请求 workflow 的健康行。每个请求 id 恒有一行、按请求顺序——无 run 的 id
// （从未跑/不存在/宿主已软删）返**零值行**、绝不缺席：端点是纯 flowruns 投影、不校验 workflow
// 存在性（孤儿 run 在 scheduler 海洋是一等公民；客户端请求↔响应 1:1 对拉）。
//
// **cancelled 的唯一立法**，下列每个字段逐字同款执行：cancelled 是**中性处置**——「未执行」桶，
// 既不是错误也不是功劳。被手动停掉 / 被 replace 顶替的 run 对该 workflow 的健康**什么都没说**，故它
// 在任何地方都**两边都不算**：永不算失败，也永不算健康的证据。它在运行上与 running 完全同待遇
// （未定局）：**透明**。别的写法都是让用户付两次账的谎——算失败，则用户主动按的 ⏹ 读成故障；算健康，
// 则一次 ⏹ 就把正在进行的 3 次故障整个从失败榜抹掉，而用 `replace` 策略的 workflow（每个被顶替的 run
// 都被**自动**取消）连败会**永久钉在 ~1**、零用户动作。
//
//   - ParkedRuns：该 workflow 等人处理的 run 数——语义与 totals 的桶完全一致（仍 running 且持
//     ≥1 parked 节点的 DISTINCT run）、按 workflow 分桶；rail 琥珀点读它。线缆键同 totals 叫
//     `parkedNodes`。
//   - Recent：最近 RecentN 个 run 的状态、新→旧，**含 running** 的全状态——诚实珠串。从未跑 []。
//   - SuccessRate：completed/(completed+failed)，取 completed_at ≥ since 的终态 run；cancelled
//     两边都不算（见立法）。窗口内无 completed/failed 时 nil（键缺席）——「无数据」必须与
//     「0%（全败）」可区分。
//   - AvgElapsedMs：窗口内 **completed 且从未 replay** 的 run 的平均 completed_at−started_at。两条
//     排除、同一个理由——耗时要答的是「这要跑多久」，而头上的 completed_at−started_at 只在「一次跑
//     完」时才答得上：失败 run 的耗时是「多久才死」；**被 replay 的** run 的耗时跨着人类的修复窗口
//     （started_at 是**最初**起点、:replay 绝不移动它——它是所有 run 列表 / 矩阵列 / 连败游走的排序键，
//     移它就是改写历史），于是一个 30 秒的 run 三天后 replay 成功会报**三天**。窗口内无此类 run 时
//     nil——诚实缺席胜过编造数字，与 SuccessRate 同立场。**已知且刻意**：审批等待**计入**（审批
//     workflow 的墙钟时间本来就是人的时间；要扣掉 parked 段须 join 工单⑤ activity，超出本有界批查的
//     射程）——这就是「触发→完成」的墙钟，api.md 已明说。
//   - ConsecutiveFailures：按 run 序列（started_at DESC, id DESC——与所有 run 列表同一顺序）
//     从最新往回数的连续 failed 数。**只有 completed 停**——自愈的意思就是它**证明**跑通了。running
//     与 cancelled **都跳过**、既不计数也不断串（running 是未定局——连败徽章不能因新 run 起跑/park
//     在审批上就闪灭；cancelled 见上方立法）。不受 RecentN 与 since 约束：连败多久以前开始都是连败。
type WorkflowStats struct {
	WorkflowID          string     `json:"workflowId"`
	Running             int        `json:"running"`
	ParkedRuns          int        `json:"parkedNodes"`
	LastRunAt           *time.Time `json:"lastRunAt,omitempty"`
	Recent              []string   `json:"recent"`
	SuccessRate         *float64   `json:"successRate,omitempty"`
	AvgElapsedMs        *int64     `json:"avgElapsedMs,omitempty"`
	ConsecutiveFailures int        `json:"consecutiveFailures"`
}

// RunStats is the endpoint's data payload: {totals, byWorkflow}.
//
// RunStats 是端点的 data 载荷：{totals, byWorkflow}。
type RunStats struct {
	Totals     StatsTotals      `json:"totals"`
	ByWorkflow []*WorkflowStats `json:"byWorkflow"`
}

var (
	// ErrStatsTooManyIDs: the batch asked for more than StatsMaxWorkflowIDs workflows (after
	// dedup) — rejected loudly with the allowed cap in Details, never silently truncated.
	// ErrStatsTooManyIDs：批查（去重后）超过 StatsMaxWorkflowIDs 个 workflow——带 allowed 上限
	// 大声拒，绝不静默截断。
	ErrStatsTooManyIDs = errorspkg.New(errorspkg.KindUnprocessable, "FLOWRUN_STATS_TOO_MANY_IDS", "flowrun-stats accepts at most 50 workflowIds per request")

	// ErrStatsInvalidSince: the since parameter parsed as neither an RFC3339 timestamp nor a
	// positive look-back duration (Go duration or <n>d days form).
	// ErrStatsInvalidSince：since 参数既不是 RFC3339 时间戳、也不是正的回看时长（Go duration
	// 或 <n>d 天数形）。
	ErrStatsInvalidSince = errorspkg.New(errorspkg.KindUnprocessable, "FLOWRUN_STATS_INVALID_SINCE", "since must be an RFC3339 timestamp or a look-back duration like 24h or 7d")
)
