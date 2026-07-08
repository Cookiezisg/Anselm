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
import 'core/router/navigation.dart';
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
    await initWindow(prefs: prefs);
    await WindowZoom.restore();
    await initLaunchAtLogin();
    runApp(TranslationProvider(
      child: ProviderScope(
        // The GoRouter (which references the shell + entity kinds) is assembled in the app layer and
        // injected into the core seam. 路由(引用壳 + 实体 kind)在 app 层装配、注入 core 缝。
        overrides: [
          settingsPrefsProvider.overrideWithValue(prefs),
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
