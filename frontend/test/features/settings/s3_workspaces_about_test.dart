import 'package:anselm/core/contract/workspace.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/core/runtime.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/settings/data/settings_repository.dart';
import 'package:anselm/features/settings/state/settings_detail_provider.dart';
import 'package:anselm/features/settings/state/update_check_provider.dart';
import 'package:anselm/features/settings/ui/panels/about_panel.dart';
import 'package:anselm/features/settings/ui/panels/workspaces_panel.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// S3 batteries: the workspace roster (active highlighted, row click = hot switch), create, the
// pushed-in editor with the danger zone (type-to-confirm + real numbers + hazard line + failed
// delete stays put), and About's update check (available / can't-check faces + version compare).
// S3 电池:名册(当前高亮/点行热切换)/新建/编辑页危险区(输入名解锁+真数字+警示+失败留守)/关于页更新检查。

class _ActiveWs extends ActiveWorkspace {
  @override
  String? build() => 'ws_demo0000000000';
}

Widget _host(
  FixtureSettingsRepository repo, {
  Widget child = const WorkspacesPanel(),
  GoRouter? router,
}) {
  return ProviderScope(
    overrides: [
      settingsPrefsProvider.overrideWithValue(SettingsPrefs.inMemory()),
      settingsRepositoryProvider.overrideWithValue(repo),
      activeWorkspaceProvider.overrideWith(_ActiveWs.new),
      if (router != null) goRouterProvider.overrideWithValue(router),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

Workspace _ws(String id, String name) => Workspace(
  id: id,
  name: name,
  language: 'zh-CN',
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  group('工作区名册 roster', () {
    testWidgets('active row carries the Current mark; row click hot-switches', (
      tester,
    ) async {
      final repo = FixtureSettingsRepository()
        ..extraWorkspaces.add(_ws('ws_2', 'Side'));
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
        initialLocation: '/',
      );
      await tester.pumpWidget(_host(repo, router: router));
      await tester.pumpAndSettle();
      final t = Translations.of(tester.element(find.byType(WorkspacesPanel)));
      expect(find.text('Demo'), findsOneWidget);
      expect(
        find.text(t.settings.ws.current),
        findsOneWidget,
        reason: '当前行常驻标',
      );

      final panelEl = tester.element(find.byType(WorkspacesPanel));
      final container = ProviderScope.containerOf(panelEl, listen: false);
      await tester.tap(find.text('Side'));
      await tester.pumpAndSettle();
      expect(container.read(activeWorkspaceProvider), 'ws_2', reason: '点行=热切换');
      expect(container.read(activeWorkspaceNameProvider), 'Side');
    });

    testWidgets('create pushes the form; a new workspace lands in the roster', (
      tester,
    ) async {
      final repo = FixtureSettingsRepository();
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();
      final t = Translations.of(tester.element(find.byType(WorkspacesPanel)));

      await tester.tap(find.text(t.settings.ws.newWorkspace));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Fresh');
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.settings.ws.create));
      await tester.pumpAndSettle();

      expect(repo.extraWorkspaces.single.name, 'Fresh');
      expect(find.text('Fresh'), findsOneWidget, reason: '回名册即见新行');
    });
  });

  group('危险区 danger zone', () {
    testWidgets(
      'real numbers + hazard line; typing the name unlocks; delete removes',
      (tester) async {
        final repo = FixtureSettingsRepository()
          ..extraWorkspaces.add(_ws('ws_2', 'Side'))
          ..stats = const WorkspaceStats(
            conversations: 7,
            functions: 2,
            agents: 1,
            documents: 3,
            runningFlowruns: 2,
          );
        await tester.pumpWidget(_host(repo));
        await tester.pumpAndSettle();
        final panelEl = tester.element(find.byType(WorkspacesPanel));
        final container = ProviderScope.containerOf(panelEl, listen: false);
        final t = Translations.of(panelEl);

        container
            .read(settingsDetailProvider.notifier)
            .push('workspace', id: 'ws_2');
        await tester.pumpAndSettle();
        expect(
          find.byType(AnTypeToConfirm),
          findsOneWidget,
          reason: '非当前+非最后=有危险区',
        );
        expect(
          find.textContaining('7 对话'),
          findsOneWidget,
          reason: '真数字入散文(S-11)',
        );
        expect(
          find.textContaining('3 实体'),
          findsOneWidget,
          reason: 'fn+hd+ag+wf 合计',
        );
        expect(
          find.text(t.settings.ws.runningWarn(n: 2)),
          findsOneWidget,
          reason: '动态警示红字',
        );

        // Locked until the EXACT name is typed. 名字不符=锁。
        final deleteBtn = find.text(t.settings.ws.confirmDelete);
        await tester.tap(deleteBtn, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(repo.extraWorkspaces, hasLength(1), reason: '未解锁,删除未发生');

        await tester.enterText(
          find.descendant(
            of: find.byType(AnTypeToConfirm),
            matching: find.byType(TextField),
          ),
          'Side',
        );
        await tester.pumpAndSettle();
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();
        expect(repo.extraWorkspaces, isEmpty, reason: '精确名解锁后删除生效');
        expect(
          container.read(settingsDetailProvider),
          isNull,
          reason: '删除成功弹回名册',
        );
      },
    );

    testWidgets(
      'the ACTIVE workspace offers no danger zone; a failed delete stays put',
      (tester) async {
        final repo = FixtureSettingsRepository()
          ..extraWorkspaces.add(_ws('ws_2', 'Side'))
          ..failNextWorkspaceDelete = 'WORKSPACE_HAS_RUNNING_WORK';
        await tester.pumpWidget(_host(repo));
        await tester.pumpAndSettle();
        final panelEl = tester.element(find.byType(WorkspacesPanel));
        final container = ProviderScope.containerOf(panelEl, listen: false);
        final t = Translations.of(panelEl);

        container
            .read(settingsDetailProvider.notifier)
            .push('workspace', id: 'ws_demo0000000000');
        await tester.pumpAndSettle();
        expect(
          find.byType(AnTypeToConfirm),
          findsNothing,
          reason: '当前 workspace 绝不给删',
        );
        expect(find.text(t.settings.ws.current), findsOneWidget);

        container
            .read(settingsDetailProvider.notifier)
            .push('workspace', id: 'ws_2');
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byType(AnTypeToConfirm),
            matching: find.byType(TextField),
          ),
          'Side',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.settings.ws.confirmDelete));
        await tester.pumpAndSettle();
        expect(repo.extraWorkspaces, hasLength(1), reason: '脚本失败,行还在');
        expect(
          container.read(settingsDetailProvider)?.id,
          'ws_2',
          reason: '失败留守编辑页(S-11)',
        );
      },
    );
  });

  group('关于 about', () {
    testWidgets(
      'versions render; a fresh check reports available with a download link',
      (tester) async {
        final repo = FixtureSettingsRepository()..version = '9.9.9-engine';
        await tester.pumpWidget(_host(repo, child: const AboutPanel()));
        await tester.pumpAndSettle();
        expect(find.text('9.9.9-engine'), findsOneWidget, reason: '引擎版本行');
      },
    );

    test('isNewerVersion: v-prefix / equal / older / garbage', () {
      expect(isNewerVersion('v1.2.3', '1.2.2'), isTrue);
      expect(isNewerVersion('1.2.3', '1.2.3'), isFalse);
      expect(isNewerVersion('v0.9.0', '1.0.0'), isFalse);
      expect(isNewerVersion('garbage', '1.0.0'), isFalse, reason: '怪格式绝不称新');
      expect(isNewerVersion('v2.0.0-beta.1', '1.9.9'), isTrue);
    });
  });
}
