import 'package:flutter/widgets.dart';

import '../design/tokens.dart';

/// A responsive auto-fit block grid — the Flutter equivalent of CSS `repeat(auto-fit, minmax(W, 1fr))`:
/// flows children into as many equal-width columns (each ≥ [minColWidth]) as fit, the columns expanding
/// to fill the row (1fr), collapsing to ONE column when too narrow, with each ROW sized to its own
/// tallest child (CSS `align-items: start`).
///
/// HAND-ROLL, with the standard delegate ruled out first (principle #8): `GridView` +
/// `SliverGridDelegateWithMaxCrossAxisExtent` is the framework's auto-fit analogue BUT pins
/// `mainAxisExtent` from a single `childAspectRatio` → every cell gets the SAME height (minExtent ==
/// maxExtent), which breaks the demo's per-content row height (cards with variable bodies). It's also a
/// scroll view (needs shrinkWrap in a Column). `flutter_layout_grid`'s minmax is an open, unimplemented
/// issue (#25). So this orchestrates three standard widgets — `LayoutBuilder` (measure) + `Wrap` (flow,
/// per-row height) + `SizedBox` (equal column width) — over one deterministic column-count formula; no
/// custom RenderObject, no re-implemented layout algorithm.
///
/// 响应式 auto-fit 块网格(= CSS repeat(auto-fit, minmax(W,1fr))):按可用宽流成 N 等宽列(每列 ≥ minColWidth)、
/// 富余均摊填满(1fr)、窄到放不下塌 1 列、每行按各自最高子定高(align-items:start)。HAND-ROLL,先证伪标准件
/// (#8):原生 delegate 由单一 childAspectRatio 钉死全表统一行高,违 demo 各行按内容;flutter_layout_grid 的
/// minmax 未实现(#25)。故编排 LayoutBuilder+Wrap+SizedBox 三个标准件 + 一条确定性列数公式,不造 RenderObject。
class AnAutoGrid extends StatelessWidget {
  const AnAutoGrid({
    required this.children,
    this.minColWidth = AnSize.block,
    this.gap = AnGap
        .block, // 12 — so a section's grid:true keeps the SAME card gap as its column mode (was 16) 与单列同块间距
    this.runGap = AnGap.block,
    super.key,
  });

  final List<Widget> children;

  /// Minimum column width before collapsing a column (= CSS minmax's W). 列最小宽(塌列阈值)。
  final double minColWidth;

  /// Column gap / row gap. Split (vs CSS `gap` shorthand) because Flutter's [Wrap] takes spacing +
  /// runSpacing separately; both default to the demo's grid gap. 拆成两参顺 Wrap 机制,默认同 demo grid gap。
  final double gap;
  final double runGap;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (!w.isFinite) {
          // Unbounded width (e.g. inside a horizontal scroll) → degrade to a single column, no stretch
          // (stretch needs a bounded width). 无界宽→单列、不拉伸(拉伸需有界宽)。
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: runGap),
                children[i],
              ],
            ],
          );
        }
        // Columns that fit (gap-compensated: n cols need n*minW + (n-1)*gap ≤ w), floored, ≥1 and never
        // more than there are children (auto-fit collapses empty tracks → occupied ones share 1fr).
        // 能放下的列数(含 gap 补偿),下限 1、上限子数(auto-fit 折叠空轨、占用轨均摊)。
        final n = ((w + gap) / (minColWidth + gap)).floor().clamp(
          1,
          children.length,
        );
        // Equal column width filling the row. floorToDouble keeps every column EQUAL (no per-column
        // rounding divergence) AND keeps n*colW + (n-1)*gap ≤ w, so a float epsilon never wrong-wraps
        // the Wrap; the < n px remainder is an invisible right margin. 等宽填行;向下取整避 FP 误折行。
        final colW = ((w - (n - 1) * gap) / n).floorToDouble();
        return Wrap(
          spacing: gap,
          runSpacing: runGap,
          children: [for (final c in children) SizedBox(width: colW, child: c)],
        );
      },
    );
  }
}
