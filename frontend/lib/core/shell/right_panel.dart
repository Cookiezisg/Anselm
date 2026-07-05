import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The right island's reveal state — a SHELL-level concern shared across oceans (entities' run terminal,
/// documents' properties inspector). SEPARATE from what the island is bound to (that follows the ocean's
/// selection). Collapsed is a sticky user preference: selecting a new subject re-binds the island but does
/// NOT force it back open (the floating-head panel-right button + a verb CTA re-open it). The shell reveals
/// the right island when the active ocean has a selection AND the panel isn't collapsed.
///
/// 右岛揭示态——shell 级、跨海洋共享(entities 的 run 终端 / documents 的属性面板)。与"绑什么"(随海洋选区)分开。
/// collapsed 是 sticky 偏好:选新对象重绑但不强制重开(浮层头 panel-right 钮 + 动词 CTA 负责重开)。壳在"当前海洋
/// 有选中 且 未收起"时揭示右岛。
class RightPanelCollapsed extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void set(bool collapsed) => state = collapsed;
}

final rightPanelCollapsedProvider =
    NotifierProvider<RightPanelCollapsed, bool>(RightPanelCollapsed.new);
