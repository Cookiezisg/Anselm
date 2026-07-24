import 'package:flutter/scheduler.dart';

/// Runs [action] at a moment when it is LEGAL to mark widgets dirty.
///
/// A `ScrollController` listener is not merely a gesture callback. A viewport notifies it
/// SYNCHRONOUSLY from `performLayout` when it corrects the offset against new content dimensions,
/// and `jumpTo` notifies synchronously as well. So a listener that dirties a widget can land in the
/// LAYOUT phase, where the framework rejects it ("setState()/markNeedsBuild() called during build")
/// — and where, per the two real crash logs behind WRK-077 CR-1, tearing a subtree mid-frame
/// desynchronised `InheritedElement`'s dependent ledger and killed the process.
///
/// [SchedulerPhase.persistentCallbacks] IS build/layout/paint. Every other phase — idle, transient
/// animation callbacks, mid-frame microtasks, post-frame — is a legal place to dirty. So this defers
/// from that ONE phase only, and only to the post-frame callback of the SAME frame: the delay is
/// microseconds, not a frame, and no `scheduleFrame` is needed because we are already inside one.
/// Deferring unconditionally would be worse than this bug — every scroll callback would cost a
/// frame of latency.
///
/// [action] MUST re-check its own `mounted` / `hasClients` and MUST close over values already read:
/// deferral means the widget, the `ref`, or the controller can be gone by the time it runs.
///
/// 让 [action] 在「可以弄脏 widget」的相位执行。
///
/// `ScrollController` 的监听器不只是手势回调:viewport 依新内容尺寸校正 offset 时会在 `performLayout`
/// 里**同步**通知,`jumpTo` 亦同步。于是监听器里的重建会落在**布局阶段**——框架直接拒绝
/// (「setState()/markNeedsBuild() called during build」),而按 WRK-077 CR-1 那两份真机崩溃栈,帧中途
/// 拆建子树会让 `InheritedElement` 的依赖账本错位,进而崩掉进程。
///
/// 只有 [SchedulerPhase.persistentCallbacks] 是 build/布局/绘制;其余相位(idle / 动画瞬时回调 /
/// 帧中微任务 / 后帧)弄脏都合法。故**只**从这一个相位延后,且延到**同一帧**的后帧回调:代价是微秒级,
/// 不是掉一帧;也无需 `scheduleFrame`——我们本就在帧内。无条件延后比这个 bug 更糟:那会给每次滚动回调
/// 都加上一帧延迟。
///
/// [action] **必须**自查 `mounted` / `hasClients`,且**必须**闭包捕获已读好的值——延后意味着执行时
/// widget、`ref`、控制器都可能已经没了。
void runFrameSafe(void Function() action) {
  final binding = SchedulerBinding.instance;
  if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
    binding.addPostFrameCallback((_) => action());
    return;
  }
  action();
}
