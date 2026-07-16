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

/// One ledger line as the CALLER has already folded it (WRK-069 §5.4). The widget deliberately does
/// NOT fold loops or compute timings itself: the flagship's fold is a tested pure projection
/// (`foldNodeLedger`) shared with the gantt, and a primitive that re-derived it would be a second
/// truth. A caller with nothing to fold (chat's card) just maps one row to one entry.
/// 一行台账(调用方已折好):widget 刻意不自行折循环/算耗时——旗舰的折叠是与甘特共享的受测纯投影,
/// 原语再推一遍就成了第二个真相;无需折叠的调用方(chat 卡)一行映一条。
class FlowrunNodeLine {
  const FlowrunNodeLine({
    required this.nodeId,
    required this.status,
    required this.kind,
    this.iterations = 1,
    this.iteration = 0,
    this.error,
    this.errorFull,
    this.measure,
    this.sub,
    this.inferred = false,
    this.iterationLines = const [],
  });

  /// One plain row — the un-folded face (chat's flowrun card). 一行直映(chat 卡的朴素脸)。
  factory FlowrunNodeLine.of(FlowrunNode n) => FlowrunNodeLine(
        nodeId: n.nodeId,
        status: n.status,
        kind: n.kind,
        iteration: n.iteration,
        error: n.status == 'failed' ? n.error : null,
      );

  final String nodeId;
  final String status;
  final String kind;

  /// Executed iterations folded into this line (>1 → the ×N badge). 折进本行的迭代数(>1 出 ×N)。
  final int iterations;

  /// The iteration this line SPEAKS for (the newest one) — the selection coordinate. 本行代表的迭代。
  final int iteration;

  /// The red SENTENCE (failed lines only) — the caller passes the SAME string the head and the gantt
  /// use (§5.1 同句同源). 红句(仅失败行):调用方传与头/甘特同一个串。
  final String? error;

  /// The whole error blob behind [error]'s first line — the failed row's disclosure. Null / equal to
  /// [error] → nothing more to show, so the row grows no dead expander.
  /// 错误全文(失败行的披露体);为空或与首句相同=没有更多可看,不长出死展开器。
  final String? errorFull;

  /// The trailing measure — the elapsed, already split «排队 x · 执行 y» by the caller when the data
  /// exists. 尾随度量:耗时(有数据时调用方已拆好「排队 x · 执行 y」)。
  final String? measure;

  /// A non-error sub line (the queue/exec split when the caller wants it below rather than trailing).
  /// 非错误副行。
  final String? sub;

  /// The speculative running front — has no row at all (§5.5). 推测执行中的前沿(无行)。
  final bool inferred;

  /// The members of a ×N fold — one per executed iteration, ascending (§5.4 循环同节点折叠 ×N 一行
  /// 计数展开). Empty when the node ran once (nothing to unfold). 折叠循环的成员(逐迭代升序);单次
  /// 执行时为空。
  final List<FlowrunNodeLine> iterationLines;
}

/// FlowrunNodeList — one row per node (status dot · nodeId · loop-turn · kind glyph), failed rows
/// surface a red error line. When the run was 80-node-capped (summary present), an honest header
/// states the REAL counts (from summary.byStatus, never nodes.length). Bounded to [cap] rows with an
/// expand-all escape; failed/parked sort to the top (the diagnostic ones you came to see).
///
/// Two faces. The PLAIN face ([nodes]) is chat's: it folds nothing and owns its own failed-first
/// sort. The FLAGSHIP face ([lines]) is fed pre-folded lines plus selection ([selectedNodeId] /
/// [selectedIteration] / [onPick]) and renders the row's disclosure — §5.4 pins «失败置顶 + 失败是唯一
/// 自动展开», the same law as WRK-065's tool cards: nothing pops open at you except the one thing that
/// broke. [framed] false drops the window shell (a host card supplies it).
///
/// FlowrunNodeList 节点台账:每节点一行,失败置顶,截断诚实账。两张脸:朴素脸(nodes,chat 用,自己排序、
/// 不折叠)与旗舰脸(lines,喂已折好的行 + 选区),后者按 §5.4 失败置顶、失败是唯一自动展开(与 WRK-065
/// tool 卡同律:除了坏掉的那一个,什么都不该自己弹开)。
class FlowrunNodeList extends StatefulWidget {
  const FlowrunNodeList({
    this.nodes = const [],
    this.lines,
    this.summary,
    this.cap = 12,
    this.selectedNodeId,
    this.selectedIteration,
    this.onPick,
    this.framed = true,
    super.key,
  });

  /// The plain face's rows (folded + sorted here). 朴素脸的行(此处排序)。
  final List<FlowrunNode> nodes;

  /// The flagship face's pre-folded lines — when non-null, [nodes] is ignored. 旗舰脸的已折行。
  final List<FlowrunNodeLine>? lines;

  final FlowrunNodeSummary? summary;
  final int cap;

  final String? selectedNodeId;
  final int? selectedIteration;

  /// Pick a line → (nodeId, iteration). Selection is the CALLER's (the flagship derives it from the
  /// URL, §5 三海拔单选区) — the list never owns it. 点行 →(节点,迭代);选区归调用方(旗舰派生自 URL)。
  final void Function(String nodeId, int iteration)? onPick;

  final bool framed;

  @override
  State<FlowrunNodeList> createState() => _FlowrunNodeListState();
}

class _FlowrunNodeListState extends State<FlowrunNodeList> {
  // failed (0) → parked (1) → everything completed (2); stable within a rank. 失败→park→完成,组内稳定。
  static int _rank(FlowrunNode n) => switch (n.status) { 'failed' => 0, 'parked' => 1, _ => 2 };

