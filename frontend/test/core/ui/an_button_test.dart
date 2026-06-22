import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Real-window regressions the matrix (fixed-width cells) missed.
void main() {
  Widget host(Widget child) =>
      MaterialApp(debugShowCheckedModeBanner: false, theme: AnTheme.light(), home: Scaffold(body: child));

  testWidgets('block button degrades (no crash) in an unbounded-width parent', (tester) async {
    // A Row gives its children unbounded width; a block button there used to expand to infinity
    // and throw. Now it degrades to intrinsic. 行给子无界宽,块级钮曾撑到无穷而崩,现退化为自适应。
    await tester.pumpWidget(host(Row(children: [AnButton(label: 'X', block: true, onPressed: () {})])));
    expect(tester.takeException(), isNull);
  });

  testWidgets('block button fills a bounded parent', (tester) async {
    await tester.pumpWidget(host(Center(child: SizedBox(width: 400, child: AnButton(label: 'Wide', block: true, onPressed: () {})))));
    expect(tester.getSize(find.byType(AnButton)).width, 400);
  });
}
