// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trigger_schedule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SchedulePoint _$SchedulePointFromJson(Map<String, dynamic> json) =>
    _SchedulePoint(
      at: DateTime.parse(json['at'] as String),
      triggerId: json['triggerId'] as String? ?? '',
      triggerName: json['triggerName'] as String? ?? '',
      workflowIds:
          (json['workflowIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$SchedulePointToJson(_SchedulePoint instance) =>
    <String, dynamic>{
      'at': instance.at.toIso8601String(),
      'triggerId': instance.triggerId,
      'triggerName': instance.triggerName,
      'workflowIds': instance.workflowIds,
    };

_TriggerSchedule _$TriggerScheduleFromJson(Map<String, dynamic> json) =>
    _TriggerSchedule(
      points:
          (json['points'] as List<dynamic>?)
              ?.map((e) => SchedulePoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <SchedulePoint>[],
      truncated: json['truncated'] as bool? ?? false,
    );

Map<String, dynamic> _$TriggerScheduleToJson(_TriggerSchedule instance) =>
    <String, dynamic>{
      'points': instance.points.map((e) => e.toJson()).toList(),
      'truncated': instance.truncated,
    };
