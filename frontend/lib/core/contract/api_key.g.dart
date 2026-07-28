// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_key.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ApiKey _$ApiKeyFromJson(Map<String, dynamic> json) => _ApiKey(
  id: json['id'] as String,
  provider: json['provider'] as String,
  displayName: json['displayName'] as String,
  keyMasked: json['keyMasked'] as String? ?? '',
  baseUrl: json['baseUrl'] as String? ?? '',
  apiFormat: json['apiFormat'] as String? ?? '',
  testStatus: json['testStatus'] as String? ?? 'pending',
  testError: json['testError'] as String? ?? '',
  lastTestedAt: json['lastTestedAt'] == null
      ? null
      : DateTime.parse(json['lastTestedAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$ApiKeyToJson(_ApiKey instance) => <String, dynamic>{
  'id': instance.id,
  'provider': instance.provider,
  'displayName': instance.displayName,
  'keyMasked': instance.keyMasked,
  'baseUrl': instance.baseUrl,
  'apiFormat': instance.apiFormat,
  'testStatus': instance.testStatus,
  'testError': instance.testError,
  'lastTestedAt': instance.lastTestedAt?.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

_ProviderMeta _$ProviderMetaFromJson(Map<String, dynamic> json) =>
    _ProviderMeta(
      name: json['name'] as String,
      displayName: json['displayName'] as String,
      defaultBaseUrl: json['defaultBaseUrl'] as String? ?? '',
      baseUrlRequired: json['baseUrlRequired'] as bool? ?? false,
      managed: json['managed'] as bool? ?? false,
      category: json['category'] as String? ?? 'llm',
      curated: json['curated'] as bool? ?? true,
      dialect: json['dialect'] as String? ?? 'openai-compatible',
      baseUrlHint: json['baseUrlHint'] as String? ?? '',
      credential: json['credential'] as String? ?? 'api_key',
      models: (json['models'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$ProviderMetaToJson(_ProviderMeta instance) =>
    <String, dynamic>{
      'name': instance.name,
      'displayName': instance.displayName,
      'defaultBaseUrl': instance.defaultBaseUrl,
      'baseUrlRequired': instance.baseUrlRequired,
      'managed': instance.managed,
      'category': instance.category,
      'curated': instance.curated,
      'dialect': instance.dialect,
      'baseUrlHint': instance.baseUrlHint,
      'credential': instance.credential,
      'models': instance.models,
    };

_FreetierQuota _$FreetierQuotaFromJson(Map<String, dynamic> json) =>
    _FreetierQuota(
      limit: (json['limit'] as num).toInt(),
      used: (json['used'] as num).toInt(),
      remaining: (json['remaining'] as num).toInt(),
      resetAt: json['resetAt'] as String? ?? '',
      available: json['available'] as bool? ?? true,
    );

Map<String, dynamic> _$FreetierQuotaToJson(_FreetierQuota instance) =>
    <String, dynamic>{
      'limit': instance.limit,
      'used': instance.used,
      'remaining': instance.remaining,
      'resetAt': instance.resetAt,
      'available': instance.available,
    };

_ClonedVoice _$ClonedVoiceFromJson(Map<String, dynamic> json) => _ClonedVoice(
  id: json['id'] as String,
  name: json['name'] as String,
  provider: json['provider'] as String? ?? '',
  upstreamId: json['upstreamId'] as String? ?? '',
  sourceAttachmentId: json['sourceAttachmentId'] as String? ?? '',
  createdAt: json['createdAt'] as String? ?? '',
);

Map<String, dynamic> _$ClonedVoiceToJson(_ClonedVoice instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'provider': instance.provider,
      'upstreamId': instance.upstreamId,
      'sourceAttachmentId': instance.sourceAttachmentId,
      'createdAt': instance.createdAt,
    };

_VoiceInventory _$VoiceInventoryFromJson(Map<String, dynamic> json) =>
    _VoiceInventory(
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => ClonedVoice.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ClonedVoice>[],
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$VoiceInventoryToJson(_VoiceInventory instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'capacity': instance.capacity,
      'remaining': instance.remaining,
    };
