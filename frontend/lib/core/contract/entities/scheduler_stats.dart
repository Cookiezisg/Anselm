import 'package:freezed_annotation/freezed_annotation.dart';

part 'scheduler_stats.freezed.dart';
part 'scheduler_stats.g.dart';

// GET /flowrun-stats (WRK-069 工单③) — the Scheduler's batched operations statistics: workspace-wide
// totals + per-workflow health for ≤50 requested ids. Read-only projection over flowruns/flowrun_nodes;
// bounded batch query (N4-exempt). `recent` is newest→oldest raw run statuses; `consecutiveFailures`
// counts failed runs from the newest backwards (the failure-aggregation「连败+自愈」semantics' data
// source). 批量运营统计:全 workspace totals + 逐 workflow 健康;recent 新→旧;连败数从最新往回数。

/// Workspace-wide counters (NOT limited to the requested ids). 全 workspace 计数。
@freezed
abstract class SchedulerTotals with _$SchedulerTotals {
  const factory SchedulerTotals({
    @Default(0) int running,
    @Default(0) int completedSince,
    @Default(0) int failedSince,
    @Default(0) int parkedNodes,
  }) = _SchedulerTotals;
  factory SchedulerTotals.fromJson(Map<String, dynamic> json) => _$SchedulerTotalsFromJson(json);
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
  factory WorkflowRunStats.fromJson(Map<String, dynamic> json) => _$WorkflowRunStatsFromJson(json);
}

/// The whole stats envelope. byWorkflow 只含请求的 ids。
@freezed
abstract class SchedulerStats with _$SchedulerStats {
  const factory SchedulerStats({
    @Default(SchedulerTotals()) SchedulerTotals totals,
    @Default(<WorkflowRunStats>[]) List<WorkflowRunStats> byWorkflow,
  }) = _SchedulerStats;
  factory SchedulerStats.fromJson(Map<String, dynamic> json) => _$SchedulerStatsFromJson(json);
}
