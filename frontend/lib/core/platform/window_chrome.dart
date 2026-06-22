import 'package:flutter/services.dart';

import 'host_platform.dart';

/// Aligns the native window controls (macOS traffic lights) with the app's chrome bar.
///
/// The lights are drawn by the OS on the frameless window, so Flutter cannot lay them out — a
/// platform channel is the only way to move them. The desired position is computed in Dart from
/// design tokens (the single source of truth) and pushed down; the native side stores it and
/// re-applies across resizes (macOS resets the buttons on every resize). Platforms with no
/// movable left-side controls (Windows/Linux) and headless test runs are silent no-ops.
///
/// 把原生窗控(macOS 红绿灯)对齐到 app 的顶栏条。灯由 OS 画在无边框窗上,Flutter 排不动它——平台
/// 通道是唯一搬法。目标位置在 Dart 由 design token 算出(事实源),下发原生;原生存下并在 resize 时
/// 重应用(macOS 每次 resize 都重置按钮)。无左侧可移控件的平台(Win/Linux)与无头测试静默 no-op。
abstract interface class WindowChrome {
  factory WindowChrome() =>
      HostPlatform.isMacOS ? const _MacWindowChrome() : const _NoopWindowChrome();

  /// Position the traffic lights so their leftmost button starts at [left] from the window's
  /// left edge and every button's vertical center sits [centerY] below the window's top edge
  /// (logical points). 让最左按钮左缘距窗左 [left]、各按钮纵向中心距窗顶 [centerY](逻辑点)。
  Future<void> alignTrafficLights({required double left, required double centerY});
}

class _NoopWindowChrome implements WindowChrome {
  const _NoopWindowChrome();

  @override
  Future<void> alignTrafficLights({required double left, required double centerY}) async {}
}

class _MacWindowChrome implements WindowChrome {
  const _MacWindowChrome();

  static const MethodChannel _channel = MethodChannel('anselm/window_chrome');

  @override
  Future<void> alignTrafficLights({required double left, required double centerY}) async {
    // Degrade silently where the native side is absent (headless / widget tests). 无原生侧静默退回。
    try {
      await _channel.invokeMethod<void>('alignTrafficLights', {'left': left, 'centerY': centerY});
    } catch (_) {/* ignore */}
  }
}
