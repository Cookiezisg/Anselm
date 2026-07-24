// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_capability.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ModelKnob _$ModelKnobFromJson(Map<String, dynamic> json) => _ModelKnob(
  key: json['key'] as String,
  label: json['label'] as String? ?? '',
  type: json['type'] as String? ?? '',
  values:
      (json['values'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  defaultValue: json['default'] as String? ?? '',
);

Map<String, dynamic> _$ModelKnobToJson(_ModelKnob instance) =>
    <String, dynamic>{
      'key': instance.key,
      'label': instance.label,
      'type': instance.type,
      'values': instance.values,
      'default': instance.defaultValue,
    };

_ModelCapability _$ModelCapabilityFromJson(Map<String, dynamic> json) =>
    _ModelCapability(
      apiKeyId: json['apiKeyId'] as String,
      keyName: json['keyName'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      modelId: json['modelId'] as String,
      displayName: json['displayName'] as String? ?? '',
      contextWindow: (json['contextWindow'] as num?)?.toInt() ?? 0,
      maxOutput: (json['maxOutput'] as num?)?.toInt() ?? 0,
      textInputLimit: (json['textInputLimit'] as num?)?.toInt() ?? 0,
      multimodalInputLimit:
          (json['multimodalInputLimit'] as num?)?.toInt() ?? 0,
      vision: json['vision'] as bool? ?? false,
      video: json['video'] as bool? ?? false,
      audio: json['audio'] as bool? ?? false,
      nativeDocs: json['nativeDocs'] as bool? ?? false,
      maxMediaParts: (json['maxMediaParts'] as num?)?.toInt() ?? 0,
      maxMediaBytes: (json['maxMediaBytes'] as num?)?.toInt() ?? 0,
      knobs:
          (json['knobs'] as List<dynamic>?)
              ?.map((e) => ModelKnob.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ModelKnob>[],
    );

Map<String, dynamic> _$ModelCapabilityToJson(_ModelCapability instance) =>
    <String, dynamic>{
      'apiKeyId': instance.apiKeyId,
      'keyName': instance.keyName,
      'provider': instance.provider,
      'modelId': instance.modelId,
      'displayName': instance.displayName,
      'contextWindow': instance.contextWindow,
      'maxOutput': instance.maxOutput,
      'textInputLimit': instance.textInputLimit,
      'multimodalInputLimit': instance.multimodalInputLimit,
      'vision': instance.vision,
      'video': instance.video,
      'audio': instance.audio,
      'nativeDocs': instance.nativeDocs,
      'maxMediaParts': instance.maxMediaParts,
      'maxMediaBytes': instance.maxMediaBytes,
      'knobs': instance.knobs.map((e) => e.toJson()).toList(),
    };
