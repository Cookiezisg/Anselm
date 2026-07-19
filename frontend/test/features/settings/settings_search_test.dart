import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/core/ui/an_wash_highlight.dart';
import 'package:anselm/dev/demo_main.dart' show demoOverrides;
import 'package:anselm/features/notifications/data/notification_demo_fixture.dart';
import 'package:anselm/features/settings/model/settings_catalog.dart';
import 'package:anselm/features/settings/model/settings_search.dart';
import 'package:anselm/features/settings/state/settings_jump_provider.dart';
import 'package:anselm/features/settings/state/settings_panel_provider.dart';
import 'package:anselm/features/settings/ui/panels/settings_panels.dart';
import 'package:anselm/features/settings/ui/settings_anchor.dart';
import 'package:anselm/features/settings/ui/settings_rail.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Item-level settings search (用户 0719): the rail search field goes SETTING-ITEM granular —
// ownedKeys was NOT a usable seed (only 4 of 13 panels declare machine keys; the network example
// declares none), so search rides a declarative index ([settingsSearchIndex]) whose every item is
// mounted in its panel behind a `SettingsAnchor`. This file guards all five contracts: grouping
// (label/hint/two-locale), the anchor-mount gate (index ↔ mounted, isomorphic to the three-equal
// catalog gate), the jump-and-wash mechanic, and the rail's directory↔results swap.
//
// 设置项级搜索:rail 搜索升到设置项粒度。ownedKeys 不是可用种子(13 面板仅 4 个声明机器键、网络例子
// 一个都没有),故搜索走声明式索引,每项在其面板里被 SettingsAnchor 挂载。本文件守五契约:分组
// (label/hint/双 locale)、锚挂载门禁(索引 ↔ 挂载,与目录三相等门禁同构)、跳转洗亮、rail 目录↔结果切换。
void main() {
  // ─────────────────────────── grouping (pure, zh) ───────────────────────────
  group('grouping (zh)', () {
    setUp(() => LocaleSettings.setLocaleRaw('zh-CN'));

    List<String> anchorsOf(List<SettingsSearchGroup> gs, SettingsPanel p) =>
        gs.firstWhere((g) => g.entry.panel == p).items.map((i) => i.anchor).toList();

    test('item match: 「代理」→ network group with the three proxy items', () {
      final gs = buildSettingsSearchGroups(t, '代理');
      final network = gs.where((g) => g.entry.panel == SettingsPanel.network).toList();
      expect(network, hasLength(1));
      expect(network.single.panelMatched, isFalse, reason: '面板名「网络」不含「代理」');
      expect(anchorsOf(gs, SettingsPanel.network), [
        SettingsItem.networkHttpProxy,
        SettingsItem.networkHttpsProxy,
        SettingsItem.networkNoProxy,
      ]);
    });

    test('panel-name match: 「网络」→ header + ALL its items (搜类别见全部)', () {
      final gs = buildSettingsSearchGroups(t, '网络');
      final network = gs.firstWhere((g) => g.entry.panel == SettingsPanel.network);
      expect(network.panelMatched, isTrue);
      expect(network.items, hasLength(3), reason: '面板名命中→其下项全出');
    });

    test('hint match: 「出站」matches the network proxy HINT, not any label', () {
      // proxyHint (zh) = 出站代理…; no proxy LABEL contains 出站. 命中靠 hint 非 label。
      final gs = buildSettingsSearchGroups(t, '出站');
      expect(gs.any((g) => g.entry.panel == SettingsPanel.network), isTrue);
      expect(anchorsOf(gs, SettingsPanel.network), hasLength(3));
    });

    test('panel-granularity backward compat: 「记忆」→ memory header, zero items', () {
      final gs = buildSettingsSearchGroups(t, '记忆');
      final mem = gs.firstWhere((g) => g.entry.panel == SettingsPanel.memory);
      expect(mem.panelMatched, isTrue);
      expect(mem.items, isEmpty, reason: 'memory 面板不声明可搜索项,仍按面板名命中');
    });

    test('cross-panel: 「缩放」hits general.zoom (界面缩放) AND shortcuts (重置缩放)', () {
      final gs = buildSettingsSearchGroups(t, '缩放');
      final panels = gs.map((g) => g.entry.panel).toSet();
      expect(panels, contains(SettingsPanel.general));
      expect(panels, contains(SettingsPanel.shortcuts));
      expect(anchorsOf(gs, SettingsPanel.general), contains(SettingsItem.generalZoom));
      expect(anchorsOf(gs, SettingsPanel.shortcuts), contains(SettingsItem.shortcutZoomReset));
    });

    test('empty query → no groups (rail shows the directory)', () {
      expect(buildSettingsSearchGroups(t, ''), isEmpty);
      expect(buildSettingsSearchGroups(t, '   '), isEmpty);
    });

    test('no match → no groups (honest empty)', () {
      expect(buildSettingsSearchGroups(t, 'zzzqqxx'), isEmpty);
    });
  });

  // ─────────────────────────── grouping (en) ───────────────────────────
  group('grouping (en)', () {
    setUp(() => LocaleSettings.setLocaleRaw('en'));

    test('«proxy» → the three network proxy items', () {
      final gs = buildSettingsSearchGroups(t, 'proxy');
      final network = gs.firstWhere((g) => g.entry.panel == SettingsPanel.network);
      expect(network.items.map((i) => i.anchor), [
        SettingsItem.networkHttpProxy,
        SettingsItem.networkHttpsProxy,
        SettingsItem.networkNoProxy,
      ]);
    });

    test('«theme» → general.theme (case-insensitive)', () {
      final gs = buildSettingsSearchGroups(t, 'ThEmE');
      final general = gs.firstWhere((g) => g.entry.panel == SettingsPanel.general);
      expect(general.items.map((i) => i.anchor), contains(SettingsItem.generalTheme));
    });

    test('cross-panel: «zoom» hits general.zoom AND all three zoom shortcut commands', () {
      final gs = buildSettingsSearchGroups(t, 'zoom');
      final general = gs.firstWhere((g) => g.entry.panel == SettingsPanel.general);
      final shortcuts = gs.firstWhere((g) => g.entry.panel == SettingsPanel.shortcuts);
      expect(general.items.map((i) => i.anchor), contains(SettingsItem.generalZoom));
      expect(shortcuts.items.map((i) => i.anchor), containsAll([
        SettingsItem.shortcutZoomIn,
        SettingsItem.shortcutZoomOut,
        SettingsItem.shortcutZoomReset,
      ]));
    });
  });

  // ─────────────────────────── index integrity ───────────────────────────
  group('index integrity', () {
    test('anchors are globally unique', () {
      final ids = settingsSearchIndex.map((i) => i.anchor).toList();
      expect(ids.toSet().length, ids.length, reason: '锚 id 全局唯一');
    });

    test('every item panel is a catalog panel', () {
      final panels = settingsCatalog.map((e) => e.panel).toSet();
      for (final it in settingsSearchIndex) {
        expect(panels, contains(it.panel));
      }
    });

    test('label + hint resolve non-empty in BOTH locales', () {
      for (final raw in ['zh-CN', 'en']) {
        LocaleSettings.setLocaleRaw(raw);
        for (final it in settingsSearchIndex) {
          expect(it.labelOf(t).trim(), isNotEmpty, reason: '${it.anchor} label 空@$raw');
          final h = it.hintOf?.call(t);
          if (it.hintOf != null) {
            expect(h!.trim(), isNotEmpty, reason: '${it.anchor} hint 空@$raw');
          }
        }
      }
    });
  });

  // ── the anchor-mount gate: index ↔ mounted anchors (isomorphic to the three-equal catalog gate) ──
  group('anchor-mount gate', () {
    setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

    Future<Set<String>> pumpAndCollect(WidgetTester tester, SettingsPanel panel) async {
      await tester.pumpWidget(ProviderScope(
        overrides: demoOverrides(SettingsPrefs.inMemory(), demoNotificationRepository()),
        child: TranslationProvider(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Builder(builder: (context) => buildSettingsPanelBody(context, panel)),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return tester
          .widgetList<SettingsAnchor>(find.byType(SettingsAnchor))
          .map((w) => w.item)
          .toSet();
    }

    for (final panel in SettingsPanel.values) {
      testWidgets('$panel: mounted anchors == declared index', (tester) async {
        final mounted = await pumpAndCollect(tester, panel);
        final declared = {
          for (final it in settingsSearchIndex)
            if (it.panel == panel) it.anchor
        };
        // Both directions: a declared item every panel row must mount, and NO stray anchor a panel
        // mounts without declaring. 双向:声明项必挂载、挂载锚必声明。
        expect(mounted, declared,
            reason: '面板 $panel 的可搜索项声明与挂载锚漂移——新增行忘声明/删行忘清索引会红在这里');
      });
    }
  });

  // ─────────────────────────── jump + wash mechanic ───────────────────────────
  group('SettingsAnchor jump + wash', () {
    testWidgets('arming the target washes the matching anchor then clears the target',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SettingsAnchor(
                item: 'probe',
                child: const SizedBox(height: 50, child: Text('row')),
              ),
            ),
          ),
        ),
      ));
      // At rest: pure pass-through, no wash. 静息:纯透传,无洗亮。
      expect(find.byType(AnWashHighlight), findsNothing);

      container.read(settingsJumpProvider.notifier).request('probe');
      await tester.pump(); // build sees the target, schedules the post-frame trigger
      await tester.pump(); // post-frame setState arms the wash

      expect(find.byType(AnWashHighlight), findsOneWidget, reason: '目标命中→洗亮');
      expect(container.read(settingsJumpProvider), isNull, reason: '触发后放开目标(重搜可再触发)');

      // The one-shot wash + its disarm timer settle back to a bare pass-through. 一次性洗亮谢幕后回透传。
      await tester.pumpAndSettle();
      expect(find.byType(AnWashHighlight), findsNothing);
    });

    testWidgets('a non-matching anchor never washes', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SettingsAnchor(item: 'a', child: const Text('a')),
            ),
          ),
        ),
      ));
      container.read(settingsJumpProvider.notifier).request('b'); // a different item
      await tester.pump();
      await tester.pump();
      expect(find.byType(AnWashHighlight), findsNothing);
    });
  });

  // ─────────────────────────── rail: directory ↔ results ───────────────────────────
  group('SettingsRail', () {
    setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

    Future<ProviderContainer> pumpRail(WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: demoOverrides(SettingsPrefs.inMemory(), demoNotificationRepository()),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            home: Scaffold(body: SizedBox(width: 320, child: const SettingsRail())),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('typing 「代理」swaps the directory for grouped item results', (tester) async {
      await pumpRail(tester);
      // Directory shows all panels; a non-network panel is present before searching. 目录显全部面板。
      expect(find.text(t.settings.panels.memory), findsOneWidget);

      await tester.enterText(find.byType(EditableText), '代理');
      await tester.pumpAndSettle();

      expect(find.text(t.settings.panels.network), findsOneWidget, reason: '面板头行');
      expect(find.text(t.settings.network.httpProxy), findsOneWidget, reason: '项行');
      expect(find.text(t.settings.network.noProxy), findsOneWidget);
      expect(find.text(t.settings.panels.memory), findsNothing, reason: '无关面板不入结果');
    });

    testWidgets('clicking an item result selects its panel + arms the jump target', (tester) async {
      final container = await pumpRail(tester);
      expect(container.read(settingsPanelProvider), SettingsPanel.general); // default

      await tester.enterText(find.byType(EditableText), '代理');
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.settings.network.httpProxy));
      await tester.pumpAndSettle();

      expect(container.read(settingsPanelProvider), SettingsPanel.network);
      expect(container.read(settingsJumpProvider), SettingsItem.networkHttpProxy);
      // Search cleared → back to the directory. 搜索清空→回目录。
      expect(find.text(t.settings.panels.memory), findsOneWidget);
    });

    testWidgets('clicking a panel HEADER jumps to the panel with no item target', (tester) async {
      final container = await pumpRail(tester);
      await tester.enterText(find.byType(EditableText), '网络');
      await tester.pumpAndSettle();
      // Scope to the results list — the search field ALSO echoes 「网络」(the query). 限定结果列表(搜索框也回显查询词)。
      await tester.tap(find.descendant(
        of: find.byType(ListView),
        matching: find.text(t.settings.panels.network),
      ));
      await tester.pumpAndSettle();
      expect(container.read(settingsPanelProvider), SettingsPanel.network);
      expect(container.read(settingsJumpProvider), isNull, reason: '面板行不点亮项目标');
    });

    testWidgets('no match → one quiet line, no result rows', (tester) async {
      await pumpRail(tester);
      await tester.enterText(find.byType(EditableText), 'zzzqqxx');
      await tester.pumpAndSettle();
      expect(find.text(t.settings.searchNoMatch), findsOneWidget);
      expect(find.text(t.settings.panels.network), findsNothing);
    });

    testWidgets('clearing the query returns to the directory', (tester) async {
      await pumpRail(tester);
      await tester.enterText(find.byType(EditableText), '代理');
      await tester.pumpAndSettle();
      expect(find.text(t.settings.panels.memory), findsNothing);

      await tester.enterText(find.byType(EditableText), '');
      await tester.pumpAndSettle();
      expect(find.text(t.settings.panels.memory), findsOneWidget);
      expect(find.text(t.settings.searchNoMatch), findsNothing);
    });
  });
}
