import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scaled_app/scaled_app.dart';

import 'app/app.dart';
import 'app/router.dart';
import 'app/entity_mention_source.dart';
import 'core/entity/mention_source.dart';
import 'features/notifications/data/notification_providers.dart';
import 'features/notifications/data/os_notifier.dart';
import 'app/window_setup.dart';
import 'core/error/error_boundary.dart';
import 'core/platform/launch_at_login.dart';
import 'core/platform/window_zoom.dart';
import 'core/process/backend_controller.dart';
import 'core/process/master_key.dart';
import 'core/router/navigation.dart';
import 'core/runtime.dart';
import 'core/settings/settings_prefs.dart';
import 'i18n/strings.g.dart';

/// Entry point. The scaled_app binding enables app-wide UI zoom (Cmd +/-): its scaleFactor reads
/// [WindowZoom.factor], so the whole tree reflows at the zoom level. Then configure the desktop
/// window, restore the persisted zoom before the first frame, and run under the assembly-root
/// [ProviderScope].
/// 入口:scaled_app binding 启用应内 UI 缩放(Cmd +/-);选语言 → 配窗口 → 首帧前恢复持久化缩放 →
/// TranslationProvider(语言态)外裹 ProviderScope(装配根)起 app。

Future<void> main() async {
  // runZonedGuarded so uncaught async errors land in ONE sink; the binding MUST be created inside the
  // zone that guards it. installErrorHandlers wires FlutterError/PlatformDispatcher + the recoverable
  // ErrorWidget. 在 zone 内建 binding(zone 须拥有它)+ 装错误汇 + 可恢复 ErrorWidget。
  runZonedGuarded(() async {
    ScaledWidgetsFlutterBinding.ensureInitialized(scaleFactor: WindowZoom.scaleFactorCallback);
    installErrorHandlers();
    LocaleSettings.useDeviceLocaleSync();
    // Central preferences load ONCE before the window opens — geometry restore + every later
    // consumer read synchronously. 中央偏好在开窗前载入:几何恢复要用,此后全员同步读。
    final prefs = await SettingsPrefs.load();
    WindowZoom.useSettingsPrefs(prefs); // zoom persists via the central prefs, not a private key
    // C-030: create the sidecar controller + kick its spawn off NOW, so the Go backend boots in PARALLEL
    // with window init + the first frame instead of serially after them (the health-wait was the cold-
    // start long pole). The startup gate's start() on first read is IDEMPOTENT, so it JOINS this in-flight
    // launch — one controller, one spawn. The keychain/master-key resolve stays inside _spawn (ADR-0008
    // ordering unchanged; only WHEN the spawn is triggered moves earlier). 提前建控制器+起 spawn,后端与开窗/
    // 首帧并行 boot(health-wait 是冷启长杆);gate 首读的 start() 幂等并入,一控制器一次 spawn;keychain 次序不变。
    final backend = BackendController(masterKey: () => MasterKey().resolve());
    unawaited(backend.start());
    // Exit hygiene (WRK-070 T2): ⌘Q / red-button terminate asks the framework before dying
    // (FlutterAppDelegate routes applicationShouldTerminate → onExitRequested), so this is THE
    // clean-quit moment to SIGTERM the sidecar — its ordered shutdown reaps every child (llama
    // included). Without it the sidecar orphans under launchd (WRK-070 measured 4 alive 5h+).
    // No anchor needed: constructing the listener registers it as a binding observer, and the
    // binding's observer list holds it for the app's whole life. Crash paths are covered by the
    // backend's own stdin deadman switch (see BackendController._spawn).
    // 退出卫生:⌘Q/红点关窗会先问框架,此刻优雅停 sidecar(其有序关停连 llama 一并收);不接=孤儿。
    // 无需锚:构造即注册进 binding 的 observer 表,由 binding 持有终生。崩溃路径由后端 stdin 死人开关兜住。
    AppLifecycleListener(onExitRequested: () => stopBackendOnExit(backend));
    await initWindow(prefs: prefs);
    WindowZoom.restore();
    await initLaunchAtLogin();
    runApp(TranslationProvider(
      child: ProviderScope(
        // The GoRouter (which references the shell + entity kinds) is assembled in the app layer and
        // injected into the core seam. 路由(引用壳 + 实体 kind)在 app 层装配、注入 core 缝。
        overrides: [
          settingsPrefsProvider.overrideWithValue(prefs),
          // Hand the pre-started controller to the provider (its dispose preserved), so the startup gate
          // reuses THIS instance rather than creating a second one. 把预启控制器交给 provider(保留 dispose)。
          backendControllerProvider.overrideWith((ref) {
            ref.onDispose(backend.dispose);
            return backend;
          }),
          goRouterProvider.overrideWith(buildAppRouter),
          mentionSourceProvider.overrideWith(entityMentionSource),
          // The real app posts OS-native notifications when unfocused (demo/gallery keep the Noop default).
          // 真 app 未聚焦时发 OS 原生通知(demo/gallery 保持 Noop 默认)。
          osNotifierProvider.overrideWithValue(LocalOsNotifier()),
        ],
        child: const AnApp(),
      ),
    ));
  }, (error, stack) {
    debugPrint('[anselm] zone error: $error\n$stack');
  });
}
