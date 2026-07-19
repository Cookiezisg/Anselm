import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/entities/control.dart';
import '../../../../core/contract/entities/values.dart';
import '../../../../core/graph/node_ref.dart';
import '../../data/entity_kind.dart';
import '../../data/entity_providers.dart';
import '../../data/entity_repository.dart';

/// [RefCandidate] (id/name/meta) is defined on the data seam; re-exported so UI can `import` just this.
/// RefCandidate 定义在数据缝上,这里再导出、UI 只 import 这一处。
export '../../data/entity_repository.dart' show RefCandidate;

/// Map a ref family to one of the four rail [EntityKind]s, or null for the families that are NOT rail
/// entities (mcp/trigger/control/approval — served by their own list endpoints). 族 → 四大 EntityKind,
/// 或 null(mcp/trigger/control/approval 非 rail 实体,走各自 list 端点)。
EntityKind? entityKindOfRefFamily(RefFamily f) => switch (f) {
      RefFamily.function => EntityKind.function,
      RefFamily.handler => EntityKind.handler,
      RefFamily.agent => EntityKind.agent,
      _ => null,
    };

/// The selectable TARGET entities for a [RefFamily]. The three rail families read an UNFILTERED
/// `listEntities` (NOT the rail's search-bound list, which would leak the search box into the picker);
/// mcp/trigger/control/approval read their own list endpoints. Local single-user workspaces are small,
/// so one 200-cap page is enough (a known bound). 某族的可选目标实体;三个 rail 族读**无过滤** listEntities,
/// mcp/trigger/control/approval 读各自端点;工作区体量小,一页 200 上限足够(已知界)。
final refTargetsProvider =
    FutureProvider.autoDispose.family<List<RefCandidate>, RefFamily>((ref, family) async {
  final repo = ref.watch(entityRepositoryProvider);
  final kind = entityKindOfRefFamily(family);
  if (kind != null) {
    final page = await repo.listEntities(kind, limit: 200);
    return [
      for (final r in page.items) (id: r.id, name: r.name.isEmpty ? r.id : r.name, meta: null),
    ];
  }
  return switch (family) {
    RefFamily.mcp => repo.listMcpServers(),
    RefFamily.trigger => repo.listTriggers(),
    RefFamily.control => repo.listControls(),
    RefFamily.approval => repo.listApprovals(),
    _ => Future.value(const <RefCandidate>[]),
  };
});

/// The MEMBERS (a handler's methods; an mcp server's tools) for a resolved (family, target). Empty for
/// families with no second level. Handler methods come from the already-wired `getHandler`. 已解析
/// (族,目标) 的成员(handler 方法 / mcp 工具);无第二层的族返空;handler 方法走已有 getHandler。
final refMembersProvider = FutureProvider.autoDispose
    .family<List<RefCandidate>, ({RefFamily family, String target})>((ref, key) async {
  final repo = ref.watch(entityRepositoryProvider);
  switch (key.family) {
    case RefFamily.handler:
      final h = await repo.getHandler(key.target);
      return [
        for (final m in h.activeVersion?.methods ?? const <MethodSpec>[])
          (id: m.name, name: m.name, meta: null),
      ];
    case RefFamily.mcp:
      return repo.listMcpTools(key.target);
    default:
      return const <RefCandidate>[];
  }
});

/// A control logic fetched FULL (its active version's branches) — the source for both the editor's
/// edge-port dropdown and the node-inspector branch peek. control 全量(活跃版本分支),供边端口下拉 + 节点分支 peek。
final controlProvider = FutureProvider.autoDispose
    .family<ControlLogic, String>((ref, controlId) => ref.watch(entityRepositoryProvider).getControl(controlId));

/// The branch PORTS a control declares — the valid `fromPort` choices for an edge leaving a control node,
/// so the editor picks from real branches instead of blind free-text. Derives from [controlProvider] so
/// both share ONE fetch. Stale entries (a port the loaded control no longer declares) are kept selectable
/// at the call site. control 声明的 branch port(派生自 controlProvider,共享一次取);陈旧值仍可选。
final controlPortsProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, controlId) async {
  final control = await ref.watch(controlProvider(controlId).future);
  return [for (final b in control.activeVersion?.branches ?? const <Branch>[]) b.port];
});
