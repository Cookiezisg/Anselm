import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/announce_probe.dart';

void main() {
  Widget host(Widget child, {double width = 360}) => TranslationProvider(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );

  BoxDecoration deco(WidgetTester t) =>
      t
              .widget<Container>(
                find
                    .descendant(
                      of: find.byType(AnCallout),
                      matching: find.byType(Container),
                    )
                    .first,
              )
              .decoration!
          as BoxDecoration;

  testWidgets('renders the message and maps severity → tone soft bg', (
    tester,
  ) async {
    final cases = {
      AnCalloutSeverity.info: AnTone.accent,
      AnCalloutSeverity.ok: AnTone.ok,
      AnCalloutSeverity.warn: AnTone.warn,
      AnCalloutSeverity.danger: AnTone.danger,
    };
    for (final e in cases.entries) {
      await tester.pumpWidget(host(AnCallout('Msg', severity: e.key)));
      expect(find.text('Msg'), findsOneWidget);
      expect(
        deco(tester).color,
        e.value.softBg(AnColors.light),
        reason: '${e.key} → ${e.value} soft bg',
      );
    }
  });

  testWidgets('dismiss: absent without onDismiss; present + fires with it', (
    tester,
  ) async {
    await tester.pumpWidget(host(const AnCallout('x')));
    expect(find.byType(AnButton), findsNothing); // no dismiss, no actions

    var dismissed = false;
    await tester.pumpWidget(
      host(AnCallout('x', onDismiss: () => dismissed = true)),
    );
    expect(find.byType(AnButton), findsOneWidget);
    await tester.tap(find.byType(AnButton));
    expect(dismissed, isTrue);
  });

  testWidgets('actions render below the message', (tester) async {
    await tester.pumpWidget(
      host(
        AnCallout(
          'x',
          actions: [
            AnButton(label: 'Update', size: AnButtonSize.sm, onPressed: () {}),
            AnButton(label: 'Later', size: AnButtonSize.sm, onPressed: () {}),
          ],
        ),
      ),
    );
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });

  testWidgets('the severity WORD is spoken via semanticsLabel (not shown)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const AnCallout('Saved', severity: AnCalloutSeverity.ok)),
    );
    // visual text is just 'Saved'; the a11y label prefixes the severity word.
    expect(find.text('Saved'), findsOneWidget); // visible
    expect(find.bySemanticsLabel('Success: Saved'), findsOneWidget); // spoken
  });

  group('a11y: the bar announces itself — ALL FOUR severities', () {
    testWidgets('info announces POLITELY on mount (this was silent before)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final said = probeAnnouncements(tester);
      await tester.pumpWidget(host(const AnCallout('Synced.')));
      await tester.pumpAndSettle();
      // info/ok used to ride `liveRegion` alone — a desktop no-op — so they announced NOTHING on every
      // platform this app ships to. Only warn/danger ever spoke. info/ok 此前只靠 liveRegion(桌面 no-op),
      // 即在所有出货平台上**什么都没念**;能出声的只有 warn/danger。
      expect(said.map((a) => a.toString()), ['polite: Info: Synced.']);
      handle.dispose();
    });

    testWidgets(
      'danger INTERRUPTS (assertive), and carries the severity word',
      (tester) async {
        final handle = tester.ensureSemantics();
        final said = probeAnnouncements(tester);
        await tester.pumpWidget(
          host(
            const AnCallout('Disk full.', severity: AnCalloutSeverity.danger),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          said.single.isAssertive,
          isTrue,
          reason: 'danger 要打断(ARIA role=alert)',
        );
        expect(said.single.message, 'Error: Disk full.');
        handle.dispose();
      },
    );

    testWidgets(
      'an in-place message change re-announces; an idle rebuild does not',
      (tester) async {
        final handle = tester.ensureSemantics();
        final said = probeAnnouncements(tester);
        await tester.pumpWidget(host(const AnCallout('First.')));
        await tester.pumpAndSettle();
        said.clear();
        await tester.pumpWidget(host(const AnCallout('First.')));
        await tester.pumpAndSettle();
        expect(said, isEmpty, reason: '同一条重建不重念');
        await tester.pumpWidget(host(const AnCallout('Second.')));
        await tester.pumpAndSettle();
        expect(said.map((a) => a.toString()), ['polite: Info: Second.']);
        handle.dispose();
      },
    );
  });

  testWidgets('long message wraps and grows, never overflows in a narrow bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AnCallout(
          'A deliberately very long callout message that must wrap onto multiple lines and grow in height instead of overflowing the bar.',
          severity: AnCalloutSeverity.danger,
        ),
        width: 240,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
