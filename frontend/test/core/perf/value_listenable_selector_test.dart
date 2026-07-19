import 'package:anselm/core/perf/value_listenable_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// C-025: the selective builder that lets a stage hang off the whole-conversation transcript notifier yet
/// rebuild ONLY when its own block's revision moves. These lock the two behaviours the fix relies on:
/// selective rebuild, and the didUpdateWidget baseline re-derive (a reused element handed a new selector).
/// C-025:选择性 builder——舞台挂整会话通知器却只在自身块 revision 变时重建。锁两行为:选择性重建 + 基线重算。
void main() {
  Widget host(Widget child) =>
      MaterialApp(home: Directionality(textDirection: TextDirection.ltr, child: child));

  testWidgets('rebuilds ONLY when the selected slice changes, not on every notification', (tester) async {
    final vn = ValueNotifier<int>(0);
    var builds = 0;
    await tester.pumpWidget(host(ValueListenableSelector<int, int>(
      listenable: vn,
      selector: (v) => v ~/ 10, // the slice = the tens place; unchanged for 0..9 切片=十位
      builder: (context, v) {
        builds++;
        return Text('$v');
      },
    )));
    expect(builds, 1); // initial build

    vn.value = 3;
    await tester.pump();
    expect(builds, 1); // slice still 0 — NO rebuild (the whole point) 切片不变→不重建

    vn.value = 9;
    await tester.pump();
    expect(builds, 1); // slice still 0

    vn.value = 12;
    await tester.pump();
    expect(builds, 2); // slice 0→1 → rebuild 切片变→重建

    vn.value = 15;
    await tester.pump();
    expect(builds, 2); // slice still 1 — no rebuild

    vn.dispose();
  });

  testWidgets('didUpdateWidget re-derives the baseline when the selector changes (no stale-skip)',
      (tester) async {
    final vn = ValueNotifier<int>(100);
    var builds = 0;
    var watchTens = false; // false: watch the hundreds digit; true: the tens digit 看百位/十位
    late StateSetter setHost;

    await tester.pumpWidget(host(StatefulBuilder(builder: (context, setState) {
      setHost = setState;
      return ValueListenableSelector<int, int>(
        listenable: vn,
        selector: (v) => watchTens ? (v ~/ 10) % 10 : (v ~/ 100) % 10,
        builder: (context, v) {
          builds++;
          return Text('$v');
        },
      );
    })));
    expect(builds, 1); // initial; hundreds(100)=1

    // Swap the selector to watch the TENS digit — a reused element with a new selector closure. The
    // baseline must re-derive to tens(100)=0. 切 selector 看十位(同元素新闭包),基线须重算到 0。
    setHost(() => watchTens = true);
    await tester.pump();
    expect(builds, 2); // rebuilt by the widget update itself

    // A change that moves the TENS digit (100→110) MUST rebuild — proves the baseline is the tens slice
    // now, not the stale hundreds one. 动十位(100→110)须重建=基线已重算到十位切片。
    vn.value = 110;
    await tester.pump();
    expect(builds, 3);

    // A change that does NOT move the tens digit (110→115) must NOT rebuild. 不动十位→不重建。
    vn.value = 115;
    await tester.pump();
    expect(builds, 3);

    vn.dispose();
  });
}
