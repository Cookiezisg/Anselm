import 'package:freezed_annotation/freezed_annotation.dart';

part 'model_capability.freezed.dart';
part 'model_capability.g.dart';

/// One configurable parameter as a render-ready descriptor (backend `llm.Knob`): a uniform container
/// whose content is entirely native — [key] and [values] are the provider's own wire vocabulary,
/// never translated or normalised. The frontend renders generically from [type]
/// (`enum` → dropdown / `int` → number field / `bool` → switch), prefilled with [defaultValue].
///
/// 一个可配置参数的可渲染描述符(后端 llm.Knob):统一容器,内容全原生——key/取值是各家自己的 wire
/// 词表,绝不翻译归一。前端按 [type] 通用渲染(enum 下拉/int 数字/bool 开关),以 [defaultValue] 预填。
@freezed
abstract class ModelKnob with _$ModelKnob {
  const factory ModelKnob({
    required String key,
    @Default('') String label,
    @Default('') String type,
    @Default(<String>[]) List<String> values,
    @JsonKey(name: 'default') @Default('') String defaultValue,
  }) = _ModelKnob;

  factory ModelKnob.fromJson(Map<String, dynamic> json) => _$ModelKnobFromJson(json);
}

/// One runnable model option — a row of `GET /model-capabilities` (the backend aggregates every probed
/// api key × the models it serves; mirrors `model.CapabilityView`). Exactly the {apiKeyId, modelId}
/// pair a default/override PUT needs, plus display labels, capability specs (context window / max
/// output / vision / native docs) and the native [knobs] the three-stage model picker renders.
///
/// 一个可跑的模型选项——`GET /model-capabilities` 的一行(后端聚合:每个已探测 key × 它服务的模型;
/// 镜像 model.CapabilityView)。恰好是默认/覆写 PUT 需要的 {apiKeyId, modelId} 对 + 展示标签 + 能力
/// 规格(上下文窗/最大输出/视觉/原生文档)+ 三段选择面板渲染的原生 [knobs]。
@freezed
abstract class ModelCapability with _$ModelCapability {
  const factory ModelCapability({
    required String apiKeyId,
    @Default('') String keyName,
    @Default('') String provider,
    required String modelId,
    @Default('') String displayName,
    @Default(0) int contextWindow,
    @Default(0) int maxOutput,
    @Default(false) bool vision,
    @Default(false) bool nativeDocs,
    @Default(<ModelKnob>[]) List<ModelKnob> knobs,
  }) = _ModelCapability;

  factory ModelCapability.fromJson(Map<String, dynamic> json) => _$ModelCapabilityFromJson(json);
}
