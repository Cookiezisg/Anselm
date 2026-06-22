import 'package:anselm/app/shell/app_shell.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/features/entities/data/entities_repository.dart';
import 'package:anselm/features/entities/state/entities_providers.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Entities feature smoke, driven through the real AppShell on fixtures (the same shell
/// `make demo`/`make app` run): the Entities ocean lists fixtures, and selecting an entity
/// swaps the schema-driven detail.
/// 经真 AppShell + fixture 跑(与 make demo/app 同一 shell):Entities 海洋列出 fixture,选中换 schema 详情。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget harness() => ProviderScope(
        overrides: [
          entitiesRepositoryProvider.overrideWithValue(const FixtureEntitiesRepository()),
        ],
        child: TranslationProvider(
          child: MaterialApp(theme: AnTheme.light(), home: const AppShell()),
        ),
      );

  // pump() not pumpAndSettle (status dots animate forever); flush futures + the cross-fade.
  Future<void> settleish(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
  }

  testWidgets('Entities ocean lists fixtures and selecting swaps the schema detail',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness());
    await settleish(tester);

    // The shell opens on the Entities ocean → rail populated across groups.
    expect(find.text('greet_user'), findsOneWidget);
    expect(find.text('Research agent'), findsOneWidget);
    expect(find.text('Nightly digest'), findsOneWidget);

    // Select the function → its schema renders a Code section.
    await tester.tap(find.text('greet_user'));
    await settleish(tester);
    expect(find.text('Code'), findsOneWidget);

    // Select the agent → detail swaps to the agent schema (Prompt; no Code).
    await tester.tap(find.text('Research agent'));
    await settleish(tester);
    expect(find.text('Prompt'), findsOneWidget);
    expect(find.text('Code'), findsNothing);
  });
}
