import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnRefPill = inline entity-mention pill. Contract: id non-empty ⇒ tappable button emitting {kind,id};
// empty/null ⇒ plain annotation (not tappable); unknown kind still renders (byKey fallback); a11y
// label "{kind}: {name}" with the kind localized. AnRefPill 提及药丸契约。
void main() {
  Widget host(Widget child) => TranslationProvider(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      home: Scaffold(
        body: Center(child: SizedBox(width: 300, child: child)),
      ),
    ),
  );

  testWidgets('renders label + kind glyph', (tester) async {
    await tester.pumpWidget(
      host(const AnRefPill(kind: 'agent', label: 'deploy-bot')),
    );
    expect(find.text('deploy-bot'), findsOneWidget);
    expect(
      find.byIcon(AnIcons.agent),
      findsOneWidget,
    ); // kind glyph resolved via AnIcons.byKey
  });

  testWidgets('tappable when id + onTap present — emits {kind,id}', (
    tester,
  ) async {
    AnRefTarget? tapped;
    await tester.pumpWidget(
      host(
        AnRefPill(
          kind: 'agent',
          id: 'ag_1',
          label: 'deploy-bot',
          onTap: (t) => tapped = t,
        ),
      ),
    );
    await tester.tap(find.byType(AnRefPill));
    expect(tapped, isNotNull);
    expect(tapped!.kind, 'agent');
    expect(tapped!.id, 'ag_1');
  });

  testWidgets('a11y label = "{kind}: {name}" with the kind localized', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        AnRefPill(
          kind: 'agent',
          id: 'ag_1',
          label: 'deploy-bot',
          onTap: (_) {},
        ),
      ),
    );
    expect(find.bySemanticsLabel('Agent: deploy-bot'), findsOneWidget);
    handle.dispose();
  });

  testWidgets(
    'id empty/null → plain annotation: not tappable, still labelled for SR',
    (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      // 'document' is the backend EntityKind wire value (entitykind.go). 后端实体 kind 线缆值。
      await tester.pumpWidget(
        host(
          AnRefPill(kind: 'document', label: 'spec.md', onTap: (_) => taps++),
        ),
      ); // no id
      await tester.tap(find.byType(AnRefPill), warnIfMissed: false);
      expect(taps, 0); // not interactive without an id
      expect(find.bySemanticsLabel('Document: spec.md'), findsOneWidget);
      handle.dispose();
    },
  );

  test(
    'every backend EntityKind resolves a glyph (no "?" fallback) — locks AnIcons.byKey ↔ contract',
    () {
      // relation/entitykind.go is the source of truth; add a kind there → byKey + ref.* must follow.
      // 实体 kind 事实源;新增即须同步 byKey + ref.*。此测试是抗漂移闸门。
      const kinds = [
        'function',
        'handler',
        'workflow',
        'agent',
        'document',
        'conversation',
        'skill',
        'mcp',
        'trigger',
        'control',
        'approval',
      ];
      for (final k in kinds) {
        expect(
          AnIcons.byKey(k),
          isNot(AnIcons.fallback),
          reason: 'byKey must resolve backend EntityKind "$k" (not "?")',
        );
      }
    },
  );

  testWidgets('empty-string id is also non-interactive', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(AnRefPill(kind: 'agent', id: '', label: 'x', onTap: (_) => taps++)),
    );
    await tester.tap(find.byType(AnRefPill), warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets(
    'unknown/forward kind still renders (fallback "?" glyph + raw kind in label)',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(const AnRefPill(kind: 'quasar', label: 'x')),
      );
      expect(
        find.byIcon(AnIcons.fallback),
        findsOneWidget,
      ); // visible "?", never a crash
      expect(
        find.bySemanticsLabel('quasar: x'),
        findsOneWidget,
      ); // raw kind for the open set
      handle.dispose();
    },
  );

  testWidgets(
    'long label ellipsis-truncates (capped at block) without overflow',
    (tester) async {
      await tester.pumpWidget(
        host(
          const AnRefPill(
            kind: 'workflow',
            label:
                'an-extremely-long-entity-reference-name-that-must-ellipsis-not-overflow',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(AnRefPill), findsOneWidget);
    },
  );
}
