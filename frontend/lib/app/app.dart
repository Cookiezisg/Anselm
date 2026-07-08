import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/theme.dart';
import '../core/overlay/an_overlay.dart';
import '../core/platform/window_zoom.dart';
import '../core/router/navigation.dart';
import '../core/settings/app_prefs_providers.dart';
import '../i18n/strings.g.dart';
import 'app_startup_gate.dart';
import 'workspace_gate.dart';

/// The root widget (Phase 4.1 STEP 6) — a `MaterialApp.router` driven by [goRouterProvider] (deep-link
/// `/entities/:kind/:id` + back/forward; the shell never remounts, see `app/router.dart`). The gates +
/// overlay host live in the `builder`, NOT in `home`: `MaterialApp.router` has no `home`. The builder's
/// `child` IS the `Router` widget, so while a gate withholds it the Router is not yet mounted; when the gate
/// opens the Router mounts and resolves the pending/initial route — deep links still land correctly, just
/// at gate-open. The gate must be HERE (inside MaterialApp.router) rather than wrapping it, so the router
/// config is attached from launch and the gate only withholds the UI subtree until ready.
///
/// Wrap order (outer → inner): [AnOverlayHost] (registers the root navigator key — shared with the
/// GoRouter, NOT passed to MaterialApp.router which has no `navigatorKey`) → [AppStartupGate] → zoom
/// [CallbackShortcuts] → autofocus [Focus] (live only once the shell shows) → [WorkspaceGate] → the routed
/// `child` (the shell). Kept thin: assembly (DI overrides) accretes in `main.dart`.
///
/// 根 widget(4.1 STEP 6)——MaterialApp.router 由 goRouterProvider 驱动(deep-link + 前进后退;壳永不重挂)。门控 + 浮层宿主
/// 放 builder(非 home:.router 无 home)。builder 的 `child` **即 Router widget**:门控扣住它时 Router 尚未挂载,门控开启时 Router
/// 挂载并解析待决/初始路由(deep-link 仍正确落地,只是在门控开启时)。门控须在此(MaterialApp.router 内、非外裹),使路由配置开机即接上、
/// 门控只在就绪前扣住 UI 子树。包裹序(外→内):AnOverlayHost(注册 root navigator key,与 GoRouter 共享、不传给无此参数的 MaterialApp.router)
/// → AppStartupGate → 缩放快捷键 → autofocus Focus(壳可见后才生效)→ WorkspaceGate → 路由 child(Router→壳)。
class AnApp extends ConsumerWidget {
  const AnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final navigatorKey = ref.watch(rootNavigatorKeyProvider);

    return MaterialApp.router(
      title: context.t.appName,
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      // Dark ships with S1b (the lighting pass); the mode axis is wired NOW so the preference is
      // honest end-to-end. 暗色随 S1b 点亮;mode 轴现在接好,偏好端到端诚实。
      darkTheme: AnTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      // Material component-level localization follows the slang locale (previously unwired — the
      // runtime language switch needs it). Material 组件级本地化跟随 slang(此前未接;运行时切语言需要)。
      locale: TranslationProvider.of(context).flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
      builder: (context, child) => AnOverlayHost(
        navigatorKey: navigatorKey,
        child: AppStartupGate(
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.equal, meta: true): WindowZoom.zoomIn,
              const SingleActivator(LogicalKeyboardKey.equal, meta: true, shift: true): WindowZoom.zoomIn,
              const SingleActivator(LogicalKeyboardKey.minus, meta: true): WindowZoom.zoomOut,
              const SingleActivator(LogicalKeyboardKey.digit0, meta: true): WindowZoom.reset,
            },
            // Backend ready → cold-start resolves the workspace → the routed shell. 后端就绪 → 冷启动定工作区 → 路由壳。
            child: Focus(autofocus: true, child: WorkspaceGate(child: child!)),
          ),
        ),
      ),
    );
  }
}
