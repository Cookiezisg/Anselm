import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_crumbs.dart';
import 'package:anselm/core/ui/an_interactive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnCrumbs = the breadcrumb TRAIL (用户 0719 面包屑律): structured [AnCrumb] segments joined by a faint «/»
// the PRIMITIVE renders (never a caller-joined "A / B" string); each segment navigable via its onTap; a
// deep chain folds its middle to «…». AnCrumbs 契约:分段 + 原语渲斜杠 + 可点导航 + 深链折中段。
void main() {
  Widget host(Widget child, {double w = 400}) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(body: Center(child: SizedBox(width: w, child: child))),
      );

  testWidgets('renders each segment + a faint «/» separator BETWEEN them (原语渲分隔符)', (tester) async {
    await tester.pumpWidget(host(const AnCrumbs([AnCrumb('Scheduler'), AnCrumb('数据清洗流水线')])));
    expect(find.text('Scheduler'), findsOneWidget);
    expect(find.text('数据清洗流水线'), findsOneWidget);
    // Exactly one separator between two segments — the «/» is the primitive's, not a joined string. 一根「/」。
    expect(find.text('/'), findsOneWidget);
  });

  testWidgets('a single segment renders no separator', (tester) async {
    await tester.pumpWidget(host(const AnCrumbs([AnCrumb('Entities')])));
    expect(find.text('Entities'), findsOneWidget);
    expect(find.text('/'), findsNothing);
  });

  testWidgets('empty → nothing', (tester) async {
    await tester.pumpWidget(host(const AnCrumbs([])));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('a segment with onTap is clickable and navigates to THAT level', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(host(AnCrumbs([
      AnCrumb('Scheduler', onTap: () => tapped++),
      const AnCrumb('数据清洗流水线'),
    ])));
    await tester.tap(find.text('Scheduler'));
    expect(tapped, 1);
  });

  testWidgets('an onTap-less segment is INERT (not a button, no AnInteractive)', (tester) async {
    // The direct-parent kind / a root you're already at has no navigable target → plain text, not a
    // control. 无去处的段=纯文本、非控件。
    await tester.pumpWidget(host(const AnCrumbs([AnCrumb('Entities'), AnCrumb('Function')])));
    // Only inert segments here → zero AnInteractive. 全惰性→零 AnInteractive。
    expect(find.byType(AnInteractive), findsNothing);
  });

  testWidgets('a clickable segment IS an AnInteractive (click cursor + button semantics)', (tester) async {
    await tester.pumpWidget(host(AnCrumbs([AnCrumb('Scheduler', onTap: () {})])));
    expect(find.byType(AnInteractive), findsOneWidget);
  });

  testWidgets('a deep chain folds its middle to «…», keeping the first + the direct parent (Notion 同款)',
      (tester) async {
    // 5 segments, foldAfter 3 → [Documents, …, 父]. 深链折中段:留首段+直属父。
    await tester.pumpWidget(host(const AnCrumbs(
      [
        AnCrumb('Documents'),
        AnCrumb('A'),
        AnCrumb('B'),
        AnCrumb('C'),
        AnCrumb('父'),
      ],
      foldAfter: 3,
    )));
    expect(find.text('Documents'), findsOneWidget); // first kept 首段留
    expect(find.text('父'), findsOneWidget); // direct parent kept 直属父留
    expect(find.text('…'), findsOneWidget); // middle collapsed 中段折
    expect(find.text('A'), findsNothing); // middle gone 中段隐
    expect(find.text('B'), findsNothing);
    expect(find.text('C'), findsNothing);
    // Documents / … / 父 → two separators. 两根分隔。
    expect(find.text('/'), findsNWidgets(2));
  });

  testWidgets('a chain within foldAfter renders in full (no fold)', (tester) async {
    await tester.pumpWidget(host(const AnCrumbs(
      [AnCrumb('Documents'), AnCrumb('父')],
      foldAfter: 3,
    )));
    expect(find.text('…'), findsNothing);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('父'), findsOneWidget);
  });
}
