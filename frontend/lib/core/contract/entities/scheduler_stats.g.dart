// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduler_stats.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SchedulerTotals _$SchedulerTotalsFromJson(Map<String, dynamic> json) =>
    _SchedulerTotals(
      running: (json['running'] as num?)?.toInt() ?? 0,
      completedSince: (json['completedSince'] as num?)?.toInt() ?? 0,
      failedSince: (json['failedSince'] as num?)?.toInt() ?? 0,
      parkedNodes: (json['parkedNodes'] as num?)?.toInt() ?? 0,
      missed: (json['missed'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$SchedulerTotalsToJson(_SchedulerTotals instance) =>
    <String, dynamic>{
      'running': instance.running,
      'completedSince': instance.completedSince,
      'failedSince': instance.failedSince,
      'parkedNodes': instance.parkedNodes,
      'missed': instance.missed,
    };

_WorkflowRunStats _$WorkflowRunStatsFromJson(Map<String, dynamic> json) =>
    _WorkflowRunStats(
      workflowId: json['workflowId'] as String,
      running: (json['running'] as num?)?.toInt() ?? 0,
      lastRunAt: json['lastRunAt'] == null
          ? null
          : DateTime.parse(json['lastRunAt'] as String),
      recent:
          (json['recent'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      successRate: (json['successRate'] as num?)?.toDouble(),
      avgElapsedMs: (json['avgElapsedMs'] as num?)?.toInt(),
      consecutiveFailures: (json['consecutiveFailures'] as num?)?.toInt() ?? 0,
      parkedNodes: (json['parkedNodes'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$WorkflowRunStatsToJson(_WorkflowRunStats instance) =>
    <String, dynamic>{
      'workflowId': instance.workflowId,
      'running': instance.running,
      'lastRunAt': instance.lastRunAt?.toIso8601String(),
      'recent': instance.recent,
      'successRate': instance.successRate,
      'avgElapsedMs': instance.avgElapsedMs,
      'consecutiveFailures': instance.consecutiveFailures,
      'parkedNodes': instance.parkedNodes,
    };

_SchedulerStats _$SchedulerStatsFromJson(Map<String, dynamic> json) =>
    _SchedulerStats(
      totals: json['totals'] == null
          ? const SchedulerTotals()
          : SchedulerTotals.fromJson(json['totals'] as Map<String, dynamic>),
      byWorkflow:
          (json['byWorkflow'] as List<dynamic>?)
              ?.map((e) => WorkflowRunStats.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <WorkflowRunStats>[],
    );

Map<String, dynamic> _$SchedulerStatsToJson(_SchedulerStats instance) =>
    <String, dynamic>{
      'totals': instance.totals.toJson(),
      'byWorkflow': instance.byWorkflow.map((e) => e.toJson()).toList(),
    };
