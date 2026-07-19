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
    );

Map<String, dynamic> _$ProviderMetaToJson(_ProviderMeta instance) =>
    <String, dynamic>{
      'name': instance.name,
      'displayName': instance.displayName,
      'defaultBaseUrl': instance.defaultBaseUrl,
      'baseUrlRequired': instance.baseUrlRequired,
      'managed': instance.managed,
      'category': instance.category,
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
