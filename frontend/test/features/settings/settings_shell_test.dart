import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/core/shell/shell_chrome.dart';
import 'package:anselm/features/settings/model/settings_catalog.dart';
import 'package:anselm/features/settings/ui/settings_ocean.dart';
import 'package:anselm/features/settings/ui/settings_rail.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The S0 settings shell: directory renders every catalog panel, selection drives the ocean and
// persists (an.settings.panel), the placeholder body is honest, and the breadcrumb binds
// 「设置 / 面板」. S0 壳电池:目录全渲/选择驱动海洋并持久化/占位诚实/面包屑绑定。

Widget _host(SettingsPrefs prefs, {Widget? child}) => ProviderScope(
  overrides: [settingsPrefsProvider.overrideWithValue(prefs)],
  child: TranslationProvider(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      home: Scaffold(
        body:
            child ??
            const Row(
              children: [
                SizedBox(width: 260, child: SettingsRail()),
                Expanded(child: SettingsOcean()),
              ],
            ),
      ),
    ),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('the directory renders all 13 panels across three sections', (
    tester,
  ) async {
    await tester.pumpWidget(_host(SettingsPrefs.inMemory()));
    await tester.pumpAndSettle();
    for (final e in settingsCatalog) {
      expect(
        find.text(e.labelOf(t)),
        findsWidgets,
        reason: '${e.panel.name} row visible',
      );
    }
    expect(find.text(t.settings.sections.prefs), findsOneWidget);
    expect(find.text(t.settings.sections.resources), findsOneWidget);
    expect(find.text(t.settings.sections.system), findsOneWidget);
  });

  testWidgets(
    'selecting a panel switches the ocean, persists, and re-opens on rebuild',
    (tester) async {
      final prefs = SettingsPrefs.inMemory();
      await tester.pumpWidget(_host(prefs));
      await tester.pumpAndSettle();
      // Default = general, big title visible. 默认通用。
      expect(find.text(t.settings.panels.general), findsWidgets);

      await tester.tap(find.text(t.settings.panels.limits));
      await tester.pumpAndSettle();
      // The ocean's H1 carries the new panel label (rail row + title = 2 finds). 海洋大标题切换。
      expect(find.text(t.settings.panels.limits), findsNWidgets(2));
      expect(
        prefs.getString(SettingsKeys.settingsPanel),
        'limits',
        reason: 'selection persisted',
      );

      // A fresh tree restores the persisted panel synchronously. 重建恢复。
      await tester.pumpWidget(_host(prefs));
      await tester.pumpAndSettle();
      expect(find.text(t.settings.panels.limits), findsNWidgets(2));
    },
  );

  testWidgets(
    'the placeholder body is honest (every panel now built — component-level check)',
    (tester) async {
      // All 13 panels shipped (S0–S6), so no panel routes to the placeholder anymore. Assert the
      // placeholder component itself renders its honest copy — kept so a future new panel that lands
      // as a placeholder still has coverage. 13 面板全建;直测占位组件本身的诚实文案。
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            theme: AnTheme.light(),
            home: const Scaffold(body: SettingsPanelPlaceholder()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.settings.building), findsOneWidget);
      expect(find.text(t.settings.buildingHint), findsOneWidget);
    },
  );

  testWidgets(
    'the floating head binds ONLY the panel title (zero path); the in-page crumb is «Settings»',
    (tester) async {
      final prefs = SettingsPrefs.inMemory();
      late ProviderContainer container;
      await tester.pumpWidget(_host(prefs));
      container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsOcean)),
        listen: false,
      );
      await tester.pumpAndSettle();
      // 用户 0719 面包屑律③:浮层头=只有黑字标题、零路径(路径在页顶的灰面包屑里看过). 浮层头只念面板名。
      expect(
        container.read(shellHeadProvider).title,
        t.settings.panels.general,
      );
      // The PARENT path lives on the page as a grey crumb — «Settings» over the panel title. 页内灰面包屑=父路径。
      expect(
        find.descendant(
          of: find.byType(SettingsOcean),
          matching: find.text(t.settings.title),
        ),
        findsWidgets,
      );

      await tester.tap(find.text(t.settings.panels.about));
      await tester.pumpAndSettle();
      expect(container.read(shellHeadProvider).title, t.settings.panels.about);
    },
  );

  testWidgets(
    'a stale persisted panel name falls back to general (byName guard)',
    (tester) async {
      final prefs = SettingsPrefs.inMemory({
        'an.settings.panel': 'renamed_gone',
      });
      await tester.pumpWidget(_host(prefs));
      await tester.pumpAndSettle();
      expect(
        find.text(t.settings.panels.general),
        findsNWidgets(2),
        reason: '旧枚举名回落 general',
      );
    },
  );
}
