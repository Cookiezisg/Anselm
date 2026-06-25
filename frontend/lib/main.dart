import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scaled_app/scaled_app.dart';

import 'app/app.dart';
import 'app/window_setup.dart';
import 'core/error/error_boundary.dart';
import 'core/platform/window_zoom.dart';
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
    await initWindow();
    await WindowZoom.restore();
    runApp(TranslationProvider(child: const ProviderScope(child: AnApp())));
  }, (error, stack) {
    debugPrint('[anselm] zone error: $error\n$stack');
  });
}
