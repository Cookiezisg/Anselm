import 'package:flutter/material.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/model/time_format.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_receipts.dart';
import 'tool_card_io_section.dart';
import 'tool_card_nav.dart';
import 'tool_card_skins.dart';

// F09 get-record furniture (B5.8) — the RunDossier (one execution's full record: status head → input/
// output windows → a double-ended-capped log drawer → a provenance line) + the ProvenanceLine (where
// this run came from: navigable conversation/trigger, mono-only message/firing/node). F09 卷宗。

const int _logCap = 6000;
const int _logHead = 2000;
const int _logTail = 4000;
const String mcpStderrSeparator = '--- server stderr tail (server-level, may predate this call) ---';

/// Cap a log to head+tail with a middle elision (the tail — last yields / stderr / dying output — is the
/// most diagnostic, so NEVER head-truncate). Returns (head, omittedChars, tail); omitted=0 when it fits.
/// 日志双端保留:头+尾+中缝省略(尾最诊断,绝不头截)。
({String head, int omitted, String tail}) capLog(String log) {
  if (log.length <= _logCap) return (head: log, omitted: 0, tail: '');
  return (head: log.substring(0, _logHead), omitted: log.length - _logHead - _logTail, tail: log.substring(log.length - _logTail));
}

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
        AnBadge(_statusWord(t), tone: AnStatus.fromRaw(status).tone),
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
        ToolWindow(child: Text(errorMessage!, style: AnText.code.copyWith(color: c.danger), maxLines: 30, overflow: TextOverflow.ellipsis))
      else
        ToolIOSection(label: t.chat.tool.ioOutput, value: output),
      if (logs != null && logs!.trim().isNotEmpty) ...[
        const SizedBox(height: AnSpace.s6),
        _LogDrawer(logs: logs!),
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

/// A «日志» disclosure over a double-ended-capped mono window; an MCP stderr tail (split on the fixed
/// separator) becomes its own danger-colored segment carrying the backend's own caveat. 日志抽屉:双端保留 + stderr 分段。
class _LogDrawer extends StatefulWidget {
  const _LogDrawer({required this.logs});
  final String logs;
  @override
  State<_LogDrawer> createState() => _LogDrawerState();
}

class _LogDrawerState extends State<_LogDrawer> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    // Split off an MCP stderr tail (server-level; the caveat matters — it may predate this call).
    // 切出 MCP stderr 尾(server 级;段头告诫要保留:可能早于本次调用)。
    final sepIdx = widget.logs.indexOf(mcpStderrSeparator);
    final main = sepIdx >= 0 ? widget.logs.substring(0, sepIdx) : widget.logs;
    final stderr = sepIdx >= 0 ? widget.logs.substring(sepIdx + mcpStderrSeparator.length).trimLeft() : null;
    final capped = capLog(main);
    return AnDisclosure(
      label: t.chat.tool.dossierLogs,
      open: _open,
      onToggle: () => setState(() => _open = !_open),
      child: _open
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              ToolWindow(
                actions: [WindowCopyButton(copyPayload: widget.logs)],
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(capped.head, style: AnText.code.copyWith(color: c.inkMuted)),
                  if (capped.omitted > 0) ...[
                    Text(t.chat.tool.logOmitted(n: '${capped.omitted}'), style: AnText.meta.copyWith(color: c.inkFaint)),
                    Text(capped.tail, style: AnText.code.copyWith(color: c.inkMuted)),
                  ],
                ]),
              ),
              if (stderr != null && stderr.isNotEmpty) ...[
                const SizedBox(height: AnSpace.s4),
                Text(t.chat.tool.dossierStderr, style: AnText.meta.copyWith(color: c.danger)),
                const SizedBox(height: AnSpace.s2),
                ToolWindow(child: Text(stderr.length > 8192 ? stderr.substring(stderr.length - 8192) : stderr,
                    style: AnText.code.copyWith(color: c.danger), maxLines: 60, overflow: TextOverflow.ellipsis)),
              ],
            ])
          : null,
    );
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
    final c = context.colors;
    final items = <Widget>[
      if (conversationId != null && conversationId!.isNotEmpty)
        toolNavPill(context, kind: 'conversation', label: '${t.chat.tool.provConversation} ${_short(conversationId!)}', id: conversationId),
      if (triggerId != null && triggerId!.isNotEmpty)
        toolNavPill(context, kind: 'trigger', label: '${t.chat.tool.provTrigger} ${_short(triggerId!)}', id: triggerId),
      // flowrun has no panel registry entry (cockpit needs workflowId) → a mono badge for now. flowrun 无面板→mono。
      if (flowrunId != null && flowrunId!.isNotEmpty) _mono(c, '${t.chat.tool.provFlowrun} ${_short(flowrunId!)}'),
      if (messageId != null && messageId!.isNotEmpty) _mono(c, '${t.chat.tool.provMessage} ${_short(messageId!)}'),
      if (firingId != null && firingId!.isNotEmpty) _mono(c, '${t.chat.tool.provFiring} ${_short(firingId!)}'),
      if (nodeId != null && nodeId!.isNotEmpty) _mono(c, '${t.chat.tool.provNode} $nodeId${(iteration ?? 0) > 0 ? '#$iteration' : ''}'),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: AnGap.inline, runSpacing: AnSpace.s4, crossAxisAlignment: WrapCrossAlignment.center, children: items);
  }

  Widget _mono(AnColors c, String s) => Text(s, style: AnText.meta.copyWith(color: c.inkFaint));
  String _short(String id) => id.length > 12 ? '${id.substring(0, 12)}…' : id;
}
