// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'limits.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LimitField _$LimitFieldFromJson(Map<String, dynamic> json) => _LimitField(
  key: json['key'] as String,
  group: json['group'] as String? ?? '',
  defaultValue: (json['default'] as num?)?.toDouble() ?? 0,
  min: (json['min'] as num?)?.toDouble() ?? 0,
  max: (json['max'] as num?)?.toDouble() ?? 0,
  exclusive: json['exclusive'] as bool? ?? false,
  unit: json['unit'] as String? ?? '',
  desc: json['desc'] as String? ?? '',
);

Map<String, dynamic> _$LimitFieldToJson(_LimitField instance) =>
    <String, dynamic>{
      'key': instance.key,
      'group': instance.group,
      'default': instance.defaultValue,
      'min': instance.min,
      'max': instance.max,
      'exclusive': instance.exclusive,
      'unit': instance.unit,
      'desc': instance.desc,
    };
