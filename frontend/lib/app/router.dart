import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router/navigation.dart';
import '../features/entities/data/entity_kind.dart';
import '../features/entities/ui/detail/workflow_editor_page.dart';
import '../features/entities/ui/graph/entities_graph_page.dart';
import 'app_shell.dart';

/// The app's GoRouter (Phase 4.1 STEP 6). Assembled in `app/` because it is the one place that knows BOTH
/// the shell ([AppShell]) AND the entity kinds ([entityKindFromWire]); it overrides the `core`
/// [goRouterProvider] seam in `main.dart` + `demo_main.dart` (and the test harness builds its own).
///
/// THE CONSTANT-SHELL CONTRACT (research-verified): both locations — `/` (no selection) and
/// `/entities/:kind/:id` — render the SAME page via [_shellPage], a [NoTransitionPage] with ONE constant
/// key. Same page key across navigations → the Navigator reuses the same Element → the three-island shell
/// (rail / ocean / the keepAlive run-terminal + scroll positions) NEVER remounts. Selection is derived
/// from the URL by `selectedEntityProvider` (which listens to this router's delegate), not from the page.
///   - Do NOT use two distinct pages → that remounts the shell (loses keepAlive state).
///   - Do NOT use ShellRoute (no child slot; the ocean is provider-driven) or StatefulShellRoute (multi-branch only).
///   - Bad `:kind` (not one of the four) → redirect home. `:id` existence can't be checked at the router
///     layer, so a missing id surfaces as the ocean's error state under the builder (no awaited DB hit
///     in redirect — that would block first paint).
///   - The startup/workspace GATES are NOT redirects: they are wrapping widgets in `MaterialApp.router`'s
///     `builder` (see `app.dart`), so the router stays live for deep-link resolution while the gates
///     withhold UI until ready.
///
/// 4.1 STEP 6 路由。建在 app(唯一同时认识壳 + 实体 kind 处),override core 的 goRouterProvider 缝。常量壳契约:两 location
/// 共用同一常量 key 的 NoTransitionPage → Navigator 复用同一 Element → 三岛壳永不重挂(keepAlive run 终端/滚动全保);选区由
/// selectedEntityProvider 监听本 delegate 派生。坏 kind→redirect 回首页;:id 存在性路由层管不了→ ocean 错误态。门控是 builder
/// 里的包裹 widget、非 redirect(使 router 常活、deep-link 照常解析)。
GoRouter buildAppRouter(Ref ref) {
  final navKey = ref.watch(rootNavigatorKeyProvider);
  final router = GoRouter(
    navigatorKey: navKey,
    initialLocation: '/',
    // An UNMATCHED path (a typo, an extra segment, a trailing slash) must NOT fall through to go_router's
    // default error screen — that is a DIFFERENT page and would remount the shell (losing keepAlive +
    // scroll). Render the same constant-key shell page instead; the URL parses to no selection → the ocean
    // shows its empty state. (Our own nav only ever targets `/` or a valid entityLocation; this defends
    // external/deep-link input.) 未匹配路径渲同一常量页(选区→null→空海洋),不触发会重挂壳的默认错误屏。
    errorPageBuilder: _shellPage,
    routes: [
      GoRoute(path: '/', pageBuilder: _shellPage),
      // `/entities` with no selection = the Overview home (same constant-key shell page; the URL parses
      // to no selection → the ocean shows the Overview). `/entities` 无选中=总览主页(同常量壳页)。
      GoRoute(path: '/entities', pageBuilder: _shellPage),
      // The full-page relationship-graph EXPLORE state — a distinct frameless route (its OWN scaffold,
      // NOT the shell), reached from the Overview's graph (node tap / "展开"). Width-aligned to the
      // workflow editor precedent. 全页关系图探索态:独立无边框路由(自有 scaffold、非壳),从总览关系图进。
      GoRoute(
        path: '/entities/graph',
        pageBuilder: (context, state) => const NoTransitionPage(
          key: ValueKey('anselm-entities-graph'),
          child: EntitiesGraphPage(),
        ),
      ),
      GoRoute(
        path: '/entities/:kind/:id',
        // Bounce an unknown kind home; a valid kind falls through (null = no redirect). 坏 kind 回首页。
        redirect: (context, state) =>
            entityKindFromWire(state.pathParameters['kind']) == null ? '/' : null,
        pageBuilder: _shellPage,
      ),
      // Chat conversation selection — same constant-key shell page (no remount). No redirect: a
      // conversation is single-domain, so there's no kind to validate, and :id existence can't be
      // checked at the router layer (same rule as entities). 对话选区,同常量页(不重挂);无 kind 可校、无 redirect。
      GoRoute(path: '/chat/:id', pageBuilder: _shellPage),
      // Documents ocean selection — a page (`/documents/:id`) or a skill (`/documents/skill/:name`;
      // skills are slug-addressed, no id). Same constant-key shell page; existence surfaces as the
      // ocean's error state. The 3-segment skill route and the 2-segment page route can't collide.
      // 文档选区:页(/documents/:id)或 skill(/documents/skill/:name,slug 寻址);同常量页;存在性→海洋错误态。
      GoRoute(path: '/documents/:id', pageBuilder: _shellPage),
      GoRoute(path: '/documents/skill/:name', pageBuilder: _shellPage),
      // Scheduler ocean (WRK-069 §11) — overview / a workflow's operations home (?run= linked pane) /
      // the run flagship (?node= selection) / the id-only run relay (fr_ paste + panel_registry
      // `flowrun` deep links resolve the host workflow there and go-replace to the full path). All the
      // same constant-key shell page. Scheduler 海洋:总览/运营主页/run 旗舰/fr_ 直达中转,同常量壳页。
      GoRoute(path: '/scheduler', pageBuilder: _shellPage),
      GoRoute(path: '/scheduler/w/:id', pageBuilder: _shellPage),
      GoRoute(path: '/scheduler/w/:id/runs/:frId', pageBuilder: _shellPage),
      GoRoute(path: '/scheduler/runs/:frId', pageBuilder: _shellPage),
      // The workflow graph editor is a FULL-SCREEN page (its OWN scaffold, NOT the shell) — a focused
      // edit mode entered from the overview hero, exited back to the entity page. 图编辑器是全屏页
      // (自有 scaffold、非壳):从概览 hero 进、退回实体页。
      GoRoute(
        path: '/entities/workflow/:id/editor',
        pageBuilder: (context, state) => NoTransitionPage(
          key: const ValueKey('anselm-workflow-editor'),
          child: WorkflowEditorPage(workflowId: state.pathParameters['id']!),
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}

/// Both routes resolve to this ONE constant-key page so the shell never remounts. 两路由共用此常量页。
Page<void> _shellPage(BuildContext context, GoRouterState state) =>
    const NoTransitionPage(key: ValueKey('anselm-shell'), child: AppShell());
