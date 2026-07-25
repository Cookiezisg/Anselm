import 'package:flutter/material.dart';

/// One of the app's exactly TWO text-selection regions — the centre ocean's content and the right
/// island's content. The count is a decision, not an omission (TS 拓扑):
///
/// - `Cmd+A` means "select all of THIS region". One global region would sweep rail labels, button copy
///   and breadcrumbs into the clipboard alongside the text the reader wanted.
/// - Sibling regions never bleed into each other, so there is no dragging a selection from the right
///   island into the centre prose, which would mean nothing.
/// - Fewer registered Selectables makes the per-frame drag dispatch and the add/remove ordering cheaper.
/// - Losing focus clears a selection, and "click the right island, the centre selection disappears" is
///   only intuitive because they are two regions.
///
/// The left rail, the top band and the island grips sit OUTSIDE both regions on purpose — they are
/// navigation and chrome, not prose (VS Code's sidebar and Finder's list behave the same way).
///
/// It must NOT be hoisted above `MaterialApp.builder`: `SelectableRegion` asserts an `Overlay` ancestor.
///
/// **Why this exists rather than a bare `SelectionArea`**: a row's `onTap` wins the gesture arena against
/// the enclosing region (Flutter #141151 — the deeper competitor wins), so clicking a row never starts a
/// selection gesture and the region is never focused. `Cmd+A` / `Cmd+C` then do nothing at all, silently.
/// So the region publishes its focus node and [AnInteractive] hands focus over on every POINTER
/// activation — see [focusOf].
///
/// 全 app **恰好两个**文字选择域——中心海洋内容 与 右岛内容。这个数目是决定,不是遗漏(TS 拓扑):
///
/// - `Cmd+A` 的语义是「全选**本域**」。全局单域会把 rail 文字、按钮文案、面包屑一起扫进剪贴板。
/// - 兄弟域天然互不越界,不会出现「从右岛拖到中心正文」这种无意义连选。
/// - 注册的 Selectable 越少,拖拽逐帧分发与增删排序越便宜。
/// - 失焦即清选区,而「点右岛,中心选区消失」这种直觉行为**只有多域才有**。
///
/// 左岛 rail、顶带、岛间 grip 刻意在两域之外——它们是导航与 chrome、不是正文(VS Code 侧栏与 Finder 列表同理)。
///
/// **不得**提到 `MaterialApp.builder` 之上:`SelectableRegion` 断言要求 `Overlay` 祖先。
///
/// **为什么不是裸 `SelectionArea`**:行的 `onTap` 会在手势竞技场里赢过外层的域(Flutter #141151——更深者赢),
/// 于是点击一行永不开启选择手势、域也永不获得焦点,`Cmd+A` / `Cmd+C` 随后**静默失效**。故本域公开自己的焦点节点,
/// 由 [AnInteractive] 在每次**指针**激活时把焦点交过去——见 [focusOf]。
class AnSelectionRegion extends StatefulWidget {
  const AnSelectionRegion({required this.child, super.key});

  final Widget child;

  /// The enclosing region's focus node, or null outside one (the rail, the top band, the gallery).
  /// Read WITHOUT registering a dependency — the node never changes, so a dependency would only buy
  /// pointless rebuilds.
  /// 外层域的焦点节点;域外为 null(rail / 顶带 / gallery)。**不建立依赖**地读——节点从不变,建依赖只买无谓重建。
  static FocusNode? focusOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<_AnSelectionRegionScope>()
      ?.focusNode;

  @override
  State<AnSelectionRegion> createState() => _AnSelectionRegionState();
}

class _AnSelectionRegionState extends State<AnSelectionRegion> {
  final FocusNode _focus = FocusNode(debugLabel: 'AnSelectionRegion');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AnSelectionRegionScope(
    focusNode: _focus,
    child: SelectionArea(focusNode: _focus, child: widget.child),
  );
}

class _AnSelectionRegionScope extends InheritedWidget {
  const _AnSelectionRegionScope({
    required this.focusNode,
    required super.child,
  });

  final FocusNode focusNode;

  @override
  bool updateShouldNotify(_AnSelectionRegionScope old) =>
      old.focusNode != focusNode;
}
