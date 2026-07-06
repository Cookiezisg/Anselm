import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/model/time_format.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import 'run_ledger.dart';
import 'tool_card_io_section.dart';
import 'tool_card_skins.dart';

// F09 run-log search cards (B5.6) — the aggregate families (function executions / handler calls / agent
// runs / MCP calls). All share {list:[...], nextCursor?, hasMore, aggregates:{okCount, failedCount}}.
// The body is a RunBeadStrip (page health) + a RunLedger (slim rows). RIGID SLIM PROJECTION: a search
// page carries full input/output/logs (agent even transcript) per row in memory — the UI renders NONE
// of it (id/status/timing/method only), and drops the parse immediately. F09 检索卡:slim 投影铁律。

Map<String, dynamic>? _obj(String s) {
  try {
    final d = jsonDecode(s);
    if (d is Map<String, dynamic>) return d;
  } catch (_) {}
  return null;
}

List<Map<String, dynamic>> _list(String s, String key) {
  final l = _obj(s)?[key];
  return l is List ? l.whereType<Map<String, dynamic>>().toList() : const [];
}

/// A localized triggeredBy word (chat|agent|workflow|manual → 对话|智能体|工作流|手动). 触发来源词。
String _triggeredBy(Translations t, String? by) => switch (by) {
      'chat' => t.chat.tool.byChat,
      'agent' => t.chat.tool.byAgent,
      'workflow' => t.chat.tool.byWorkflow,
      'manual' => t.chat.tool.byManual,
      _ => by ?? '',
    };

/// The aggregates rollup receipt: `{ok} ✓ · {failed} ✗` (ALWAYS grey — a historical failed record is not
/// THIS call failing). aggregates ignore the status filter (they always report the full match set), and
/// failedCount = every non-ok (incl. cancelled/timeout) — the body's note spells that out. 聚合回执恒灰。
ToolReceipt? aggregatesReceipt(Translations t, String output) {
  final agg = _obj(output)?['aggregates'];
  if (agg is! Map) return null;
  final ok = agg['okCount'] is int ? agg['okCount'] as int : 0;
  final failed = agg['failedCount'] is int ? agg['failedCount'] as int : 0;
  if (ok == 0 && failed == 0) return (text: t.chat.tool.logNoRecords, tone: ToolReceiptTone.none);
  return (text: t.chat.tool.aggRollup(ok: '$ok', failed: '$failed'), tone: ToolReceiptTone.none);
}

/// Whether an aggregate search has any record at all (empty → the receipt IS the card, no body). 有无记录。
bool aggregatesHasBody(String output) {
  final agg = _obj(output)?['aggregates'];
  if (agg is! Map) return _obj(output) != null; // unparseable aggregates → let the generic body show
  final ok = agg['okCount'] is int ? agg['okCount'] as int : 0;
  final failed = agg['failedCount'] is int ? agg['failedCount'] as int : 0;
  return ok + failed > 0;
}

// ── row mappers (one per family; SLIM only) ──

RunBead _bead(AnColors c, Map<String, dynamic> row) =>
    RunBead(color: runStatusColor(c, '${row['status']}'), tooltip: '${row['id']} · ${row['status']}');

RunLedgerRow _execRow(Translations t, Map<String, dynamic> row, {List<Widget> extraChips = const []}) => RunLedgerRow(
      leading: RunLeading.status('${row['status']}'),
      monoId: row['id'] as String?,
      chips: [
        ...extraChips,
        if ((row['triggeredBy'] as String?)?.isNotEmpty ?? false) AnBadge(_triggeredBy(t, row['triggeredBy'] as String?), tone: AnTone.none),
      ],
      elapsed: row['elapsedMs'] is int ? fmtElapsed(row['elapsedMs'] as int) : null,
      stamp: fmtStamp(row['startedAt'] as String?),
    );

