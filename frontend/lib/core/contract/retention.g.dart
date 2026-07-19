// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'retention.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RetentionConfig _$RetentionConfigFromJson(Map<String, dynamic> json) =>
    _RetentionConfig(
      runRetentionDays: (json['runRetentionDays'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$RetentionConfigToJson(_RetentionConfig instance) =>
    <String, dynamic>{'runRetentionDays': instance.runRetentionDays};
