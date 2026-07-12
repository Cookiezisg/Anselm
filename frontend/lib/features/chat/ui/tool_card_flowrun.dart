import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../core/contract/entities/workflow.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import 'tool_card_io_section.dart';
import 'run_dossier.dart';
import 'tool_card_nav.dart';

// F08 flowrun bodies (B5.3) — replay_flowrun's node ledger. The tool result is the {flowrun, nodes,
// nodeSummary?} composite (SAME shape as get_flowrun); the body's core is FlowrunNodeList — you SEE the
// run's per-node record (what completed, what broke, what's parked). Counts always come from
// nodeSummary (never nodes.length, which is 80 when the run was capped). F08 flowrun:节点台账,看见 run。

Map<String, dynamic>? _obj(String s) {
  try {
    final d = jsonDecode(s);
    if (d is Map<String, dynamic>) return d;
  } catch (_) {}
  return null;
}

// ── trigger_workflow — the async «run now» card ──
// Wire: {flowrunId, workflowId} — starts a run and returns only the two ids (the run's fate is a
// SEPARATE ledger; get_flowrun reads it back). NEVER danger — the tool only lights the run; a return IS
// success. The version-pinned graph snapshot (FlowrunSnapshotPane) is deferred (no by-version graph
// endpoint yet) — the card shows the launch credential + a get_flowrun pointer. trigger_workflow 薄卡。

/// The flowrunId receipt (fr_… truncated); null if unparseable. Never danger (fire-and-return=success).
/// trigger 回执:flowrun id 截断;永不危险色。
ToolReceipt? triggerWorkflowReceipt(Translations t, String output) {
  final fr = _obj(output)?['flowrunId'];
  if (fr is! String || fr.isEmpty) return null;
  return (text: fr.length > 12 ? '${fr.substring(0, 12)}…' : fr, tone: ToolReceiptTone.none);
}

/// trigger_workflow body — the payload input (empty → grey note) + a launch credential (navigable
/// workflow pill + flowrunId copy) + a get_flowrun pointer. trigger 落定体:输入 + 启动凭据 + 指路。
Widget triggerWorkflowBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final out = _obj(state.resultText);
  final flowrunId = out?['flowrunId'] as String?;
  final workflowId = (out?['workflowId'] as String?) ?? argString(state.argsText, 'workflowId');
  final payload = _obj(state.argsText)?['payload'];
  final emptyPayload = payload == null || (payload is Map && payload.isEmpty);
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    if (state.summary.isNotEmpty)
      Padding(padding: const EdgeInsets.only(bottom: AnSpace.s6), child: Text(state.summary, style: AnText.meta.copyWith(color: c.inkMuted))),
    // The payload fed to the entry trigger — an empty {} is stated, never dressed as an empty tree.
    // 喂给入口触发器的 payload;空 {} 明说、不装空树。
    if (emptyPayload)
      Text(t.chat.tool.emptyPayload, style: AnText.code.copyWith(color: c.inkFaint))
    else
      ToolIOSection(label: t.chat.tool.ioInput, value: payload),
    const SizedBox(height: AnSpace.s6),
    Wrap(spacing: AnGap.inline, runSpacing: AnSpace.s4, crossAxisAlignment: WrapCrossAlignment.center, children: [
      if (workflowId != null && workflowId.isNotEmpty) toolNavPill(context, kind: 'workflow', label: workflowId, id: workflowId),
      if (flowrunId != null && flowrunId.isNotEmpty) AnChip(flowrunId, look: AnChipLook.outlined, mono: true, copyValue: flowrunId, tooltip: flowrunId),
    ]),
    const SizedBox(height: AnSpace.s6),
    Text(t.chat.tool.triggerStartedNote, style: AnText.meta.copyWith(color: c.inkFaint)),
  ]);
}

/// Decode a {flowrun, nodes, nodeSummary?} tool result, or null if unparseable. 解码 flowrun 复合结果。
FlowrunComposite? decodeFlowrunResult(String output) {
  try {
    final d = jsonDecode(output);
    if (d is Map<String, dynamic> && d['flowrun'] is Map) return FlowrunComposite.fromJson(d);
  } catch (_) {}
  return null;
}

