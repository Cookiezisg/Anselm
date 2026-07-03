import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../graph/flowrun_timeline.dart';
import '../model/status_state.dart';
import 'an_node_gantt.dart';
import 'an_row.dart';
import 'an_state.dart';

/// One run in the board's left list. A workflow is triggered many times → many flowruns; this is the
/// list-row projection (status dot + mono id + trigger·time hint + ↻replay meta). 看板左列的一条 run。
class AnRunItem {
  const AnRunItem({
    required this.id,
    required this.status,
    this.hint,
    this.replayCount = 0,
  });

  final String id;
  final String status;
  final String? hint; // "trigger · when"
  final int replayCount;
}

/// The run board for one workflow (the demo's `an-run-board`): left = the run list (each run a mono
/// AnRow, emphatic-selected), right = the selected run's [AnNodeGantt]. A framed 2-column card with
/// its own headers; the two columns are strong-linked by the caller (pick a run → its gantt; pick a
/// node → its debug). Empty run set → an inset empty state (not blank). Pure composition of existing
/// primitives — the board owns only the 2-column chrome + the run↔gantt selection wiring.
///
/// 单 workflow 的运行看板(demo `an-run-board`):左=run 列表(每条 mono AnRow,emphatic 选中),
/// 右=选中 run 的 [AnNodeGantt]。带各自表头的 framed 2 列卡;两列由调用方强链(点 run→其甘特,点
/// 节点→其调试)。空 run 集=内嵌空态、非裸白。既有原语组合,看板只管 2 列外壳 + run↔甘特选区接线。
class AnRunBoard extends StatelessWidget {
  const AnRunBoard({
    required this.runs,
    required this.gantt,
    this.selectedRunId,
    this.onRunPick,
    this.selectedNodeId,
    this.onNodePick,
    required this.runsHeader,
    required this.ganttHeader,
    required this.emptyTitle,
    required this.emptyHint,
    this.notRunLabel = '',
    this.waitingLabel = '',
    super.key,
  });

  final List<AnRunItem> runs;
  final List<GanttRow> gantt; // the selected run's timeline 选中 run 的时间轴
  final String? selectedRunId;
  final ValueChanged<String>? onRunPick;
  final String? selectedNodeId;
  final ValueChanged<String>? onNodePick;

  /// Caller i18n (core stays string-free). 调用方 i18n。
  final String runsHeader;
  final String ganttHeader;
  final String emptyTitle;
  final String emptyHint;
  final String notRunLabel;
  final String waitingLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AnRadius.card),
        border: Border.all(color: c.line, width: AnSize.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      // IntrinsicHeight equalizes the two columns so the divider spans full — and it can measure the
      // gantt now that each gantt row is a FIXED-height SizedBox (the per-row track LayoutBuilder
      // only measures width, not height). IntrinsicHeight 让两列等高、分隔线满高;甘特每行定高、其逐行
      // LayoutBuilder 只测宽,故可被量。
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: AnSize.runListW,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: c.line, width: AnSize.hairline)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _header(context, runsHeader),
                if (runs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AnSpace.s8),
                    child: AnState(
                        kind: AnStateKind.empty,
                        size: AnStateSize.inset,
                        title: emptyTitle,
                        hint: emptyHint),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(AnSpace.s4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final r in runs)
                          AnRow(
                            dot: AnStatus.fromRaw(r.status),
                            label: r.id,
                            hint: r.hint,
                            meta: r.replayCount > 0 ? '↻${r.replayCount}' : null,
                            mono: true,
                            emphatic: true,
                            selected: r.id == selectedRunId,
                            onSelect: onRunPick == null ? null : () => onRunPick!(r.id),
                          ),
                      ],
                    ),
                  ),
              ]),
            ),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _header(context, ganttHeader),
              Padding(
                padding: const EdgeInsets.all(AnSpace.s8),
                child: AnNodeGantt(
                  rows: gantt,
                  selectedNodeId: selectedNodeId,
                  onNodePick: onNodePick,
                  notRunLabel: notRunLabel,
                  waitingLabel: waitingLabel,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _header(BuildContext context, String label) {
    final c = context.colors;
    return Container(
      height: AnSize.control,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: AnSpace.s12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line, width: AnSize.hairline)),
      ),
      child: Text(label,
          style: AnText.meta.weight(AnText.emphasisWeight).copyWith(color: c.inkFaint)),
    );
  }
}
