import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnOceanHeader = crumb + H2 title (editable in place via AnInlineEdit) + actions + meta. AnOceanHeader 契约。
void main() {
  Widget host(Widget child, {double w = 600}) => TranslationProvider(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: w, child: child),
        ),
      ),
    ),
  );

  testWidgets('renders crumb (structured segments) + title + actions + meta', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AnOceanHeader(
          crumbs: const [AnCrumb('Workspace'), AnCrumb('Functions')],
          title: 'normalize-input',
          actions: [
            AnButton.iconOnly(
              AnIcons.more,
              semanticLabel: 'More',
              onPressed: () {},
            ),
          ],
          meta: const [AnChip('function', tone: AnTone.accent)],
        ),
      ),
    );
    expect(find.text('normalize-input'), findsOneWidget);
    expect(find.text('Workspace'), findsOneWidget); // crumb segment
    expect(find.text('Functions'), findsOneWidget); // crumb segment
    expect(
      find.text('normalize-input'),
      findsOneWidget,
    ); // the name is the TITLE, never a crumb 名只在黑字
    expect(find.byIcon(AnIcons.more), findsOneWidget);
    expect(find.text('function'), findsOneWidget); // meta badge
    expect(tester.takeException(), isNull);
  });

  testWidgets('a clickable crumb segment navigates (fires its onTap)', (
    tester,
  ) async {
    var hits = 0;
    await tester.pumpWidget(
      host(
        AnOceanHeader(
          crumbs: [AnCrumb('Scheduler', onTap: () => hits++)],
          title: 'my-workflow',
        ),
      ),
    );
    await tester.tap(find.text('Scheduler'));
    expect(hits, 1);
  });

  testWidgets(
    'editable title edits in place (pencil → commit fires onTitleChange)',
    (tester) async {
      String? committed;
      await tester.pumpWidget(
        host(
          AnOceanHeader(title: 'old-name', onTitleChange: (v) => committed = v),
        ),
      );
      expect(
        find.byType(AnInlineEdit),
        findsOneWidget,
      ); // editable → inline rename
      await tester.tap(find.byIcon(AnIcons.edit)); // the rename pencil
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'new-name');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(committed, 'new-name');
    },
  );

  testWidgets('read-only (no onTitleChange) has no rename pencil', (
    tester,
  ) async {
    await tester.pumpWidget(host(const AnOceanHeader(title: 'read-only')));
    expect(find.byType(AnInlineEdit), findsNothing);
    expect(find.text('read-only'), findsOneWidget);
  });

  testWidgets(
    'read-only title is a header node (screen-reader heading navigation)',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(const AnOceanHeader(title: 'my-entity')));
      expect(
        tester.getSemantics(find.text('my-entity')).flagsCollection.isHeader,
        isTrue,
      );
      handle.dispose();
    },
  );
}