/// The node count a run really has — nodeSummary.totalNodes when capped, else nodes.length. Never
/// nodes.length blindly (it's 80 on a capped run). 真节点数:截断取 summary、否则 nodes 长度。
int flowrunTotalNodes(FlowrunComposite comp) => comp.nodeSummary?.totalNodes ?? comp.nodes.length;

/// Whether any node parked (an approval waiting) — the run header stays `running` while a node parks,
/// so «awaiting approval» is read off the NODES, not the run status. 有节点 park=等待审批(run 头仍 running)。
bool flowrunHasParked(FlowrunComposite comp) => comp.nodes.any((n) => n.status == 'parked');

/// The replay receipt — completed→`完成·N 节点`; failed→red `仍失败`+auto-expand; cancelled→`已取消`;
/// running with a parked node→`等待审批` (grey text, amber lives in the body); running w/o park→none.
/// FlowRun.status has NO `parked` (park is a node state). replay 回执:四态,run 头无 parked 分支。
ToolReceipt? replayReceipt(Translations t, String output) {
  final comp = decodeFlowrunResult(output);
  if (comp == null) return null;
  final n = flowrunTotalNodes(comp);
  final nodes = t.chat.tool.nodeCount(n: '$n');
  switch (comp.flowrun.status) {
    case 'completed':
      return (text: '${t.chat.tool.runCompleted} · $nodes', tone: ToolReceiptTone.none);
    case 'failed':
      return (text: t.chat.tool.runStillFailed, tone: ToolReceiptTone.danger);
    case 'cancelled':
      return (text: t.chat.tool.runCancelled, tone: ToolReceiptTone.none);
    case 'running':
      // A parked node → «awaiting approval» (grey — it's not a failure). 有 park→等待审批(灰,非失败)。
      return flowrunHasParked(comp) ? (text: t.chat.tool.runAwaitApproval, tone: ToolReceiptTone.none) : null;
    default:
      return null;
  }
}

/// Whether the replayed run is still failed (auto-expand for diagnosis). 仍失败→自动展开诊断。
bool replayResultFailed(String output) => decodeFlowrunResult(output)?.flowrun.status == 'failed';

/// replay_flowrun body — a pinned-versions caution + the node ledger (FlowrunNodeList) + a footer
/// (status word · 第 N 次重放 · workflow pill · flowrunId copy). replay 落定体。
Widget replayFlowrunBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final comp = decodeFlowrunResult(state.resultText);
  if (comp == null) {
    return Text(state.resultText, style: AnText.code.copyWith(color: c.inkMuted), maxLines: 40, overflow: TextOverflow.ellipsis);
  }
  final run = comp.flowrun;
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    // The replay honesty note — the fix you made after the failure did NOT take effect (pinned versions).
    // 重放诚实注:事后改的代码这次没生效(用原 pin 版本)。
    Text(t.chat.tool.replayPinNote, style: AnText.meta.copyWith(color: c.inkFaint)),
    const SizedBox(height: AnSpace.s6),
    if (run.error != null && run.error!.isNotEmpty) ...[
      AnWindow(child: Text(run.error!, style: AnText.code.copyWith(color: c.danger), maxLines: 12, overflow: TextOverflow.ellipsis)),
      const SizedBox(height: AnSpace.s6),
    ],
    FlowrunNodeList(nodes: comp.nodes, summary: comp.nodeSummary),
    // No SizedBox — the family bar brings its own top s6 (批3: a kept one doubles the gap). 条自带前距。
    _runFooter(context, run),
  ]);
}

