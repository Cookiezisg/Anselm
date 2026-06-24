import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnScrollBehavior = suppress the scrollbar (used locally where the design hides it) + enable mouse/trackpad
// drag-to-scroll. AnScrollBehavior 契约:隐滚动条 + 开鼠标拖滚。
void main() {
  testWidgets('suppresses the scrollbar a scrollable would otherwise show', (tester) async {
    Widget host(ScrollBehavior? behavior) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 100,
              child: ScrollConfiguration(
                behavior: behavior ?? ScrollConfiguration.of(WidgetsBinding.instance.rootElement!),
                child: ListView(children: [for (var i = 0; i < 50; i++) SizedBox(height: 20, child: Text('row $i'))]),
              ),
            ),
          ),
        );
    // With AnScrollBehavior: no Scrollbar in the tree. 无滚动条。
    await tester.pumpWidget(host(const AnScrollBehavior()));
    expect(find.byType(Scrollbar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('drag devices include mouse + trackpad (desktop drag-to-scroll)', () {
    final devices = const AnScrollBehavior().dragDevices;
    expect(devices, contains(PointerDeviceKind.mouse));
    expect(devices, contains(PointerDeviceKind.trackpad));
  });
}
