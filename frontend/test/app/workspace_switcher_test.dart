import 'package:anselm/app/app_shell.dart';
import 'package:anselm/app/router.dart';
import 'package:anselm/core/contract/workspace.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/core/runtime.dart';
import 'package:anselm/core/shell/oceans.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/data/chat_demo_fixture.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/entities/data/entity_demo_fixture.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/library/data/library_demo_fixture.dart';
import 'package:anselm/features/library/data/library_repository.dart';
import 'package:anselm/features/notifications/data/notification_demo_fixture.dart';
import 'package:anselm/features/notifications/data/notification_providers.dart';
import 'package:anselm/features/scheduler/data/scheduler_demo_fixture.dart';
import 'package:anselm/features/scheduler/data/scheduler_repository.dart';
import 'package:anselm/core/workspace/workspace_switch.dart';
import 'package:anselm/features/chat/ui/stage_panel.dart';
import 'package:anselm/features/settings/state/workspaces_provider.dart';
import 'package:anselm/features/settings/model/settings_catalog.dart';
import 'package:anselm/features/settings/state/settings_detail_provider.dart';
import 'package:anselm/features/settings/state/settings_panel_provider.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// WRK-083 L3 — the left island's workspace menu must be able to SWITCH workspaces.
//
// It could not. The menu's only informative row was hardcoded to `AnMenuItem(label: wsName,
// checked: true, onTap: () {})` — the current workspace, inert, echoing the name already printed on
// the button that opened the menu. A user with two workspaces had no route to the second one from the
// shell at all; the only working switch lived in a settings panel three clicks away.
//
// Nothing was broken enough to notice: the menu opened, it looked right, it had a tick next to the
// workspace you were in. Only counting the rows against `/workspaces` shows it — which is exactly the
// kind of thing the real-machine sweep is for (the API returned two, the menu listed one).
//
// The guard is the COUNT, not the strings: every workspace the app knows about must be reachable here.
// A test that asserted「Personal and 演示工作台 are both listed」would pass just as well against a menu
// that hardcoded those two names.
//
// WRK-083 L3——左岛的 workspace 菜单必须**能切换**。
//
// 它不能。菜单里唯一有信息量的那一行被写死成 `AnMenuItem(label: wsName, checked: true, onTap: () {})`
// ——当前 workspace、不可点、复述着**打开这个菜单的那颗按钮上已经印着的名字**。有两个 workspace 的用户从壳里
// **根本没有路**到第二个;唯一能用的切换藏在三次点击之外的设置面板里。
//
// 没有任何东西坏到会被注意到:菜单打得开、看着也对、你所在的那个 workspace 旁边还有个勾。只有**把行数与
// `/workspaces` 对一对**才看得出来——而这正是真机扫查存在的意义(接口返两个,菜单列一个)。
//
// 守卫守的是**数目**、不是字符串:app 知道的每一个 workspace 都必须在这里够得着。一条断言「Personal 与
// 演示工作台都在列」的测试,对一个把这两个名字写死的菜单同样会通过。

Workspace _ws(String id, String name) => Workspace(
  id: id,
  name: name,
  language: 'zh-CN',
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

const _all = [
  ('ws_one', 'Personal'),
  ('ws_two', '演示工作台'),
  ('ws_three', 'Scratch'),
];

/// The workspace list, fixed — the real controller reaches through the settings repository.
/// 固定的 workspace 列表——真控制器要穿过 settings repository。
class _FixedWorkspaces extends WorkspacesController {
  @override
  Future<List<Workspace>> build() async => [
    for (final (id, name) in _all) _ws(id, name),
  ];
}

class _Shell extends ConsumerWidget {
  const _Shell();
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: AnTheme.light(),
    routerConfig: ref.watch(goRouterProvider),
  );
}

ProviderScope _host() => ProviderScope(
  overrides: [
    entityRepositoryProvider.overrideWithValue(demoEntityRepository()),
    chatRepositoryProvider.overrideWithValue(demoChatRepository()),
    notificationRepositoryProvider.overrideWithValue(
      demoNotificationRepository(),
    ),
    libraryRepositoryProvider.overrideWithValue(demoLibraryRepository()),
    schedulerRepositoryProvider.overrideWithValue(demoSchedulerRepository()),
    goRouterProvider.overrideWith(buildAppRouter),
    workspacesProvider.overrideWith(_FixedWorkspaces.new),
  ],
  child: TranslationProvider(child: const _Shell()),
);