/// The run footer (批3 条族: a mapping onto the family head) — status badge (AnStatus.fromRaw 单源;
/// domain words: failed=仍失败, running=等待审批) + replay count + a navigable workflow pill + the
/// flowrunId (copy). run 页脚:状态词徽(fromRaw 单源+域词)+重放数+workflow 药丸+flowrunId 复制。
Widget _runFooter(BuildContext context, Flowrun run) {
  final t = Translations.of(context);
  return AnStatBar(
    status: AnStatus.fromRaw(run.status),
    statusLabel: switch (run.status) {
      'completed' => t.chat.tool.runCompleted,
      'failed' => t.chat.tool.runStillFailed,
      'cancelled' => t.chat.tool.runCancelled,
      'running' => t.chat.tool.runAwaitApproval,
      _ => run.status,
    },
    stats: [if (run.replayCount > 0) AnStat(t.chat.tool.replayTimes(n: '${run.replayCount}'), tabular: true)],
    chips: [
      if (run.workflowId.isNotEmpty) toolNavPill(context, kind: 'workflow', label: run.workflowId, id: run.workflowId),
      AnChip(run.id, look: AnChipLook.outlined, mono: true, copyValue: run.id, tooltip: run.id),
    ],
  );
}

/// FlowrunNodeList (WRK-056 #38) — the per-node record of a run: one row per node (kind glyph · nodeId ·
/// loop-turn · status dot), failed rows surface a red error line. When the run was 80-node-capped
/// (summary present), an honest header states the REAL counts (from summary.byStatus, never
/// nodes.length). Bounded to [cap] rows with an expand-all escape; failed/parked sort to the top (the
/// diagnostic ones you came to see). FlowrunNodeList 节点台账:每节点一行,失败置顶,截断诚实账。
class FlowrunNodeList extends StatefulWidget {
  const FlowrunNodeList({required this.nodes, this.summary, this.cap = 12, super.key});

  final List<FlowrunNode> nodes;
  final FlowrunNodeSummary? summary;
  final int cap;

  @override
  State<FlowrunNodeList> createState() => _FlowrunNodeListState();
}

class _FlowrunNodeListState extends State<FlowrunNodeList> {
  bool _showAll = false;

  // failed (0) → parked (1) → everything completed (2); stable within a rank. 失败→park→完成,组内稳定。
  static int _rank(FlowrunNode n) => switch (n.status) { 'failed' => 0, 'parked' => 1, _ => 2 };

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final sorted = [...widget.nodes];
    // A stable sort by rank (Dart's sort is not stable — pair with the original index). 稳定按 rank 排。
    final indexed = [for (final (i, n) in sorted.indexed) (i, n)]
      ..sort((a, b) {
        final r = _rank(a.$2).compareTo(_rank(b.$2));
        return r != 0 ? r : a.$1.compareTo(b.$1);
      });
    final ordered = [for (final e in indexed) e.$2];
    final over = ordered.length > widget.cap;
    final visible = _showAll ? ordered : ordered.take(widget.cap).toList();
    return AnWindow(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (widget.summary != null) ...[
          _summaryBar(context, widget.summary!),
          const SizedBox(height: AnSpace.s4),
        ],
        for (final n in visible) _nodeRow(context, n),
        if (over && !_showAll)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s4),
            child: AnInteractive(
              onTap: () => setState(() => _showAll = true),
              builder: (context, _) => Text(t.chat.tool.flowExpandAll(n: '${ordered.length - widget.cap}'),
                  style: AnText.meta.weight(AnText.emphasisWeight).copyWith(color: context.colors.accent)),
            ),
          ),
      ]),
    );
  }

  // The 80-cap honest header: real counts from summary.byStatus (NEVER nodes.length). 截断诚实账。
  Widget _summaryBar(BuildContext context, FlowrunNodeSummary s) {
    final t = Translations.of(context);
    final c = context.colors;
    final parts = <String>[
      if ((s.byStatus['completed'] ?? 0) > 0) '${t.chat.tool.runCompleted} ${s.byStatus['completed']}',
      if ((s.byStatus['failed'] ?? 0) > 0) '${t.chat.tool.failed} ${s.byStatus['failed']}',
      if ((s.byStatus['parked'] ?? 0) > 0) '${t.chat.tool.nodeWait} ${s.byStatus['parked']}',
    ];
    return Text(
      '${t.chat.tool.flowShown(shown: '${s.shownNodes}', total: '${s.totalNodes}')}${parts.isEmpty ? '' : ' · ${parts.join(' · ')}'}',
      style: AnText.meta.copyWith(color: c.inkFaint),
    );
  }

  Widget _nodeRow(BuildContext context, FlowrunNode n) {
    final c = context.colors;
    final failed = n.status == 'failed';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AnSpace.s2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(AnIcons.node(n.kind), size: AnSize.iconSm, color: c.inkFaint),
          const SizedBox(width: AnSpace.s8),
          Flexible(
            child: Text(n.nodeId, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AnText.mono.copyWith(color: c.inkMuted)),
          ),
          // A loop turn > 0 → the 0-based iteration index (disambiguates repeated nodeId rows). 循环轮次。
          if (n.iteration > 0) ...[
            const SizedBox(width: AnSpace.s6),
            Text('#${n.iteration}', style: AnText.metaTabular().copyWith(color: c.inkFaint)),
          ],
          const SizedBox(width: AnSpace.s8),
          AnStatusDot(AnStatus.fromRaw(n.status)),
        ]),
        if (failed && (n.error ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: AnSize.iconSm + AnSpace.s8, top: AnSpace.s2),
            child: Text(n.error!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AnText.code.copyWith(color: c.danger)),
          ),
      ]),
    );
  }
}

