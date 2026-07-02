import 'package:freezed_annotation/freezed_annotation.dart';

part 'model_capability.freezed.dart';
part 'model_capability.g.dart';

/// One runnable model option — a row of `GET /model-capabilities` (the backend aggregates every probed
/// api key × the models it serves). Exactly the {apiKeyId, modelId} pair a per-thread override PATCH
/// needs, plus display labels; capability details (context window, vision…) ride the same row and are
/// added here when a surface needs them.
///
/// 一个可跑的模型选项——`GET /model-capabilities` 的一行(后端聚合:每个已探测 key × 它服务的模型)。恰好是
/// 线程级覆写 PATCH 需要的 {apiKeyId, modelId} 对 + 展示标签;能力细节(上下文窗/视觉…)同行携带,表面需要时再加。
@freezed
abstract class ModelCapability with _$ModelCapability {
  const factory ModelCapability({
    required String apiKeyId,
    @Default('') String keyName,
    @Default('') String provider,
    required String modelId,
    @Default('') String displayName,
  }) = _ModelCapability;

  factory ModelCapability.fromJson(Map<String, dynamic> json) => _$ModelCapabilityFromJson(json);
}
