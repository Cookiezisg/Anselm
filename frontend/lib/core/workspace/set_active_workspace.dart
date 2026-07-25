import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../runtime.dart';

/// Change the active workspace AND settle the runtime chain behind it, as ONE indivisible action.
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
/// to flush.
///
/// **Why the write and the settle live in one function rather than two lines at each call site**: the
/// two-line version is the shape WRK-083 B1 was made of — a rule that every future writer must remember,
/// which means the next writer will not. Fold them together and there is nothing to remember. Calling
/// `activeWorkspaceProvider.notifier.set` directly is guarded against at the source level
/// (`test/guards/workspace_write_guard_test.dart`).
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
/// 它不能住进 [ActiveWorkspace.set] 里:dio **watch** 着那个 provider,从那里反手去够 dio 会闭合依赖环,
/// riverpod 会直接拒绝。
void setActiveWorkspace(Ref ref, String? id) {
  ref.read(activeWorkspaceProvider.notifier).set(id);
  ref.read(apiClientProvider);
}
