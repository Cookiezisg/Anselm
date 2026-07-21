import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../graph/flowrun_timeline.dart';
import '../model/status_state.dart';
import '../model/time_format.dart';
import 'an_tooltip.dart';
import 'icons.dart';

/// The per-node gantt for one flowrun (the demo's `an-node-gantt`): each graph node is a row —
/// kind icon + mono id + ×N badge in a fixed lane, then status bars along a shared [0,1] time track.
/// Reads at a glance: which node is slow (long bar) · how many loop iterations (N bars + ×N) · where
/// it parked (a warn waiting box) · what never ran (a "未运行" stub). Data is the pure [GanttRow]
/// list from [flowrunTimeline] — the widget only maps a folded [AnStatus] to a bar colour. Rows tap
/// to [onNodePick]; [selectedNodeId] highlights (strong-linked to the run graph + node debug).
///
/// A bar draws its three parts as the model gave them (WRK-069 §5): a grey QUEUE lead-in, the
/// status-coloured EXEC body, and an amber PARKED tail — each present only when its data is. The
/// FLAGSHIP face additionally passes [chart], which unlocks the absolute furniture: a time [ruler]
/// eyebrow, the [nowLine], and per-bar hover with real start/end stamps. Those only render in the
/// chart's `timeMode` — under the equal-slot fallback the fractions carry no time meaning, so the
/// widget draws no ruler and no now-line rather than pointing at a lie (不装权威).
///
/// 单 flowrun 的逐节点甘特(demo `an-node-gantt`):每图节点一行——kind 图标 + mono id + ×N 徽在定宽
/// 车道,后接沿共享 [0,1] 时间轨的状态条。一眼看出:谁慢(条长)· 循环几轮(N 条 + ×N)· 在哪 parked
/// (warn 等待框)· 谁没跑(未运行占位)。数据=纯 [flowrunTimeline] 出的 [GanttRow];widget 只把折好的
/// [AnStatus] 映射成条色。点行 [onNodePick];[selectedNodeId] 高亮(强链运行图 + 节点调试)。三段条按
/// 模型所给渲(排队灰/执行状态色/停车琥珀,各自数据在才出现)。旗舰脸另传 [chart] 解锁绝对家具:刻度眉
/// /now 线/hover 真起止——且仅在 timeMode 下渲,回退分槽时分数无时间含义、绝不画刻度指着谎言。
class AnNodeGantt extends StatelessWidget {
  const AnNodeGantt({
    required this.rows,
    this.chart,
    this.selectedNodeId,
    this.onNodePick,
    this.ruler = false,
    this.nowLine = false,
    this.notRunLabel = '',
    this.waitingLabel = '',
    this.inferredLabel = '',
    this.queueLabel = '',
    this.execLabel = '',
    super.key,
  });

  /// The bars. A caller holding a [chart] passes `chart.rows` here (the two stay separate so the
  /// simple face never has to build a chart). 条;持 chart 的调用方传 chart.rows。
  final List<GanttRow> rows;

  /// The absolute axis (WRK-069 §5 flagship). Null = the plain face: no ruler, no now-line, no
  /// stamped hover. 绝对轴(旗舰);null=朴素脸。
  final GanttChart? chart;

  final String? selectedNodeId;
  final ValueChanged<String>? onNodePick;

  /// Draw the time-scale eyebrow above the tracks (needs a [chart] in timeMode). 刻度眉。
  final bool ruler;

  /// Draw the vertical «now» line (needs a [chart] with a nowAt). now 线。
  final bool nowLine;

  /// Caller i18n (core stays string-free). 调用方 i18n(core 不含文案)。
  final String notRunLabel;
  final String waitingLabel;
  final String inferredLabel;
  final String queueLabel;
  final String execLabel;

  bool get _timed => chart?.timeMode ?? false;

