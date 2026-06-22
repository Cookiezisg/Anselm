import 'package:flutter/widgets.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:window_manager/window_manager.dart';

import '../core/design/tokens.dart';
import '../core/platform/host_platform.dart';

/// Configures the desktop window before the app runs — using the RIGHT package for each job
/// (CLAUDE.md 原则 #8, best practice over hand-rolling):
///
///  • `window_manager` owns GEOMETRY — initial size, minimum size, center, resize. It's the
///    purpose-built desktop window package and handles the Retina scale factor + live resize
///    correctly (hand-rolling / sizing through the cosmetics layer caused the window to blow up
///    ×2 on corner-resize — that's the bug this split fixes).
///  • `macos_window_utils` owns CHROME only — a FRAMELESS opaque-white window with a TALLER title
///    bar (`addToolbar`) so macOS vertically centers the OS-managed traffic lights lower, INSIDE
///    the clickable title-bar layer. We never move the native buttons into the content area, and
///    we never size the window through this package.
///
/// 用对的包做对的事(原则 #8):window_manager 管尺寸(scale 正确、修掉 resize ×2 炸开);
/// macos_window_utils 只管外观(无边框 + 加高标题栏让红绿灯居中可点)。Win/Linux 暂 no-op。
Future<void> initWindow() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!HostPlatform.isMacOS) return;

  await windowManager.ensureInitialized();
  await WindowManipulator.initialize();

  // CHROME (macos_window_utils): frameless white + taller title bar → clickable centered lights.
  await WindowManipulator.makeTitlebarTransparent();
  await WindowManipulator.enableFullSizeContentView();
  await WindowManipulator.hideTitle();
  await WindowManipulator.addToolbar();
  await WindowManipulator.setToolbarStyle(toolbarStyle: NSWindowToolbarStyle.unified);

  // GEOMETRY (window_manager): scale-correct size / min / center. Title-bar style stays untouched
  // here — the frameless look is owned by macos_window_utils above. 尺寸由 window_manager 管(标题栏不碰)。
  final options = WindowOptions(
    size: const Size(AnSize.windowInitialWidth, AnSize.windowInitialHeight),
    minimumSize: const Size(AnSize.windowMinWidth, AnSize.windowMinHeight),
    center: true,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
