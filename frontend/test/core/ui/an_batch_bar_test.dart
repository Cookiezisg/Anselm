import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnBatchBar (WRK-069 判决② S2b) — the multi-select batch bar + its AnBatchCheck companion.
// Pins: count text, action tone→button voice, busy freeze, count≤0 floor, checkbox toggle + a11y.

Widget _host(Widget child) => TranslationProvider(
  child: MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('renders the count, fires actions and clear', (tester) async {
    var ran = 0;
    var cleared = 0;
    await tester.pumpWidget(
      _host(
        AnBatchBar(
          count: 3,
          actions: [
            BatchAction(label: '批量批准', tone: AnTone.accent, onRun: () => ran++),
            BatchAction(
              label: '批量拒绝',
              tone: AnTone.danger,
              onRun: () => ran += 10,
            ),
          ],
          onClear: () => cleared++,
        ),
      ),
    );
    await tester.pump();
    final tr = Translations.of(tester.element(find.byType(AnBatchBar)));
    expect(find.text(tr.feedback.batch.selected(n: '3')), findsOneWidget);

    await tester.tap(find.text('批量批准'));
    await tester.tap(find.text('批量拒绝'));
    expect(ran, 11);

    await tester.tap(find.bySemanticsLabel(tr.feedback.batch.clear));
    expect(cleared, 1);
  });

  testWidgets('busy freezes every action AND the clear', (tester) async {
    var fired = 0;
    await tester.pumpWidget(
      _host(
        AnBatchBar(
          count: 2,
          busy: true,
          actions: [BatchAction(label: 'go', onRun: () => fired++)],
          onClear: () => fired++,
        ),
      ),
    );
    await tester.pump();
    final tr = Translations.of(tester.element(find.byType(AnBatchBar)));
    await tester.tap(find.text('go'), warnIfMissed: false);
    await tester.tap(
      find.bySemanticsLabel(tr.feedback.batch.clear),
      warnIfMissed: false,
    );
    expect(fired, 0);
  });

  testWidgets('count ≤ 0 renders nothing (no selection, no bar)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(AnBatchBar(count: 0, actions: const [], onClear: () {})),
    );
    await tester.pump();
    expect(find.byType(DecoratedBox), findsNothing);
  });

  testWidgets(
    'overlong labels ellipsize inside a narrow host instead of overflowing',
    (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            child: AnBatchBar(
              count: 99999,
              actions: [
                BatchAction(
                  label: '把选中的全部重新排队并等待下一个调度窗口再统一执行' * 3,
                  onRun: () {},
                ),
                BatchAction(label: '批量拒绝', tone: AnTone.danger, onRun: () {}),
              ],
              onClear: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '窄宿主不溢出');
    },
  );

  testWidgets('AnBatchCheck toggles and carries checked semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    bool? got;
    await tester.pumpWidget(
      _host(
        AnBatchCheck(
          checked: false,
          semanticLabel: '选择 周报生成',
          onChanged: (v) => got = v,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(AnBatchCheck));
    expect(got, isTrue, reason: '未选→选');

    await tester.pumpWidget(
      _host(
        AnBatchCheck(
          checked: true,
          semanticLabel: '选择 周报生成',
          onChanged: (v) => got = v,
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.getSemantics(find.byType(AnBatchCheck)),
      // isButton rides in from the AnInteractive substrate (kit-wide actionable voice); the checkbox's
      // OWN channel is `checked`. NOT hasSelectedState — a checkbox is checked, never «selected», and
      // the old assertion pinned that stray flag in place (it came from AnInteractive.selected being a
      // non-nullable bool). button 来自 AnInteractive 基底;复选框自己的通道是 checked。**不含**
      // hasSelectedState——复选框只有 checked、没有「选中」,旧断言把那面走私旗标钉住了。
      matchesSemantics(
        label: '选择 周报生成',
        isChecked: true,
        hasCheckedState: true,
        hasTapAction: true,
        isFocusable: true,
        hasEnabledState: true,
        isEnabled: true,
        hasFocusAction: true,
        isButton: true,
      ),
    );
    await tester.tap(find.byType(AnBatchCheck));
    expect(got, isFalse, reason: '已选→取消');
    handle.dispose();
  });
}
