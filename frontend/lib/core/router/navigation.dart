import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The navigation seam (Phase 4.1 STEP 6). Two app-created, ref-wired injection points the rest of the
/// tree depends on WITHOUT importing the app layer — the same DIP idiom ADR 0004 uses for workspace +
/// baseUrl. The concrete [GoRouter] (which knows BOTH the app shell AND the entity kinds, so it can only
/// be assembled in the `app/` layer) is supplied by an override; `core`/`features` consume the seam.
///
/// - [rootNavigatorKeyProvider]: the root Navigator key, SHARED by the GoRouter (its root navigator) and
///   [AnOverlayHost] (imperative dialog push). go_router owns the root navigator, so this key is the one
///   sharing point — passed to `GoRouter(navigatorKey:)` and to `AnOverlayHost(navigatorKey:)`. It is NOT
///   passed to `MaterialApp.router` (that constructor has no `navigatorKey`).
/// - [goRouterProvider]: the live router. Throw-by-default so a missing override fails loudly (never a
///   silent blank app); `app/router.dart#buildAppRouter` overrides it in both `main.dart` and
///   `demo_main.dart`, and the test harness overrides it with a test router. Selection derives one-way
///   from this router's delegate (see `features/entities/state/selected_entity.dart`).
///
/// 导航缝(4.1 STEP 6)。两个 app 建、ref 接的注入点,使其余层不 import app 即可依赖(同 ADR 0004 的 workspace/baseUrl
/// DIP)。具体 GoRouter 同时认识壳(app)与实体 kind(features),故只能在 app 层装配、经 override 注入;core/features 消费缝。
/// rootNavigatorKey 由 GoRouter 与 AnOverlayHost 共享(go_router 持 root navigator,此 key 是唯一共享点;不传给 MaterialApp.router——无此参数)。
/// goRouterProvider throw 默认(漏 override 即响亮失败,绝不静默白屏);选区单向派生自其 delegate。
final rootNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (ref) => GlobalKey<NavigatorState>(debugLabel: 'anselm-root'),
);

/// The app's [GoRouter] — injected by the app root (throws until overridden). See [buildAppRouter] in
/// `app/router.dart`. app 根注入(未 override 即抛)。
final goRouterProvider = Provider<GoRouter>(
  (ref) => throw UnimplementedError(
    'goRouterProvider must be overridden by the app root (see app/router.dart#buildAppRouter)',
  ),
);
