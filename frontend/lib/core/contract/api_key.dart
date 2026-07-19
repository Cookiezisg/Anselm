import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_key.freezed.dart';
part 'api_key.g.dart';

/// An API credential row — mirrors backend `apikey.APIKey` (the encrypted key itself never travels;
/// [keyMasked] is the display form). [testStatus] ∈ pending|ok|error (open set kept as String — the
/// probe vocabulary may grow). NOTE the row carries NO `managed` flag: managed-ness is provider-level
/// metadata — join [ProviderMeta.managed] (设置面按 provider 目录判受管,行上没有).
///
/// API 凭证行——镜像后端 apikey.APIKey(密文永不下发,keyMasked 是展示形)。testStatus∈pending|ok|error
/// (保持开放 String)。行上**没有 managed 字段**:受管性是 provider 级元数据,须 join ProviderMeta.managed。
@freezed
abstract class ApiKey with _$ApiKey {
  const factory ApiKey({
    required String id,
    required String provider,
    required String displayName,
    @Default('') String keyMasked,
    @Default('') String baseUrl,
    @Default('') String apiFormat,
    @Default('pending') String testStatus,
    @Default('') String testError,
    DateTime? lastTestedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ApiKey;

  factory ApiKey.fromJson(Map<String, dynamic> json) => _$ApiKeyFromJson(json);
}

/// One provider-catalog entry — `GET /providers` (static backend catalog; `mock` only under dev).
/// provider 目录一项——GET /providers(后端静态目录;mock 仅 dev 下发)。
@freezed
abstract class ProviderMeta with _$ProviderMeta {
  const factory ProviderMeta({
    required String name,
    required String displayName,
    @Default('') String defaultBaseUrl,
    @Default(false) bool baseUrlRequired,
    @Default(false) bool managed,
    @Default('llm') String category, // llm | search
  }) = _ProviderMeta;

  factory ProviderMeta.fromJson(Map<String, dynamic> json) => _$ProviderMetaFromJson(json);
}

/// The free-tier month quota — `GET /freetier/quota` (backend proxies the gateway; 404
/// FREETIER_NOT_PROVISIONED maps to null at the repository seam). [available] folds the gateway's
/// global day budget, so it can be false while [remaining] > 0.
/// 免费档本月配额——后端代理网关;404 在数据缝映射为 null。available 折网关全局日预算,remaining>0 仍可能 false。
@freezed
abstract class FreetierQuota with _$FreetierQuota {
  const factory FreetierQuota({
    required int limit,
    required int used,
    required int remaining,
    @Default('') String resetAt,
    @Default(true) bool available,
  }) = _FreetierQuota;

  factory FreetierQuota.fromJson(Map<String, dynamic> json) => _$FreetierQuotaFromJson(json);
}
