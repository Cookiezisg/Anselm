import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anselm/core/perf/frame_safe.dart';

/// CR-1b (WRK-077). The bug these lock down is not hypothetical: a `ScrollController` listener is
/// notified SYNCHRONOUSLY from `performLayout` when a viewport reconciles the offset against new
/// content dimensions, so a listener that dirties a widget lands in the layout phase. Two real crash
/// logs came from that, via "setState()/markNeedsBuild() called during build" and a desynchronised
/// `InheritedElement` dependent ledger.
///
/// The first test is the REGRESSION itself — it reproduces the layout-phase notification with a real
/// widget tree and asserts no exception. Without [runFrameSafe] it fails.
///
/// CR-1b(WRK-077)。这里钉的 bug 不是假想:viewport 依新内容尺寸校正 offset 时会在 `performLayout` 里
/// **同步**通知 `ScrollController` 的监听器,于是监听器里的重建落在布局阶段。两份真机崩溃栈正源于此
/// (「setState()/markNeedsBuild() called during build」+ `InheritedElement` 依赖账本错位)。
///
/// 第一条测试就是**回归本身**——用真 widget 树复现布局期通知,断言不抛;去掉 [runFrameSafe] 它就红。
void main() {
  testWidgets('a scroll listener that fires DURING layout may dirty state', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The synchronous path: `jumpTo` notifies its listeners INLINE, and here it is invoked from a
    // LayoutBuilder's builder — i.e. from inside a `buildScope` nested in the layout phase, which is
    // where the framework's "setState() called during build" assertion lives. That is not a
    // contrivance: it is exactly the shape production had (a scroll-to-top in `ref.listen`, under a
    // shell built inside a LayoutBuilder).
    //
    // Two constructions that look right and prove NOTHING, both hit while writing this: content that
    // merely shrinks (a viewport corrects over-scroll through a ballistic activity, AFTER layout), and
    // jumping on the FIRST layout pass (the controller has no clients yet, so the jump never happens).
    //
    // 同步那条路径:`jumpTo` **就地**通知监听器,而这里它从 LayoutBuilder 的 builder 里调用——即布局阶段内
    // 嵌套的 `buildScope`,框架那句「setState() called during build」断言正住在这里。这不是硬凑:生产侧
    // 原本就是这个形状(`ref.listen` 里回顶 + 壳建在 LayoutBuilder 里)。
    //
    // 两个看着对、实则什么都证明不了的构造(写这条时都踩过):仅让内容缩短(viewport 对越界滚动走 ballistic
    // 活动、在布局**之后**校正),以及在**首次**布局就跳(控制器尚未 attach,那次 jump 根本没发生)。
    await tester.pumpWidget(
      MaterialApp(home: _Subject(controller: controller)),
    );
    await tester.pumpAndSettle();

    // Force a SECOND layout pass — now the controller has clients, so the jump really happens from
    // inside the layout phase. 逼出**第二次**布局:此时控制器已 attach,跳转才真的发生在布局阶段内。
    tester.view.physicalSize = const Size(700, 600);
    await tester.pumpAndSettle();

    expect(
      controller.offset,
      300,
      reason: 'the mid-layout jump must have happened',
    );
    expect(tester.takeException(), isNull);
  });

  test(
    'runs INLINE in a safe phase — no frame of latency for ordinary callbacks',
    () {
      // The phase check is the whole point: deferring unconditionally would put a frame of latency on
      // every scroll callback, which is worse than the bug. 相位判定就是要害:无条件延后会给每次滚动回调
      // 都加一帧延迟,比 bug 本身更糟。
      expect(SchedulerBinding.instance.schedulerPhase, SchedulerPhase.idle);
      var ran = false;
      runFrameSafe(() => ran = true);
      expect(
        ran,
        isTrue,
        reason: 'idle is a legal phase to dirty — must not defer',
      );
    },
  );

  testWidgets('defers out of the build/layout phase, and to the SAME frame', (
    tester,
  ) async {
    var ran = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            // persistentCallbacks == build/layout/paint. 这一相位即 build/布局/绘制。
            expect(
              SchedulerBinding.instance.schedulerPhase,
              SchedulerPhase.persistentCallbacks,
            );
            runFrameSafe(() => ran = true);
            expect(ran, isFalse, reason: 'must not run inside the build phase');
            return const SizedBox();
          },
        ),
      ),
    );
    // Same frame, not the next one: post-frame callbacks of the frame we were already inside.
    // 同一帧、不是下一帧:延到我们本就身处其中的那一帧的后帧回调。
    expect(ran, isTrue);
  });
}

/// A scroller that jumps from INSIDE the layout phase — the synchronous way a real listener gets
/// notified mid-layout. Its listener dirties state exactly like the nine production sites do.
/// 从**布局阶段内部**跳转的滚动体——真实监听器在布局中途被同步通知的路径;其监听器弄脏状态的写法与生产侧
/// 那九处完全一致。
class _Subject extends StatefulWidget {
  const _Subject({required this.controller});

  final ScrollController controller;

  @override
  State<_Subject> createState() => _SubjectState();
}

class _SubjectState extends State<_Subject> {
  bool _past = false;
  bool _jumped = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final past = widget.controller.offset > 100;
    runFrameSafe(() {
      if (mounted && past != _past) setState(() => _past = past);
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, _) {
      if (!_jumped && widget.controller.hasClients) {
        _jumped = true;
        widget.controller.jumpTo(300);
      }
      return SingleChildScrollView(
        controller: widget.controller,
        child: SizedBox(height: 4000, child: Text('$_past')),
      );
    },
  );
}
