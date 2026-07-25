import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/overlay/an_overlay.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/data/entity_repository.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// STEP 6 test support — selection is route-derived, so a feature widget can no longer be handed a fixed
/// selection via a `selectedEntityProvider` override; instead it is driven by a real (test) [GoRouter].
/// This mirrors the app's two locations (`/` + `/entities/:kind/:id` with the same kind redirect) but
/// renders [page] (the widget under test) as the route's content, so a feature can be exercised through
/// routing in isolation. The SAME router instance is the `routerConfig` AND the [goRouterProvider]
/// override, so the widget's `context.go` and `selectedEntityProvider` agree on one source of truth.
///
/// STEP 6 测试支撑:选区由路由派生,不能再用 selectedEntityProvider override 喂固定选区,改由真(测试)GoRouter 驱动。
/// 镜像 app 两 location + kind 校验,但渲被测件作路由内容。同一 router 既是 routerConfig 又是 goRouterProvider override,
/// 故 context.go 与 selectedEntityProvider 同一真相源。

/// A test router rendering [page] for every app location (entities + documents selections). Disposed at
/// tear-down. 测试路由(全部 location 渲被测件)。
GoRouter buildTestRouter({String initialLocation = '/', required Widget page}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/', builder: (_, _) => page),
      GoRoute(
        path: '/entities/:kind/:id',
        redirect: (context, state) =>
            entityKindFromWire(state.pathParameters['kind']) == null
            ? '/'
            : null,
        builder: (_, _) => page,
      ),
      // The workflow graph-editor route (mirrors app/router.dart) — the rail row menu's «打开编辑器» item
      // navigates here. 图编辑器路由(镜像 app 路由)——行菜单「打开编辑器」项导航至此。
      GoRoute(path: '/entities/workflow/:id/editor', builder: (_, _) => page),
      // Documents ocean selections (page / slug-addressed skill) — mirrors app router. 文档选区,镜像 app 路由。
      GoRoute(path: '/library/:id', builder: (_, _) => page),
      GoRoute(path: '/library/skill/:name', builder: (_, _) => page),
      // The chat ocean, id-only (mirrors app/router.dart) — `:iterate` navigates here with the new
      // conversation id. chat 海洋(镜像 app 路由)——`:iterate` 导航至此(新对话 id)。
      GoRoute(path: '/chat/:id', builder: (_, _) => page),
    ],
  );
  addTearDown(router.dispose);
  return router;
}

/// Wrap [page] in a `MaterialApp.router` driven by a test router (injected into [goRouterProvider]), with
/// the [repository] seam overridden (the one override every entities test needs). Pass [initialLocation]
/// to pre-select an entity (deep-link). [overlay] optionally swaps in a scripted [AnOverlayController]
/// (e.g. a fake `confirm()`) for tests exercising the row-menu delete confirm — omitted, the real
/// controller resolves `confirm()` false (no host navigator registered), the safe default for tests that
/// don't care. The `Override` type isn't part of flutter_riverpod's public API, so the common override is
/// taken by concrete type rather than a `List<Override>`.
/// 把被测件包进 MaterialApp.router(测试路由,注入 goRouterProvider)+ 覆盖 repository 缝;initialLocation 预选
/// (deep-link)。overlay 可选换入脚本化 AnOverlayController(测行菜单删除确认);不传则真 controller 的 confirm()
/// 解 false(未挂 host navigator)——对不关心它的测试是安全默认。
Widget routedHost(
  Widget page, {
  String initialLocation = '/',
  EntityRepository? repository,
  GoRouter? router,
  AnOverlayController? overlay,
}) {
  final r =
      router ?? buildTestRouter(initialLocation: initialLocation, page: page);
  return ProviderScope(
    overrides: [
      goRouterProvider.overrideWithValue(r),
      if (repository != null)
        entityRepositoryProvider.overrideWithValue(repository),
      if (overlay != null) overlayProvider.overrideWith(() => overlay),
    ],
    child: TranslationProvider(
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        routerConfig: r,
      ),
    ),
  );
}

/// The deep-link location for a [kind]/[id] selection — `/entities/<kind>/<id>` (re-exported so tests need
/// only this support file). 实体 deep-link 位置(re-export,测试只依赖本支撑文件)。
String selectionLocation(EntityKind kind, String id) =>
    entityLocation(kind, id);
