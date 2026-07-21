import 'package:freezed_annotation/freezed_annotation.dart';

part 'scheduler_stats.freezed.dart';
part 'scheduler_stats.g.dart';

// GET /flowrun-stats (WRK-069 工单③+⑭) — the Scheduler's batched operations statistics: workspace-wide
// totals + per-workflow health for ≤50 requested ids. Bounded batch query (N4-exempt). `recent` is
// newest→oldest raw run statuses; `consecutiveFailures` counts failed runs from the newest backwards
// (the failure-aggregation「连败+自愈」semantics' data source). It is the Overview's STATISTICS SINGLE
// SOURCE rather than a projection of the flowrun tables alone: `totals.missed` (工单⑭) is counted off
// `trigger_firings`, stitched in by the backend's app layer through the scheduler's FiringInbox port.
// 批量运营统计:全 workspace totals + 逐 workflow 健康;recent 新→旧;连败数从最新往回数。它是 Overview 的
// **统计单源**、而非仅 flowrun 两表的投影:totals.missed 数的是 trigger_firings(工单⑭)。

/// Workspace-wide counters (NOT limited to the requested ids). 全 workspace 计数。
///
/// [missed] (工单⑭/判决⑥) is the ONE total that is not a flowrun — it counts the cron ticks that came
/// due while the app was asleep, were booked and deliberately never caught up, i.e. runs that SHOULD
/// exist and don't. Three properties the client depends on: it is windowed on the SAME `since` as
/// [completedSince]/[failedSince] (the backend defaults `since` once, so the fifth KPI card cannot
/// drift from the other four — an all-time missed count would only grow and is forbidden as a vanity
/// number); it is windowed on the missed firing's `createdAt`, which IS the scheduled tick (the
/// backend rewinds it), not the wake instant; and it is counted with the SAME predicates
/// `GET /firings?status=missed&createdAfter=` takes — so the card and the list its click opens can
/// never disagree.
/// missed(工单⑭/判决⑥)=唯一一个不数 flowrun 的 total:它数的是**本该存在却不存在**的 run。三条性质:
/// 与 completedSince/failedSince **同一个 since**(绝不 all-time——只增的虚荣数字规范禁);按 createdAt
/// 开窗而该戳**就是调度刻度**(后端回拨);与 `GET /firings?status=missed&createdAfter=` **同一组谓词**
/// 计数,故牌与它点开的列表不可能互相矛盾。
@freezed
abstract class SchedulerTotals with _$SchedulerTotals {
  const factory SchedulerTotals({
    @Default(0) int running,
    @Default(0) int completedSince,
    @Default(0) int failedSince,
    @Default(0) int parkedNodes,
    @Default(0) int missed,
  }) = _SchedulerTotals;
  factory SchedulerTotals.fromJson(Map<String, dynamic> json) =>
      _$SchedulerTotalsFromJson(json);
}

/// One workflow's operational health. [recent] carries raw status words (`completed`/`failed`/
/// `cancelled`/`running`, newest first) — fold through AnStatus.fromRaw at the widget layer.
/// [successRate]/[avgElapsedMs] are ABSENT (null) when the window holds no data — «no data» is not
/// «0%», render an em-dash. [consecutiveFailures] skips running runs (undecided) and stops on
/// completed/cancelled, so the streak badge never flickers while a fresh run is in flight.
/// 单 workflow 运营健康;successRate/avgElapsedMs 窗口无数据即缺席(≠0%);连败数跳过 running、
/// 遇 completed/cancelled 停(徽章不因新 run 起跑闪灭)。
@freezed
abstract class WorkflowRunStats with _$WorkflowRunStats {
  const factory WorkflowRunStats({
    required String workflowId,
    @Default(0) int running,
    DateTime? lastRunAt,
    @Default(<String>[]) List<String> recent,
    double? successRate,
    int? avgElapsedMs,
    @Default(0) int consecutiveFailures,
    @Default(0) int parkedNodes,
  }) = _WorkflowRunStats;
  factory WorkflowRunStats.fromJson(Map<String, dynamic> json) =>
      _$WorkflowRunStatsFromJson(json);
}

/// The whole stats envelope. byWorkflow 只含请求的 ids。
@freezed
abstract class SchedulerStats with _$SchedulerStats {
  const factory SchedulerStats({
    @Default(SchedulerTotals()) SchedulerTotals totals,
    @Default(<WorkflowRunStats>[]) List<WorkflowRunStats> byWorkflow,
  }) = _SchedulerStats;
  factory SchedulerStats.fromJson(Map<String, dynamic> json) =>
      _$SchedulerStatsFromJson(json);
}
