// Operational run statistics (scheduler 工单③ + ⑭) — a READ-ONLY projection (no new table, no new
// column). One bounded batch answers the scheduler ocean's rail + Overview in a single round trip:
// workspace-wide totals plus a per-workflow health row for at most StatsMaxWorkflowIDs requested
// workflows (the rail feeds its current page of ids).
//
// This is the Overview's STATISTICS SINGLE SOURCE, not a projection of the flowrun tables alone —
// every KPI card reads it, and Totals.Missed (工单⑭) is counted off trigger_firings, stitched in by
// the app service through the scheduler's FiringInbox port (the domain owns the SHAPE; it does not
// reach a store). That one field is the reason this file no longer claims to be a pure two-table
// projection: the Overview asks one question — "how is my automation doing in this window" — and a
// tick that never became a run is part of the answer, so putting it behind a second endpoint would
// buy domain tidiness with a second `since` for the client to keep in sync and a fifth card that
// could disagree with the other four.
//
// 运营统计（scheduler 工单③ + ⑭）——**只读**投影（零新表零新列）。一次有界批查喂饱 scheduler 海洋的
// rail + Overview：全 workspace 聚合 + 至多 StatsMaxWorkflowIDs 个请求 workflow 的健康行（rail 逐页
// 喂当页 ids）。
//
// 它是 Overview 的**统计单源**、而非「仅 flowrun 两表的投影」——每张 KPI 牌都读它，而 Totals.Missed
// （工单⑭）数的是 trigger_firings，由 app 服务经 scheduler 的 FiringInbox 端口缝进来（domain 只拥有
// **形状**、它并不伸手去够 store）。就是这一个字段让本文件不再自称「纯两表投影」：Overview 问的是**一个**
// 问题——「我的自动化在这个窗口里过得怎么样」——而一个**从未成为 run** 的刻度正是答案的一部分；把它挪去
// 第二个端点，买到的是 domain 的整洁，付出的是客户端要自己同步的第二个 `since`、和一张可能与另外四张
// 互相矛盾的第五张牌。
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
// Until is the OPTIONAL exclusive end of the windowed stats, pairing with Since as the half-open
// window [Since, Until). A zero Until is UNBOUNDED (today's behavior — the window runs to now and
// beyond), never defaulted: an end-of-window look-back duration is ambiguous, so unlike Since the
// handler accepts an RFC3339 timestamp for it ALONE. It bounds exactly what Since bounds
// (completedSince/failedSince, per-workflow successRate/avgElapsedMs, and totals.missed via the
// firing count's CreatedBefore) and nothing else. An inverted window (Until ≤ Since) is not an
// error — it silently yields empty windowed results, the same stance as GET /flowruns startedBefore.
//
// StatsQuery 是批查请求。WorkflowIDs 保序去重（去重后 ≤50，否则 ErrStatsTooManyIDs）；RecentN ≤0
// 取默认、>上限钳制；Since 零值取 now-StatsDefaultWindow。默认由 app service 应用、非 store。
//
// Until 是窗口统计的**可选**不含上界，与 Since 配成半开窗 [Since, Until)。零值 Until = **不设界**
// （今日行为——窗口一直延到 now 及之后），**绝不默认**：末端的回看时长有歧义，故与 Since 不同、handler
// **只**收 RFC3339 时间戳。它界的恰是 Since 所界的那些（completedSince/failedSince、逐 workflow 的
// successRate/avgElapsedMs、以及经 firing 计数的 CreatedBefore 缝入的 totals.missed），别的都不动。
// 倒挂窗（Until ≤ Since）不是错误——静默给出空窗结果，与 GET /flowruns startedBefore 同立场。
type StatsQuery struct {
	WorkflowIDs []string
	RecentN     int
	Since       time.Time
	Until       time.Time
}

