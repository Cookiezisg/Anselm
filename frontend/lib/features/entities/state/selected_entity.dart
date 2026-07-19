import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/navigation.dart';
import '../data/entity_kind.dart';

/// The currently-selected entity (kind + id) — the shared axis the rail SETS (by navigating) and the
/// ocean / inspector / detail providers WATCH (cross-island, cross-feature via this one provider).
///
/// STEP 6: backed by go_router. This is now a READ-ONLY shim DERIVED one-way from the router's URL: it
/// watches [goRouterProvider]'s delegate (a `ChangeNotifier`) and parses the current `/entities/:kind/:id`
/// location into an [EntityRef]. There is no `select`/`clear` — the ONLY way to change selection is to
/// navigate (`context.go(entityLocation(...))` from the rail, or `goRouter.go('/')` to clear). Strictly
/// one-way (route → provider); never push provider → URL implicitly. Consumers keep calling
/// `ref.watch(selectedEntityProvider)` unchanged — they don't know it is route-backed now.
///
/// 当前选中实体(kind+id)——rail 设(经导航)、ocean/inspector/detail 读的共享轴。STEP 6 接 go_router:只读 shim,单向
/// 派生自路由 URL(监听 goRouterProvider 的 delegate[ChangeNotifier],解析 /entities/:kind/:id → EntityRef)。无
/// select/clear——改选区的唯一途径是导航。严格单向 route→provider,绝不隐式回写 URL。消费者照旧 watch、不知背后换成路由。
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
  EntityRef? build() {
    final delegate = ref.watch(goRouterProvider).routerDelegate;
    // Re-derive on every navigation; the delegate is a ChangeNotifier. Setting state from a listener
    // (outside build) is safe — NEVER mutate selection during build. 每次导航重派生;监听里 set 安全。
    void onRoute() => state = _parse(delegate.currentConfiguration.uri);
    delegate.addListener(onRoute);
    ref.onDispose(() => delegate.removeListener(onRoute));
    return _parse(delegate.currentConfiguration.uri);
  }

  /// `/entities/<kind>/<id>` → [EntityRef]; anything else (incl. `/`, a bad kind) → null. 路由路径解析。
  static EntityRef? _parse(Uri uri) {
    final segs = uri.pathSegments;
    if (segs.length == 3 && segs[0] == 'entities') {
      final kind = entityKindFromWire(segs[1]);
      if (kind != null) return EntityRef(kind, segs[2]);
    }
    return null;
  }
}

final selectedEntityProvider =
    NotifierProvider<SelectedEntity, EntityRef?>(SelectedEntity.new);
