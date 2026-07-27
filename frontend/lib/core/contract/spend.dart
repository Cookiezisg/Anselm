import 'package:freezed_annotation/freezed_annotation.dart';

part 'spend.freezed.dart';
part 'spend.g.dart';

/// One aggregated cell of the direct-side generation spend projection (`GET /api/v1/spend`,
/// WRK-082 H10) — the exact projection of the backend's wire row.
///
/// **`units` is TRUE, `estPUSD` is an ESTIMATE.** Units are counted (images, characters, seconds);
/// the price comes from a hand-written table that can be wrong or absent, and `estPUSD == 0` means
/// the table has no entry for that model — honestly unknown, never "free". Every surface rendering
/// this MUST label the money as an estimate whose authority is the provider's own billing console.
/// Managed (free-tier) calls are absent by construction: the gateway journals those and the
/// free-tier quota card already shows them.
///
/// 直连侧生成支出投影的一格聚合(`GET /api/v1/spend`,H10)——后端线缆行的精确投影。
///
/// **`units` 恒真、`estPUSD` 恒为估算。** 用量是数出来的(张/字符/秒);价出自一张可能错、可能没有的
/// 手写表,`estPUSD == 0` 表示表里没有该模型——**诚实的未知,绝不是「免费」**。渲染它的每个面**必须**
/// 把钱标成估算、并说明权威在供应商自己的账单控制台。受管(免费档)调用**结构上不在这里**:网关记
/// 那本账,免费档配额卡已在展示。
@freezed
abstract class SpendRow with _$SpendRow {
  const factory SpendRow({
    @Default('') String date,
    @Default('') String category,
    @Default('') String provider,
    @Default('') String model,
    @Default(0) int units,
    @JsonKey(name: 'estPUSD') @Default(0) int estPUSD,
  }) = _SpendRow;

  factory SpendRow.fromJson(Map<String, dynamic> json) =>
      _$SpendRowFromJson(json);
}