// StatsTotals is the workspace-wide aggregate — deliberately NOT limited to the requested
// WorkflowIDs (the Overview KPI cards count the whole workspace). completedSince/failedSince
// window on completed_at (when the run REACHED its terminal, not when it started — a long run
// failing now is a fresh failure). ParkedRuns counts RUNS awaiting a human: distinct runs that
// are still running and hold ≥1 parked node (a run parked on several approvals counts once; a
// parked row orphaned on an already-terminal run is not actionable and is excluded). The wire
// key stays `parkedNodes` per the ticket's fixed shape.
//
// Missed (工单⑭) counts `missed` trigger_firings created within the window — cron ticks that came
// due while the app was asleep and were booked, never re-run (判决⑥). It is the ONE total that is
// not a flowrun: it counts runs that should exist and don't. Three properties make it honest:
//   - WINDOWED on the same Since as completedSince/failedSince. An all-time missed count only ever
//     grows and says nothing about today — a vanity number, and the spec forbids those. Since is
//     defaulted once in the app service, so the fifth card cannot drift from the other four.
//   - Windowed on created_at, which for a missed row IS the scheduled tick (AppendMissedFiring
//     backdates it, 工单⑨) — not the sweep instant. That is what makes "missed in the last 24h"
//     mean the ticks of those 24h; a night-long outage spreads across the night instead of piling
//     onto the second the machine woke up.
//   - Counted with the SAME filter the /firings list takes, so the card and the list its click
//     opens are the same predicates and cannot disagree.
//
// StatsTotals 是全 workspace 聚合——刻意**不限**请求的 WorkflowIDs（Overview KPI 牌数整个
// workspace）。completedSince/failedSince 按 completed_at 开窗（run **落定**的时刻、非起跑——
// 跑了很久现在才失败的是新鲜失败）。ParkedRuns 数**等人处理的 run 数**：仍 running 且持 ≥1
// parked 节点的 run（一个 run park 在多个审批上只计 1；遗留在已终态 run 上的 parked 行不可
// 决策、不计）。线缆键按工单定形仍叫 `parkedNodes`。
//
// Missed（工单⑭）数窗口内创建的 `missed` trigger_firings——app 睡着时到期、被记账且**绝不补跑**的
// cron 刻度（判决⑥）。它是唯一一个**不是 flowrun** 的 total：它数的是**本该存在却不存在**的 run。
// 三条性质让它诚实：
//   - 与 completedSince/failedSince **同一个 Since** 开窗。all-time 的 missed 只会一直涨、对今天什么
//     都没说——那是虚荣数字，规范明令禁止。Since 在 app 服务里只默认一次，故第五张牌不可能与另外四张漂移。
//   - 按 created_at 开窗，而 missed 行的 created_at **就是**那个调度刻度（AppendMissedFiring 回拨盖戳，
//     工单⑨）、不是 sweep 时刻。正是它让「近 24h 错过 N」的意思是**那 24h 的刻度**；整夜停机会摊在整夜里，
//     而不是全堆在机器醒来的那一秒。
//   - 用**与 /firings 列表完全相同**的 filter 计数，故这张牌与它点开的那个列表是同一组谓词、不可能互相矛盾。
type StatsTotals struct {
	Running        int `json:"running"`
	CompletedSince int `json:"completedSince"`
	FailedSince    int `json:"failedSince"`
	ParkedRuns     int `json:"parkedNodes"`
	Missed         int `json:"missed"`
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

	// ErrStatsInvalidUntil: the until parameter did not parse as an RFC3339 timestamp. Unlike since
	// it is an ABSOLUTE end bound ONLY — an end-of-window look-back duration is ambiguous, so the
	// duration grammar is deliberately NOT accepted here (parsed by parseListTime, the same RFC3339
	// window-bound implementation the flowruns list uses).
	// ErrStatsInvalidUntil：until 参数没解析成 RFC3339 时间戳。与 since 不同，它**只**是绝对上界——
	// 末端的回看时长有歧义，故这里刻意**不**收时长文法（用 parseListTime 解析，即 flowruns 列表所用的
	// 同一份 RFC3339 窗口界实现）。
	ErrStatsInvalidUntil = errorspkg.New(errorspkg.KindUnprocessable, "FLOWRUN_STATS_INVALID_UNTIL", "until must be an RFC3339 timestamp")
)
