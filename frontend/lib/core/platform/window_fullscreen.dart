import 'package:flutter/foundation.dart';

/// Whether the desktop window is in native macOS fullscreen — a global platform bit (like
/// [WindowZoom.factor]) flipped by a `window_manager` WindowListener in `app/window_setup.dart`.
///
/// In fullscreen macOS hides the traffic lights, so the HORIZONTAL room reserved for them must free up:
/// the [AnSize.windowControlsInset] lights zone the [AnWindowControls] leaf reserves collapses (→ the
/// product brand shows there instead, like Windows/Linux). This is the ONE reader of this notifier.
///
/// The VERTICAL chrome band does NOT collapse: [AppShell] feeds a constant [AnSize.titlebar] to
/// [AnShell.titlebarHeight] in fullscreen too (see the note at that call site) — an earlier
/// `fullScreen ? 0` collapse cramped the top controls against the screen edge and was itself the bug.
/// So the top controls keep the same comfortable gap windowed and fullscreen; only the left lights
/// gutter is a fullscreen-conditional axis.
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
