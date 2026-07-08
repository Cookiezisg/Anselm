import 'dart:async';
import 'dart:ui';

import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../settings/settings_prefs.dart';

/// Window-geometry memory (WRK-062 拍板 #13) — remember the window's bounds across launches, with
/// the multi-display clamp discipline: a stored rect is only restored when its TITLE-BAR BAND still
/// intersects a live display enough to grab (a monitor that was unplugged must not strand the
/// window off-screen — fall back to the default size, centered). Capture is debounced off the
/// moved/resized window events and honours the `an.window.remember` switch live.
///
/// 窗口几何记忆(拍板 #13):跨启动记住窗口 bounds,守多显示器 clamp 纪律——存的矩形只有当其**标题栏带**
/// 仍与某个在线显示器相交到「抓得住」时才恢复(拔掉的显示器绝不能把窗口困在屏外——回落默认尺寸居中)。
/// 捕获=moved/resized 事件去抖落盘,实时尊重「记住窗口」开关。
abstract final class WindowBounds {
  /// Minimum grabbable strip: this much of the title bar must land on a display. 最小可抓面积。
  static const double _minVisibleW = 200;
  static const double _minVisibleH = 24;

  /// The rect to restore, or null (off / nothing stored / stranded). 应恢复的矩形,或 null。
  static Future<Rect?> restoreTarget(SettingsPrefs prefs) async {
    if (!prefs.getBool(SettingsKeys.windowRemember)) return null;
    final raw = prefs.getString(SettingsKeys.windowBounds);
    final parts = raw.split(',');
    if (parts.length != 4) return null;
    final nums = parts.map(double.tryParse).toList();
    if (nums.any((n) => n == null)) return null;
    final rect = Rect.fromLTWH(nums[0]!, nums[1]!, nums[2]!, nums[3]!);
    try {
      final displays = await screenRetriever.getAllDisplays();
      final screens = [
        for (final d in displays)
          Rect.fromLTWH(
            (d.visiblePosition ?? Offset.zero).dx,
            (d.visiblePosition ?? Offset.zero).dy,
            (d.visibleSize ?? d.size).width,
            (d.visibleSize ?? d.size).height,
          ),
      ];
      return clampToDisplays(rect, screens);
    } catch (_) {
      return null; // best-effort — restore nothing 尽力而为
    }
  }

  /// PURE clamp: the rect survives iff its TITLE-BAR band still lands grabbably on one of
  /// [screens] (a window whose body peeks out but whose bar is off-screen can't be dragged back);
  /// its size is then clamped into that display. Null = stranded/degenerate → caller centers the
  /// default. 纯 clamp:标题栏带仍可抓地落在某屏才存活(只露身子抓不回来),尺寸收进该屏;null=搁浅/退化。
  static Rect? clampToDisplays(Rect rect, List<Rect> screens) {
    if (rect.width < 400 || rect.height < 300) return null; // degenerate 退化值不恢复
    for (final screen in screens) {
      final bar = Rect.fromLTWH(rect.left, rect.top, rect.width, _minVisibleH);
      final overlap = bar.intersect(screen);
      if (overlap.width >= _minVisibleW && overlap.height >= _minVisibleH) {
        return Rect.fromLTWH(
          rect.left,
          rect.top,
          rect.width.clamp(400, screen.width),
          rect.height.clamp(300, screen.height),
        );
      }
    }
    return null;
  }

  /// Start capturing (call once after the window is shown). 开始捕获(窗口显示后一次)。
  static void attach(SettingsPrefs prefs) {
    windowManager.addListener(_BoundsListener(prefs));
  }
}

class _BoundsListener with WindowListener {
  _BoundsListener(this._prefs);

  final SettingsPrefs _prefs;
  Timer? _debounce;

  @override
  void onWindowMoved() => _capture();

  @override
  void onWindowResized() => _capture();

  void _capture() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!_prefs.getBool(SettingsKeys.windowRemember)) return;
      try {
        final b = await windowManager.getBounds();
        _prefs.setString(
          SettingsKeys.windowBounds,
          '${b.left.round()},${b.top.round()},${b.width.round()},${b.height.round()}',
        );
      } catch (_) {
        /* best-effort */
      }
    });
  }
}
