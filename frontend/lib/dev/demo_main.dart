import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` (the ProviderScope override type) is exported from misc.dart, not the main barrel (Riverpod
// 3.x). Named only for demoOverrides's signature. Override 类型在 misc.dart(3.x 主 barrel 不导出)。
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:scaled_app/scaled_app.dart';

import '../app/router.dart';
import '../app/window_setup.dart';
import '../core/design/an_fonts.dart';
import '../core/design/theme.dart';
import '../core/overlay/an_overlay.dart';
import '../core/platform/window_zoom.dart';
import '../core/router/navigation.dart';
import '../core/settings/app_prefs_providers.dart';
import '../core/settings/settings_prefs.dart';
import '../core/shortcuts/global_shortcuts.dart';
import '../core/model/model_capabilities.dart';
import '../core/notice/notice_center.dart';
import '../features/scheduler/data/scheduler_demo_fixture.dart';
import '../features/scheduler/data/scheduler_repository.dart';
import '../features/settings/data/settings_demo_fixture.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/chat/data/chat_demo_fixture.dart';
import '../features/chat/data/chat_providers.dart';
import '../features/library/data/library_repository.dart';
import '../features/library/data/library_demo_fixture.dart';
import '../features/entities/data/entity_demo_fixture.dart';
import '../features/entities/data/entity_providers.dart';
import '../features/notifications/data/notification_demo_fixture.dart';
import '../features/notifications/data/notification_fixture.dart';
import '../features/notifications/data/notification_providers.dart';
import '../i18n/strings.g.dart';
import 'demo_notice_showcase.dart';
import 'perf_probe.dart';
import '../app/entity_mention_source.dart';
import '../core/entity/mention_source.dart';

/// Entry for `make demo` — the REAL app shell + router (byte-identical routing to `make app`, sharing
/// [buildAppRouter]) driven by fake data: one ProviderScope override swaps the repository seam for the
/// zero-backend fixtures. The ONLY differences from `make app` are (a) the data source and (b) NO startup
/// or workspace gates (there is no sidecar to wait for). Everything else — `MaterialApp.router`,
/// deep-link routing, the [AnOverlayHost] toast/dialog layer — is the same surface. NO per-feature run
/// targets: app and demo share the shell + router, differing only in data + gates.
///
/// 入口:`make demo`——真 app 壳 + 路由(与 make app 共用 buildAppRouter、路由逐字一致),假数据驱动:一个 override 把数据缝换成
/// 零后端 fixture。与 make app 仅两处差异:①数据源 ②无启动/工作区门控(无 sidecar 可等)。其余(MaterialApp.router、deep-link、
/// AnOverlayHost toast/dialog 层)同一面。绝不加 per-feature 入口。
/// The demo's ProviderScope overrides — the repository seam swapped for the zero-backend fixtures.
/// Shared by [main] and the P5 perf harness (`integration_test/perf/`) so both drive the byte-identical
/// app off the same fixtures; the caller passes the [notifications] repo it wants (main keeps a handle to
/// drive its live-notice timer). demo override 集,main 与 P5 perf harness 共用同一份 fixture 驱动同一 app。
List<Override> demoOverrides(
  SettingsPrefs prefs,
  FixtureNotificationRepository notifications,
) => [
  settingsPrefsProvider.overrideWithValue(prefs),
  goRouterProvider.overrideWith(buildAppRouter),
  entityRepositoryProvider.overrideWithValue(demoEntityRepository()),
  chatRepositoryProvider.overrideWithValue(demoChatRepository()),
  libraryRepositoryProvider.overrideWithValue(demoLibraryRepository()),
  notificationRepositoryProvider.overrideWithValue(notifications),
  settingsRepositoryProvider.overrideWithValue(demoSettingsRepository()),
  schedulerRepositoryProvider.overrideWithValue(demoSchedulerRepository()),
  // Capabilities are core-level (S-15): zero-backend demo feeds them directly, never HTTP.
  // 能力目录在 core(S-15):零后端 demo 直喂,绝不打 HTTP。
  modelCapabilitiesProvider.overrideWith((ref) async => demoModelCapabilities),
  mentionSourceProvider.overrideWith(entityMentionSource),
];

Future<void> main() async {
  // The SCALED binding, byte-for-byte as main.dart creates it. Zoom is neither a data source nor a
  // gate, so the 铁律「app 与 demo 只差两点」 forbids it diverging here — and it is not decorative:
  // WindowZoom._apply() only relayouts `if (binding is ScaledWidgetsFlutterBinding)`, so a bare
  // WidgetsFlutterBinding makes that test FALSE and ⌘± dies SILENTLY (the factor moves, the tree
  // never reflows). The demo is the visual acceptance floor — every deviation from the app falsifies
  // an acceptance run. Guarded by test/guards/demo_parity_guard_test.dart.
  // scaled binding,与 main.dart 逐字同款。缩放既非数据源亦非门控,故「只差两点」铁律不许它在此分叉——
  // 且它不是装饰:WindowZoom._apply() 只在 `binding is ScaledWidgetsFlutterBinding` 时才重排,裸 binding
  // 让该判恒假、⌘± **静默**失效(factor 动了、树永不重排)。demo 是视觉验收地板,与 app 的每处偏离都让
  // 验收失真。由 demo_parity_guard_test.dart 守。
  ScaledWidgetsFlutterBinding.ensureInitialized(
    scaleFactor: WindowZoom.scaleFactorCallback,
  );
  if (kPerfProbeEnabled) installPerfProbe();
  LocaleSettings.useDeviceLocaleSync();
  // Real persisted prefs in the demo too — chrome memory (island widths / last ocean / window
  // geometry) survives a relaunch, same as the app. demo 也用真持久偏好,与 app 同。
  final prefs = await SettingsPrefs.load();
  WindowZoom.useSettingsPrefs(
    prefs,
  ); // zoom persists via the central prefs, same as the app
  // Resolve the RESTART font axes before runApp, same as the app (content axis stays hot). 同 app 启动前解析重启字体轴。
  AnFonts.applyAtBoot(
    ui: prefs.getString(SettingsKeys.fontUi),
    code: prefs.getString(SettingsKeys.fontCode),
  );
  await initWindow(title: 'Anselm · Demo (fixtures)', prefs: prefs);
  WindowZoom.restore(); // the persisted zoom, before the first frame 首帧前恢复持久化缩放
  // Keep the fixture repository as a stable data seam; the demo-only top-band tour itself is mounted below
  // the app root, where it can enqueue operation/event/approval presentation copies and clean up its timers.
  // fixture 仓储仍是稳定数据缝;顶带巡演改挂在 app root 下,可送操作/事件/审批副本并随根卸载清计时器。
  final notifRepo = demoNotificationRepository();
  runApp(
    ProviderScope(
      overrides: demoOverrides(prefs, notifRepo),
      child: TranslationProvider(
        child: const DemoRoot(showcaseNotifications: true),
      ),
    ),
  );
}

/// The demo root — `MaterialApp.router` with the overlay host but NO gates. Mirrors `app.dart#AnApp`
/// minus AppStartupGate/WorkspaceGate. Public so the P5 perf harness mounts the exact same tree.
/// demo 根:MaterialApp.router + 浮层宿主,无门控;公开供 P5 perf harness 挂同一棵树。
class DemoRoot extends ConsumerWidget {
  const DemoRoot({this.showcaseNotifications = false, super.key});

