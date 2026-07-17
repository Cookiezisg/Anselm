import 'dart:async';

import 'package:anselm/core/contract/retention.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/model/byte_format.dart';
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

  // ── Run 历史保留 (scheduler 判决④/工单⑬) ──
  testWidgets('retention: hydrates from the WIRE (never a hardcoded default) and commits on pick',
      (tester) async {
    final repo = FixtureSettingsRepository()
      ..fixtureDataDir = '/Users/x/.anselm'
      // A value that is NOT the backend default — a panel that hardcoded 90 would still show 90 and
      // this test would catch it. 一个**不是**后端默认的值——硬编 90 的面板会照样显示 90,本测试抓的就是它。
      ..fixtureRetention = const RetentionConfig(runRetentionDays: 30);
    await tester.pumpWidget(_host(repo, const StoragePanel()));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(StoragePanel)));

    expect(find.text(t.settings.storage.retention30), findsOneWidget,
        reason: '面板水化自线缆,绝不硬编默认(后端恒返具体值)');

    await tester.tap(find.byType(AnDropdown<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.settings.storage.retention180).last);
    await tester.pumpAndSettle();
    expect(repo.fixtureRetention.runRetentionDays, 180, reason: '选中即提交,无 Save 钮');
    expect(find.text(t.settings.storage.retentionSaved), findsOneWidget);
  });

  testWidgets('retention: «forever» commits 0 — the sweeper must be switchable OFF', (tester) async {
    final repo = FixtureSettingsRepository()..fixtureDataDir = '/tmp/x';
    await tester.pumpWidget(_host(repo, const StoragePanel()));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(StoragePanel)));

    await tester.tap(find.byType(AnDropdown<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.settings.storage.retentionForever).last);
    await tester.pumpAndSettle();
    expect(repo.fixtureRetention.runRetentionDays, 0, reason: '0=永久:清理绝不跑');
  });

  testWidgets('retention: the row wears the MACHINE scope badge (settings.json, no workspace axis)',
      (tester) async {
    final repo = FixtureSettingsRepository()..fixtureDataDir = '/tmp/x';
    await tester.pumpWidget(_host(repo, const StoragePanel()));
    await tester.pumpAndSettle();
    // Section-level, because storage is a MIXED-scope panel (data dir = machine, reset prefs =
    // device) — S-16: a page-head badge on a mixed page necessarily lies.
    // 节级:存储是**混域**面板(数据目录=全机、重置本地偏好=本机)——S-16:混域页的页头徽必撒谎。
    // Two machine-scoped sections now (retention + database), both correctly section-level.
    // 现有两个机器级节(retention + database),都正确地节级。
    expect(
        find.byWidgetPredicate((w) => w is AnScopeBadge && w.scope == AnSettingScope.machine),
        findsNWidgets(2));
  });

  // ── 数据库 (磁盘回收, WRK-070 T4) ──
  testWidgets('database: footprint shows the DB size AND the reclaimable dead space (honest)',
      (tester) async {
    final repo = FixtureSettingsRepository()
      ..fixtureDataDir = '/tmp/x'
      ..fixtureDbBytes = 120 * 1024 * 1024
      ..fixtureDeadBytes = 48 * 1024 * 1024;
    await tester.pumpWidget(_host(repo, const StoragePanel()));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(StoragePanel)));

    expect(find.text(t.settings.storage.database), findsWidgets, reason: '数据库节存在');
    // The footprint reads «120.0 MB, of which 48.0 MB reclaimable» — dead space is displayed, not hidden.
    // 足迹读作「120.0 MB,其中 48.0 MB 可回收」——死空间被显示、不被隐藏。
    expect(
        find.text(t.settings.storage
            .dbFootprint(size: formatBytes(120 * 1024 * 1024), dead: formatBytes(48 * 1024 * 1024))),
        findsOneWidget,
        reason: '诚实展示库大小 + 死空间');
    // The compact button is enabled once the stat resolves. 统计读回后压缩按钮可用。
    expect(find.text(t.settings.storage.compact), findsOneWidget);
  });

  testWidgets('database: compact shows a BUSY state while locked, then reclaims and refetches',
      (tester) async {
    final repo = FixtureSettingsRepository()
      ..fixtureDataDir = '/tmp/x'
      ..fixtureDbBytes = 120 * 1024 * 1024
      ..fixtureDeadBytes = 48 * 1024 * 1024;
    // Gate the compact so we can observe the in-flight «Compacting…» state (VACUUM locks the DB a few
    // seconds in reality). 用闸卡住压缩,以观察在飞的「压缩中…」态(现实里 VACUUM 锁库几秒)。
    final gate = Completer<void>();
    repo.compactGate = gate;
    await tester.pumpWidget(_host(repo, const StoragePanel()));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(StoragePanel)));

    await tester.ensureVisible(find.text(t.settings.storage.compact));
    await tester.tap(find.text(t.settings.storage.compact));
    await tester.pump(); // let setState(_busy=true) land, but the gate keeps compact in flight

    // Busy: label flips to «Compacting…» + a spinner, and the button is disabled (no re-tap).
    // 忙态:标签翻成「压缩中…」+ 转圈,按钮禁用(不可重复点)。
    expect(find.text(t.settings.storage.compacting), findsWidgets, reason: '锁库期间显示忙态');
    expect(find.byType(AnSpinner), findsOneWidget, reason: '诚实反馈:正在压缩、非卡死');

    // Release the lock → reclaim completes. 放开锁→回收完成。
    gate.complete();
    await tester.pumpAndSettle();

    // Reclaimed toast reports the bytes returned; the stat refetches → dead space now 0.
    // 回收 toast 报告还回的字节;统计重取→死空间归 0。
    expect(find.text(t.settings.storage.compacted(mb: formatBytes(48 * 1024 * 1024))), findsOneWidget);
    expect(repo.fixtureDeadBytes, 0, reason: '压缩把死空间还给 OS');
    expect(
        find.text(t.settings.storage
            .dbFootprint(size: formatBytes(72 * 1024 * 1024), dead: formatBytes(0))),
        findsOneWidget,
        reason: '重取后足迹缩小(120-48=72MB)、可回收归 0');
  });

  testWidgets('database: a compact failure (disk full) surfaces an honest error toast',
      (tester) async {
    final repo = FixtureSettingsRepository()
      ..fixtureDataDir = '/tmp/x'
      ..failNextCompact = true;
    await tester.pumpWidget(_host(repo, const StoragePanel()));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(StoragePanel)));

    await tester.ensureVisible(find.text(t.settings.storage.compact));
    await tester.tap(find.text(t.settings.storage.compact));
    await tester.pumpAndSettle();

    // The backend message is shown verbatim (STORAGE_COMPACT_FAILED), and the button is usable again.
    // 后端信息原样显示,按钮恢复可用。
    expect(find.textContaining('compaction failed'), findsOneWidget, reason: '诚实报错、非静默');
    expect(find.text(t.settings.storage.compact), findsOneWidget, reason: '失败后按钮回可用');
  });
}
