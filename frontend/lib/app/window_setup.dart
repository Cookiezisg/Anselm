import 'package:flutter/widgets.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:window_manager/window_manager.dart';

import '../core/design/tokens.dart';
import '../core/platform/host_platform.dart';
import '../core/platform/window_fullscreen.dart';

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
///
/// NO LAUNCH FLASH: the native window is HIDDEN at launch (`MainFlutterWindow.order` →
/// `hiddenWindowAtLaunch()`, window_manager's blessed recipe) so it never paints at the xib's default
/// 800×600/off-center rect. `waitUntilReadyToShow` applies size + min + center to the still-hidden
/// window, then its callback's `show()` is the SINGLE reveal — the first frame the user sees is already
/// at the final geometry. 无启动闪烁:原生窗口启动即隐藏(order 钩子),几何就绪后由下方 show() 一次性显示到最终位置。
Future<void> initWindow({String? title}) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!HostPlatform.isMacOS) return;

  await windowManager.ensureInitialized();
  if (title != null) await windowManager.setTitle(title);

  // CHROME (macos_window_utils): frameless white + taller title bar → clickable centered lights.
  // BEST-EFFORT under try: the native window is now HIDDEN at launch (MainFlutterWindow.order →
  // hiddenWindowAtLaunch), so `windowManager.show()` below is the ONLY reveal — a chrome call throwing
  // here must NOT abort initWindow and leave the window invisible forever. A cosmetic failure
  // degrades to a plain (non-frameless) but VISIBLE, correctly-sized window. 窗口已 hidden-at-launch,
  // show() 是唯一显示点;chrome 尽力而为,抛错也不能让 initWindow 中断、窗口永不显示(降级为有边框但可见)。
  try {
    await WindowManipulator.initialize();
    await WindowManipulator.makeTitlebarTransparent();
    await WindowManipulator.enableFullSizeContentView();
    await WindowManipulator.hideTitle();
    // Launch-in-fullscreen guard: macOS can restore an app DIRECTLY into fullscreen, where the
    // unified NSToolbar renders as an OPAQUE white band (AppKit hosts it in a separate fullscreen
    // container that ignores titlebarAppearsTransparent). Only add the toolbar when NOT already
    // fullscreen; the WindowListener below keeps it in sync across later transitions. 全屏启动守卫:
    // macOS 可直接以全屏恢复,此时统一 toolbar 会渲成不透明白带,故未全屏才加 toolbar;下方监听维持后续同步。
    final full = await windowManager.isFullScreen();
    WindowFullScreen.active.value = full;
    if (!full) {
      await WindowManipulator.addToolbar();
      await WindowManipulator.setToolbarStyle(toolbarStyle: NSWindowToolbarStyle.unified);
    }
  } catch (_) {
    // chrome is cosmetic; the window must still be revealed below. 外观非必需,下方仍须显示窗口。
  }

  // Adapt the chrome to native fullscreen transitions: in fullscreen the OS drops the traffic
  // lights + taller title bar, so the toolbar (else an opaque white band) is removed and the
  // shell's lights-reservations collapse via WindowFullScreen; on leave, restore both. Registered
  // AFTER ensureInitialized (required). 随全屏切换适配 chrome:进则撤 toolbar(否则白带)+ 收灯位,出则还原。
  windowManager.addListener(_FullScreenChrome());

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

/// Keeps the macOS chrome consistent across native fullscreen transitions (window_manager fires
/// these AFTER the transition completes). Enter → drop the unified toolbar (AppKit would render it
/// opaque = the white-band bug) + flip [WindowFullScreen.active] so the shell collapses its
/// traffic-light insets to 0. Leave → rebuild a fresh toolbar and RE-APPLY the unified style
/// (`addToolbar` builds a new NSToolbar but does NOT restyle) + clear the flag. The flag is set
/// synchronously first (immediate Flutter reflow); the native toolbar call trails best-effort.
///
/// 维持 macOS chrome 随原生全屏切换一致(window_manager 在切换完成后触发)。进:撤统一 toolbar(否则
/// AppKit 渲成不透明=白带 bug)+ 翻 WindowFullScreen 使壳收灯位;出:重建 toolbar 并**重设**统一样式
/// (addToolbar 建新 NSToolbar 但不带样式)+ 清标志。标志先同步设(即时 Flutter 重排),原生调用随后尽力而为。
class _FullScreenChrome with WindowListener {
  @override
  void onWindowEnterFullScreen() {
    WindowFullScreen.active.value = true;
    WindowManipulator.removeToolbar();
  }

  @override
  void onWindowLeaveFullScreen() {
    WindowFullScreen.active.value = false;
    _restoreToolbar();
  }

  Future<void> _restoreToolbar() async {
    await WindowManipulator.addToolbar();
    await WindowManipulator.setToolbarStyle(toolbarStyle: NSWindowToolbarStyle.unified);
  }
}
