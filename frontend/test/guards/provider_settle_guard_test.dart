import 'package:anselm/core/process/backend_controller.dart';
import 'package:anselm/core/runtime.dart';
import 'package:anselm/core/workspace/set_active_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// WRK-083 L2 law: a foundational provider may NOT be left dirty across the boundary into a widget
// build that mounts new dependents.
//
// Riverpod flushes lazily: `ref.watch` on a provider whose ancestor is dirty rebuilds that ancestor
// RIGHT THERE, and the rebuild notifies the ancestor's existing subscribers. If one of those
// subscribers is itself a provider, it self-invalidates, schedules a refresh, and the refresh is a
// `setState` on `UncontrolledProviderScope`. Do that inside a widget build and Flutter throws
// «setState() or markNeedsBuild() called during build».
//
// That is exactly what the app did on EVERY cold start and every hot restart (deterministic, verified
// twice on the real machine). The chain: the workspace bootstrap `ref.read(apiClientProvider)` early —
// mounting dio + apiClient — then, after its await, sets `activeWorkspaceProvider`, which dio watches.
// dio is now dirty with apiClient still subscribed to it. The shell mounts in a later frame, the
// conversation rail's build watches `chatRepositoryProvider`, that watches `apiClientProvider`, the
// lazy flush finally runs — inside a widget build — and the cascade fires.
//
// Nothing was red. Riverpod caught the assertion and the app carried on, which is precisely why it
// survived: the only trace was a wall of text in a terminal nobody was reading (WRK-083 §2.1).
//
// The guard reproduces the shape rather than the app: set the workspace outside build (as the
// bootstrap does), THEN mount a consumer that first-watches the client. `tester.takeException()` is
// the whole assertion.
//
// WRK-083 L2 军规:基础 provider **不得**带着「脏」跨过边界、进入一次会挂载新依赖者的 widget build。
//
// Riverpod 是**懒刷新**的:`ref.watch` 一个祖先为脏的 provider,会**就地**重建那个祖先,而重建会通知祖先
// **既有**的订阅者。若某个订阅者本身是 provider,它会自我失效、调度一次 refresh,而那次 refresh 就是对
// `UncontrolledProviderScope` 的一次 `setState`。在 widget build 里做这件事,Flutter 直接抛
// 「setState() or markNeedsBuild() called during build」。
//
// app **每一次**冷启动与热重启都在这么做(确定性,真机验过两次)。链条:workspace bootstrap 早早
// `ref.read(apiClientProvider)`——把 dio 与 apiClient 挂了起来——随后在 await 之后 set
// `activeWorkspaceProvider`,而 dio watch 着它。此刻 dio 脏、apiClient 仍订阅着它。壳在后续某帧挂载,
// 对话 rail 的 build watch `chatRepositoryProvider`、后者 watch `apiClientProvider`,那次懒刷新终于跑了
// ——**在 widget build 里**——级联开火。
//
// 没有任何东西变红。riverpod 接住断言、app 照常跑下去,这正是它活下来的原因:唯一的痕迹是一段没人在看的
// 终端文字(WRK-083 §2.1)。
//
// 守卫复现的是**那个形状**、不是整个 app:像 bootstrap 那样在 build 之外 set workspace,**然后**挂载一个
// 首次 watch 客户端的消费者。`tester.takeException()` 就是全部断言。

/// A backend that is already up — the real one spawns a sidecar. 已就绪的后端(真的那个会拉起 sidecar)。
class _ReadyBackend extends BackendStartup {
  @override
  BackendState build() =>
      const BackendState(BackendPhase.ready, baseUrl: 'http://127.0.0.1:9');
}

/// A real [Ref] to hand the production helper — `ProviderContainer` is not one, and splitting the
/// helper into a container-flavoured twin just to satisfy a test would put the rule in two places again.
/// 给生产 helper 一个真 [Ref]——`ProviderContainer` 不是 Ref,而为了迁就测试再造一个容器版孪生件,等于把
/// 规矩又放回两处。
final _setter = Provider<void Function(String?)>(
  (ref) =>
      (id) => setActiveWorkspace(ref, id),
);

class _ClientConsumer extends ConsumerWidget {
  const _ClientConsumer();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(apiClientProvider);
    return const SizedBox.shrink();
  }
}

void main() {
  testWidgets(
    'a workspace set outside build leaves nothing dirty for a later build to flush',
    (tester) async {
      final container = ProviderContainer(
        overrides: [backendStartupProvider.overrideWith(_ReadyBackend.new)],
      );
      addTearDown(container.dispose);

      // Mount the client the way the bootstrap does — a plain read, no subscription of its own, but
      // enough to bring dio + apiClient into existence with apiClient subscribed to dio.
      // 像 bootstrap 那样把客户端挂起来——一次普通 read,自己不建订阅,但足以让 dio 与 apiClient 存在、
      // 且 apiClient 订阅着 dio。
      container.read(apiClientProvider);

      // A shell is on screen but nothing is watching the client yet. 壳已在屏上,但还没人 watch 客户端。
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SizedBox.shrink()),
        ),
      );

      // The bootstrap's post-await write, through the ONE entry point that also settles the chain.
      // Swap this line for a bare `activeWorkspaceProvider.notifier.set` and the test goes red — that
      // is the whole difference between the two, stated as an executable fact.
      // bootstrap 在 await 之后的那次写,走**唯一**那个顺手摊平链条的入口。把这一行换成裸的
      // `activeWorkspaceProvider.notifier.set`,测试就会变红——两者的全部差别,写成一条可执行的事实。
      container.read(_setter)('ws_1');

      // Now a feature mounts and first-watches the client — the frame where the lazy flush lands.
      // 现在一个 feature 挂载并首次 watch 客户端——懒刷新落地的那一帧。
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: _ClientConsumer()),
        ),
      );

      expect(
        tester.takeException(),
        isNull,
        reason:
            'the runtime chain must be settled before a widget build first watches it — '
            'otherwise the flush cascades into setState-during-build (WRK-083 L2)',
      );
    },
  );
}
