import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The dropdown opens an overlay menu — the matrix only builds the trigger, so the menu's open/
// select/dismiss + the massive-list (海量) overflow are covered here.
// 下拉开浮层菜单——矩阵只 build 触发器,故菜单的开/选/关 + 海量溢出在此覆盖。
void main() {
  Widget host(Widget child) => TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(body: Center(child: SizedBox(width: 280, child: child))),
        ),
      );

  const opts = [
    AnDropdownOption(value: 'a', label: 'Apple'),
    AnDropdownOption(value: 'b', label: 'Banana'),
  ];

  testWidgets('opens, selects a value, closes', (tester) async {
    String? picked;
    String? value;
    await tester.pumpWidget(host(StatefulBuilder(
      builder: (context, setState) => AnDropdown<String>(
        options: opts,
        value: value,
        onChanged: (v) {
          picked = v;
          setState(() => value = v);
        },
      ),
    )));

    expect(find.text('Banana'), findsNothing); // menu closed
    await tester.tap(find.byType(AnDropdown<String>));
    await tester.pumpAndSettle();
    expect(find.text('Apple'), findsOneWidget); // menu open
    expect(find.text('Banana'), findsOneWidget);

    await tester.tap(find.text('Banana'));
    await tester.pumpAndSettle();
    expect(picked, 'b');
    expect(find.text('Banana'), findsOneWidget); // echoed in trigger
    expect(find.text('Apple'), findsNothing); // menu dismissed
  });

  testWidgets('disabled does not open', (tester) async {
    await tester.pumpWidget(host(const AnDropdown<String>(
      options: opts,
      value: null,
      onChanged: null,
      enabled: false,
    )));
    await tester.tap(find.byType(AnDropdown<String>), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Apple'), findsNothing);
  });

  testWidgets('block dropdown in a wide container opens menu without non-normalized constraints', (tester) async {
    // Regression: a full-width trigger makes the menu's minWidth large; the maxWidth cap must rise
    // with it or BoxConstraints goes minWidth>maxWidth (the real-run white/red error).
    // 回归:块级触发器→菜单 minWidth 大,maxWidth 上限须随之抬,否则 min>max 非法(真跑报错)。
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 900,
            child: AnDropdown<String>(options: opts, value: 'a', block: true, onChanged: (_) {}),
          ),
        ),
      ),
    ));
    await tester.tap(find.byType(AnDropdown<String>));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Banana'), findsOneWidget);
  });

  testWidgets('massive option list opens and scrolls without overflow', (tester) async {
    final many = [for (var i = 0; i < 80; i++) AnDropdownOption(value: '$i', label: 'Option $i')];
    await tester.pumpWidget(host(AnDropdown<String>(options: many, value: '0', onChanged: (_) {})));
    await tester.tap(find.byType(AnDropdown<String>));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Option 0'), findsWidgets);
    // the menu is scrollable — drag up and confirm a later option surfaces
    await tester.drag(find.text('Option 0').last, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