  /// The ONE row that opens itself: the FIRST failed line. Everything else waits to be asked
  /// (WRK-065 同律). 唯一自动展开的行=第一条失败行;其余等你问。
  String? _autoOpenKey(List<FlowrunNodeLine> lines) {
    for (final l in lines) {
      if (l.status == 'failed') return '${l.nodeId}#${l.iteration}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.lines ?? _plainLines();
    final autoOpen = _autoOpenKey(lines);
    final body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The honest-count header stays OUTSIDE the list shell (heterogeneous headers are the
          // caller's, 批6 A-071). 诚实账头件留壳外。
          if (widget.summary != null) ...[
            _summaryBar(context, widget.summary!),
            const SizedBox(height: AnSpace.s4),
          ],
          AnLedgerList(
            cap: widget.cap,
            children: [for (final l in lines) _line(context, l, autoOpen)],
          ),
        ]);
    return widget.framed ? AnWindow(child: body) : body;
  }

  /// The plain face: fold each row to a line, failed/parked first. 朴素脸:逐行映射 + 失败置顶。
  List<FlowrunNodeLine> _plainLines() {
    // A stable sort by rank (Dart's sort is not stable — pair with the original index). 稳定按 rank 排。
    final indexed = [for (final (i, n) in widget.nodes.indexed) (i, n)]
      ..sort((a, b) {
        final r = _rank(a.$2).compareTo(_rank(b.$2));
        return r != 0 ? r : a.$1.compareTo(b.$1);
      });
    return [for (final e in indexed) FlowrunNodeLine.of(e.$2)];
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

  /// The row's ONE disclosure layer (§5.4 页内披露只此一层): the whole error behind the red first
  /// line, and/or a ×N fold's individual turns (each of which picks that iteration). Everything
  /// heavier — the I/O trees, the logs — lives in the right island, one click away.
  /// 行的唯一披露层:错误全文 与/或 ×N 折叠的逐轮(点即选中该迭代);更重的 I/O 与日志归右岛。
  Widget? _disclosure(BuildContext context, FlowrunNodeLine l) {
    final c = context.colors;
    final pick = widget.onPick;
    final full = l.errorFull;
    final hasError = full != null && full.trim().isNotEmpty && full.trim() != l.error?.trim();
    if (!hasError && l.iterationLines.isEmpty) return null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      // BARE mono — the list already sits in its window, and a window may never nest a window
      // (法典 窗禁套窗). 裸 mono:列表已在窗里,窗禁套窗。
      if (hasError)
        Text(full.trim(),
            maxLines: AnCap.monoErrorLines,
            overflow: TextOverflow.ellipsis,
            style: AnText.code.copyWith(color: c.danger)),
      if (hasError && l.iterationLines.isNotEmpty) const SizedBox(height: AnSpace.s6),
      for (final it in l.iterationLines)
        AnLedgerRow(
          lead: AnStatusDot(AnStatus.fromRaw(it.status)),
          primary: '#${it.iteration}',
          chips: const [],
          sub: it.status == 'failed' ? it.error : null,
          subTone: AnTone.danger,
          measure: it.measure,
          onTap: pick == null ? null : () => pick(it.nodeId, it.iteration),
        ),
    ]);
  }

  Widget _line(BuildContext context, FlowrunNodeLine l, String? autoOpenKey) {
    final c = context.colors;
    final t = Translations.of(context);
    final key = '${l.nodeId}#${l.iteration}';
    final failed = l.status == 'failed';
    final selected = widget.selectedNodeId == l.nodeId &&
        (widget.selectedIteration == null || widget.selectedIteration == l.iteration);
    final pick = widget.onPick;
    final disclosure = _disclosure(context, l);
    // Family row (批6 A-076): the status dot moves LEFT (法典族四②——was the family's one
    // right-side dot), the kind glyph steps down to the first chip, the error line rides the
    // danger sub voice (its indent arithmetic died with it). 族行:状态点归左,kind 字形降为首枚
    // chip,错误行走 danger 副行(缩进算术随行退役)。
    final row = AnLedgerRow(
      lead: AnStatusDot(AnStatus.fromRaw(l.status)),
      primary: l.nodeId,
      chips: [
        Icon(AnIcons.node(l.kind), size: AnSize.iconSm, color: c.inkFaint),
        // A loop turn > 0 → the 0-based iteration index (disambiguates repeated nodeId rows). 循环轮次。
        if (l.iterations <= 1 && l.iteration > 0)
          Text('#${l.iteration}', style: AnText.metaTabular().copyWith(color: c.inkFaint)),
        // Folded loop → the ×N count (§5.4 循环同节点折叠 ×N 一行). 折叠循环 → ×N。
        if (l.iterations > 1)
          Text('×${l.iterations}', style: AnText.metaTabular().copyWith(color: c.accent)),
        // The speculative front says so, in words, right on the row. 推测前沿:把话写在行上。
        if (l.inferred) AnChip(t.run.inferredRunning, tone: AnTone.accent),
      ],
      sub: failed ? l.error : l.sub,
      subTone: failed ? AnTone.danger : AnTone.none,
      measure: l.measure,
      onTap: pick == null ? null : () => pick(l.nodeId, l.iteration),
      expandChild: disclosure,
      // The one auto-disclosure: the first failure, open on arrival (WRK-065 同律 — nothing else
      // pops open at you). A selected row opens too, because YOU asked for it.
      // 唯一自动展开=第一条失败行(其余绝不自己弹开);选中行也开——那是你亲自要的。
      expanded: disclosure != null && (selected || key == autoOpenKey),
    );
    return row;
  }
}
