import 'package:freezed_annotation/freezed_annotation.dart';

import 'entity_kind.dart';

part 'entity_row.freezed.dart';

/// The uniform left-rail row — one lightweight projection across all four kinds (the rail needs only
/// the common header + a few kind-specific badges, NOT the full typed entity, so a single list shape
/// serves every group). Built from the raw list-item map by [EntityRow.fromListItem], which plucks
/// each kind's badge fields opportunistically (a function item simply has no runtimeState). Detail
/// views fetch the full typed entity separately.
///
/// 统一左岛行——跨四 kind 的轻量投影(rail 只需公共头 + 少量 kind 专属徽标,非完整 typed 实体,故单一
/// 列表形状服务每组)。由 [fromListItem] 从原始 list-item map 机会式拔取各 kind 徽标字段。详情另取
/// 完整 typed 实体。
@freezed
abstract class EntityRow with _$EntityRow {
  const factory EntityRow({
    required EntityKind kind,
    required String id,
    @Default('') String name,
    @Default('') String description,
    @Default(<String>[]) List<String> tags,
    required DateTime updatedAt,
    // handler badges
    String? configState,
    String? runtimeState,
    @Default(0) int missingConfigCount,
    // workflow badges
    bool? active,
    String? lifecycleState,
    @Default(false) bool needsAttention,
  }) = _EntityRow;

  /// Project a raw list-item map (a bare entity with embedded activeVersion) onto a rail row. Badge
  /// fields are read opportunistically — absent keys stay null/0/false, so the same code path works
  /// for every kind.
  ///
  /// 把原始 list-item map 投影成 rail 行。徽标字段机会式读取——缺失键留 null/0/false,故同一代码路径
  /// 服务每 kind。
  static EntityRow fromListItem(EntityKind kind, Map<String, dynamic> m) => EntityRow(
        kind: kind,
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        description: m['description'] as String? ?? '',
        tags: (m['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
        updatedAt: DateTime.tryParse(m['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        configState: m['configState'] as String?,
        runtimeState: m['runtimeState'] as String?,
        missingConfigCount: (m['missingConfig'] as List<dynamic>?)?.length ?? 0,
        active: m['active'] as bool?,
        lifecycleState: m['lifecycleState'] as String?,
        needsAttention: m['needsAttention'] as bool? ?? false,
      );
}
