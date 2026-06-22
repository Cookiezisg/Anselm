import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) =>
      MaterialApp(debugShowCheckedModeBanner: false, theme: AnTheme.light(), home: Scaffold(body: child));

  testWidgets('full input fills a bounded parent (empty does not collapse)', (tester) async {
    await tester.pumpWidget(host(Center(child: SizedBox(width: 500, child: AnInput(full: true)))));
    await tester.pump();
    expect(tester.getSize(find.byType(AnInput)).width, 500);
  });

  testWidgets('full input in an unbounded parent falls back to inputMin (no crash)', (tester) async {
    await tester.pumpWidget(host(Row(children: const [AnInput(full: true)])));
    expect(tester.takeException(), isNull);
  });

  testWidgets('focusNode swap rewires without throwing', (tester) async {
    final a = FocusNode();
    final b = FocusNode();
    Widget build(FocusNode f) => host(AnInput(focusNode: f, full: true));
    await tester.pumpWidget(build(a));
    await tester.pumpWidget(build(b)); // swap → didUpdateWidget moves the listener
    expect(tester.takeException(), isNull);
    b.requestFocus();
    await tester.pump();
    expect(tester.takeException(), isNull);
    // Release the widget before disposing external nodes so AnInput.dispose detaches cleanly.
    await tester.pumpWidget(host(const SizedBox()));
    a.dispose();
    b.dispose();
  });
}
