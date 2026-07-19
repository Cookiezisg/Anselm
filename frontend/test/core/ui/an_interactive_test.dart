import 'package:anselm/core/ui/an_interactive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// AnInteractive is the activation substrate for every control — the key contract is that a DISABLED
// surface activates by neither pointer nor keyboard (the demo matrix's disabled-passthrough gate).
// AnInteractive 是所有控件的激活基座——关键契约:禁用时指针与键盘都不激活(对齐 demo disabled 门)。
void main() {
  // The `selected` contract. Measured against the STOCK TextButton, which is the baseline that exposed
  // the defect: ours used to add `hasSelectedState` to EVERY control in the app because the prop was a
  // non-nullable bool that always annotated. Asserted on the semantics tree, never on the prop.
  // selected 契约。以**原装 TextButton** 为基线(正是它照出缺陷:我们给全 app 每个控件都加了 hasSelectedState,
  // 因为该 prop 曾是恒annotate 的非空 bool)。断言打在语义树上、不打在 prop 上。
  group('selected: «say no by not saying»', () {
    Set<String> flagsOf(WidgetTester t, Finder f) {
      final d = t.getSemantics(f).getSemanticsData();
      return {
        if (d.flagsCollection.isSelected.toBoolOrNull() == true) 'isSelected',
        if (d.flagsCollection.isSelected.toBoolOrNull() != null) 'hasSelectedState',
        if (d.flagsCollection.isButton) 'isButton',
      };
    }

    testWidgets('omitted → identical to a stock TextButton (no selection flags at all)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: Column(children: [
            TextButton(onPressed: () {}, child: const Text('Stock')),
            AnInteractive(onTap: () {}, builder: (_, _) => const Text('Ours')),
          ]),
        ),
      ));
      final stock = flagsOf(tester, find.byType(TextButton));
      final ours = flagsOf(tester, find.byType(AnInteractive));
      expect(stock, {'isButton'});
      expect(ours, stock,
          reason: '不传 selected 的控件必须与原装按钮一字不差——「没有选中这个概念」');
    });

    testWidgets('false → still says NOTHING (an explicit false is announced as SELECTED on mac/win)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Center(child: AnInteractive(onTap: () {}, selected: false, builder: (_, _) => const Text('x'))),
      ));
      expect(flagsOf(tester, find.byType(AnInteractive)), {'isButton'},
          reason: 'kFlutterTristateFalse==2 在 bridge 的 bool 形参里是真值 → false 会被念成「已选中」');
    });

    testWidgets('true → isSelected + hasSelectedState (the one thing that IS safe to say)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Center(child: AnInteractive(onTap: () {}, selected: true, builder: (_, _) => const Text('x'))),
      ));
      expect(flagsOf(tester, find.byType(AnInteractive)),
          {'isButton', 'isSelected', 'hasSelectedState'});
    });

    testWidgets('the VISUAL state is untouched by the a11y workaround (false ≠ selected on screen)',
        (tester) async {
      // The wire goes quiet; the paint must not. WidgetState.selected still drives every tint/ring.
      // 线上闭嘴,画面不许:WidgetState.selected 照旧驱动一切底色/环。
      late Set<WidgetState> off;
      late Set<WidgetState> on;
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: Column(children: [
            AnInteractive(onTap: () {}, selected: false, builder: (_, s) { off = s; return const Text('a'); }),
            AnInteractive(onTap: () {}, selected: true, builder: (_, s) { on = s; return const Text('b'); }),
          ]),
        ),
      ));
      expect(off.contains(WidgetState.selected), isFalse);
      expect(on.contains(WidgetState.selected), isTrue);
    });
  });

  testWidgets('enabled surface activates by tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: AnInteractive(
          onTap: () => taps++,
          builder: (_, _) => const SizedBox(width: 48, height: 48),
        ),
      ),
    ));
    await tester.tap(find.byType(AnInteractive));
    expect(taps, 1);
  });

  testWidgets('pressed state is surfaced while the pointer is down', (tester) async {
    late Set<WidgetState> states;
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: AnInteractive(
          onTap: () {},
          builder: (_, s) {
            states = s;
            return const SizedBox(width: 48, height: 48);
          },
        ),
      ),
    ));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(AnInteractive)));
    await tester.pump();
    expect(states.contains(WidgetState.pressed), isTrue);
    await gesture.up();
    await tester.pump();
    expect(states.contains(WidgetState.pressed), isFalse);
  });

  testWidgets('enabled surface activates by keyboard (Enter / Space)', (tester) async {
    var taps = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: AnInteractive(
          focusNode: focus,
          onTap: () => taps++,
          builder: (_, _) => const SizedBox(width: 48, height: 48),
        ),
      ),
    ));
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1, reason: 'Enter activates a focused surface');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(taps, 2, reason: 'Space activates a focused surface');
  });

  testWidgets('disabled surface is NOT focusable and does not activate by keyboard', (tester) async {
    var taps = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: AnInteractive(
          enabled: false,
          focusNode: focus,
          onTap: () => taps++,
          builder: (_, _) => const SizedBox(width: 48, height: 48),
        ),
      ),
    ));
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isFalse, reason: 'disabled → non-focusable (FAD enabled:false)');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('disabled surface is inert (no tap, carries disabled state)', (tester) async {
    var taps = 0;
    late Set<WidgetState> states;
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: AnInteractive(
          enabled: false,
          onTap: () => taps++,
          builder: (_, s) {
            states = s;
            return const SizedBox(width: 48, height: 48);
          },
        ),
      ),
    ));
    await tester.tap(find.byType(AnInteractive), warnIfMissed: false);
    expect(taps, 0);
    expect(states.contains(WidgetState.disabled), isTrue);
  });

  testWidgets('expanded passes through to Semantics for disclosure surfaces (collapsible row / detail)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: AnInteractive(
          onTap: () {},
          expanded: true,
          builder: (_, _) => const SizedBox(width: 48, height: 48),
        ),
      ),
    ));
    // isExpanded is a Tristate; toBoolOrNull() → true/false/null. expanded:true → true.
    // isExpanded 是 Tristate;toBoolOrNull() → true/false/null。expanded:true → true。
    final node = tester.getSemantics(find.byType(AnInteractive));
    expect(node.flagsCollection.isExpanded.toBoolOrNull(), isTrue);
    handle.dispose();
  });

  testWidgets('no expanded → not a disclosure control (expanded state unset)', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: AnInteractive(onTap: () {}, builder: (_, _) => const SizedBox(width: 48, height: 48)),
      ),
    ));
    // null (Tristate.none) — no spurious "collapsed" announcement on non-disclosure rows. 不误报折叠。
    expect(tester.getSemantics(find.byType(AnInteractive)).flagsCollection.isExpanded.toBoolOrNull(), isNull);
    handle.dispose();
  });
}