  /// Only `make demo` turns this on. Test and perf mounts keep their timeline deterministic unless they
  /// explicitly opt in. 仅 make demo 开启;测试/perf 默认不启,时间线保持确定。
  final bool showcaseNotifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final navigatorKey = ref.watch(rootNavigatorKeyProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      darkTheme: AnTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
      // Mirror app.dart's wrap (minus the startup/workspace gates the demo has no backend for): the
      // rebindable global shortcuts (⌘B/⌘\/⌘,/⌘±/⌘0) ABOVE the autofocus Focus so cold-start chords
      // reach them (D-035). Handlers are pure provider/static calls — no backend needed. ⌘± additionally
      // needs the SCALED binding main() installs above: this wrap only DELIVERS the chord, it cannot make
      // the tree reflow. 镜像 app 快捷键;⌘± 另需上面那口 scaled binding——本层只负责把和弦送到,让树重排的
      // 不是它。
      builder: (context, child) => AnOverlayHost(
        navigatorKey: navigatorKey,
        child: _DemoNoticeShowcase(
          enabled: showcaseNotifications,
          child: GlobalShortcuts(child: Focus(autofocus: true, child: child!)),
        ),
      ),
    );
  }
}

/// Demo-only, finite top-band tour. It is intentionally mounted below [TranslationProvider] so the script
/// uses the active locale, and below the ProviderScope so it reaches the real shared notice center. The
/// test-facing [DemoRoot] leaves it off by default. demo 专用、有限的顶带巡演:置于 TranslationProvider/ProviderScope
/// 之下,随当前语言进真正共享中心;测试用 DemoRoot 默认关闭。
class _DemoNoticeShowcase extends ConsumerStatefulWidget {
  const _DemoNoticeShowcase({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  ConsumerState<_DemoNoticeShowcase> createState() =>
      _DemoNoticeShowcaseState();
}

class _DemoNoticeShowcaseState extends ConsumerState<_DemoNoticeShowcase> {
  final List<Timer> _timers = <Timer>[];
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.enabled || _scheduled) return;
    _scheduled = true;
    for (final beat in demoTopBandShowcase(context.t)) {
      _timers.add(
        Timer(beat.at, () {
          if (!mounted) return;
          ref
              .read(noticeCenterProvider.notifier)
              .push(beat.message, priority: beat.priority);
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
