import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// T6 (leak-hunt 0717): a TextPainter owns a native ui.Paragraph that is released ONLY by dispose() —
// 3 of 4 measure sites forgot it, leaking one native paragraph per keystroke/build. All four now route
// through measureText, which disposes in a `finally`. These tests count the FlutterMemoryAllocations
// creation/disposal events for TextPainter (the SAME signal leak_tracker consumes) and assert the
// balance is even (notDisposed == 0), deterministically — NO GC needed.
//
// Isolation from framework noise: the framework's own RenderParagraph painters are created ONCE at mount
// and reused across rebuilds (they dispatch no new events until teardown, which itself leaves a stable
// off-by-one). So we attach the ledger AFTER the initial mount and count only what a burst of 20 pure
// rebuilds dispatches: each rebuild re-runs the widget's measure site (a fresh painter, created AND
// disposed in-build) while the framework painters sit still. A leaking site would make `created` outrun
// `disposed` by ~20; a correct site keeps them equal. Enabled because kFlutterMemoryAllocationsEnabled =
// ... || kDebugMode holds under `flutter test`; the created>0 guard fails loudly if instrumentation is
// ever off (no vacuous pass).
//
// T6:TextPainter 持原生 paragraph、仅 dispose 释放,4 站漏 3(每击键/build 漏一个);现全走 measureText(finally
// 必 dispose)。测试数 TextPainter 的创建/销毁事件(与 leak_tracker 同源信号),断言收支相抵(notDisposed==0)、
// 确定无需 GC。隔离框架噪声:框架自己的 RenderParagraph painter 在挂载时一次性建、rebuild 间复用(不再派事件),
// 故在初始挂载后才挂账,只数 20 次纯 rebuild 期间的事件——每次 rebuild 重跑量测站(新 painter,当帧建当帧毁),
// 框架 painter 岿然不动。漏的站会让 created 比 disposed 多 ~20,不漏则恒等。created>0 守卫防空过。

class _TextPainterLedger {
  int created = 0;
  int disposed = 0;

  void _on(ObjectEvent event) {
    if (event.object is! TextPainter) return;
    if (event is ObjectCreated) {
      created++;
    } else if (event is ObjectDisposed) {
      disposed++;
    }
  }

  void attach() => FlutterMemoryAllocations.instance.addListener(_on);
  void detach() => FlutterMemoryAllocations.instance.removeListener(_on);
}

void main() {
  Widget host(Widget child) => TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(body: Center(child: SizedBox(width: 460, height: 360, child: child))),
        ),
      );

  // Mount, settle, then attach the ledger and force 20 pure rebuilds ([build] returns a fresh but
  // same-config instance so the element updates and re-runs the measure site). Every measure-site painter
  // must be disposed → created stays equal to disposed. 挂载→settle→挂账→逼 20 次纯 rebuild,量测站每个
  // painter 都要被销毁 → created 恒等 disposed。
  Future<void> expectNoLeak(WidgetTester tester, Widget Function() build) async {
    await tester.pumpWidget(host(build()));
    await tester.pumpAndSettle();
    final ledger = _TextPainterLedger()..attach();
    for (var i = 0; i < 20; i++) {
      await tester.pumpWidget(host(build()));
      await tester.pump();
    }
    ledger.detach();
    expect(ledger.created, greaterThan(0),
        reason: 'guard must not be vacuous — rebuilds must re-run the measure site');
    expect(ledger.disposed, ledger.created,
        reason: 'T6: measure-site TextPainters all disposed — no growth across 20 rebuilds (notDisposed == 0)');
  }

  test('measureText disposes its TextPainter — normal AND throwing read paths', () {
    final ledger = _TextPainterLedger()..attach();
    final w = measureText(const TextSpan(text: 'hello', style: TextStyle(fontSize: 14)),
        read: (tp) => tp.width);
    expect(w, greaterThan(0));
    // finally must still dispose when read throws. read 抛异常时 finally 仍须 dispose。
    expect(
      () => measureText<int>(const TextSpan(text: 'x', style: TextStyle(fontSize: 14)),
          read: (_) => throw StateError('boom')),
      throwsStateError,
    );
    ledger.detach();
    expect(ledger.created, 2);
    expect(ledger.disposed, 2, reason: 'both painters disposed — the normal path and the throwing path');
  });

  testWidgets('AnOceanSwitcher (labelWidth measure) leaves no undisposed TextPainter', (tester) async {
    await expectNoLeak(
      tester,
      () => AnOceanSwitcher(
        selectedIndex: 0,
        onSelect: (_) {},
        items: const [
          AnOceanItem(id: 'chat', icon: Icons.chat_bubble_outline, label: 'Chat'),
          AnOceanItem(id: 'entities', icon: Icons.category_outlined, label: 'Entities'),
        ],
      ),
    );
  });

  testWidgets('AnVersionDiff (gutter measure) leaves no undisposed TextPainter', (tester) async {
    await expectNoLeak(tester, () => AnVersionDiff(before: 'alpha\nbeta', after: 'alpha\ngamma'));
  });

  testWidgets('AnComposer (line-count measure) leaves no undisposed TextPainter', (tester) async {
    // Stable controller/focus across rebuilds — else the TextField would rebuild its own RenderEditable
    // painter and pollute the count. 控制器/焦点跨 rebuild 稳定,否则 TextField 会重建自己的 painter 污染计数。
    final controller = TextEditingController(text: 'a composer line long enough to actually measure');
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await expectNoLeak(
      tester,
      () => AnComposer(controller: controller, focusNode: focus, placeholder: 'Message'),
    );
  });
}
