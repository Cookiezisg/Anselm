import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'oceans.dart';

/// The right island's reveal state — a SHELL-level concern, BUCKETED PER OCEAN (WRK-061 W0): collapsing
/// the documents inspector must not leave the chat sidestage collapsed — each ocean keeps its own sticky
/// preference, and the provider exposes the CURRENT ocean's bucket (consumers keep calling toggle/set
/// without naming an ocean). SEPARATE from what the island is bound to (that follows the ocean's
/// selection). Collapsed is a sticky user preference within its ocean: selecting a new subject re-binds
/// the island but does NOT force it back open (the floating-head panel-right button + a verb CTA re-open
/// it). The shell reveals the right island when the active ocean has a selection AND its bucket isn't
/// collapsed.
///
/// 右岛揭示态——shell 级、**按海洋分桶**(WRK-061 W0):在 documents 收起属性面板,不得连累 chat 的侧幕——
/// 每海洋各存 sticky 偏好,provider 暴露当前海洋的桶(消费方照旧 toggle/set、不点名海洋)。与「绑什么」
/// (随海洋选区)分开。收起是海洋内的 sticky 偏好:选新对象重绑但不强制重开(浮层头 panel-right 钮 + 动词
/// CTA 负责重开)。壳在「当前海洋有选中 且 该桶未收起」时揭示右岛。
class RightPanelCollapsed extends Notifier<bool> {
  // Session-scoped buckets (the notifier instance outlives build() re-runs). 会话级分桶,实例跨 build 存续。
  final Map<OceanKind, bool> _byOcean = {};

  @override
  bool build() {
    final ocean = ref.watch(selectedOceanProvider);
    return _byOcean[ocean] ?? false;
  }

  void toggle() => set(!state);

  void set(bool collapsed) {
    _byOcean[ref.read(selectedOceanProvider)] = collapsed;
    state = collapsed;
  }
}

final rightPanelCollapsedProvider =
    NotifierProvider<RightPanelCollapsed, bool>(RightPanelCollapsed.new);
