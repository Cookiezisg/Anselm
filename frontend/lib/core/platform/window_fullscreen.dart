import 'package:flutter/foundation.dart';

/// Whether the desktop window is in native macOS fullscreen — a global platform bit (like
/// [WindowZoom.factor]) flipped by a `window_manager` WindowListener in `app/window_setup.dart`.
///
/// In fullscreen macOS hides the traffic lights AND the app's taller (toolbar-padded) title bar, so
/// every top-chrome reservation made FOR those lights must collapse to 0:
///  - the vertical [AnSize.titlebar] band the shell centers its top controls in (fed to
///    [AnShell.titlebarHeight] by [AppShell]), and
///  - the horizontal [AnSize.windowControlsInset] lights zone the [AnWindowControls] leaf reserves.
/// Left un-collapsed, that reserved-but-now-empty strip reads as a blank white band and shoves the
/// header/content down (the reported fullscreen bug). Both readers watch this notifier and collapse.
///
/// This is a platform fact (the OS owns fullscreen), NOT app state — hence a plain global notifier
/// read directly, the same shape as [WindowZoom], rather than a Riverpod provider threaded through
/// the kit (which stays Riverpod-free).
///
/// 桌面窗口是否处于 macOS 原生全屏——全局平台位(似 WindowZoom.factor),由 window_setup 的
/// window_manager 监听翻转。全屏时 OS 隐藏红绿灯 + 加高标题栏,故一切为灯预留的顶控空间须归零:
/// 竖向 titlebar 带([AnShell.titlebarHeight],由 [AppShell] 喂)+ 横向 windowControlsInset 灯位
/// ([AnWindowControls])。不归零则预留却空的条带读作空白白带、把头/正文顶下去(本次全屏 bug)。
/// 全屏是平台事实(OS 拥有)、非 app 状态,故用全局 notifier 直读(同 WindowZoom 形),不穿进 Riverpod-free 套件。
abstract final class WindowFullScreen {
  static final ValueNotifier<bool> active = ValueNotifier<bool>(false);
}