/// The shared aggregate-search body — a page-health bead strip + a slim RunLedger, wrapped in the
/// machine window. Empty (with a filter) keeps the body + a «无匹配 · 全史 N✓M✗» honest echo; empty with
/// no records is handled by [aggregatesHasBody] (no body at all). 检索族共享体。
Widget _aggBody(BuildContext context, String output, String listKey, List<RunLedgerRow> Function(Translations, AnColors, List<Map<String, dynamic>>) mapRows) {
  final c = context.colors;
  final t = Translations.of(context);
  final rows = _list(output, listKey);
  final agg = _obj(output)?['aggregates'];
  final ok = (agg is Map && agg['okCount'] is int) ? agg['okCount'] as int : 0;
  final failed = (agg is Map && agg['failedCount'] is int) ? agg['failedCount'] as int : 0;
  final hasMore = _obj(output)?['hasMore'] == true;

  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    // The aggregates note — failedCount counts EVERY non-ok (cancelled/timeout too), and ignores any
    // status filter (always the full match set). 聚合注:✗ 含取消/超时、无视过滤。
    Padding(
      padding: const EdgeInsets.only(bottom: AnSpace.s6),
      child: Text('${t.chat.tool.aggRollup(ok: '$ok', failed: '$failed')} · ${t.chat.tool.aggNote}',
          style: AnText.meta.copyWith(color: c.inkFaint)),
    ),
    if (rows.isEmpty)
      Text(t.chat.tool.logNoMatch, style: AnText.code.copyWith(color: c.inkFaint))
    else ...[
      RunBeadStrip(beads: [for (final r in rows) _bead(c, r)]),
      const SizedBox(height: AnSpace.s6),
      ToolWindow(child: RunLedger(rows: mapRows(t, c, rows))),
      if (hasMore)
        Padding(padding: const EdgeInsets.only(top: AnSpace.s4), child: Text('${rows.length}+', style: AnText.meta.copyWith(color: c.inkFaint))),
    ],
  ]);
}

// function executions — {executions:[{id, status, triggeredBy, elapsedMs, startedAt, ...}]}. slim.
Widget fnExecBody(BuildContext context, ToolCardState s) =>
    _aggBody(context, s.resultText, 'executions', (t, c, rows) => [for (final r in rows) _execRow(t, r)]);

// handler calls — + a method() chip + an optional instanceId subtext.
Widget hdCallsBody(BuildContext context, ToolCardState s) => _aggBody(context, s.resultText, 'calls', (t, c, rows) => [
      for (final r in rows)
        RunLedgerRow(
          leading: RunLeading.status('${r['status']}'),
          monoId: r['id'] as String?,
          chips: [
            if ((r['method'] as String?)?.isNotEmpty ?? false) AnBadge('${r['method']}()', tone: AnTone.accent),
            if ((r['triggeredBy'] as String?)?.isNotEmpty ?? false) AnBadge(_triggeredBy(t, r['triggeredBy'] as String?), tone: AnTone.none),
          ],
          subText: r['instanceId'] as String?,
          elapsed: r['elapsedMs'] is int ? fmtElapsed(r['elapsedMs'] as int) : null,
          stamp: fmtStamp(r['startedAt'] as String?),
        ),
    ]);

// agent executions — same slim as fn (DROP the transcript that ships with every list row). 丢弃 transcript。
Widget agentExecBody(BuildContext context, ToolCardState s) =>
    _aggBody(context, s.resultText, 'executions', (t, c, rows) => [for (final r in rows) _execRow(t, r)]);

// MCP calls — a tool chip; the row id is mcl_. serverId lives in the collapsed chip.
Widget mcpCallsBody(BuildContext context, ToolCardState s) => _aggBody(context, s.resultText, 'calls', (t, c, rows) => [
      for (final r in rows)
        RunLedgerRow(
          leading: RunLeading.status('${r['status']}'),
          monoId: r['id'] as String?,
          chips: [
            if ((r['tool'] as String?)?.isNotEmpty ?? false) AnBadge('${r['tool']}', tone: AnTone.accent),
            if ((r['triggeredBy'] as String?)?.isNotEmpty ?? false) AnBadge(_triggeredBy(t, r['triggeredBy'] as String?), tone: AnTone.none),
          ],
          elapsed: r['elapsedMs'] is int ? fmtElapsed(r['elapsedMs'] as int) : null,
          stamp: fmtStamp(r['startedAt'] as String?),
        ),
    ]);
