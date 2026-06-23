import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A controlled host: a StatefulBuilder owns the list so onChanged actually mutates + rebuilds.
  Future<List<AnTag> Function()> pumpEditable(WidgetTester tester, List<AnTag> initial, {bool single = false}) async {
    var tags = initial;
    Widget build() => TranslationProvider(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 340,
                  child: StatefulBuilder(
                    builder: (ctx, ss) => AnTags(
                      tags: tags,
                      single: single,
                      placeholder: 'Add',
                      onChanged: (t) => ss(() => tags = t),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
    await tester.pumpWidget(build());
    return () => tags;
  }

  testWidgets('typing + Enter adds a new tag', (tester) async {
    final read = await pumpEditable(tester, [const AnTag('agent')]);
    await tester.enterText(find.byType(TextField), 'workflow');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(read().map((e) => e.label), ['agent', 'workflow']);
    expect(find.text('workflow'), findsOneWidget);
  });

  testWidgets('duplicate (case-insensitive) is rejected — not added', (tester) async {
    final read = await pumpEditable(tester, [const AnTag('agent')]);
    await tester.enterText(find.byType(TextField), 'Agent');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(read().length, 1, reason: 'duplicate must be rejected (decision ④)');
  });

  testWidgets('single mode replaces the one value', (tester) async {
    final read = await pumpEditable(tester, [const AnTag('medium')], single: true);
    await tester.enterText(find.byType(TextField), 'high');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(read().map((e) => e.label), ['high']);
  });

  testWidgets('remove × deletes the tag and is a labelled button', (tester) async {
    final handle = tester.ensureSemantics();
    final read = await pumpEditable(tester, [const AnTag('agent'), const AnTag('workflow')]);
    expect(find.bySemanticsLabel('Remove agent'), findsOneWidget); // per-× button label
    await tester.tap(find.bySemanticsLabel('Remove agent'));
    await tester.pump();
    expect(read().map((e) => e.label), ['workflow']);
    handle.dispose();
  });

  testWidgets('Backspace on an empty field removes the last tag', (tester) async {
    final read = await pumpEditable(tester, [const AnTag('agent'), const AnTag('workflow')]);
    await tester.tap(find.byType(TextField)); // focus the empty add field
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(read().map((e) => e.label), ['agent']);
  });

  testWidgets('readOnly: no add field, no remove ×', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 340,
            child: AnTags(readOnly: true, tags: [AnTag('passed', tone: AnTone.ok, health: AnStatus.done)]),
          ),
        ),
      ),
    ));
    expect(find.text('passed'), findsOneWidget);
    expect(find.byType(TextField), findsNothing); // no inline add
    expect(find.bySemanticsLabel('Remove passed'), findsNothing); // no ×
    handle.dispose();
  });
}
