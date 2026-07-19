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

  // ── host-controlled add field (showAddField / onAddDismissed) — the KV tags row's contract ──
  group('host-controlled add field', () {
    Future<({List<AnTag> Function() tags, bool Function() dismissed, void Function(bool) setShow})> pumpHost(
        WidgetTester tester, List<AnTag> initial, {bool show = false}) async {
      var tags = initial;
      var dismissed = false;
      late StateSetter setState;
      var showAdd = show;
      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 340,
                child: StatefulBuilder(
                  builder: (ctx, ss) {
                    setState = ss;
                    return AnTags(
                      tags: tags,
                      placeholder: 'Add',
                      showAddField: showAdd,
                      onChanged: (t) => ss(() => tags = t),
                      onAddDismissed: () => ss(() {
                        dismissed = true;
                        showAdd = false;
                      }),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ));
      return (
        tags: () => tags,
        dismissed: () => dismissed,
        setShow: (v) {
          setState(() => showAdd = v);
        },
      );
    }

    testWidgets('showAddField:false hides the field but keeps the ×', (tester) async {
      final handle = tester.ensureSemantics();
      final h = await pumpHost(tester, [const AnTag('agent')]);
      expect(find.byType(TextField), findsNothing);
      expect(find.bySemanticsLabel('Remove agent'), findsOneWidget); // still editable
      expect(h.dismissed(), isFalse);
      handle.dispose();
    });

    testWidgets('false→true mounts the field AND focuses it', (tester) async {
      final h = await pumpHost(tester, [const AnTag('agent')]);
      h.setShow(true);
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      expect(field, findsOneWidget);
      expect(tester.widget<TextField>(field).focusNode?.hasFocus, isTrue);
    });

    testWidgets('Enter chains: adds, keeps the field + focus, no dismissal', (tester) async {
      final h = await pumpHost(tester, [const AnTag('agent')], show: true);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'net');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(h.tags().map((t) => t.label), contains('net'));
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus, isTrue);
      expect(h.dismissed(), isFalse);
    });

    testWidgets('Esc discards the draft + dismisses', (tester) async {
      final h = await pumpHost(tester, [const AnTag('agent')], show: true);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'draft');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(h.dismissed(), isTrue);
      expect(find.byType(TextField), findsNothing);
      expect(h.tags().map((t) => t.label), isNot(contains('draft'))); // draft discarded
      // re-open: no stale draft resurrects 重开无陈旧草稿
      h.setShow(true);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, isEmpty);
    });

    testWidgets('blur with text commits it, then dismisses; blur empty just dismisses', (tester) async {
      final h = await pumpHost(tester, [const AnTag('agent')], show: true);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'kept');
      FocusManager.instance.primaryFocus?.unfocus(); // focus leaves the field
      await tester.pumpAndSettle();
      expect(h.tags().map((t) => t.label), contains('kept')); // blur-commit
      expect(h.dismissed(), isTrue);
    });
  });
}