Future<void> _pump(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('the shell workspace menu lists EVERY workspace, and switches', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await _pump(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
      listen: false,
    );
    container.read(activeWorkspaceProvider.notifier).state = 'ws_one';
    await _pump(tester);

    // Open the footer menu BY TYPE — its label is the workspace NAME, which is a separate provider
    // from the id and would make this tap depend on a thing the test is not about.
    // **按类型**打开底栏菜单——它的标签是 workspace **名字**,那是与 id 分开的另一个 provider,按文字点会让
    // 这一下依赖于本测试并不关心的东西。
    await tester.tap(find.byType(AnWorkspaceButton));
    await tester.pumpAndSettle();

    for (final (_, name) in _all) {
      expect(
        find.text(name),
        findsWidgets,
        reason:
            'every workspace must be reachable from the shell — "$name" is missing '
            '(WRK-083 L3)',
      );
    }

    // And the rows are LIVE: tapping another workspace switches to it. 且行是活的:点别的即切过去。
    await tester.tap(find.text('Scratch').last);
    await tester.pumpAndSettle();
    expect(
      container.read(activeWorkspaceProvider),
      'ws_three',
      reason: 'the row must run the hot-switch action, not sit there checked',
    );

    // “New workspace” is not a stub and does not grow a second popover form: it opens the canonical
    // Workspaces/addWorkspace surface in Settings.
    // 「新建工作区」不是 stub、也不另长浮层表单:直达 Settings 的规范 Workspaces/addWorkspace 面。
    await tester.tap(find.byType(AnWorkspaceButton));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(
        Translations.of(
          tester.element(find.byType(AppShell)),
        ).shell.newWorkspace,
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedOceanProvider), OceanKind.settings);
    expect(container.read(settingsPanelProvider), SettingsPanel.workspaces);
    expect(container.read(settingsDetailProvider)?.kind, 'addWorkspace');
  });

  // WRK-083 L1 (the residual) — the right island's chat face REMEMBERS the last conversation so the
  // sidestage survives an ocean peek (deliberate, see _InspectorStack). But a WORKSPACE switch is not
  // an ocean peek: the remembered thread belongs to the old world, and a memory that survives the
  // switch keeps a StagePanel mounted (offstage, island folded — invisible) whose four providers
  // (director→messages / ledger→touchpoints / pending→interactions / rundown→todos) are all keyed by
  // the old conversation. When the axis flips and the repository cascade fires, they re-run with the
  // old id under the NEW workspace — the exact four-request burst the real-machine log showed, one of
  // them a 404.
  //
  // This guard is STRUCTURAL, on the real shell: after a switch, no StagePanel may remain mounted —
  // offstage included, because offstage is precisely where the defect lives. The wire twin (nothing
  // may ASK about the old conversation) is in test/core/workspace/hot_switch_test.dart.
  //
  // WRK-083 L1(残留)——右岛 chat 脸**记住最后一个对话**,让侧幕活过「去别的海洋看一眼」(刻意为之,见
  // _InspectorStack)。但 workspace 切换不是看一眼:被记住的线程属于**旧世界**,记忆活过切换,就有一个
  // StagePanel 挂着(offstage,岛折着——不可见),它的四个 provider(director→messages / ledger→touchpoints /
  // pending→interactions / rundown→todos)全按旧对话分家。轴一翻、repository 级联开火,它们带着旧 id 在**新**
  // workspace 下重跑——正是真机日志那一簇四条请求,其中一条 404。
  //
  // 本守卫是**结构**的、打在真壳上:切换之后不得再有任何 StagePanel 挂载——**含 offstage**,因为缺陷恰恰住在
  // offstage 里。线缆孪生守卫(不得再有谁**问**旧对话)在 test/core/workspace/hot_switch_test.dart。
  testWidgets('a workspace switch unbinds the kept-alive sidestage (L1)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await _pump(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
      listen: false,
    );
    container.read(activeWorkspaceProvider.notifier).state = 'ws_one';
    await _pump(tester);

    // Open a thread: the inspector's chat slot binds and mounts its StagePanel — offstage, because
    // chat's island defaults folded; that is exactly why the finder must not skip offstage.
    // 打开线程:右岛 chat 槽绑定并挂 StagePanel——offstage(chat 岛默认折),这正是 finder 不得跳过 offstage 的原因。
    container.read(goRouterProvider).go('/chat/cv_sync');
    await _pump(tester);
    expect(
      find.byType(StagePanel, skipOffstage: false),
      findsOneWidget,
      reason: 'precondition: opening a thread really did bind the sidestage',
    );

    container
        .read(workspaceSwitchProvider)
        .switchTo(id: 'ws_two', name: '演示工作台');
    await _pump(tester);

    expect(container.read(activeWorkspaceProvider), 'ws_two');
    expect(
      find.byType(StagePanel, skipOffstage: false),
      findsNothing,
      reason:
          'the remembered chat thread belongs to the OLD workspace — a StagePanel that '
          'survives the switch re-fetches four old-conversation endpoints under the new '
          "one (WRK-083 L1's 404 burst)",
    );
  });
}