// ── get_flowrun (B5.9): the run cockpit read (run header + FlowrunNodeList + provenance) ──
// Same {flowrun, nodes, nodeSummary?} shape as replay; nodes are record-once (createdAt≈completedAt →
// no real duration bars) so FlowrunNodeList (event-point ledger) IS the honest visualization — no
// separate time-axis waterfall. get_flowrun 运行解剖:头条 + 节点台账 + 出处。

/// The get_flowrun receipt — `{status} · {shown}/{total} 节点`; failed/no-parked-running → danger
/// auto-expand (you opened a run to inspect a problem). running → grey (a live snapshot). get_flowrun 回执。
ToolReceipt? getFlowrunReceipt(Translations t, String output) {
  final comp = decodeFlowrunResult(output);
  if (comp == null) return null;
  final total = flowrunTotalNodes(comp);
  final shown = comp.nodeSummary?.shownNodes ?? comp.nodes.length;
  final nodes = total == shown ? t.chat.tool.nodeCount(n: '$total') : '$shown/$total';
  final status = comp.flowrun.status;
  final word = switch (status) {
    'completed' => t.chat.tool.runCompleted,
    'failed' => t.chat.tool.runStillFailed,
    'cancelled' => t.chat.tool.runCancelled,
    'running' => flowrunHasParked(comp) ? t.chat.tool.runAwaitApproval : t.chat.tool.runStatusRunning,
    _ => status,
  };
  final danger = status == 'failed';
  return (text: '$word · $nodes', tone: danger ? ToolReceiptTone.danger : ToolReceiptTone.none);
}

bool getFlowrunFailed(String output) => decodeFlowrunResult(output)?.flowrun.status == 'failed';

/// get_flowrun body — a run header (status badge · workflow pill · replay× · run-level error) + the node
/// ledger + a provenance line (triggerId / firingId). get_flowrun 落定体。
Widget getFlowrunBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final comp = decodeFlowrunResult(state.resultText);
  if (comp == null) {
    return Text(state.resultText, style: AnText.code.copyWith(color: c.inkMuted), maxLines: 40, overflow: TextOverflow.ellipsis);
  }
  final run = comp.flowrun;
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    _runFooter(context, run),
    if (run.error != null && run.error!.isNotEmpty) ...[
      const SizedBox(height: AnSpace.s6),
      AnWindow(child: Text(run.error!, style: AnText.code.copyWith(color: c.danger), maxLines: 12, overflow: TextOverflow.ellipsis)),
    ],
    const SizedBox(height: AnSpace.s6),
    FlowrunNodeList(nodes: comp.nodes, summary: comp.nodeSummary),
    const SizedBox(height: AnSpace.s6),
    ProvenanceLine(triggerId: run.triggerId, firingId: run.firingId),
  ]);
}
