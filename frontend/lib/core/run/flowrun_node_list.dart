import 'package:flutter/widgets.dart';

import '../contract/entities/workflow.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/ui.dart';
import '../../i18n/strings.g.dart';

// The per-node record of a run — upstreamed from chat's tool cards (WRK-056 #38 → WRK-069 S0) so the
// Scheduler's run flagship page and chat's flowrun cards render the SAME ledger. Pure props-in; the
// i18n words live in the core-visible `run.*` namespace (core primitives must not reach into feature
// namespaces, 批6a). 节点台账——自 chat 工具卡上收(S0),Scheduler 旗舰页与 chat 卡渲同一件;纯 props;
// 词表在 core 可见的 run.*。

/// FlowrunNodeList — one row per node (status dot · nodeId · loop-turn · kind glyph), failed rows
/// surface a red error line. When the run was 80-node-capped (summary present), an honest header
/// states the REAL counts (from summary.byStatus, never nodes.length). Bounded to [cap] rows with an
/// expand-all escape; failed/parked sort to the top (the diagnostic ones you came to see).
/// FlowrunNodeList 节点台账:每节点一行,失败置顶,截断诚实账。
class FlowrunNodeList extends StatefulWidget {
  const FlowrunNodeList({required this.nodes, this.summary, this.cap = 12, super.key});

  final List<FlowrunNode> nodes;
  final FlowrunNodeSummary? summary;
  final int cap;

  @override
  State<FlowrunNodeList> createState() => _FlowrunNodeListState();
}

class _FlowrunNodeListState extends State<FlowrunNodeList> {
  // failed (0) → parked (1) → everything completed (2); stable within a rank. 失败→park→完成,组内稳定。
  static int _rank(FlowrunNode n) => switch (n.status) { 'failed' => 0, 'parked' => 1, _ => 2 };

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.nodes];
    // A stable sort by rank (Dart's sort is not stable — pair with the original index). 稳定按 rank 排。
    final indexed = [for (final (i, n) in sorted.indexed) (i, n)]
      ..sort((a, b) {
        final r = _rank(a.$2).compareTo(_rank(b.$2));
        return r != 0 ? r : a.$1.compareTo(b.$1);
      });
    final ordered = [for (final e in indexed) e.$2];
    return AnWindow(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        // The honest-count header stays OUTSIDE the list shell (heterogeneous headers are the
        // caller's, 批6 A-071). 诚实账头件留壳外。
        if (widget.summary != null) ...[
          _summaryBar(context, widget.summary!),
          const SizedBox(height: AnSpace.s4),
        ],
        AnLedgerList(cap: widget.cap, children: [for (final n in ordered) _nodeRow(context, n)]),
      ]),
    );
  }

  // The 80-cap honest header — the bar family face (文法 #3: a rendered ' · ' chain lives ONLY in
  // AnStatBar; this hand-joined meta line was its last flowrun holdout, A-087). Real counts from
  // summary.byStatus (NEVER nodes.length). 截断诚实账走条族当家件(' · ' 链归 AnStatBar);真数来自
  // byStatus,绝不数 nodes.length。
  Widget _summaryBar(BuildContext context, FlowrunNodeSummary s) {
    final t = Translations.of(context);
    return AnStatBar(stats: [
      AnStat(t.run.flowShown(shown: '${s.shownNodes}', total: '${s.totalNodes}')),
      if ((s.byStatus['completed'] ?? 0) > 0) AnStat('${t.run.runCompleted} ${s.byStatus['completed']}'),
      if ((s.byStatus['failed'] ?? 0) > 0) AnStat('${t.run.failed} ${s.byStatus['failed']}'),
      if ((s.byStatus['parked'] ?? 0) > 0) AnStat('${t.run.nodeWait} ${s.byStatus['parked']}'),
    ]);
  }

  Widget _nodeRow(BuildContext context, FlowrunNode n) {
    final c = context.colors;
    final failed = n.status == 'failed';
    // Family row (批6 A-076): the status dot moves LEFT (法典族四②——was the family's one
    // right-side dot), the kind glyph steps down to the first chip, the error line rides the
    // danger sub voice (its indent arithmetic died with it). 族行:状态点归左,kind 字形降为首枚
    // chip,错误行走 danger 副行(缩进算术随行退役)。
    return AnLedgerRow(
      lead: AnStatusDot(AnStatus.fromRaw(n.status)),
      primary: n.nodeId,
      chips: [
        Icon(AnIcons.node(n.kind), size: AnSize.iconSm, color: c.inkFaint),
        // A loop turn > 0 → the 0-based iteration index (disambiguates repeated nodeId rows). 循环轮次。
        if (n.iteration > 0) Text('#${n.iteration}', style: AnText.metaTabular().copyWith(color: c.inkFaint)),
      ],
      sub: failed ? n.error : null,
      subTone: AnTone.danger,
    );
  }
}
