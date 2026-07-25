import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnScrollBehavior = suppress the scrollbar, used locally where the design hides it. That is now its WHOLE
// contract.
//
// It used to also add PointerDeviceKind.mouse to dragDevices, and the test below asserted that — i.e. the
// suite was pinning the defect in place. Flutter's default set excludes mouse deliberately, so that text
// inside scrollable containers stays selectable, and that one addition made every SelectionArea in the app
// inert (TS 红线①). The assertion is inverted here rather than deleted, so the reversal is on the record;
// the standing guard lives in test/guards/drag_devices_guard_test.dart.
//
// AnScrollBehavior 的契约=隐滚动条,局部用于设计上要隐藏滚动条之处。**现在这就是它的全部契约。**
//
// 它原先还把 `PointerDeviceKind.mouse` 加进 dragDevices,而下面那条测试**断言了这一点**——也就是说,测试套件在
// 把这个缺陷钉住。Flutter 默认集**刻意**排除 mouse,以保滚动容器内的文字可选;仅这一处添加就让全 app 的
// SelectionArea 形同虚设(TS 红线①)。此处把断言**反转**而非删除,好让这次翻案留在记录里;常驻守卫在
// test/guards/drag_devices_guard_test.dart。
void main() {
  testWidgets('suppresses the scrollbar a scrollable would otherwise show', (
    tester,
  ) async {
    Widget host(ScrollBehavior? behavior) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 100,
          child: ScrollConfiguration(
            behavior:
                behavior ??
                ScrollConfiguration.of(WidgetsBinding.instance.rootElement!),
            child: ListView(
              children: [
                for (var i = 0; i < 50; i++)
                  SizedBox(height: 20, child: Text('row $i')),
              ],
            ),
          ),
        ),
      ),
    );
    // With AnScrollBehavior: no Scrollbar in the tree. 无滚动条。
    await tester.pumpWidget(host(const AnScrollBehavior()));
    expect(find.byType(Scrollbar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'drag devices EXCLUDE mouse (so text stays selectable) but keep trackpad',
    () {
      final devices = const AnScrollBehavior().dragDevices;
      expect(
        devices,
        isNot(contains(PointerDeviceKind.mouse)),
        reason: 'a mouse drag must select text, not scroll (TS 红线①)',
      );
      expect(devices, contains(PointerDeviceKind.trackpad));
    },
  );
}
