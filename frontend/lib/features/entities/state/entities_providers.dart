import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/entities_repository.dart';
import '../model/entity.dart';

/// Riverpod wiring for the Entities feature (classic providers per ADR 0004). The repository
/// is injected by override — fixtures for dev, the real impl in the app composition root —
/// mirroring the backend's "single omniscient assembler" as a scope override.
/// Entities 的 Riverpod 装配(经典 provider)。repository 经 override 注入:dev 用 fixture、app 装配根用真实现。
final entitiesRepositoryProvider = Provider<EntitiesRepository>(
  (ref) => throw UnimplementedError(
    'override entitiesRepositoryProvider (FixtureEntitiesRepository for dev, real impl in app)',
  ),
);

final entityListProvider = FutureProvider<List<EntitySummary>>(
  (ref) => ref.watch(entitiesRepositoryProvider).list(),
);

class SelectedEntityId extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String id) => state = id;
}

final selectedEntityIdProvider =
    NotifierProvider<SelectedEntityId, String?>(SelectedEntityId.new);

final selectedEntityProvider = FutureProvider<EntityDetail?>((ref) async {
  final id = ref.watch(selectedEntityIdProvider);
  if (id == null) return null;
  return ref.watch(entitiesRepositoryProvider).detail(id);
});
