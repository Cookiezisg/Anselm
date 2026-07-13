import 'package:flutter/widgets.dart';

/// An [IndexedStack] that builds each slot LAZILY: a slot isn't built until it is first shown, and once
/// built it stays MOUNTED behind the fold — so re-showing it is instant and its State (scroll offset,
/// expansion, in-flight controllers) survives. A never-yet-shown slot is a zero-cost [SizedBox], so the
/// cold path never pays to mount every slot up front (the whole point over a plain [IndexedStack], which
/// builds all children eagerly). This is the standard "keep tabs/pages alive without eager-mounting them
/// all" pattern; [index] selects the visible slot, [count] is the slot count, [builder] builds slot i
/// (its output should be stable per slot — a `const` child then short-circuits rebuild when this widget
/// rebuilds; theme/inherited changes still reach mounted offstage slots normally).
///
/// 懒 [IndexedStack]:槽首显才建、建后常驻折叠(重显瞬时且保 State——滚动位/展开/在飞控制器);从未显的槽=零成本
/// SizedBox,冷路径不急挂全部槽(相对普通 IndexedStack 全量急建的价值)。标准「保活 tab/page 但不急挂」范式;
/// [index] 选可见槽、[count] 槽数、[builder] 建第 i 槽(输出应每槽稳定——const 子在本件重建时短路;主题/继承变更仍
/// 正常抵达 offstage 已挂槽)。
class AnLazyIndexedStack extends StatefulWidget {
  const AnLazyIndexedStack({
    required this.index,
    required this.count,
    required this.builder,
    this.sizing = StackFit.loose,
    super.key,
  });

  /// The visible slot. 可见槽。
  final int index;

  /// Total slot count. 槽总数。
  final int count;

  /// Builds slot i — called only for slots that have been shown at least once. 建第 i 槽(仅曾显过的槽调用)。
  final IndexedWidgetBuilder builder;

  /// How the stack sizes to its children (mirrors [IndexedStack.sizing]). 尺寸策略。
  final StackFit sizing;

  @override
  State<AnLazyIndexedStack> createState() => _AnLazyIndexedStackState();
}

class _AnLazyIndexedStackState extends State<AnLazyIndexedStack> {
  // The slots shown at least once — only these are built; the rest stay a zero-cost box. Insertion is
  // idempotent, and a slot never leaves (that IS the keep-alive). 曾显过的槽:仅这些建,其余零成本盒;只增不减=保活。
  final _visited = <int>{};

  @override
  Widget build(BuildContext context) {
    // Guard against an out-of-range index (a non-stack selection): clamp so IndexedStack always has a
    // valid slot and the mounted-alive slots below never get torn down. 越界钳制,保活槽不卸。
    if (widget.index >= 0 && widget.index < widget.count) _visited.add(widget.index);
    return IndexedStack(
      index: widget.index.clamp(0, widget.count - 1),
      sizing: widget.sizing,
      children: [
        for (var i = 0; i < widget.count; i++)
          _visited.contains(i) ? widget.builder(context, i) : const SizedBox.shrink(),
      ],
    );
  }
}
