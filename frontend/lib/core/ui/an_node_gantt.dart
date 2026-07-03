import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../graph/flowrun_timeline.dart';
import '../model/status_state.dart';
import 'icons.dart';

/// The per-node gantt for one flowrun (the demo's `an-node-gantt`): each graph node is a row —
/// kind icon + mono id + ×N badge in a fixed lane, then status bars along a shared [0,1] time track.
/// Reads at a glance: which node is slow (long bar) · how many loop iterations (N bars + ×N) · where
/// it parked (a warn waiting box) · what never ran (a "未运行" stub). Data is the pure [GanttRow]
/// list from [flowrunTimeline] — the widget only maps a folded [AnStatus] to a bar colour. Rows tap
/// to [onNodePick]; [selectedNodeId] highlights (strong-linked to the run graph + node debug).
///
/// 单 flowrun 的逐节点甘特(demo `an-node-gantt`):每图节点一行——kind 图标 + mono id + ×N 徽在定宽
/// 车道,后接沿共享 [0,1] 时间轨的状态条。一眼看出:谁慢(条长)· 循环几轮(N 条 + ×N)· 在哪 parked
/// (warn 等待框)· 谁没跑(未运行占位)。数据=纯 [flowrunTimeline] 出的 [GanttRow];widget 只把折好的
/// [AnStatus] 映射成条色。点行 [onNodePick];[selectedNodeId] 高亮(强链运行图 + 节点调试)。
class AnNodeGantt extends StatelessWidget {
  const AnNodeGantt({
    required this.rows,
    this.selectedNodeId,
    this.onNodePick,
    this.notRunLabel = '',
    this.waitingLabel = '',
    super.key,
  });

  final List<GanttRow> rows;
  final String? selectedNodeId;
  final ValueChanged<String>? onNodePick;

  /// Caller i18n (core stays string-free). 调用方 i18n(core 不含文案)。
  final String notRunLabel;
  final String waitingLabel;

  @override
  Widget build(BuildContext context) {
    // Column of fixed-height rows (so an enclosing IntrinsicHeight — the run board — can measure the
    // gantt's height without recursing into the per-row track LayoutBuilder, which only measures
    // WIDTH). 定高行的 Column:外层 IntrinsicHeight(看板)量得了高,不必递归进逐行测宽的 LayoutBuilder。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final r in rows) _row(context, r)],
    );
  }

  Widget _row(BuildContext context, GanttRow r) {
    final c = context.colors;
    final selected = r.nodeId == selectedNodeId;
    final tap = onNodePick;
    return _HoverRow(
      selected: selected,
      onTap: tap == null ? null : () => tap(r.nodeId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
        child: SizedBox(
          height: AnSize.row,
          child: Row(children: [
            SizedBox(
              width: AnSize.ganttLaneW,
              child: Row(children: [
                Icon(AnIcons.node(r.kind.name), size: AnSize.iconSm, color: c.inkFaint),
                const SizedBox(width: AnSpace.s6),
                Flexible(
                  child: Text(r.nodeId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AnText.code.copyWith(color: c.inkMuted)),
                ),
                if (r.iterations > 1) ...[
                  const SizedBox(width: AnSpace.s6),
                  Text('×${r.iterations}',
                      style: AnText.metaTabular().copyWith(color: c.accent)),
                ],
              ]),
            ),
            const SizedBox(width: AnSpace.s12),
            Expanded(child: _track(context, r)),
          ]),
        ),
      ),
    );
  }

  // A single LayoutBuilder measures the track WIDTH (fixed height above), then Positioned bars go
  // DIRECTLY into the Stack. 单次测轨宽(高固定),条 Positioned 直入 Stack。
  Widget _track(BuildContext context, GanttRow r) {
    final c = context.colors;
    return SizedBox(
      height: AnSize.controlSm,
      child: LayoutBuilder(builder: (context, cst) {
        final w = cst.maxWidth;
        // The min visible width can't exceed the track (a track narrower than s4 would make
        // clamp(s4, w) throw: lowerLimit > upperLimit — a hard ArgumentError, not just an overflow).
        // 最小可见宽不得超过轨宽(否则 clamp 下限>上限抛 ArgumentError、非仅溢出)。
        final minBar = w < AnSpace.s4 ? w : AnSpace.s4;
        Widget bar(GanttSegment seg, {required Color fill, Color? border, Widget? child}) => Positioned(
              left: (seg.at * w).clamp(0.0, w),
              top: 0,
              bottom: 0,
              width: (seg.w * w).clamp(minBar, w),
              child: Container(
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(AnRadius.tag),
                  border: border == null ? null : Border.all(color: border, width: AnSize.hairline),
                ),
                child: child,
              ),
            );

        if (r.parked) {
          final seg = r.segments.isEmpty ? const GanttSegment(0, 0.12) : r.segments.first;
          return Stack(children: [
            bar(seg,
                fill: c.warnSoft,
                border: c.warn,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AnSpace.s6),
                  child: Text(waitingLabel,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: AnText.meta.copyWith(color: c.warn)),
                )),
          ]);
        }
        if (r.segments.isEmpty) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(notRunLabel, style: AnText.meta.copyWith(color: c.inkFaint)),
          );
        }
        final fill = _barColor(context, r.status);
        return Stack(children: [for (final seg in r.segments) bar(seg, fill: fill)]);
      }),
    );
  }

  // Bar colour NEVER defaults to done: an unknown/uppercased status folds to idle (neutral), so a
  // failed node is never painted a green success bar (demo's explicit guard). 条色绝不默认成 done。
  Color _barColor(BuildContext context, String status) {
    final c = context.colors;
    return switch (AnStatus.fromRaw(status)) {
      AnStatus.done => c.ok,
      AnStatus.err => c.danger,
      AnStatus.wait => c.warn,
      AnStatus.run => c.accent,
      AnStatus.idle => c.surfaceSunken,
    };
  }
}

/// A hover/selected row wrapper (the gantt/board list idiom). 悬停/选中行外壳。
class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.child, required this.selected, this.onTap});
  final Widget child;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = widget.selected
        ? c.surfaceActive
        : (_hover ? c.surfaceHover : const Color(0x00000000));
    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AnRadius.button)),
          child: widget.child,
        ),
      ),
    );
  }
}
