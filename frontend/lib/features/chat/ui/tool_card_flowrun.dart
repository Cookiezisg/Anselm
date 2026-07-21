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
import 'tool_card_skins.dart';
import '../../../core/run/flowrun_node_list.dart';
import '../../../core/run/provenance_line.dart';
import '../../../core/run/run_nav.dart';

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
  return (text: truncate(fr, AnTrunc.id), tone: ToolReceiptTone.none);
}

/// trigger_workflow body — the payload input (empty → grey note) + a launch credential (navigable
/// workflow pill + flowrunId copy) + a get_flowrun pointer. trigger 落定体:输入 + 启动凭据 + 指路。
Widget triggerWorkflowBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final out = _obj(state.resultText);
  final flowrunId = out?['flowrunId'] as String?;
  final workflowId =
      (out?['workflowId'] as String?) ??
      argString(state.argsText, 'workflowId');
  final payload = _obj(state.argsText)?['payload'];
  final emptyPayload = payload == null || (payload is Map && payload.isEmpty);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      toolIntent(context, state),
      // The payload fed to the entry trigger — an empty {} is stated, never dressed as an empty tree.
      // 喂给入口触发器的 payload;空 {} 明说、不装空树。
      if (emptyPayload)
        Text(t.run.emptyPayload, style: AnText.code.copyWith(color: c.inkFaint))
      else
        ToolIOSection(label: t.run.ioInput, value: payload),
      const SizedBox(height: AnSpace.s6),
      Wrap(
        spacing: AnGap.inline,
        runSpacing: AnGap.stackTight,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (workflowId != null && workflowId.isNotEmpty)
            toolNavPill(
              context,
              kind: 'workflow',
              label: workflowId,
              id: workflowId,
            ),
          if (flowrunId != null && flowrunId.isNotEmpty)
            AnChip(
              flowrunId,
              look: AnChipLook.outlined,
              mono: true,
              copyValue: flowrunId,
              tooltip: flowrunId,
            ),
        ],
      ),
      const SizedBox(height: AnSpace.s6),
      Text(
        t.run.triggerStartedNote,
        style: AnText.meta.copyWith(color: c.inkFaint),
      ),
    ],
  );
}

/// Decode a {flowrun, nodes, nodeSummary?} tool result, or null if unparseable. 解码 flowrun 复合结果。
FlowrunComposite? decodeFlowrunResult(String output) {
  try {
    final d = jsonDecode(output);
    if (d is Map<String, dynamic> && d['flowrun'] is Map) {
      return FlowrunComposite.fromJson(d);
    }
  } catch (_) {}
  return null;
}

/// The node count a run really has — nodeSummary.totalNodes when capped, else nodes.length. Never
/// nodes.length blindly (it's 80 on a capped run). 真节点数:截断取 summary、否则 nodes 长度。
int flowrunTotalNodes(FlowrunComposite comp) =>
    comp.nodeSummary?.totalNodes ?? comp.nodes.length;

/// Whether any node parked (an approval waiting) — the run header stays `running` while a node parks,
/// so «awaiting approval» is read off the NODES, not the run status. 有节点 park=等待审批(run 头仍 running)。
bool flowrunHasParked(FlowrunComposite comp) =>
    comp.nodes.any((n) => n.status == 'parked');

/// The replay receipt — completed→`完成·N 节点`; failed→red `仍失败`+auto-expand; cancelled→`已取消`;
/// running with a parked node→`等待审批` (grey text, amber lives in the body); running w/o park→none.
/// FlowRun.status has NO `parked` (park is a node state). replay 回执:四态,run 头无 parked 分支。
ToolReceipt? replayReceipt(Translations t, String output) {
  final comp = decodeFlowrunResult(output);
  if (comp == null) return null;
  final n = flowrunTotalNodes(comp);
  final nodes = t.run.nodeCount(n: '$n');
  switch (comp.flowrun.status) {
    case 'completed':
      return (
        text: '${t.run.runCompleted} · $nodes',
        tone: ToolReceiptTone.none,
      );
    case 'failed':
      return (text: t.run.runStillFailed, tone: ToolReceiptTone.danger);
    case 'cancelled':
      return (text: t.run.runCancelled, tone: ToolReceiptTone.none);
    case 'running':
      // A parked node → «awaiting approval» (grey — it's not a failure). 有 park→等待审批(灰,非失败)。
      return flowrunHasParked(comp)
          ? (text: t.run.runAwaitApproval, tone: ToolReceiptTone.none)
          : null;
    default:
      return null;
  }
}

/// Whether the replayed run is still failed (auto-expand for diagnosis). 仍失败→自动展开诊断。
bool replayResultFailed(String output) =>
    decodeFlowrunResult(output)?.flowrun.status == 'failed';

