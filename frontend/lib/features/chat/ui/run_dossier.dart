import 'package:flutter/material.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/model/time_format.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_receipts.dart';
import 'tool_card_io_section.dart';
import 'log_drawer.dart';
import 'tool_card_nav.dart';

// F09 get-record furniture (B5.8) — the RunDossier (one execution's full record: status head → input/
// output windows → a double-ended-capped log drawer → a provenance line) + the ProvenanceLine (where
// this run came from: navigable conversation/trigger, mono-only message/firing/node). F09 卷宗。

/// The record status → elapsed receipt: `{status} · {elapsed}`; failed/timeout → danger (auto-expand —
/// you opened a failed record to triage). null when unparseable. 卷宗回执:状态·耗时,失败/超时红。
ToolReceipt? statusElapsedReceipt(Translations t, String? status, int? elapsedMs) {
  if (status == null || status.isEmpty) return null;
  final word = switch (status) {
    'ok' => t.chat.tool.runCompleted,
    'failed' => t.chat.tool.failed,
    'timeout' => t.chat.tool.agentTimeout,
    'cancelled' => t.chat.tool.runCancelled,
    _ => status,
  };
  final elapsed = elapsedMs != null ? fmtElapsed(elapsedMs) : null;
  final txt = elapsed == null ? word : '$word · $elapsed';
  final danger = status == 'failed' || status == 'timeout';
  return (text: txt, tone: danger ? ToolReceiptTone.danger : ToolReceiptTone.none);
}

/// The RunDossier — one execution's full audit record. The head badge + provenance-triggeredBy + timing;
/// the input/output machine windows (a failed record swaps output for the errorMessage); the log drawer
/// (double-ended cap, an MCP stderr tail split into its own danger-colored segment); the provenance line.
/// RunDossier:一次执行的完整审计卷宗。
class RunDossier extends StatelessWidget {
  const RunDossier({
    required this.status,
    this.triggeredBy,
    this.elapsedMs,
    this.startedAt,
    this.endedAt,
    this.headChips = const [],
    required this.input,
    this.output,
    this.errorMessage,
    this.logs,
    this.extra,
    this.provenance,
    super.key,
  });

  final String status;
  final String? triggeredBy;
  final int? elapsedMs;
  final String? startedAt;
  final String? endedAt;
  final List<Widget> headChips;
  final Object? input;
  final Object? output;
  final String? errorMessage;
  final String? logs;

  /// An extra section between the log drawer and the provenance line (get_agent_execution's
  /// TranscriptPeek). 日志抽屉与出处行之间的额外段(agent 执行的轨迹目录)。
  final Widget? extra;
  final Widget? provenance;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final ok = status == 'ok';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      // Head: status badge · head chips (method/tool) · triggeredBy. 头条(词章行)。
      Wrap(spacing: AnGap.inline, runSpacing: AnSpace.s4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        AnChip(_statusWord(t), tone: AnStatus.fromRaw(status).tone),
        ...headChips,
        if (triggeredBy != null && triggeredBy!.isNotEmpty) Text(triggeredBy!, style: AnText.meta.copyWith(color: c.inkFaint)),
      ]),
      // The started→ended span on its own full-width line (a long stamp pair overflows a narrow head
      // Wrap; a wrapping Text handles it). 时间跨度独占一行(长时戳对在窄头会溢出,独行可折)。
      if (startedAt != null)
        Padding(padding: const EdgeInsets.only(top: AnSpace.s2), child: Text(_span(), style: AnText.metaTabular().copyWith(color: c.inkFaint))),
      const SizedBox(height: AnSpace.s6),
      if (input != null) ToolIOSection(label: t.chat.tool.ioInput, value: input),
      const SizedBox(height: AnSpace.s6),
      if (!ok && errorMessage != null && errorMessage!.isNotEmpty)
        AnWindow(child: Text(errorMessage!, style: AnText.code.copyWith(color: c.danger), maxLines: 30, overflow: TextOverflow.ellipsis))
      else
        ToolIOSection(label: t.chat.tool.ioOutput, value: output),
      if (logs != null && logs!.trim().isNotEmpty) ...[
        const SizedBox(height: AnSpace.s6),
        LogDrawer(logs: logs!, splitStderr: true),
      ],
      if (extra != null) ...[
        const SizedBox(height: AnSpace.s6),
        extra!,
      ],
      if (provenance != null) ...[
        const SizedBox(height: AnSpace.s6),
        provenance!,
      ],
    ]);
  }

  String _statusWord(Translations t) => switch (status) {
        'ok' => t.chat.tool.runCompleted,
        'failed' => t.chat.tool.failed,
        'timeout' => t.chat.tool.agentTimeout,
        'cancelled' => t.chat.tool.runCancelled,
        _ => status,
      };

  String _span() {
    final s = fmtStamp(startedAt);
    final e = endedAt != null ? fmtStamp(endedAt) : '';
    return e.isEmpty ? s : '$s → $e';
  }
}

/// A run's provenance line — WHERE it came from. Navigable coordinates (conversation → /chat, trigger →
/// its panel) are ref pills; non-panel coordinates (message / firing / node#iteration) are mono
/// copy-badges (they have no deep-link target, NEVER a dead pill). ProvenanceLine 出处行。
class ProvenanceLine extends StatelessWidget {
  const ProvenanceLine({
    this.conversationId,
    this.messageId,
    this.flowrunId,
    this.triggerId,
    this.firingId,
    this.nodeId,
    this.iteration,
    super.key,
  });

  final String? conversationId;
  final String? messageId;
  final String? flowrunId;
  final String? triggerId;
  final String? firingId;
  final String? nodeId;
  final int? iteration;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final items = <Widget>[
      if (conversationId != null && conversationId!.isNotEmpty)
        toolNavPill(context, kind: 'conversation', label: '${t.chat.tool.provConversation} ${truncate(conversationId!, AnTrunc.id)}', id: conversationId),
      if (triggerId != null && triggerId!.isNotEmpty)
        toolNavPill(context, kind: 'trigger', label: '${t.chat.tool.provTrigger} ${truncate(triggerId!, AnTrunc.id)}', id: triggerId),
      // Non-navigable coordinates become COPY chips (批5 A-047 关联 A-037 — the bare grey text
      // lied about being «mono copy-badges»; flowrun has no panel entry, cockpit needs workflowId).
      // 非导航坐标改真复制芯片(旧裸灰字谎称 mono copy-badges);截断走族档、copy 保全量。
      if (flowrunId != null && flowrunId!.isNotEmpty)
        AnChip('${t.chat.tool.provFlowrun} ${truncate(flowrunId!, AnTrunc.id)}',
            look: AnChipLook.outlined, mono: true, copyValue: flowrunId!),
      if (messageId != null && messageId!.isNotEmpty)
        AnChip('${t.chat.tool.provMessage} ${truncate(messageId!, AnTrunc.id)}',
            look: AnChipLook.outlined, mono: true, copyValue: messageId!),
      if (firingId != null && firingId!.isNotEmpty)
        AnChip('${t.chat.tool.provFiring} ${truncate(firingId!, AnTrunc.id)}',
            look: AnChipLook.outlined, mono: true, copyValue: firingId!),
      if (nodeId != null && nodeId!.isNotEmpty)
        AnChip('${t.chat.tool.provNode} $nodeId${(iteration ?? 0) > 0 ? '#$iteration' : ''}',
            look: AnChipLook.outlined, mono: true, copyValue: nodeId!),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: AnGap.inline, runSpacing: AnSpace.s4, crossAxisAlignment: WrapCrossAlignment.center, children: items);
  }
}
