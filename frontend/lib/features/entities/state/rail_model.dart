import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/entity_kind.dart';
import 'entity_list_provider.dart';
import 'entity_list_state.dart';

/// One left-rail group = one kind's header + its live list state. The rail UI (STEP 3) renders each
/// group's [state] (loading skeleton / rows / empty / error) and the [count] badge. Thin VM: it just
/// fans the four [entityListProvider]s into an ordered list so the rail widget watches ONE provider.
///
/// 一个左岛分组 = 一个 kind 的头 + 其实时列表态。rail UI(STEP 3)据 [state] 渲(骨架/行/空/错)+ [count]
/// 徽标。薄 VM:把四个 entityListProvider 扇成有序列表,使 rail widget 只 watch 一个 provider。
class RailGroup {
  const RailGroup({required this.kind, required this.state});

  final EntityKind kind;
  final AsyncValue<EntityListState> state;

  /// Exact filtered total from the backend response header. A cursor page's loaded row count is not a
  /// total: keep it nullable so the UI never presents a partial page as a precise database count.
  /// 后端响应头给的精确过滤总数。游标页已载行数不是总数，故保持可空，UI 绝不把半页冒充数据库计数。
  int? get totalCount {
    final s = state.value;
    if (s == null) return null;
    return s.totalCount ?? (s.hasMore ? null : s.rows.length);
  }

  /// Loaded rows remain useful for local projections, but are not a badge count.
  /// 已载行仍供本地投影使用，但不再冒充徽标总数。
  int get count => state.value?.rows.length ?? 0;
}

/// The ordered rail model — the four executable kinds, each with its live list state. 有序 rail 模型。
final railModelProvider = Provider<List<RailGroup>>((ref) {
  return [
    for (final kind in EntityKind.values)
      RailGroup(kind: kind, state: ref.watch(entityListProvider(kind))),
  ];
});
