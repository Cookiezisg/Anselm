import 'package:freezed_annotation/freezed_annotation.dart';

part 'limits.freezed.dart';
part 'limits.g.dart';

/// One tunable limit's metadata — `GET /limits/schema` rows (WRK-062 ⑩: the panel renders from
/// this, NEVER re-declares Go constants). `key` is a dotted path into the nested limits JSON
/// (`agent.maxSteps`); `max == 0` means unbounded above; `exclusive` marks open bounds
/// (triggerRatio ∈ (0,1)).
///
/// 单个可调限额的元数据——面板据此渲染,绝不复刻 Go 常量。key 是嵌套 JSON 的点路径;max==0=上不封顶;
/// exclusive=开区间。
@freezed
abstract class LimitField with _$LimitField {
  const factory LimitField({
    required String key,
    @Default('') String group,
    @JsonKey(name: 'default') @Default(0) double defaultValue,
    @Default(0) double min,
    @Default(0) double max,
    @Default(false) bool exclusive,
    @Default('') String unit,
    @Default('') String desc,
  }) = _LimitField;

  factory LimitField.fromJson(Map<String, dynamic> json) =>
      _$LimitFieldFromJson(json);
}
