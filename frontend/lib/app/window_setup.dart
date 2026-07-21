import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:window_manager/window_manager.dart';

import '../core/design/tokens.dart';
import '../core/platform/host_platform.dart';
import '../core/platform/window_bounds.dart';
import '../core/settings/settings_prefs.dart';
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
Future<void> initWindow({String? title, SettingsPrefs? prefs}) async {
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
      await WindowManipulator.setToolbarStyle(
        toolbarStyle: NSWindowToolbarStyle.unified,
      );
    }
  } catch (_) {
    // chrome is cosmetic; the window must still be revealed below. 外观非必需,下方仍须显示窗口。
  }

  // Set the window's OUTER corner radius to [AnRadius.window] (= chip + shellPad) so it is CONCENTRIC with
  // the shell's left island, overriding NSThemeFrame's larger toolbar-window radius (26pt on Tahoe, too round
  // against our 12pt island). The native `MainFlutterWindow` swizzles NSThemeFrame's radius getters to this
  // value (the only lever that reshapes a titled window — content-side clips can't touch the OS window shape);
  // the value is SOURCED FROM THE TOKEN here, not hard-coded natively. The native default already matches, so
  // this is a confirm/redraw; a retuned chip/shellPad flows through automatically. Cosmetic → its own guard.
  // 把窗外圆角设成 AnRadius.window(=chip+shellPad)与左岛同心、覆写 NSThemeFrame 偏大的 toolbar 圆角(Tahoe 26pt)。原生侧 swizzle
  // NSThemeFrame 半径 getter 到此值(重塑 titled 窗形的唯一杠杆,内容侧裁剪碰不到 OS 窗形);值在此来自 token、非原生写死。原生默认已一致故此为确认/重画,
  // 改 chip/shellPad 自动生效。外观项单独兜底。
  try {
    const chromeChannel = MethodChannel('app/window_chrome');
    await chromeChannel.invokeMethod<void>('setCornerRadius', AnRadius.window);
  } catch (_) {
    // corner radius is cosmetic; fall back to the native default. 圆角是外观,失败退原生默认。
  }

  // Adapt the chrome to native fullscreen transitions: in fullscreen the OS drops the traffic
  // lights + taller title bar, so the toolbar (else an opaque white band) is removed and the
  // shell's lights-reservations collapse via WindowFullScreen; on leave, restore both. Registered
  // AFTER ensureInitialized (required). NOTE: the actual toolbar REMOVAL happens PRE-animation in the
  // native `MainFlutterWindow` (willEnterFullScreenNotification) — window_manager only exposes the
  // post-animation `did` callback, too late to keep the white band off the ~0.5s zoom. This listener's
  // removeToolbar() is a harmless post-animation fallback; it owns only the flag flip + the on-leave rebuild.
  // 随全屏切换适配 chrome:进则撤 toolbar(否则白带)+ 收灯位,出则还原。**真正的撤 toolbar 在原生侧动画前做**
  // (MainFlutterWindow 的 willEnterFullScreen)——window_manager 只给动画后的 did 回调,太晚。此监听的 removeToolbar()
  // 是动画后幂等兜底;它只负责翻旗标 + 出全屏时重建 toolbar。
  windowManager.addListener(_FullScreenChrome());

  // GEOMETRY (window_manager): scale-correct size / min / center — OR the remembered bounds
  // (拍板 #13): a stored rect only wins when its title bar still lands on a live display
  // (WindowBounds.restoreTarget's multi-display clamp); otherwise default size, centered.
  // 尺寸由 window_manager 管;「记住窗口」开且存的矩形仍落在在线显示器上→按其恢复,否则默认居中。
  final remembered = prefs == null
      ? null
      : await WindowBounds.restoreTarget(prefs);
  final options = WindowOptions(
    size: remembered == null
        ? const Size(AnSize.windowInitialWidth, AnSize.windowInitialHeight)
        : Size(remembered.width, remembered.height),
    minimumSize: const Size(AnSize.windowMinWidth, AnSize.windowMinHeight),
    center: remembered == null,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    if (remembered != null) {
      await windowManager.setBounds(remembered);
    }
    await windowManager.show();
    await windowManager.focus();
  });
  // Start capturing moved/resized geometry (debounced; honours the switch live). 开始捕获几何。
  if (prefs != null) WindowBounds.attach(prefs);
}

/// Keeps the macOS chrome consistent across native fullscreen transitions (window_manager fires
/// these AFTER the transition completes). Enter → flip [WindowFullScreen.active] so the shell
/// collapses its traffic-light insets to 0 (+ an idempotent removeToolbar() fallback; the real
/// PRE-animation drop lives natively in [MainFlutterWindow], since window_manager has no `will`
/// callback and a post-animation removal leaves the white band riding the whole zoom). Leave →
/// rebuild a fresh toolbar and RE-APPLY the unified style (`addToolbar` builds a new NSToolbar but
/// does NOT restyle) + clear the flag. The flag is set synchronously first (immediate Flutter reflow);
/// the native toolbar call trails best-effort.
///
/// 维持 macOS chrome 随原生全屏切换一致(window_manager 在切换完成后触发)。进:翻 WindowFullScreen 使壳收灯位
/// (+ 幂等 removeToolbar() 兜底;真正的动画前撤 toolbar 在原生 MainFlutterWindow——window_manager 无 will 回调,动画后
/// 才撤会让白带跟满整个缩放);出:重建 toolbar 并**重设**统一样式(addToolbar 建新 NSToolbar 但不带样式)+ 清标志。
/// 标志先同步设(即时 Flutter 重排),原生调用随后尽力而为。
class _FullScreenChrome with WindowListener {
  @override
  void onWindowEnterFullScreen() {
    WindowFullScreen.active.value = true;
    // Post-animation fallback only — the seamless drop already happened natively at will-enter.
    // 仅动画后兜底——丝滑撤除已在原生 will-enter 完成。
    WindowManipulator.removeToolbar();
  }

  @override
  void onWindowLeaveFullScreen() {
    WindowFullScreen.active.value = false;
    _restoreToolbar();
  }

  Future<void> _restoreToolbar() async {
    await WindowManipulator.addToolbar();
    await WindowManipulator.setToolbarStyle(
      toolbarStyle: NSWindowToolbarStyle.unified,
    );
  }
}
