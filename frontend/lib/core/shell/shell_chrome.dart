import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/tokens.dart';

/// Shell chrome state shared across the app + features (kept in `core/shell` so a feature ocean may feed
/// the floating-head breadcrumb without importing `app`). Two concerns:
///  - [ShellChromeController] — the LEFT island collapse + drag width, persisted (mirrors the demo's
///    `fy.side.collapsed` / `fy.side.w`). Restore is async (best-effort) after first frame.
///  - [ShellHeadController] — the OCEAN floating-head breadcrumb (compact title + scroll-collapse flag +
///    scroll-to-top tap), SET by whichever ocean is mounted (the demo's `setHeadTitle`/`setHeadCollapsed`
///    in Riverpod form). The RIGHT island's reveal lives with the run terminal (`rightPanelProvider`).
///
/// 壳 chrome 状态(放 core/shell,使 feature 海洋无需 import app 即可喂面包屑)。左岛收起+拖宽(持久化,对齐 demo 键);
/// 海洋浮层头面包屑(紧凑标题 + 滚动折叠标志 + 回顶点击,由当前海洋设入)。右岛揭示在 run 终端的 rightPanelProvider。

const _kCollapsed = 'fy.side.collapsed';
const _kWidth = 'fy.side.w';

@immutable
class ShellChrome {
  const ShellChrome({required this.leftCollapsed, required this.leftWidth});

  final bool leftCollapsed;
  final double leftWidth;

  ShellChrome copyWith({bool? leftCollapsed, double? leftWidth}) => ShellChrome(
    leftCollapsed: leftCollapsed ?? this.leftCollapsed,
    leftWidth: leftWidth ?? this.leftWidth,
  );
}

class ShellChromeController extends Notifier<ShellChrome> {
  @override
  ShellChrome build() {
    _restore();
    return const ShellChrome(leftCollapsed: false, leftWidth: AnSize.sidebar);
  }

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      final w = p.getDouble(_kWidth);
      final collapsed = p.getBool(_kCollapsed) ?? false;
      state = state.copyWith(
        leftCollapsed: collapsed,
        leftWidth:
            (w != null && w >= AnSize.sidebarMin && w <= AnSize.sidebarMax)
            ? w
            : state.leftWidth,
      );
    } catch (_) {
      /* best-effort 尽力而为 */
    }
  }

  void toggleLeft() {
    final next = !state.leftCollapsed;
    state = state.copyWith(leftCollapsed: next);
    _persistBool(_kCollapsed, next);
  }

  /// Commit a drag-resized width (called on drag-END, not per move — the demo persists on pointerup).
  /// 提交拖拽宽度(拖拽结束时,非每帧——对齐 demo pointerup 持久化)。
  void setLeftWidth(double width) {
    final w = width.clamp(AnSize.sidebarMin, AnSize.sidebarMax);
    if (w == state.leftWidth) return;
    state = state.copyWith(leftWidth: w);
    _persistDouble(_kWidth, w);
  }

  Future<void> _persistBool(String k, bool v) async {
    try {
      (await SharedPreferences.getInstance()).setBool(k, v);
    } catch (_) {
      /* best-effort */
    }
  }

  Future<void> _persistDouble(String k, double v) async {
    try {
      (await SharedPreferences.getInstance()).setDouble(k, v);
    } catch (_) {
      /* best-effort */
    }
  }
}

final shellChromeProvider =
    NotifierProvider<ShellChromeController, ShellChrome>(
      ShellChromeController.new,
    );

/// The ocean floating-head breadcrumb. `title` = the current ocean's compact title; `collapsed` = whether
/// the big in-content title has scrolled under the head (→ show the compact title); `onTap` = scroll the
/// big title back to top. The mounted ocean SETs these; the shell head reads them. 浮层头面包屑。
@immutable
class ShellHead {
  const ShellHead({this.title = '', this.collapsed = false, this.onTap});

  final String title;
  final bool collapsed;
  final VoidCallback? onTap;
}

class ShellHeadController extends Notifier<ShellHead> {
  @override
  ShellHead build() => const ShellHead();

  /// Bind the head to the current ocean's title + scroll-to-top callback. PRESERVES [collapsed] —
  /// oceans re-bind post-frame on every data rebuild (rename / SSE refetch), and resetting it here
  /// popped the breadcrumb open mid-scroll with nothing to restore it until the next scroll event;
  /// the ocean-SWITCH reset goes through [clear] / the switch listeners. The onTap closure is always
  /// refreshed (a remounted view brings a NEW scroll controller — a deduped stale closure would jump
  /// a disposed one). 绑定当前海洋标题 + 回顶回调。**保留 collapsed**——海洋每次数据重建都后帧重绑
  /// (改名/SSE 重取),在此重置会把滚动中的面包屑弹开且无人恢复;换海洋的重置走 clear()/切换监听。onTap
  /// 恒刷新(重挂的视图带新 scroll controller,去重会留下指向已 dispose 控制器的旧闭包)。
  void bind(String title, VoidCallback onTap) =>
      state = ShellHead(title: title, collapsed: state.collapsed, onTap: onTap);

  void setCollapsed(bool collapsed) {
    if (state.collapsed == collapsed) return;
    state = ShellHead(title: state.title, collapsed: collapsed, onTap: state.onTap);
  }

  void clear() => state = const ShellHead();
}

final shellHeadProvider = NotifierProvider<ShellHeadController, ShellHead>(
  ShellHeadController.new,
);
