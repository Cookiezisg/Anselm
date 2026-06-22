import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) =>
      MaterialApp(debugShowCheckedModeBanner: false, theme: AnTheme.light(), home: Scaffold(body: child));

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
