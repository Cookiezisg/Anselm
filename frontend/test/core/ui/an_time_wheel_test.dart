import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// AnTimeWheel (0717-深夜拍板:「时刻不打字,改滚轮」) — the batteries pin the desktop input contract:
// ONE mouse-wheel notch = ONE step (explicit Listener drive, not the framework wheel's flaky
// pointer-scroll), ↑/↓ per focused column, looping wrap at both ends, and external value re-seat.
// 电池钉桌面输入契约:滚轮一格一步/↑↓ 步进/两端循环/外部值重新落座。

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );

  Widget wheel(
    List<AnWheelTime> log, {
    AnWheelTime initial = (hour: 9, minute: 30),
  }) => StatefulBuilder(
    builder: (context, setState) {
      final v = log.isEmpty ? initial : log.last;
      return AnTimeWheel(
        value: v,
        onChanged: (n) => setState(() => log.add(n)),
        semanticLabel: '从',
      );
    },
  );

  Future<void> notch(WidgetTester tester, Finder column, double dy) async {
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(tester.getCenter(column));
    await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
    await tester.pumpAndSettle();
  }

  testWidgets('renders zero-padded HH:MM with the selected pair emphasised', (
    tester,
  ) async {
    await tester.pumpWidget(host(wheel([])));
    expect(find.text('09'), findsWidgets);
    expect(find.text('30'), findsWidgets);
    expect(find.text(':'), findsOneWidget);
  });

  testWidgets('ONE mouse-wheel notch = ONE step, per column', (tester) async {
    final log = <AnWheelTime>[];
    await tester.pumpWidget(host(wheel(log)));
    final cols = find.byType(ListWheelScrollView);
    await notch(tester, cols.first, 20); // hour +1
    expect(log.last, (hour: 10, minute: 30));
    await notch(tester, cols.last, -20); // minute -1
    expect(log.last, (hour: 10, minute: 29));
  });

  testWidgets('the wheel LOOPS: 23 scrolls forward to 00, 00 back to 59', (
    tester,
  ) async {
    final log = <AnWheelTime>[];
    await tester.pumpWidget(host(wheel(log, initial: (hour: 23, minute: 0))));
    final cols = find.byType(ListWheelScrollView);
    await notch(tester, cols.first, 20);
    expect(log.last.hour, 0, reason: '23→00 跨午夜,平列表会死胡同');
    await notch(tester, cols.last, -20);
    expect(log.last.minute, 59, reason: '00→59 反向同理');
  });

  testWidgets('↑/↓ step the FOCUSED column', (tester) async {
    final log = <AnWheelTime>[];
    await tester.pumpWidget(host(wheel(log)));
    Focus.of(
      tester.element(find.byType(ListWheelScrollView).first),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(log.last, (hour: 10, minute: 30));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(log.last, (hour: 9, minute: 30));
  });

  testWidgets(
    'an EXTERNAL value re-seats the wheel without an onChanged echo',
    (tester) async {
      var value = (hour: 9, minute: 30);
      final log = <AnWheelTime>[];
      late StateSetter rebuild;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return AnTimeWheel(
                value: value,
                onChanged: log.add,
                semanticLabel: '从',
              );
            },
          ),
        ),
      );
      rebuild(() => value = (hour: 17, minute: 5));
      await tester.pumpAndSettle();
      expect(find.text('17'), findsWidgets, reason: '开面板预填/宿主重置须重新落座');
      expect(log, isEmpty, reason: '外部落座不是用户操作,不得回声 onChanged');
    },
  );
}
