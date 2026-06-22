import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../core/design/tokens.dart';
import '../core/platform/window_chrome.dart';

/// Shared desktop window setup, used by the real app AND every dev entry (so `make demo` /
/// `make gallery` show the genuine native window). The window is a FRAMELESS, opaque white
/// window that KEEPS the real macOS traffic-light controls (hidden title bar, buttons
/// visible) — the app must never draw fake ones. A minimum size keeps the three-island
/// layout usable; below the responsive breakpoints the shell auto-collapses islands.
///
/// Once the window is realized we push the traffic-light geometry (derived from design tokens)
/// to the native side via [WindowChrome], so the OS lights line up with the chrome bar instead
/// of floating at the OS default — the position lives in Dart, not a magic number in Swift.
///
/// 桌面窗口统一设置(真 app + dev 入口共用)。窗口=无边框、不透明白窗,保留 macOS 真红绿灯(隐藏标题栏、
/// 按钮可见)——绝不画假的。最小尺寸保证三岛可用;低于响应式断点 shell 自动收岛。窗口就绪后经
/// [WindowChrome] 把红绿灯几何(由 design token 派生)下发原生,使 OS 灯对齐顶栏条——位置事实源在 Dart。
Future<void> initWindow({String title = 'Anselm', Size size = const Size(1280, 820)}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  final options = WindowOptions(
    size: size,
    minimumSize: const Size(900, 600),
    center: true,
    title: title,
    backgroundColor: Colors.white,
    titleBarStyle: TitleBarStyle.hidden, // hide chrome, keep the real OS buttons (below)
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: true, // keep the real red/yellow/green controls
    );
    await windowManager.show();
    await windowManager.focus();
    // Align the OS traffic lights to the chrome bar (token-derived; native re-applies on resize).
    // 把 OS 红绿灯对齐顶栏条(token 派生;原生在 resize 时重应用)。
    await WindowChrome().alignTrafficLights(
      left: AnSize.trafficLightLeft,
      centerY: AnSize.trafficLightCenterY,
    );
  });
}