/// replay_flowrun body — a pinned-versions caution + the node ledger (FlowrunNodeList) + a footer
/// (status word · 第 N 次重放 · workflow pill · flowrunId copy). replay 落定体。
Widget replayFlowrunBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final comp = decodeFlowrunResult(state.resultText);
  if (comp == null) {
    return Text(
      state.resultText,
      style: AnText.code.copyWith(color: c.inkMuted),
      maxLines: 40,
      overflow: TextOverflow.ellipsis,
    );
  }
  final run = comp.flowrun;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      // The replay honesty note — the fix you made after the failure did NOT take effect (pinned versions).
      // 重放诚实注:事后改的代码这次没生效(用原 pin 版本)。
      Text(t.run.replayPinNote, style: AnText.meta.copyWith(color: c.inkFaint)),
      const SizedBox(height: AnSpace.s6),
      if (run.error != null && run.error!.isNotEmpty) ...[
        rawMonoWindow(
          context,
          run.error!,
          maxLines: AnCap.monoErrorLines,
          color: c.danger,
        ),
        const SizedBox(height: AnSpace.s6),
      ],
      FlowrunNodeList(nodes: comp.nodes, summary: comp.nodeSummary),
      // No SizedBox — the family bar brings its own top s6 (批3: a kept one doubles the gap). 条自带前距。
      _runFooter(context, run, hasParked: flowrunHasParked(comp)),
    ],
  );
}

/// The flowrun status → its domain word, the ONE in-file map (B-074 — the footer and the get_flowrun
/// receipt carried it twice; the deliberate DOMAIN deviation from runStatusWord stays: failed=仍失败,
/// running splits on the parked gate). flowrun 域词唯一映射(域词偏离是刻意:仍失败;running 按停车分)。
String _flowrunStatusWord(
  Translations t,
  String status, {
  required bool hasParked,
}) => switch (status) {
  'completed' => t.run.runCompleted,
  'failed' => t.run.runStillFailed,
  'cancelled' => t.run.runCancelled,
  'running' => hasParked ? t.run.runAwaitApproval : t.run.runStatusRunning,
  _ => status,
};

/// The run footer (批3 条族: a mapping onto the family head) — status badge (AnStatus.fromRaw 单源;
/// domain words via [_flowrunStatusWord]) + replay count + a navigable workflow pill + the
/// flowrunId (copy). run 页脚:状态词徽(fromRaw 单源+域词)+重放数+workflow 药丸+flowrunId 复制。
Widget _runFooter(
  BuildContext context,
  Flowrun run, {
  required bool hasParked,
}) {
  final t = Translations.of(context);
  return AnStatBar(
    status: AnStatus.fromRaw(run.status),
    statusLabel: _flowrunStatusWord(t, run.status, hasParked: hasParked),
    stats: [
      if (run.replayCount > 0)
        AnStat(t.run.replayTimes(n: '${run.replayCount}'), tabular: true),
    ],
    chips: [
      if (run.workflowId.isNotEmpty)
        toolNavPill(
          context,
          kind: 'workflow',
          label: run.workflowId,
          id: run.workflowId,
        ),
      AnChip(
        run.id,
        look: AnChipLook.outlined,
        mono: true,
        copyValue: run.id,
        tooltip: run.id,
      ),
    ],
  );
}

// FlowrunNodeList (WRK-056 #38) upstreamed to core/run/flowrun_node_list.dart (WRK-069 S0) — the
// Scheduler's run flagship and these cards render the SAME ledger. FlowrunNodeList 已上收 core/run。

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
  final nodes = total == shown ? t.run.nodeCount(n: '$total') : '$shown/$total';
  final status = comp.flowrun.status;
  final word = _flowrunStatusWord(t, status, hasParked: flowrunHasParked(comp));
  final danger = status == 'failed';
  return (
    text: '$word · $nodes',
    tone: danger ? ToolReceiptTone.danger : ToolReceiptTone.none,
  );
}

bool getFlowrunFailed(String output) =>
    decodeFlowrunResult(output)?.flowrun.status == 'failed';

/// get_flowrun body — a run header (status badge · workflow pill · replay× · run-level error) + the node
/// ledger + a provenance line (triggerId / firingId). get_flowrun 落定体。
Widget getFlowrunBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final comp = decodeFlowrunResult(state.resultText);
  if (comp == null) {
    return Text(
      state.resultText,
      style: AnText.code.copyWith(color: c.inkMuted),
      maxLines: 40,
      overflow: TextOverflow.ellipsis,
    );
  }
  final run = comp.flowrun;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      _runFooter(context, run, hasParked: flowrunHasParked(comp)),
      if (run.error != null && run.error!.isNotEmpty) ...[
        const SizedBox(height: AnSpace.s6),
        rawMonoWindow(
          context,
          run.error!,
          maxLines: AnCap.monoErrorLines,
          color: c.danger,
        ),
      ],
      const SizedBox(height: AnSpace.s6),
      FlowrunNodeList(nodes: comp.nodes, summary: comp.nodeSummary),
      const SizedBox(height: AnSpace.s6),
      ProvenanceLine(triggerId: run.triggerId, firingId: run.firingId),
    ],
  );
}
