import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/overlay/an_overlay.dart';
import 'package:anselm/core/platform/window_bounds.dart';
import 'package:anselm/core/settings/app_prefs_providers.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/features/chat/model/stage_director.dart';
import 'package:anselm/features/chat/state/stage_director_provider.dart';
import 'package:anselm/features/settings/data/settings_repository.dart';
import 'package:anselm/features/settings/model/settings_catalog.dart';
import 'package:anselm/features/settings/state/settings_panel_provider.dart';
import 'package:anselm/features/settings/ui/panels/chat_panel.dart';
import 'package:anselm/features/settings/ui/panels/general_panel.dart';
import 'package:anselm/features/settings/ui/panels/notifications_panel.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// S1 偏好域 batteries: the three preference panels wire their providers + prefs round-trip, the
// dark notch stays un-pickable, the language row double-writes, webFetch PATCHes the workspace,
// and the bounds clamp discipline is pure-tested. S1 电池:三面板接线往返/dark 不可点/语言双写/
// webFetch PATCH/多显示器 clamp 纯测。

Widget _host(SettingsPrefs prefs, Widget child, {SettingsRepository? repo}) => ProviderScope(
      overrides: [
        settingsPrefsProvider.overrideWithValue(prefs),
        if (repo != null) settingsRepositoryProvider.overrideWithValue(repo),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  group('GeneralPanel 通用', () {
    testWidgets('theme segmented: all three notches apply + persist (dark live since S1b)', (tester) async {
      final prefs = SettingsPrefs.inMemory();
      await tester.pumpWidget(_host(prefs, const GeneralPanel(), repo: FixtureSettingsRepository()));
      await tester.pumpAndSettle();

      await tester.tap(find.text(t.settings.themeSystem).first); // theme segment(语言下拉同词)
      await tester.pumpAndSettle();
      expect(prefs.getString(SettingsKeys.theme), 'system', reason: '即时持久化');

      await tester.tap(find.text(t.settings.themeDark).first);
      await tester.pumpAndSettle();
      expect(prefs.getString(SettingsKeys.theme), 'dark', reason: 'dark 已随 S1b 点亮,可选可存');
    });

    testWidgets('language double-writes: UI locale + workspace.language', (tester) async {
      final prefs = SettingsPrefs.inMemory();
      final repo = FixtureSettingsRepository();
      await tester.pumpWidget(_host(prefs, const GeneralPanel(), repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text(t.settings.langSystem).last); // open the dropdown 开下拉
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.settings.langEn).last);
      await tester.pumpAndSettle();

      expect(prefs.getString(SettingsKeys.locale), 'en', reason: 'UI half persisted');
      expect(repo.workspace.language, 'en', reason: 'workspace half PATCHed (双写)');
      // Restore for the rest of the suite (setLocaleSync is process-global). 还原全局 locale。
      LocaleSettings.setLocaleRaw('zh-CN');
    });

    testWidgets('window/update switches round-trip their declared keys', (tester) async {
      final prefs = SettingsPrefs.inMemory();
      await tester.pumpWidget(_host(prefs, const GeneralPanel(), repo: FixtureSettingsRepository()));
      await tester.pumpAndSettle();

      // Both default ON → flip window-remember off. 默认皆开,关记住窗口。
      final switches = find.byType(Switch);
      expect(switches, findsNothing, reason: 'NO Material Switch — AnSwitch only 禁 Material');
      await tester.tap(find.text(t.settings.rememberWindow));
      // Row tap is inert (control is the writer) — flip via the switch itself. 行不写,开关写。
      final row = find.ancestor(
          of: find.text(t.settings.rememberWindow), matching: find.byType(Column));
      expect(row, findsWidgets);
      final sw = find.descendant(
          of: find.ancestor(
              of: find.text(t.settings.rememberWindow),
              matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == 'AnSettingRow')),
          matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == 'AnSwitch'));
      await tester.tap(sw);
      await tester.pumpAndSettle();
      expect(prefs.getBool(SettingsKeys.windowRemember), isFalse);
    });
  });

  group('NotificationsPanel 通知', () {
    testWidgets('level notches persist; switching to silent toasts the one-shot hint', (tester) async {
      final prefs = SettingsPrefs.inMemory();
      await tester.pumpWidget(_host(prefs, const NotificationsPanel()));
      final container = ProviderScope.containerOf(
          tester.element(find.byType(NotificationsPanel)), listen: false);
      await tester.pumpAndSettle();

      await tester.tap(find.text(t.settings.levelAll));
      await tester.pumpAndSettle();
      expect(prefs.getString(SettingsKeys.notifyLevel), 'all');

      await tester.tap(find.text(t.settings.levelSilent));
      await tester.pumpAndSettle();
      expect(prefs.getString(SettingsKeys.notifyLevel), 'silent');
      // The host has no AnOverlayHost — assert the dispatched toast on the overlay STATE. 断言 overlay 态。
      expect(container.read(overlayProvider).toasts.map((x) => x.text),
          contains(t.settings.silentHint), reason: '一次性静音确认 toast');
    });
  });

  group('ChatPanel 对话', () {
    testWidgets('auto-stage reads/writes the SAME followModeProvider as the sidestage', (tester) async {
      final prefs = SettingsPrefs.inMemory({'an.stage.follow': 'never'});
      late ProviderContainer container;
      await tester.pumpWidget(_host(prefs, const ChatPanel(), repo: FixtureSettingsRepository()));
      container = ProviderScope.containerOf(tester.element(find.byType(ChatPanel)), listen: false);
      await tester.pumpAndSettle();
      expect(container.read(followModeProvider), FollowMode.never, reason: '同一 provider 恢复');

      await tester.tap(find.text(t.settings.stageAlways));
      await tester.pumpAndSettle();
      expect(container.read(followModeProvider), FollowMode.always);
      expect(prefs.getString(SettingsKeys.chatAutoStage), 'always');
    });

    testWidgets('webFetch PATCHes the workspace; failure rolls back + toasts', (tester) async {
      final prefs = SettingsPrefs.inMemory();
      final repo = FixtureSettingsRepository();
      await tester.pumpWidget(_host(prefs, const ChatPanel(), repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text(t.settings.webJina));
      await tester.pumpAndSettle();
      expect(repo.workspace.webFetchMode, 'jina');

      repo.failNextPatch = true;
      final container =
          ProviderScope.containerOf(tester.element(find.byType(ChatPanel)), listen: false);
      await tester.tap(find.text(t.settings.webLocal));
      await tester.pumpAndSettle();
      expect(repo.workspace.webFetchMode, 'jina', reason: '失败未写库');
      expect(container.read(overlayProvider).toasts.map((x) => x.text),
          contains(t.settings.patchFailed), reason: '回滚 + danger toast');
      // The segmented itself must show the rolled-back value. 分段器回滚显示。
      expect(find.text(t.settings.patchFailed), findsNothing);
    });

    testWidgets('the ghost link jumps to Models & keys', (tester) async {
      final prefs = SettingsPrefs.inMemory();
      late ProviderContainer container;
      await tester.pumpWidget(_host(prefs, const ChatPanel(), repo: FixtureSettingsRepository()));
      container = ProviderScope.containerOf(tester.element(find.byType(ChatPanel)), listen: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.settings.defaultModelLink));
      await tester.pumpAndSettle();
      expect(container.read(settingsPanelProvider), SettingsPanel.modelsKeys);
    });
  });

  group('WindowBounds.clampToDisplays 多显示器 clamp 纪律', () {
    const main = Rect.fromLTWH(0, 0, 1728, 1080);
    const ext = Rect.fromLTWH(1728, -200, 2560, 1440);

    test('a rect on a live display restores as-is', () {
      final r = WindowBounds.clampToDisplays(const Rect.fromLTWH(100, 84, 1280, 792), [main]);
      expect(r, const Rect.fromLTWH(100, 84, 1280, 792));
    });

    test('a rect from an unplugged display is stranded → null (fallback centered)', () {
      final r = WindowBounds.clampToDisplays(const Rect.fromLTWH(2000, 100, 1280, 792), [main]);
      expect(r, isNull, reason: '标题栏带不在任何在线屏上');
    });

    test('the same rect restores when the external display IS live', () {
      final r = WindowBounds.clampToDisplays(const Rect.fromLTWH(2000, 100, 1280, 792), [main, ext]);
      expect(r, isNotNull);
    });

    test('an oversized rect clamps its size into the matched display', () {
      final r = WindowBounds.clampToDisplays(const Rect.fromLTWH(0, 0, 3000, 2000), [main])!;
      expect(r.width, main.width);
      expect(r.height, main.height);
    });

    test('a body-visible-but-bar-offscreen rect does NOT restore (grab test on the bar)', () {
      // The bar sits above the screen top; only the body pokes in. 标题栏在屏外上方。
      final r = WindowBounds.clampToDisplays(const Rect.fromLTWH(100, -100, 1280, 792), [main]);
      expect(r, isNull, reason: '只露身子抓不回来');
    });

    test('degenerate stored sizes are rejected', () {
      expect(WindowBounds.clampToDisplays(const Rect.fromLTWH(0, 0, 10, 10), [main]), isNull);
    });
  });
}
