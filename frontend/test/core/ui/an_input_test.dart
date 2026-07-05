import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) =>
      MaterialApp(debugShowCheckedModeBanner: false, theme: AnTheme.light(), home: Scaffold(body: child));

  testWidgets('caret is derived from the effective style (fontSize + caretRise), not a fixed constant', (tester) async {
    // Default body 13 → 16, exactly the old constant (no regression for chrome inputs). 默认 13→16。
    await tester.pumpWidget(host(const AnInput()));
    var field = tester.widget<TextField>(find.byType(TextField));
    expect(field.cursorHeight, AnText.body.fontSize! + AnSize.caretRise);
    expect(field.cursorWidth, AnSize.caret);

    // A style-overridden field scales its caret with its glyphs — the H2-24 rename / 15 content
    // value no longer get the stubby 13-era caret. 覆写样式的字段光标随字走。
    await tester.pumpWidget(host(AnInput(style: AnText.h2)));
    field = tester.widget<TextField>(find.byType(TextField));
    expect(field.cursorHeight, AnText.h2.fontSize! + AnSize.caretRise);

    await tester.pumpWidget(host(AnInput(style: AnText.valueReading())));
    field = tester.widget<TextField>(find.byType(TextField));
    expect(field.cursorHeight, AnText.reading.fontSize! + AnSize.caretRise);
  });

  testWidgets('full input fills a bounded parent (empty does not collapse)', (tester) async {
    await tester.pumpWidget(host(Center(child: SizedBox(width: 500, child: AnInput(block: true)))));
    await tester.pump();
    expect(tester.getSize(find.byType(AnInput)).width, 500);
  });

  testWidgets('full input in an unbounded parent falls back to inputMin (no crash)', (tester) async {
    await tester.pumpWidget(host(Row(children: const [AnInput(block: true)])));
    expect(tester.takeException(), isNull);
  });

  testWidgets('focusNode swap actually moves the listener (focusing the new node deepens the border)', (tester) async {
    final a = FocusNode();
    final b = FocusNode();
    Widget build(FocusNode f) => host(AnInput(focusNode: f, block: true));
    await tester.pumpWidget(build(a));
    await tester.pumpWidget(build(b)); // swap → didUpdateWidget must move the listener to b
    expect(tester.takeException(), isNull);

    Color borderColor() {
      final box = tester.widget<AnimatedContainer>(
          find.descendant(of: find.byType(AnInput), matching: find.byType(AnimatedContainer)));
      return ((box.decoration! as BoxDecoration).border! as Border).top.color;
    }

    final unfocused = borderColor();
    b.requestFocus();
    await tester.pumpAndSettle();
    // If the listener were still on the OLD node, focusing b wouldn't update _focused → no change.
    expect(borderColor(), isNot(unfocused), reason: 'focusing the swapped-in node must deepen the border');

    await tester.pumpWidget(host(const SizedBox())); // release before disposing external nodes
    a.dispose();
    b.dispose();
  });
}
