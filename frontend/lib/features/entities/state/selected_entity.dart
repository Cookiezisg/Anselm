import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/entity_kind.dart';

/// The currently-selected entity (kind + id) — the shared axis the rail SETS and the ocean/inspector
/// WATCH (cross-island, cross-feature via this one core-ish provider). STEP 6 will back this with
/// go_router so it deep-links + survives back/forward; for now it is a plain Notifier so the rail is
/// interactive and the ocean has something to render.
///
/// 当前选中实体(kind+id)——rail 设、ocean/inspector 读的共享轴。STEP 6 接 go_router(deep-link+前进后退);
/// 现为普通 Notifier,使 rail 可交互、ocean 有可渲染对象。
class EntityRef {
  const EntityRef(this.kind, this.id);

  final EntityKind kind;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is EntityRef && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => 'EntityRef(${kind.name}:$id)';
}

class SelectedEntity extends Notifier<EntityRef?> {
  @override
  EntityRef? build() => null;

  void select(EntityRef ref) => state = ref;
  void clear() => state = null;
}

final selectedEntityProvider =
    NotifierProvider<SelectedEntity, EntityRef?>(SelectedEntity.new);
