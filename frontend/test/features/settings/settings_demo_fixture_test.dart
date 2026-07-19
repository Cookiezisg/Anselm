import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/core/ui/an_state.dart';
import 'package:anselm/dev/demo_main.dart' show demoOverrides;
import 'package:anselm/features/notifications/data/notification_demo_fixture.dart';
import 'package:anselm/features/settings/model/settings_catalog.dart';
import 'package:anselm/features/settings/ui/panels/settings_panels.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The 13-PANEL DATA BATTERY (0719 P0 防线) — every settings panel pumped under the REAL demo
// override list (`demoOverrides`, the one `make demo` mounts) must render its seeded data and no
// error face. This is the gate the 0719 audit lacked: the capture harness's hand-copied override
// subset had silently dropped the settings seam, so six panels shot as "broken" (limits
// ApiException / empty workspaces / MCP·memory·sandbox tombstones) while the product was fine.
// Because this battery goes THROUGH demoOverrides, any future drift in that list — or a panel
// silently unhooking from [settingsRepositoryProvider] — fails here, not in a screenshot review.
//
// 十三面板数据电池(0719 P0 防线)——每个设置面板在**真 demo override 清单**(make demo 挂的
// demoOverrides)下 pump,断言渲出种子数据、无错误脸。这是 0719 审计缺的那道闸:capture 手抄
// override 子集漂移掉 settings 缝,六面板拍成「坏」而产品其实无恙。电池走 demoOverrides 本尊,
// 该清单再漂移、或面板脱钩 settingsRepositoryProvider,先红在这里,不是红在截图复审。
void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  Future<void> pumpPanel(WidgetTester tester, SettingsPanel panel) async {
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
  }

  /// No error face anywhere on a fixture-backed panel. 面板上不允许任何错误脸。
  void expectNoErrorFace() {
    expect(
      find.byWidgetPredicate((w) => w is AnState && w.kind == AnStateKind.error),
      findsNothing,
      reason: 'fixture 数据在,错误脸=断线回归',
    );
  }

  /// Seeded panels must not show an empty state either. 有种子的面板不允许空态。
  void expectNoEmptyFace() {
    expect(
      find.byWidgetPredicate((w) => w is AnState && w.kind == AnStateKind.empty),
      findsNothing,
      reason: 'fixture 种子在,空态=断线回归',
    );
  }

  testWidgets('general — theme row renders', (tester) async {
    await pumpPanel(tester, SettingsPanel.general);
    expect(find.text(t.settings.theme), findsOneWidget);
    expectNoErrorFace();
  });

  testWidgets('notifications — level row renders (no stray prose line)', (tester) async {
    await pumpPanel(tester, SettingsPanel.notifications);
    expect(find.text(t.settings.notifLevel), findsOneWidget);
    expectNoErrorFace();
  });

  testWidgets('chat — send key + webFetch live, no resident save-failed line', (tester) async {
    await pumpPanel(tester, SettingsPanel.chat);
    expect(find.text(t.settings.sendKey), findsOneWidget);
    expect(find.text(t.settings.webJina), findsOneWidget, reason: '工作区载入,抓取分段器可用');
    expect(find.text(t.settings.patchFailed), findsNothing, reason: '红句常驻=工作区缝断线');
    expectNoErrorFace();
  });

  testWidgets('modelsKeys — managed + BYOK key rows and quota render', (tester) async {
    await pumpPanel(tester, SettingsPanel.modelsKeys);
    expect(find.text('Anselm Free'), findsWidgets);
    expect(find.text('DeepSeek (personal)'), findsOneWidget);
    expectNoErrorFace();
    expectNoEmptyFace();
  });

  testWidgets('mcp — seeded servers render (ready + failed), counts non-zero only', (tester) async {
    await pumpPanel(tester, SettingsPanel.mcp);
    expect(find.text('context7'), findsOneWidget);
    expect(find.text('github'), findsOneWidget);
    expect(
        find.text([
          t.settings.mcp.statCount(n: 2),
          t.settings.mcp.statReady(n: 1),
          t.settings.mcp.statFailed(n: 1),
        ].join(' · ')),
        findsOneWidget);
    expectNoErrorFace();
    expectNoEmptyFace();
  });

  testWidgets('memory — the three seeded notes render', (tester) async {
    await pumpPanel(tester, SettingsPanel.memory);
    expect(find.text('coding-style'), findsOneWidget);
    expect(find.text('retry-policy'), findsOneWidget);
    expectNoErrorFace();
    expectNoEmptyFace();
  });

  testWidgets('sandbox — runtimes + the function-owner env render; no hollow disk track',
      (tester) async {
    await pumpPanel(tester, SettingsPanel.sandbox);
    expect(find.text('python 3.11.9'), findsOneWidget);
    expect(find.text('node 20.11.0'), findsOneWidget);
    expect(find.text('sync_inventory'), findsOneWidget, reason: 'function tab 默认页种子 env');
    expect(find.text('42.0 MB'), findsOneWidget, reason: '磁盘=诚实数字,非空进度轨');
    expectNoErrorFace();
  });

  testWidgets('workspaces — active + secondary rows render', (tester) async {
    await pumpPanel(tester, SettingsPanel.workspaces);
    expect(find.text('Demo'), findsWidgets);
    expect(find.text('Side Projects'), findsOneWidget);
    expectNoErrorFace();
    expectNoEmptyFace();
  });

  testWidgets('storage — data dir path + disk figure render', (tester) async {
    await pumpPanel(tester, SettingsPanel.storage);
    expect(find.text('/tmp/anselm-fixture'), findsOneWidget);
    expect(find.text('42.0 MB'), findsOneWidget);
    expectNoErrorFace();
  });

  testWidgets('limits — schema-driven rows render (no ApiException page)', (tester) async {
    await pumpPanel(tester, SettingsPanel.limits);
    expect(find.text('agent.maxSteps'), findsOneWidget);
    expect(find.text(t.settings.limits.errorTitle), findsNothing);
    expectNoErrorFace();
  });

  testWidgets('network — proxy form renders live', (tester) async {
    await pumpPanel(tester, SettingsPanel.network);
    expect(find.text(t.settings.network.httpProxy), findsOneWidget);
    expectNoErrorFace();
  });

  testWidgets('shortcuts — every catalog command has a row', (tester) async {
    await pumpPanel(tester, SettingsPanel.shortcuts);
    expect(find.text(t.settings.shortcuts.cmdToggleLeft), findsOneWidget);
    expect(find.text(t.settings.shortcuts.cmdZoomIn), findsOneWidget);
    expectNoErrorFace();
  });

  testWidgets('about — the fixture engine version renders', (tester) async {
    await pumpPanel(tester, SettingsPanel.about);
    expect(find.text('0.0.0-fixture'), findsOneWidget);
    expectNoErrorFace();
  });
}
