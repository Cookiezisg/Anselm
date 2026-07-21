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
import '../../../core/run/provenance_line.dart';

// F09 get-record furniture (B5.8) — the RunDossier (one execution's full record: status head → input/
// output windows → a double-ended-capped log drawer → a provenance line) + the ProvenanceLine (where
// this run came from: navigable conversation/trigger, mono-only message/firing/node). F09 卷宗。

// runStatusWord + ProvenanceLine upstreamed to core/run/provenance_line.dart (WRK-069 S0 — the words
// moved to the core-visible run.* namespace, unblocking core residence). 状态词与出处行已上收 core/run。

/// The record status → elapsed receipt: `{status} · {elapsed}`; failed/timeout → danger (auto-expand —
/// you opened a failed record to triage). null when unparseable. 卷宗回执:状态·耗时,失败/超时红。
ToolReceipt? statusElapsedReceipt(
  Translations t,
  String? status,
  int? elapsedMs,
) {
  if (status == null || status.isEmpty) return null;
  final word = runStatusWord(t, status);
  final elapsed = elapsedMs != null ? fmtElapsed(elapsedMs) : null;
  final txt = elapsed == null ? word : '$word · $elapsed';
  final danger = status == 'failed' || status == 'timeout';
  return (
    text: txt,
    tone: danger ? ToolReceiptTone.danger : ToolReceiptTone.none,
  );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Head: status badge · head chips (method/tool) · triggeredBy. 头条(词章行)。
        Wrap(
          spacing: AnGap.inline,
          runSpacing: AnGap.stackTight,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AnChip(
              runStatusWord(t, status),
              tone: AnStatus.fromRaw(status).tone,
            ),
            ...headChips,
            if (triggeredBy != null && triggeredBy!.isNotEmpty)
              Text(
                triggeredBy!,
                style: AnText.meta.copyWith(color: c.inkFaint),
              ),
          ],
        ),
        // The started→ended span on its own full-width line (a long stamp pair overflows a narrow head
        // Wrap; a wrapping Text handles it). 时间跨度独占一行(长时戳对在窄头会溢出,独行可折)。
        if (startedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s2),
            child: Text(
              _span(),
              style: AnText.metaTabular().copyWith(color: c.inkFaint),
            ),
          ),
        const SizedBox(height: AnSpace.s6),
        if (input != null) ToolIOSection(label: t.run.ioInput, value: input),
        const SizedBox(height: AnSpace.s6),
        if (!ok && errorMessage != null && errorMessage!.isNotEmpty)
          AnWindow(
            child: Text(
              errorMessage!,
              style: AnText.code.copyWith(color: c.danger),
              maxLines: 30,
              overflow: TextOverflow.ellipsis,
            ),
          )
        else
          ToolIOSection(label: t.run.ioOutput, value: output),
        if (logs != null && logs!.trim().isNotEmpty) ...[
          const SizedBox(height: AnSpace.s6),
          LogDrawer(logs: logs!, splitStderr: true),
        ],
        if (extra != null) ...[const SizedBox(height: AnSpace.s6), extra!],
        if (provenance != null) ...[
          const SizedBox(height: AnSpace.s6),
          provenance!,
        ],
      ],
    );
  }

  String _span() {
    final s = fmtStamp(startedAt);
    final e = endedAt != null ? fmtStamp(endedAt) : '';
    return e.isEmpty ? s : '$s → $e';
  }
}
