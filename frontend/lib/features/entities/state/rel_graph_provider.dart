import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/relation.dart';
import '../data/entity_kind.dart';
import '../data/entity_providers.dart';
import '../data/entity_row.dart';

/// The whole-workspace relation snapshot (`GET /api/v1/relgraph`), backing the Entities Overview graph.
/// autoDispose so it refetches each time the Overview (or the explore page) is (re)shown — a bounded
/// snapshot, cheap to refetch; the rail's own SSE liveness keeps the five-card counts fresh independently.
/// 关系快照 provider,supports 总览关系图。autoDispose:每次(重)显总览/探索页即重取(有界快照、便宜)。
final relGraphProvider = FutureProvider.autoDispose<EntityRelGraph>((ref) {
  final repo = ref.watch(entityRepositoryProvider);
  Timer? refreshTimer;
  final relationSub = repo.relationSignals().listen((_) {
    // Deletes and their aggregated dependency notification arrive back-to-back. Coalesce them into
    // one read so the graph never briefly paints an intermediate topology or storms /relgraph.
    // 删除与聚合依赖通知通常背靠背到达；合成一次重读，避免中间拓扑闪现或打爆 /relgraph。
    refreshTimer?.cancel();
    refreshTimer = Timer(const Duration(milliseconds: 300), () {
      refreshTimer = null;
      ref.invalidateSelf();
    });
  });
  final resyncSub = repo.lifecycleResync().listen((_) {
    refreshTimer?.cancel();
    refreshTimer = null;
    ref.invalidateSelf();
  });
  ref.onDispose(() {
    refreshTimer?.cancel();
    unawaited(relationSub.cancel());
    unawaited(resyncSub.cancel());
  });
  return repo.getRelGraph();
});

/// A rail-kind entity's lean row (name/description/vN) for the explore-state right-island card — fetched
/// on demand for the selected node. Only the 7 rail kinds have a row fetcher; skill/mcp/document/
/// conversation nodes render name-only. autoDispose so a deselect drops it. 探索态右岛卡按需取选中节点的行。
final entityRowFetchProvider = FutureProvider.autoDispose
    .family<EntityRow, ({EntityKind kind, String id})>((ref, arg) {
      return ref.watch(entityRepositoryProvider).getEntityRow(arg.kind, arg.id);
    });
