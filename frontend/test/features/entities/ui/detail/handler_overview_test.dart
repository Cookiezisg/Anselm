import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_callout.dart';
import 'package:anselm/features/entities/data/entity_demo_fixture.dart';
import 'package:anselm/features/entities/ui/detail/overview/handler_overview.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => TranslationProvider(
  child: MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 720, child: child)),
    ),
  ),
);

void main() {
  testWidgets('environment failure is distinct from stopped runtime', (
    tester,
  ) async {
    final repo = demoEntityRepository();
    final original = await repo.getHandler('hd_slack');
    final failedVersion = original.activeVersion!.copyWith(
      envStatus: 'failed',
      envError:
          'sandboxapp.EnsureEnv https://github.com/anselm/runtime context canceled: runtime install failed',
    );
    final handler = original.copyWith(
      runtimeState: 'stopped',
      activeVersion: failedVersion,
    );

    await tester.pumpWidget(_host(HandlerOverview(hd: handler)));
    await tester.pump();

    final d = TranslationProvider.of(
      tester.element(find.byType(HandlerOverview)),
    ).translations.entities.detail;
    expect(find.byType(AnCallout), findsOneWidget);
    expect(find.text(d.environment.buildFailed), findsOneWidget);
    expect(find.text(d.environment.cancelled), findsOneWidget);
    expect(find.textContaining('github.com'), findsNothing);
    expect(find.text(d.environment.technicalDetails), findsOneWidget);
    expect(find.text(d.card.venv), findsOneWidget);
    expect(find.text('failed'), findsWidgets);
    expect(find.text('stopped'), findsOneWidget);

    await tester.tap(find.text(d.environment.technicalDetails));
    await tester.pumpAndSettle();
    expect(find.textContaining('github.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
