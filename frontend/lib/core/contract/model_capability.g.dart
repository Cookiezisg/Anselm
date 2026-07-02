// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_capability.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ModelCapability _$ModelCapabilityFromJson(Map<String, dynamic> json) =>
    _ModelCapability(
      apiKeyId: json['apiKeyId'] as String,
      keyName: json['keyName'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      modelId: json['modelId'] as String,
      displayName: json['displayName'] as String? ?? '',
    );

Map<String, dynamic> _$ModelCapabilityToJson(_ModelCapability instance) =>
    <String, dynamic>{
      'apiKeyId': instance.apiKeyId,
      'keyName': instance.keyName,
      'provider': instance.provider,
      'modelId': instance.modelId,
      'displayName': instance.displayName,
    };
