import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../media/media_source.dart';
import '../runtime.dart';

/// Change the active workspace, settle the runtime chain behind it, and record the activation on the
/// server as ONE indivisible action.
///
/// The settle half is not housekeeping — without it the app threw
/// «setState() or markNeedsBuild() called during build» on every cold start and every hot restart
/// (WRK-083 L2, deterministic, verified twice on the real machine and reproduced in
/// `test/guards/provider_settle_guard_test.dart`).
///
/// Why: [dioProvider] watches [activeWorkspaceProvider] — that watch IS the hot-switch pulse, a new Dio
/// per switch so the old ApiClient's interceptor retires with it. So the instant the id changes, dio is
/// DIRTY. Riverpod flushes lazily: dio stays dirty until somebody watches down that chain, and the
/// somebody is a widget — the conversation rail's build reaching `chatRepositoryProvider` →
/// `apiClientProvider`. The flush then runs INSIDE that build, dio rebuilds, apiClient's own `ref.watch`
/// callback self-invalidates, the self-invalidation schedules a provider refresh, and the refresh is a
/// `setState` on `UncontrolledProviderScope`. Mid-build. Flutter throws.
///
/// Reading the client here forces that same flush to happen HERE — outside any build, where a scheduled
/// refresh is simply a frame marked dirty. By the time a widget watches the chain there is nothing left
/// to flush. The platform media seam is part of that chain too: read-aloud availability is a long-lived
/// provider that transcript leaves may first watch after a switch, so it must be rebuilt here rather than
/// lazily from `_ReadAloudSlot.build`.
///
/// 在这里读一次客户端,就把同一次刷新逼到这里发生——在任何 build 之外,那里的「调度一次 refresh」不过是把下一帧
/// 标脏。等 widget 真去 watch 那条链时,已经没有脏可刷。平台媒体缝也属于这条链:朗读可用性是一个常驻 provider,
/// transcript 叶子可能在切换后才第一次 watch 它,必须在这里重建,不能等 `_ReadAloudSlot.build` 懒刷新。
///
/// **Why the write and the settle live in one function rather than two lines at each call site**: the
/// two-line version is the shape WRK-083 B1 was made of — a rule that every future writer must remember,
/// which means the next writer will not. Fold them together and there is nothing to remember. Calling
/// `activeWorkspaceProvider.notifier.set` directly is guarded against at the source level
/// (`test/guards/workspace_write_guard_test.dart`).
///
/// The server call is deliberately fire-and-forget: the local workspace switch must not wait for a
/// bookkeeping write before the new shell can render. Its error is still observed and printed, rather
/// than becoming an unhandled Flutter future or silently pretending the recency ledger was updated.
///
/// It cannot live inside [ActiveWorkspace.set] itself: dio WATCHES that provider, so reaching from there
/// into dio would close a dependency cycle and Riverpod would refuse it outright.
///
/// 切换活动 workspace,**并**把它背后的运行时链摊平——作为**一个不可分的动作**。
///
/// settle 那一半不是内务:少了它,app 在**每一次**冷启动与热重启都抛
/// 「setState() or markNeedsBuild() called during build」(WRK-083 L2,确定性,真机验过两次,并在
/// `test/guards/provider_settle_guard_test.dart` 复现)。
///
/// 为什么:[dioProvider] watch 着 [activeWorkspaceProvider]——那个 watch **就是**热切换脉搏,每次切换换一个新
/// Dio、旧 ApiClient 的拦截器随之退役。故 id 一变,dio 立刻**脏**。而 riverpod 是**懒刷新**的:dio 会一直脏着,
/// 直到有谁 watch 到那条链上,而那个「谁」是一个 **widget**——对话 rail 的 build 一路走到
/// `chatRepositoryProvider` → `apiClientProvider`。于是那次刷新在**那次 build 里**跑:dio 重建,apiClient 自己的
/// `ref.watch` 回调自我失效,自我失效调度一次 provider refresh,而那次 refresh 就是对 `UncontrolledProviderScope`
/// 的一次 `setState`。在 build 中途。Flutter 抛。
///
/// 在这里读一次客户端,就把**同一次刷新**逼到**这里**发生——在任何 build 之外,那里的「调度一次 refresh」不过是
/// 把下一帧标脏而已。等到 widget 真去 watch 那条链时,已经没有脏可刷。
///
/// **为什么把「写」与「摊平」合进一个函数、而不是在每个调用点写两行**:两行版正是 WRK-083 B1 的形状——一条
/// 「每个将来的写入者都必须记得」的规矩,而那意味着下一个写入者不会记得。合成一个,就没有什么需要记得。直接调
/// `activeWorkspaceProvider.notifier.set` 由源码级守卫挡住(`test/guards/workspace_write_guard_test.dart`)。
///
/// 服务端记账刻意 fire-and-forget:本地 workspace 切换不能等一笔记账写完才让新壳渲染。错误仍会被观察并打印,
/// 不变成未处理的 Flutter future,也不静默假装「最近使用」已经写回。
///
/// 它不能住进 [ActiveWorkspace.set] 里:dio **watch** 着那个 provider,从那里反手去够 dio 会闭合依赖环,
/// riverpod 会直接拒绝。
void setActiveWorkspace(Ref ref, String? id) {
  ref.read(activeWorkspaceProvider.notifier).set(id);
  final api = ref.read(apiClientProvider);
  // Keep workspace-bound platform descendants out of a later widget build. This probe is cheap,
  // honest (loading renders as no affordance), and also makes availability follow the workspace
  // axis instead of showing the previous workspace's answer.
  // 把 workspace 绑定的平台后代摊在 widget build 之外。探测成本低且诚实(loading 渲成无入口),同时让可用性
  // 跟随 workspace 轴,不把上一个 workspace 的答案带到当前面上。
  ref.read(mediaSourceProvider);
  ref.read(readAloudAvailableProvider);
  if (id == null || id.isEmpty) return;

  unawaited(
    api
        .postData('/api/v1/workspaces/$id:activate')
        .then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) {
            debugPrint(
              '[workspace] activation bookkeeping failed for $id: $error',
            );
          },
        ),
  );
}
