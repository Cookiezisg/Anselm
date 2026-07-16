import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` (the ProviderScope override type) is exported from misc.dart, not the main barrel (Riverpod
// 3.x). Named only for demoOverrides's signature. Override 类型在 misc.dart(3.x 主 barrel 不导出)。
import 'package:flutter_riverpod/misc.dart' show Override;

import '../app/router.dart';
import '../app/window_setup.dart';
import '../core/design/theme.dart';
import '../core/overlay/an_overlay.dart';
import '../core/router/navigation.dart';
import '../core/settings/app_prefs_providers.dart';
import '../core/settings/settings_prefs.dart';
import '../core/shortcuts/global_shortcuts.dart';
import '../core/model/model_capabilities.dart';
import '../features/settings/data/settings_demo_fixture.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/chat/data/chat_demo_fixture.dart';
import '../features/chat/data/chat_providers.dart';
import '../features/documents/data/document_repository.dart';
import '../features/documents/data/documents_demo_fixture.dart';
import '../features/entities/data/entity_demo_fixture.dart';
import '../features/entities/data/entity_providers.dart';
import '../features/notifications/data/notification_demo_fixture.dart';
import '../features/notifications/data/notification_fixture.dart';
import '../features/notifications/data/notification_providers.dart';
import '../i18n/strings.g.dart';
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
/// drive its live-toast timer). demo override 集,main 与 P5 perf harness 共用同一份 fixture 驱动同一 app。
List<Override> demoOverrides(SettingsPrefs prefs, FixtureNotificationRepository notifications) => [
      settingsPrefsProvider.overrideWithValue(prefs),
      goRouterProvider.overrideWith(buildAppRouter),
      entityRepositoryProvider.overrideWithValue(demoEntityRepository()),
      chatRepositoryProvider.overrideWithValue(demoChatRepository()),
      documentsRepositoryProvider.overrideWithValue(demoDocumentsRepository()),
      notificationRepositoryProvider.overrideWithValue(notifications),
      settingsRepositoryProvider.overrideWithValue(demoSettingsRepository()),
      // Capabilities are core-level (S-15): zero-backend demo feeds them directly, never HTTP.
      // 能力目录在 core(S-15):零后端 demo 直喂,绝不打 HTTP。
      modelCapabilitiesProvider.overrideWith((ref) async => demoModelCapabilities),
      mentionSourceProvider.overrideWith(entityMentionSource),
    ];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kPerfProbeEnabled) installPerfProbe();
  LocaleSettings.useDeviceLocaleSync();
  // Real persisted prefs in the demo too — chrome memory (island widths / last ocean / window
  // geometry) survives a relaunch, same as the app. demo 也用真持久偏好,与 app 同。
  final prefs = await SettingsPrefs.load();
  await initWindow(title: 'Anselm · Demo (fixtures)', prefs: prefs);
  // D-031 — a live toast a few seconds in: a background workflow «fails» and emits a durable danger
  // signal, so the ToastDispatcher (watched by the shell) pops the right-top toast. Hoist the repo so we
  // can drive it after the shell has mounted its signal listener. 延时活 toast:后台工作流「失败」推信号。
  final notifRepo = demoNotificationRepository();
  Timer(const Duration(seconds: 6), () => notifRepo.emit(demoLiveToast()));
  runApp(
    ProviderScope(
      overrides: demoOverrides(prefs, notifRepo),
      child: TranslationProvider(child: const DemoRoot()),
    ),
  );
}

/// The demo root — `MaterialApp.router` with the overlay host but NO gates. Mirrors `app.dart#AnApp`
/// minus AppStartupGate/WorkspaceGate. Public so the P5 perf harness mounts the exact same tree.
/// demo 根:MaterialApp.router + 浮层宿主,无门控;公开供 P5 perf harness 挂同一棵树。
class DemoRoot extends ConsumerWidget {
  const DemoRoot({super.key});

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
      // reach them (D-035). Handlers are pure provider/static calls — no backend needed. 镜像 app 快捷键。
      builder: (context, child) => AnOverlayHost(
        navigatorKey: navigatorKey,
        child: GlobalShortcuts(child: Focus(autofocus: true, child: child!)),
      ),
    );
  }
}
