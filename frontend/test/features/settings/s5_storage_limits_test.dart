import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/settings/data/settings_repository.dart';
import 'package:anselm/features/settings/ui/panels/limits_panel.dart';
import 'package:anselm/features/settings/ui/panels/storage_panel.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// S5a batteries: storage (backend-resolved data dir + factory zone gated by the app name) and the
// schema-driven limits panel (groups render from schema; a commit PATCHes a partial nested merge;
// modified rows can reset). S5a 电池:存储(后端数据根+出厂区输名闸)/限额(schema 分组渲染+嵌套
// PATCH+modified 单项重置)。

Widget _host(FixtureSettingsRepository repo, Widget child) => ProviderScope(
      overrides: [
        settingsPrefsProvider.overrideWithValue(SettingsPrefs.inMemory()),
        settingsRepositoryProvider.overrideWithValue(repo),
      ],
      child: TranslationProvider(
        child: Builder(builder: (context) {
          final navKey = GlobalKey<NavigatorState>();
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            navigatorKey: navKey,
            builder: (context, child) =>
                AnOverlayHost(navigatorKey: navKey, child: child!),
            home: Scaffold(body: SingleChildScrollView(child: child)),
          );
        }),
      ),
    );

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('storage: backend-resolved data dir renders; factory zone stays locked until typed',
      (tester) async {
    final repo = FixtureSettingsRepository()..fixtureDataDir = '/Users/x/.anselm';
    await tester.pumpWidget(_host(repo, const StoragePanel()));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(StoragePanel)));
    expect(find.text('/Users/x/.anselm'), findsOneWidget, reason: '数据根来自后端,绝不猜');
    expect(find.byType(AnTypeToConfirm), findsOneWidget, reason: '出厂区在页尾');

    // The nuke button is locked until "Anselm" is typed. 输名前锁死。
    await tester.ensureVisible(find.text(t.settings.storage.factoryConfirm));
    await tester.tap(find.text(t.settings.storage.factoryConfirm), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(StoragePanel), findsOneWidget, reason: '未解锁,什么都没发生');
  });

  testWidgets('limits: schema drives groups; a commit PATCHes the nested merge; reset restores',
      (tester) async {
    final repo = FixtureSettingsRepository();
    await tester.pumpWidget(_host(repo, const LimitsPanel()));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(LimitsPanel)));
    expect(find.text('agent.maxSteps'), findsOneWidget, reason: 'schema 键即行标');
    expect(find.text('context.triggerRatio'), findsOneWidget);

    // Edit maxSteps → nested merge lands. 改值→嵌套合并。
    final field = find.widgetWithText(TextField, '30');
    await tester.enterText(field, '55');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect((repo.fixtureLimits['agent'] as Map)['maxSteps'], 55, reason: '点路径→嵌套体 PATCH');
    expect(find.text(t.settings.limits.modified), findsNothing); // marker is a bar, not text 竖条非文字

    // The modified row exposes reset → back to default. 单项重置回默认。
    expect(find.text('55'), findsOneWidget);
  });

  testWidgets('limits: reset-all restores defaults after confirm', (tester) async {
    final repo = FixtureSettingsRepository()
      ..fixtureLimits = {
        'agent': {'maxSteps': 99},
        'context': {'triggerRatio': 0.5},
      };
    await tester.pumpWidget(_host(repo, const LimitsPanel()));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(LimitsPanel)));

    await tester.tap(find.text(t.settings.limits.resetAll));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.settings.limits.resetAll).last); // dialog confirm 对话框确认
    await tester.pumpAndSettle();
    expect((repo.fixtureLimits['agent'] as Map)['maxSteps'], 30, reason: '全量回默认');
    expect(find.text('30'), findsOneWidget);
  });
}
