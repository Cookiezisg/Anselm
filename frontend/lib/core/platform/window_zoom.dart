import 'package:flutter/widgets.dart';
import 'package:scaled_app/scaled_app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../design/tokens.dart';
import 'host_platform.dart';

/// In-app UI zoom (Cmd +/- / 0) — scales the ENTIRE UI reflow-correct, browser-style.
///
/// Best practice (CLAUDE.md 原则 #8): NOT `Transform.scale` (image-like, no reflow) and NOT only
/// `textScaler` (text-only). Instead `scaled_app`'s [ScaledWidgetsFlutterBinding] overrides the
/// view configuration so the whole tree lays out + reflows at the zoom factor. On change we
/// relayout (`handleMetricsChanged`) and grow the window minimum by the same factor.
///
/// ZOOM-IN IS CAPPED ([maxFactor]) so it can never break the layout: the largest zoom at which
/// the window — grown to the screen — can still hold the design minimum is `screen / designMin`.
/// Past that the content would be forced to compress/overflow, so zoom-in stops.
///
/// 应内 UI 缩放(Cmd +/-/0):整体重排式(非 Transform/textScaler)。zoom-in **受管控**([maxFactor]):
/// 上限 = 屏幕能容下 设计min×zoom 的最大 zoom(= 屏/设计min),超过会撑破布局,故到顶即停。
abstract final class WindowZoom {
  /// Discrete zoom stops (like a browser). 1.0 = 100% (default). 离散缩放档,1.0=默认。
  static const List<double> steps = [0.8, 0.9, 1.0, 1.1, 1.25, 1.5];
  static const double defaultFactor = 1.0;
  static const String _prefKey = 'an.window.zoom';
  static const double _menuBarInset = 40; // approx macOS menu bar + margin (height不可用部分)

  /// Current zoom factor; the [scaleFactorCallback] reads this. UI may listen. 当前缩放因子。
  static final ValueNotifier<double> factor = ValueNotifier<double>(defaultFactor);

  /// Wired into `ScaledWidgetsFlutterBinding.ensureInitialized(scaleFactor:)` in main().
  static double scaleFactorCallback(Size _) => factor.value;

  /// The maximum zoom that still fits the design minimum once the window is grown to the screen
  /// (`screen / designMin`, per axis, capped at the last stop). Beyond it, content would break —
  /// so zoom-in is clamped here. 最大缩放(屏/设计min,逐轴取小,末档封顶);超过会撑破故 zoom-in 卡在此。
  static double maxFactor() {
    try {
      final d = WidgetsBinding.instance.platformDispatcher.views.first.display;
      final screen = d.size / d.devicePixelRatio; // logical points 逻辑点
      final byW = screen.width / AnSize.windowMinWidth;
      final byH = (screen.height - _menuBarInset) / AnSize.windowMinHeight;
      final fit = byW < byH ? byW : byH;
      return fit < steps.last ? fit : steps.last;
    } catch (_) {
      return steps.last; // headless / unknown display → allow up to the last stop 无头则放开到末档
    }
  }

  /// Next stop up that still fits [cap]; unchanged if already at/over the cap. (Pure — testable.)
  /// 下一档向上(不超过 cap);已到顶则不变。纯函数,可测。
  static double nextUp(double cap) {
    final i = _index();
    return (i + 1 < steps.length && steps[i + 1] <= cap + 1e-6) ? steps[i + 1] : factor.value;
  }

  /// Next stop down; clamps at the minimum stop. (Pure — testable.) 下一档向下,最小档封底。
  static double nextDown() {
    final i = _index();
    return i > 0 ? steps[i - 1] : factor.value;
  }

  static int _index() {
    final i = steps.indexOf(factor.value);
    return i < 0 ? steps.indexOf(defaultFactor) : i;
  }

  /// Jump straight to a step (the settings segmented control) — capped at the live [maxFactor],
  /// same as the shortcuts. 直设某档(设置分段器用);同快捷键受当前屏 cap。
  static void set(double step) {
    if (!steps.contains(step)) return;
    _apply(step.clamp(steps.first, maxFactor()));
  }

  static void zoomIn() => _apply(nextUp(maxFactor()));
  static void zoomOut() => _apply(nextDown());
  static void reset() => _apply(defaultFactor);

  static void _apply(double z) {
    if (z == factor.value) return;
    factor.value = z;
    final binding = WidgetsBinding.instance;
    if (binding is ScaledWidgetsFlutterBinding) {
      binding.handleMetricsChanged(); // relayout the whole tree at the new scale 全树按新比例重排
      if (HostPlatform.isMacOS) {
        // Grow the window minimum with the zoom so the layout's minimum still fits (real points =
        // design points × zoom). 窗口最小值随 zoom 同步(真点=设计点×zoom)。
        windowManager.setMinimumSize(
          Size(AnSize.windowMinWidth * z, AnSize.windowMinHeight * z),
        );
      }
    }
    _persist(z);
  }

  static Future<void> _persist(double z) async {
    try {
      (await SharedPreferences.getInstance()).setDouble(_prefKey, z);
    } catch (_) {/* persistence is best-effort 持久化尽力而为 */}
  }

  /// Restore the persisted zoom before the first frame, clamped to what the current screen fits
  /// (a level saved on a big monitor won't break a smaller one). 首帧前恢复持久化缩放,并按当前屏可容上限收敛。
  static Future<void> restore() async {
    try {
      final z = (await SharedPreferences.getInstance()).getDouble(_prefKey);
      if (z == null) return;
      final cap = maxFactor();
      final target = steps.lastWhere(
        (s) => s <= z + 1e-6 && s <= cap + 1e-6,
        orElse: () => defaultFactor,
      );
      if (target != factor.value) _apply(target);
    } catch (_) {/* defaults to 100% 退回 100% */}
  }
}