  @override
  Widget build(BuildContext context) {
    // Column of fixed-height rows (so an enclosing IntrinsicHeight — the run board — can measure the
    // gantt's height without recursing into the per-row track LayoutBuilder, which only measures
    // WIDTH). 定高行的 Column:外层 IntrinsicHeight(看板)量得了高,不必递归进逐行测宽的 LayoutBuilder。
    final showNow = nowLine && _timed && chart?.nowAt != null;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ruler && _timed) _ruler(context),
        for (final r in rows) _row(context, r),
      ],
    );
    if (!showNow) return body;
    // The now-line spans every track at the SAME fraction — one overlay above the rows, aligned to
    // the shared track geometry (the lane is a fixed width, so the overlay can reproduce it without
    // measuring each row). now 线跨全轨同一分数:一层覆层贴共享轨几何(车道定宽,覆层无需逐行测)。
    return Stack(
      children: [
        body,
        Positioned.fill(
          child: IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.only(
                left: AnSize.ganttLaneW + AnSpace.s12 + AnSpace.s8,
                right: AnSpace.s8,
              ),
              child: _NowLine(at: chart!.nowAt!),
            ),
          ),
        ),
      ],
    );
  }

  // The time-scale eyebrow: the axis start on the left, the end on the right, with the span in the
  // middle — three honest anchors rather than a fake evenly-divided ruler (an axis whose span is
  // seconds and whose ticks would collide). 刻度眉:左起点、右终点、中间跨度——三个诚实锚点,不画会撞
  // 在一起的等分假刻度。
  Widget _ruler(BuildContext context) {
    final c = context.colors;
    final ch = chart!;
    final style = AnText.metaTabular().copyWith(color: c.inkFaint);
    return Padding(
      padding: const EdgeInsets.only(
        left: AnSize.ganttLaneW + AnSpace.s12 + AnSpace.s8,
        right: AnSpace.s8,
        bottom: AnSpace.s4,
      ),
      child: Row(
        children: [
          Text(fmtClock(ch.start), style: style),
          Expanded(
            child: Center(
              child: Text(
                ch.start != null && ch.end != null
                    ? fmtDuration(ch.end!.difference(ch.start!))
                    : '',
                style: style,
              ),
            ),
          ),
          Text(fmtClock(ch.end), style: style),
        ],
      ),
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
          child: Row(
            children: [
              SizedBox(
                width: AnSize.ganttLaneW,
                child: Row(
                  children: [
                    Icon(
                      AnIcons.node(r.kind.name),
                      size: AnSize.iconSm,
                      color: c.inkFaint,
                    ),
                    const SizedBox(width: AnSpace.s6),
                    Flexible(
                      child: Text(
                        r.nodeId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AnText.code.copyWith(color: c.inkMuted),
                      ),
                    ),
                    if (r.iterations > 1) ...[
                      const SizedBox(width: AnSpace.s6),
                      Text(
                        '×${r.iterations}',
                        style: AnText.metaTabular().copyWith(color: c.accent),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AnSpace.s12),
              Expanded(child: _track(context, r)),
            ],
          ),
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
      child: LayoutBuilder(
        builder: (context, cst) {
          final w = cst.maxWidth;
          // The min visible width can't exceed the track (a track narrower than s4 would make
          // clamp(s4, w) throw: lowerLimit > upperLimit — a hard ArgumentError, not just an overflow).
          // 最小可见宽不得超过轨宽(否则 clamp 下限>上限抛 ArgumentError、非仅溢出)。
          final minBar = w < AnSpace.s4 ? w : AnSpace.s4;
          Widget part(
            double at,
            double width, {
            required Color fill,
            Color? border,
            Widget? child,
          }) => Positioned(
            left: (at * w).clamp(0.0, w),
            top: 0,
            bottom: 0,
            width: (width * w).clamp(minBar, w),
            child: Container(
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(AnRadius.tag),
                border: border == null
                    ? null
                    : Border.all(color: border, width: AnSize.hairline),
              ),
              child: child,
            ),
          );

          if (r.segments.isEmpty) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                r.inferred ? inferredLabel : notRunLabel,
                style: AnText.meta.copyWith(
                  color: r.inferred ? c.accent : c.inkFaint,
                ),
              ),
            );
          }

          // The speculative front (§5.5): a soft accent bar that claims a POSITION, not a duration —
          // it carries the «推测执行中» word inside so the bar can never be read as measured fact.
          // 推测前沿:柔和 accent 条,只声称位置不声称时长——词就写在条里,读不成实测事实。
          if (r.inferred) {
            final seg = r.segments.first;
            return Stack(
              children: [
                part(
                  seg.at,
                  seg.w,
                  fill: c.accentSoft,
                  border: c.accent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AnSpace.s6),
                    child: Text(
                      inferredLabel,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: AnText.meta.copyWith(color: c.accent),
                    ),
                  ),
                ),
              ],
            );
          }

          final fill = _barColor(context, r.status);
          final bars = <Widget>[];
          Widget waitBox(double at, double width, {required bool label}) =>
              part(
                at,
                width,
                fill: c.warnSoft,
                border: c.warn,
                child: label
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AnSpace.s6,
                        ),
                        child: Text(
                          waitingLabel,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: AnText.meta.copyWith(color: c.warn),
                        ),
                      )
                    : null,
              );

          for (final seg in r.segments) {
            // QUEUE — the grey lead-in (工单⑫). Only ever drawn when the row really carried the
            // stamps. 排队灰段:仅行真带戳时。
            if (seg.queueW > 0) {
              bars.add(part(seg.at, seg.queueW, fill: c.surfaceSunken));
            }
            // A row that is STILL parked but whose bar carries no separate park part is the SIMPLE
            // shape (a caller that hand-built the row, or a legacy row with no queue stamps to split
            // on): its one bar IS the wait. The `parked` FLAG stays authoritative for «this node is
            // waiting on a human» — the three-part split is a refinement of the drawing, never the
            // thing that decides whether the wait exists.
            // 仍 parked 且无独立停车段=朴素形(调用方手搓的行,或无戳可拆的旧行):它那一条就是等待本身。
            // 「在等人」的权威永远是 parked 标志——三段拆分只是画法的细化,绝不是「等待是否存在」的裁决者。
            final wholeBarIsTheWait = r.parked && seg.parkedW <= 0;
            if (seg.w > 0) {
              bars.add(
                wholeBarIsTheWait
                    ? waitBox(seg.at + seg.queueW, seg.w, label: true)
                    : part(seg.at + seg.queueW, seg.w, fill: fill),
              );
            }
            // PARKED — the amber human wait. A row that is STILL parked wears the waiting word; a
            // settled approval's wait is just the amber span (its status word lives in the ledger).
            // 停车琥珀段:仍在等的戴「等待」词,已决审批只留琥珀跨度(状态词在台账)。
            if (seg.parkedW > 0) {
              bars.add(
                waitBox(
                  seg.at + seg.queueW + seg.w,
                  seg.parkedW,
                  label: r.parked,
                ),
              );
            }
          }
          final stack = Stack(children: bars);
          if (!_timed) return stack;
          // Hover the TRACK, not each bar: the parts of one bar are one fact, and a per-part tooltip
          // would flicker as the pointer crosses the seams. 悬停整轨而非逐段:一条=一个事实,逐段 tooltip
          // 会在接缝处闪。
          final tip = _tooltipFor(r);
          return tip.isEmpty ? stack : AnTooltip(message: tip, child: stack);
        },
      ),
    );
  }

  /// The hover truth: absolute start→end plus the queue/exec split when the model has it. Built off
  /// the LAST segment (the newest iteration — what a loop row is asked about). hover 真相:绝对起止 +
  /// 有数据时的排队/执行拆分;取最后一段(最新迭代)。
  String _tooltipFor(GanttRow r) {
    final seg = r.segments.last;
    final from = seg.from, to = seg.to;
    if (from == null || to == null) return '';
    final lines = <String>['${fmtClock(from)} → ${fmtClock(to)}'];
    final ch = chart;
    if (ch?.start != null && ch?.end != null) {
      final spanMs = ch!.end!.difference(ch.start!).inMilliseconds;
      if (spanMs > 0) {
        final queueMs = (seg.queueW * spanMs).round();
        final execMs = (seg.w * spanMs).round();
        final parts = <String>[
          if (seg.queueW > 0 && queueLabel.isNotEmpty)
            '$queueLabel ${fmtDuration(Duration(milliseconds: queueMs))}',
          if (execLabel.isNotEmpty)
            '$execLabel ${fmtDuration(Duration(milliseconds: execMs))}',
        ];
        if (parts.isNotEmpty) lines.add(parts.join(' · '));
      }
    }
    return lines.join('\n');
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

/// The «now» marker — a hairline the full height of the chart at the axis fraction. now 线。
class _NowLine extends StatelessWidget {
  const _NowLine({required this.at});
  final double at;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, cst) {
        final x = (at * cst.maxWidth).clamp(
          0.0,
          cst.maxWidth - AnSize.hairline,
        );
        return Stack(
          children: [
            Positioned(
              left: x,
              top: 0,
              bottom: 0,
              width: AnSize.hairline,
              child: ColoredBox(color: c.accent),
            ),
          ],
        );
      },
    );
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
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AnRadius.button),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
