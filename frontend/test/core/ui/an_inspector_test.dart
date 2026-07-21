import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnInspector = right-island content shell: head (icon + title) + scrolling block-flow body; headless omits
// the head and lets the child fill. It lives inside an AnIsland (which draws the skin). AnInspector 契约。
void main() {
  Widget host(Widget child, {double w = 320, double h = 360}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AnTheme.light(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: w,
          height: h,
          child: AnIsland(padding: EdgeInsets.zero, child: child),
        ),
      ),
    ),
  );

  testWidgets('head renders icon + title; body blocks render', (tester) async {
    await tester.pumpWidget(
      host(
        AnInspector(
          title: 'normalize-input',
          icon: AnIcons.function,
          children: const [
            AnInfoCard(
              title: 'Overview',
              child: AnKv(rows: [AnKvRow('Kind', 'function')]),
            ),
          ],
        ),
      ),
    );
    expect(find.text('normalize-input'), findsOneWidget);
    expect(find.byIcon(AnIcons.function), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'head title is a header node (screen-reader heading navigation)',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(const AnInspector(title: 'normalize-input')),
      );
      expect(
        tester
            .getSemantics(find.text('normalize-input'))
            .flagsCollection
            .isHeader,
        isTrue,
      );
      handle.dispose();
    },
  );

  testWidgets('headless omits the head + fills with the child', (tester) async {
    await tester.pumpWidget(
      host(
        const AnInspector(
          headless: true,
          child: AnState(
            kind: AnStateKind.empty,
            size: AnStateSize.inset,
            title: 'Headless body',
          ),
        ),
      ),
    );
    expect(find.text('Headless body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'AnInspectorHead sub-row: leading + trailing value + a trailing widget (A-010 badge slot)',
    (tester) async {
      await tester.pumpWidget(
        host(
          AnInspectorHead(
            icon: AnIcons.workflow,
            label: 'nightly_sync',
            subLeading: 'Trigger',
            subTrailing: 'fr_9a8b · 3 nodes',
            subTrailingWidget: AnChip('running', tone: AnTone.accent),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('nightly_sync'), findsOneWidget);
      expect(find.text('Trigger'), findsOneWidget);
      expect(find.text('fr_9a8b · 3 nodes'), findsOneWidget);
      expect(
        find.text('running'),
        findsOneWidget,
      ); // the phase badge rides the new slot 相位徽在新槽
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long title ellipsizes; many blocks scroll without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AnInspector(
          title:
              'an-extremely-long-inspector-title-that-must-ellipsis-in-the-head-and-not-overflow',
          icon: AnIcons.workflow,
          children: [
            for (final t in const ['A', 'B', 'C', 'D', 'E', 'F'])
              AnInfoCard(
                title: t,
                child: const AnKv(rows: [AnKvRow('k', 'v')]),
              ),
          ],
        ),
        h: 200,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.byType(SingleChildScrollView),
      findsOneWidget,
    ); // body scrolls 可滚
  });
}
