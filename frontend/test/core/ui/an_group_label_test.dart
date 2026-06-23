import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnGroupLabel is the single source for small uppercase section/group captions. G3.2 made [padding]
// overridable so AnSection's caption reuses the same ink/weight without the rail-proximity insets.
// AnGroupLabel = 小标题单源;G3.2 让 padding 可覆盖,Section caption 复用同源字色/字重、去掉 rail 内距。
void main() {
  Widget host(Widget child) => MaterialApp(theme: AnTheme.light(), home: Scaffold(body: child));

  Padding labelPadding(WidgetTester tester) => tester.widget<Padding>(
        find.descendant(of: find.byType(AnGroupLabel), matching: find.byType(Padding)),
      );

  testWidgets('uppercases the label', (tester) async {
    await tester.pumpWidget(host(const AnGroupLabel('inputs')));
    expect(find.text('INPUTS'), findsOneWidget);
  });

  testWidgets('default padding follows proximity (more above, less below)', (tester) async {
    await tester.pumpWidget(host(const AnGroupLabel('inputs')));
    expect(labelPadding(tester).padding, const EdgeInsets.fromLTRB(AnSpace.s4, AnSpace.s8, AnSpace.s4, AnSpace.s4));
  });

  testWidgets('padding override drops the rail insets (AnSection caption reuse path)', (tester) async {
    await tester.pumpWidget(host(const AnGroupLabel('inputs', padding: EdgeInsets.zero)));
    expect(labelPadding(tester).padding, EdgeInsets.zero);
  });
}
