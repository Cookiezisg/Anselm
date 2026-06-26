// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'common.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ExecutionAggregates _$ExecutionAggregatesFromJson(Map<String, dynamic> json) =>
    _ExecutionAggregates(
      okCount: (json['okCount'] as num?)?.toInt() ?? 0,
      failedCount: (json['failedCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$ExecutionAggregatesToJson(
  _ExecutionAggregates instance,
) => <String, dynamic>{
  'okCount': instance.okCount,
  'failedCount': instance.failedCount,
};

_CapabilityReport _$CapabilityReportFromJson(
  Map<String, dynamic> json,
) => _CapabilityReport(
  structurallyValid: json['structurallyValid'] as bool? ?? false,
  resolved: json['resolved'] as bool? ?? false,
  problems:
      (json['problems'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  warnings:
      (json['warnings'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
);

Map<String, dynamic> _$CapabilityReportToJson(_CapabilityReport instance) =>
    <String, dynamic>{
      'structurallyValid': instance.structurallyValid,
      'resolved': instance.resolved,
      'problems': instance.problems,
      'warnings': instance.warnings,
    };
