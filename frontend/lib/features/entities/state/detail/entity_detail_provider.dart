import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/entities/agent.dart';
import '../../../../core/router/navigation.dart';
import '../../../../core/sse/frame.dart';
import '../../data/entity_kind.dart';
import '../../data/entity_providers.dart';
import '../../data/entity_repository.dart';
import '../../data/entity_signal.dart';
import '../selected_entity.dart';
import 'entity_detail.dart';
import 'log_list_provider.dart';
import 'version_list_provider.dart';

/// The selected entity's detail (family over [EntityRef]). Fetches the typed entity (+ agent
/// mount-health) and subscribes to BOTH SSE streams. Realtime contract (researched, DB-row-is-truth):
///  - notifications (durable, low-freq) → the re-fetch trigger: `edited`/`updated`/… re-fetch the
///    detail AND invalidate the version/log families (so they reconcile the new active version);
///    `deleted` clears the selection (ocean falls back to its empty state); `created` is ignored.
///  - entities (ephemeral, high-freq) → held but a no-op in STEP 4 (the build-mirror banner + run
///    terminal are STEP 5; the subscription documents the seam). Never patch fields from a signal
///    payload (it carries only ids). Auto-retry off (the ocean offers an explicit retry).
///
/// 选中实体详情(按 EntityRef family)。取 typed 实体 + agent 挂载健康,订两条流:notifications(durable)→
/// 重取 + 让版本/日志 family 失效;deleted→清选区;created→忽略。entities(ephemeral)→STEP 4 持有但 no-op
/// (build 镜像/run 终端归 STEP 5)。绝不据 signal payload patch 字段(只带 id)。关自动重试。
class EntityDetailNotifier extends AsyncNotifier<EntityDetail> {
  EntityDetailNotifier(this.entityRef);

  final EntityRef entityRef;
  late EntityRepository _repo;

  @override
  Future<EntityDetail> build() async {
    _repo = ref.watch(entityRepositoryProvider);
    final life = _repo.lifecycleSignals(entityRef.kind).listen(_onLifecycle);
    final panel = _repo.panelSignals(entityRef.kind.scope(entityRef.id)).listen(_onPanel);
    ref.onDispose(() {
      life.cancel();
      panel.cancel();
    });
    return _fetch();
  }

  Future<EntityDetail> _fetch() async => switch (entityRef.kind) {
        EntityKind.function =>
          EntityDetail(ref: entityRef, function: await _repo.getFunction(entityRef.id)),
        EntityKind.handler =>
          EntityDetail(ref: entityRef, handler: await _repo.getHandler(entityRef.id)),
        EntityKind.agent => EntityDetail(
            ref: entityRef,
            agent: await _repo.getAgent(entityRef.id),
            mountHealth: await _safeMountHealth(),
          ),
        EntityKind.workflow =>
          EntityDetail(ref: entityRef, workflow: await _repo.getWorkflow(entityRef.id)),
      };

  // Mount-health is a non-fatal preflight — a failed probe must not blank the whole agent detail.
  // 挂载健康是非致命预检,探测失败不该把整个 agent 详情打空。
  Future<MountHealthReport?> _safeMountHealth() async {
    try {
      return await _repo.getMountHealth(entityRef.id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _onLifecycle(EntitySignal s) async {
    if (!s.durable || s.id != entityRef.id) return;
    switch (s.action) {
      case EntityAction.deleted:
        // The open entity vanished → navigate home (clears selection; the ocean falls back to empty).
        // ONLY when THIS is the currently-routed entity — a stale-but-alive detail notifier for some
        // OTHER entity must not yank the user out of what they're viewing. STEP 6: "clear" = go to `/`.
        // 仅当被删的是当前选中实体才回首页(防陈旧 notifier 把用户从正看的实体里拽走);选区随路由清空。
        if (ref.read(selectedEntityProvider) == entityRef) {
          ref.read(goRouterProvider).go('/');
        }
      case EntityAction.created:
        return; // detail is open on an existing id
      case EntityAction.edited:
      case EntityAction.updated:
      case EntityAction.unknown:
        final next = await AsyncValue.guard(_fetch);
        // autoDispose: the user may have left this entity mid-fetch (provider disposed) — writing state
        // after dispose throws. 已 autoDispose:取数途中可能已离开本实体(provider 释放),释放后写 state 会抛。
        if (!ref.mounted) return;
        state = next;
        // The active version (and its logs) may have moved — let those tabs reconcile from truth.
        ref.invalidate(versionListProvider(entityRef));
        ref.invalidate(logListProvider(entityRef));
    }
  }

  // No-op: the run terminal owns its OWN panel subscription (state/run/run_terminal_controller); this
  // seam is held for the future build-mirror banner (create/edit streaming over the entity scope).
  // no-op:run 终端自管面板订阅;此缝留给未来 build 镜像横幅(实体 scope 上的 create/edit 流式)。
  void _onPanel(StreamEnvelope env) {}
}

/// autoDispose: leaving an entity tears down the notifier + its TWO SSE subscriptions (life/panel) — a
/// non-autoDispose family would leak a subscription pair per entity ever opened. Re-selecting re-fetches
/// (the deferred skeleton suppresses any flash on a fast local fetch). autoDispose:离开实体即释放 notifier
/// + 其两条 SSE 订阅;非 autoDispose 会每开一个实体泄漏一对订阅。重选重取(本地快取经延迟骨架不闪)。
final entityDetailProvider =
    AsyncNotifierProvider.autoDispose.family<EntityDetailNotifier, EntityDetail, EntityRef>(
  EntityDetailNotifier.new,
  retry: (_, _) => null,
);
