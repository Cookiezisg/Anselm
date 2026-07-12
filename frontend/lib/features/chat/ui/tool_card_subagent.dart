import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/messages/transcript_hydration.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import 'run_ledger.dart';
import 'tool_card_document_skill.dart';
import 'tool_card_skins.dart';
import 'transcript_peek.dart';

// F15 nested conversation (B6) — the Subagent card + get_subagent_trace. A Subagent runs an isolated
// sub-task and returns its final answer (a string); its E3 nested trajectory streams under the card
// LIVE (never persisted) → the live pane shows it, the settled card falls back to a get_subagent_trace
// pointer. get_subagent_trace reads that durable record back (list of runs / one run's blocks).
// F15 嵌套对话:Subagent 卡 + 轨迹回放。

Map<String, dynamic>? _obj(String s) {
  try {
    final d = jsonDecode(s);
    if (d is Map<String, dynamic>) return d;
  } catch (_) {}
  return null;
}

// ── Subagent (spawn a focused sub-task) ──

/// Subagent body — the task (prompt, in-flight readable) → the nested trajectory (LIVE: streaming
/// with the shimmer tail; SETTLED in-tree: the full pane; reloaded: the get_subagent_trace replay
/// note — settled only, mid-run it would misread as «already archived», WRK-065) → the final answer
/// (prose; the whole tool_result IS the answer string). Subagent 体:任务 + 轨迹(活=流式;重载注仅落定)
/// + 回答。
Widget subagentBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final live = toolLive(state);
  final prompt = argStringPartial(state.argsText, 'prompt');
  final answer = state.resultText;
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    if (prompt != null && prompt.isNotEmpty) ...[
      Text(t.chat.tool.subagentTask, style: AnText.meta.copyWith(color: c.inkFaint)),
      const SizedBox(height: AnSpace.s2),
      Text(prompt, style: AnText.code.copyWith(color: c.inkMuted), maxLines: 6, overflow: TextOverflow.ellipsis),
      const SizedBox(height: AnSpace.s6),
    ],
    if (state.nested.isNotEmpty)
      NestedRunPane(nested: state.nested, live: live)
    else if (!live)
      Text(t.chat.tool.subagentTraceNote, style: AnText.meta.copyWith(color: c.inkFaint)),
    if (answer.isNotEmpty) ...[
      const SizedBox(height: AnSpace.s6),
      Text(t.chat.tool.subagentAnswer, style: AnText.meta.copyWith(color: c.inkFaint)),
      const SizedBox(height: AnSpace.s2),
      ProseWindow(markdown: answer),
    ],
  ]);
}

// ── get_subagent_trace (read a subagent run back) ──

/// The trace receipt — with a run: `{status}·{n} 块`; the list form: `{n} 个子代理运行`. 轨迹回执。
ToolReceipt? subTraceReceipt(Translations t, String output) {
  final o = _obj(output);
  if (o == null) return null;
  if (o.containsKey('subagentRuns')) {
    final n = o['count'] is int ? o['count'] as int : (o['subagentRuns'] as List?)?.length ?? 0;
    return (text: t.chat.tool.subTraceRuns(n: '$n'), tone: ToolReceiptTone.none);
  }
  if (o.containsKey('blocks')) {
    final n = (o['blocks'] as List?)?.length ?? 0;
    return (text: t.chat.tool.transcriptSteps(n: '$n'), tone: ToolReceiptTone.none);
  }
  return null;
}

/// get_subagent_trace body — the list form (a run ledger of this conversation's subagent runs) or the
/// detail form (one run's blocks hydrated through the SHARED adapter → TranscriptPeek). get_subagent_trace 体。
Widget getSubTraceBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final o = _obj(state.resultText);
  if (o == null) {
    return Text(state.resultText, style: AnText.code.copyWith(color: c.inkMuted), maxLines: 20, overflow: TextOverflow.ellipsis);
  }
  // Detail form: {subagentRunId, spawningToolCallId, blocks:[blockView]}. 详情形态。
  if (o.containsKey('blocks')) {
    final blocks = o['blocks'] as List? ?? const [];
    final roots = hydrateTranscriptTree(blocks);
    final failed = roots.any((n) => n.isError);
    return TranscriptPeek(roots: roots, totalBlocks: blocks.length, failed: failed);
  }
  // List form: {count, subagentRuns:[{subagentRunId, status, finalText?, blockCount, ...}]}. 列表形态。
  final runs = (o['subagentRuns'] as List?)?.whereType<Map>().toList() ?? const [];
  if (runs.isEmpty) return Text(t.chat.tool.subTraceNoRuns, style: AnText.meta.copyWith(color: c.inkFaint));
  return AnWindow(
    child: RunLedger(rows: [
      for (final r in runs)
        RunLedgerRow(
          leading: RunLeading.status('${r['status']}'),
          monoId: r['subagentRunId'] as String?,
          subText: r['finalText'] as String?,
          chips: [
            if ((r['blockCount'] is int ? r['blockCount'] as int : 0) > 0)
              AnBadge(t.chat.tool.transcriptSteps(n: '${r['blockCount']}'), tone: AnTone.none),
          ],
        ),
    ]),
  );
}
