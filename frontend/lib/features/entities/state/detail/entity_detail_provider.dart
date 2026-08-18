import 'dart:async';

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
  StreamSubscription<StreamEnvelope>? _panelSub;

  @override
  Future<EntityDetail> build() async {
    _repo = ref.watch(entityRepositoryProvider);
    final life = _repo.lifecycleSignals(entityRef.kind).listen(_onLifecycle);
    ref.onDispose(life.cancel);
    // The same stream's 410: an edit that landed inside the gap left no signal, so re-read rather than
    // show a detail page that silently diverged from the row (WRK-083 L7). 同流 410:落在缺口里的编辑没有
    // 留下信号,故重读,而不是展示一个已经和行悄悄分家的详情页。
    final resync = _repo.lifecycleResync().listen((_) => ref.invalidateSelf());
    ref.onDispose(resync.cancel);
    // Trigger pause/resume is an ephemeral scoped status signal rather than a durable lifecycle
    // notification. The detail is still a read projection, so use the signal only as a prompt to
    // re-fetch; never patch `paused`/`listening`/`nextFireAt` from its payload. Other entity kinds keep
    // their scoped subscriptions in the tab that owns the high-frequency panel work.
    // trigger 的 pause/resume 只发 ephemeral 作用域 status 信号,详情仍以 REST 读模型为真,故只借信号
    // 触发重读,绝不据 payload patch paused/listening/nextFireAt。其它 kind 的高频面板仍由所属 tab 订阅。
    if (entityRef.kind == EntityKind.trigger) {
      _panelSub = _repo
          .panelSignals(entityRef.kind.scope(entityRef.id))
          .listen(_onPanel);
      ref.onDispose(() => unawaited(_panelSub?.cancel()));
      // Trigger `listening` is derived from active workflow bindings, so a workflow lifecycle pulse
      // can change this detail without emitting a trigger-owned signal. Re-read the trigger projection
      // rather than leaving a stale "Listening" badge after the last workflow is deactivated.
      // trigger 的 listening 由 active workflow 绑定派生；workflow 生命周期变化可能不发 trigger 自己的信号，
      // 必须重读详情，否则最后一个 workflow 下线后会把旧的「Listening」留在画面上。
      final workflowLife = _repo.lifecycleSignals(EntityKind.workflow).listen((
        s,
      ) {
        if (s.durable) unawaited(_refreshFromTruth());
      });
      ref.onDispose(workflowLife.cancel);
    }
    return _fetch();
  }

  Future<EntityDetail> _fetch() async => switch (entityRef.kind) {
    EntityKind.function => EntityDetail(
      ref: entityRef,
      function: await _repo.getFunction(entityRef.id),
    ),
    EntityKind.handler => EntityDetail(
      ref: entityRef,
      handler: await _repo.getHandler(entityRef.id),
    ),
    EntityKind.agent => EntityDetail(
      ref: entityRef,
      agent: await _repo.getAgent(entityRef.id),
      mountHealth: await _safeMountHealth(),
    ),
    EntityKind.workflow => EntityDetail(
      ref: entityRef,
      workflow: await _repo.getWorkflow(entityRef.id),
    ),
    EntityKind.control => EntityDetail(
      ref: entityRef,
      control: await _repo.getControl(entityRef.id),
    ),
    EntityKind.approval => EntityDetail(
      ref: entityRef,
      approval: await _repo.getApproval(entityRef.id),
    ),
    EntityKind.trigger => EntityDetail(
      ref: entityRef,
      trigger: await _repo.getTrigger(entityRef.id),
    ),
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
        await _refreshFromTruth();
    }
  }

  void _onPanel(StreamEnvelope env) {
    if (env.frame is! FrameSignal) return;
    final node = (env.frame as FrameSignal).node;
    if (node.type == 'status') {
      unawaited(_refreshFromTruth());
      return;
    }
    if (entityRef.kind != EntityKind.trigger || node.type != 'fire') return;

    // A webhook/cron fire is ephemeral, but it is the trigger detail's live refresh hint. The
    // payload only names the activation; the REST rows remain the truth for lastFiredAt and both
    // observability tabs. Never patch the detail from the signal itself.
    // webhook/cron fire 虽是 ephemeral,但它是 trigger 详情的实时刷新提示。payload 只带 activation
    // 名称; lastFiredAt 与两条观测流仍以 REST 行为真,绝不据 signal 自行 patch 详情。
    unawaited(_refreshFromTruth());
  }

  Future<void> _refreshFromTruth() async {
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

/// autoDispose: leaving an entity tears down the notifier + its TWO SSE subscriptions (life/panel) — a
/// non-autoDispose family would leak a subscription pair per entity ever opened. Re-selecting re-fetches
/// (the deferred skeleton suppresses any flash on a fast local fetch). autoDispose:离开实体即释放 notifier
/// + 其两条 SSE 订阅;非 autoDispose 会每开一个实体泄漏一对订阅。重选重取(本地快取经延迟骨架不闪)。
final entityDetailProvider = AsyncNotifierProvider.autoDispose
    .family<EntityDetailNotifier, EntityDetail, EntityRef>(
      EntityDetailNotifier.new,
      retry: (_, _) => null,
    );
