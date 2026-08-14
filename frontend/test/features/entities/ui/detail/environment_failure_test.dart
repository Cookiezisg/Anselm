import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_callout.dart';
import 'package:anselm/features/entities/data/entity_demo_fixture.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/ui/detail/overview/function_overview.dart';
import 'package:anselm/features/entities/ui/detail/ocean_header.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/state/detail/entity_detail.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:anselm/core/ui/an_chip.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Widget _host(Widget child) {
  final repo = demoEntityRepository();
  return ProviderScope(
    overrides: [entityRepositoryProvider.overrideWithValue(repo)],
    child: TranslationProvider(
      child: MaterialApp(
        theme: AnTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: 720, child: child),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Function uses the same compact error and technical disclosure', (
    tester,
  ) async {
    final repo = demoEntityRepository();
    final original = await repo.getFunction('fn_normalize');
    final function = original.copyWith(
      activeVersion: original.activeVersion!.copyWith(
        envStatus: 'failed',
        envError:
            'sandboxapp.EnsureEnv https://github.com/anselm/runtime context canceled: runtime install failed',
      ),
    );

    await tester.pumpWidget(_host(FunctionOverview(fn: function)));
    await tester.pump();

    final d = TranslationProvider.of(
      tester.element(find.byType(FunctionOverview)),
    ).translations.entities.detail;
    expect(find.byType(AnCallout), findsOneWidget);
    expect(find.text(d.environment.buildFailed), findsOneWidget);
    expect(find.text(d.environment.cancelled), findsOneWidget);
    expect(find.textContaining('github.com'), findsNothing);

    await tester.tap(find.text(d.environment.technicalDetails));
    await tester.pumpAndSettle();
    expect(find.textContaining('github.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Function header separates version identity from environment state',
    (tester) async {
      final repo = demoEntityRepository();
      final original = await repo.getFunction('fn_normalize');
      final function = original.copyWith(
        activeVersion: original.activeVersion!.copyWith(envStatus: 'failed'),
      );
      final detail = EntityDetail(
        ref: const EntityRef(EntityKind.function, 'fn_normalize'),
        function: function,
      );

      await tester.pumpWidget(_host(EntityOceanHeader(detail: detail)));
      await tester.pump();

      final d = TranslationProvider.of(
        tester.element(find.byType(EntityOceanHeader)),
      ).translations.entities.detail;
      expect(find.byType(AnChip), findsNWidgets(2));
      expect(find.text('v2'), findsOneWidget);
      expect(find.text(d.hero.envStatus(status: 'failed')), findsOneWidget);
      expect(find.text('v2 · failed'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
