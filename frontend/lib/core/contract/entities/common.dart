import 'package:freezed_annotation/freezed_annotation.dart';

part 'common.freezed.dart';
part 'common.g.dart';

/// Cross-entity log aggregates (the ok/failed tallies shown atop the 日志 tab; carried in the
/// PageWithAggregate envelope alongside the log page). execution.go。日志页聚合计数。
@freezed
abstract class ExecutionAggregates with _$ExecutionAggregates {
  const factory ExecutionAggregates({
    @Default(0) int okCount,
    @Default(0) int failedCount,
  }) = _ExecutionAggregates;
  factory ExecutionAggregates.fromJson(Map<String, dynamic> json) =>
      _$ExecutionAggregatesFromJson(json);
}

/// The capability/structural-validity report (shared by fn/hd/ag/wf preflight — "is this entity runnable?").
/// `problems` block execution, `warnings` don't. capability.go。结构可运行性报告。
@freezed
abstract class CapabilityReport with _$CapabilityReport {
  const factory CapabilityReport({
    @Default(false) bool structurallyValid,
    @Default(false) bool resolved,
    @Default(<String>[]) List<String> problems,
    @Default(<String>[]) List<String> warnings,
  }) = _CapabilityReport;
  factory CapabilityReport.fromJson(Map<String, dynamic> json) =>
      _$CapabilityReportFromJson(json);
}
