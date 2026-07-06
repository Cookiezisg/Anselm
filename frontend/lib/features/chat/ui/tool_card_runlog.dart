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
import '../../../core/messages/block_tree_reducer.dart';
import '../../../core/messages/transcript_hydration.dart';
import 'run_dossier.dart';
import 'run_ledger.dart';
import 'transcript_peek.dart';
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

// ── count families (no aggregates: flowruns / firings / activations) ──

/// The count receipt — `{n} 条` / `{n}+ 条` (hasMore). These families carry NO aggregates → we never
/// fabricate a ✓/✗ split. Empty → 无记录 (this query found nothing). 计数回执:无聚合、不编造 ✓✗。
ToolReceipt? countListReceipt(Translations t, String output, String listKey) {
  final o = _obj(output);
  if (o == null) return null;
  final n = o['count'] is int ? o['count'] as int : (o[listKey] is List ? (o[listKey] as List).length : 0);
  final more = o['hasMore'] == true || ((o['nextCursor'] as String?)?.isNotEmpty ?? false);
  if (n == 0) return (text: t.chat.tool.logNoRecords, tone: ToolReceiptTone.none);
  return (text: more ? t.chat.tool.logCountMore(n: '$n') : t.chat.tool.logCount(n: '$n'), tone: ToolReceiptTone.none);
}

bool countListHasBody(String output, String listKey) {
  final o = _obj(output);
  if (o == null) return false;
  final n = o['count'] is int ? o['count'] as int : (o[listKey] is List ? (o[listKey] as List).length : 0);
  return n > 0;
}

/// The shared count-family body — a page-scoped bead strip (no global aggregate) + a slim RunLedger.
/// 计数族共享体(珠串标「本页」,无全局聚合)。
Widget _countBody(BuildContext context, String output, String listKey,
    {required List<RunLedgerRow> Function(Translations, AnColors, List<Map<String, dynamic>>) mapRows,
    List<RunBead> Function(AnColors, List<Map<String, dynamic>>)? beads,
    String? caption}) {
  final c = context.colors;
  final t = Translations.of(context);
  final rows = _list(output, listKey);
  final more = _obj(output)?['hasMore'] == true || ((_obj(output)?['nextCursor'] as String?)?.isNotEmpty ?? false);
  if (rows.isEmpty) return Text(t.chat.tool.logNoMatch, style: AnText.code.copyWith(color: c.inkFaint));
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    RunBeadStrip(beads: beads?.call(c, rows) ?? [for (final r in rows) _bead(c, r)], pageScoped: true),
    const SizedBox(height: AnSpace.s6),
    ToolWindow(child: RunLedger(rows: mapRows(t, c, rows))),
    if (caption != null) Padding(padding: const EdgeInsets.only(top: AnSpace.s4), child: Text(caption, style: AnText.meta.copyWith(color: c.inkFaint))),
    if (more) Padding(padding: const EdgeInsets.only(top: AnSpace.s4), child: Text('${rows.length}+', style: AnText.meta.copyWith(color: c.inkFaint))),
  ]);
}

// search_flowruns — {runs:[FlowRun]} (status running|completed|failed|cancelled; replayCount; error?).
// pageScoped beads; a replay× micro-badge; the run-level error as subtext; a parked-run caption.
Widget flowrunsBody(BuildContext context, ToolCardState s) => _countBody(context, s.resultText, 'runs',
    caption: Translations.of(context).chat.tool.parkRunCaption,
    mapRows: (t, c, rows) => [
          for (final r in rows)
            RunLedgerRow(
              leading: RunLeading.status('${r['status']}'),
              monoId: r['id'] as String?,
              chips: [
                if ((r['replayCount'] is int ? r['replayCount'] as int : 0) > 0)
                  AnBadge(t.chat.tool.replayTimes(n: '${r['replayCount']}'), tone: AnTone.none),
              ],
              subText: r['error'] as String?,
              stamp: fmtStamp(r['startedAt'] as String?),
            ),
        ]);

/// A localized firing disposition (pending|started|skipped|superseded|shed). 派发处置词。
String _firingWord(Translations t, String? status) => switch (status) {
      'pending' => t.chat.tool.firingPending,
      'started' => t.chat.tool.firingStarted,
      'skipped' => t.chat.tool.firingSkipped,
      'superseded' => t.chat.tool.firingSuperseded,
      'shed' => t.chat.tool.firingShed,
      _ => status ?? '',
    };

AnTone _firingTone(String? status) => switch (status) {
      'started' => AnTone.ok,
      'pending' => AnTone.warn,
      _ => AnTone.none, // skipped / superseded / shed → grey
    };

// search_firings — {firings:[Firing]} (status pending|started|skipped|superseded|shed). A disposition
// badge; started rows carry a flowrunId; the dedupKey is faint subtext.
Widget firingsBody(BuildContext context, ToolCardState s) => _countBody(context, s.resultText, 'firings',
    mapRows: (t, c, rows) => [
          for (final r in rows)
            RunLedgerRow(
              leading: RunLeading.status('${r['status']}'),
              monoId: r['id'] as String?,
              chips: [
                AnBadge(_firingWord(t, r['status'] as String?), tone: _firingTone(r['status'] as String?)),
                if ((r['flowrunId'] as String?)?.isNotEmpty ?? false)
                  AnBadge('${(r['flowrunId'] as String).length > 12 ? '${(r['flowrunId'] as String).substring(0, 12)}…' : r['flowrunId']}', tone: AnTone.none),
              ],
              subText: r['dedupKey'] as String?,
              stamp: fmtStamp(r['createdAt'] as String?),
            ),
        ]);

// search_activations — {activations:[Activation]} (fired bool; kind; returnValue?; firingCount; detail?).
// The leading is a fired mark (not a status dot); the returnValue (which CAN be large) is a lazy inline
// tree; detail is the subtext. 活化:fire 标记 + returnValue 惰性行内树。
Widget activationsBody(BuildContext context, ToolCardState s) => _countBody(context, s.resultText, 'activations',
    beads: (c, rows) => [
          for (final r in rows)
            RunBead(color: r['fired'] == true ? c.ok : c.inkFaint, tooltip: '${r['id']} · ${r['fired'] == true ? 'fired' : 'not fired'}'),
        ],
    mapRows: (t, c, rows) => [
          for (final r in rows)
            RunLedgerRow(
              leading: RunLeading.fired(r['fired'] == true),
              monoId: r['id'] as String?,
              chips: [
                if ((r['kind'] as String?)?.isNotEmpty ?? false) AnBadge('${r['kind']}', tone: AnTone.none),
                if ((r['firingCount'] is int ? r['firingCount'] as int : 0) > 0)
                  AnBadge(t.chat.tool.actFanout(n: '${r['firingCount']}'), tone: AnTone.none),
              ],
              subText: r['detail'] as String? ?? r['error'] as String?,
              stamp: fmtStamp(r['createdAt'] as String?),
              // The sensor probe value — kept even when not fired, and CAN be large → a lazy inline tree.
              // 探测返回值(未 fire 也留、可大)→ 惰性行内树。
              expandContent: (r['returnValue'] is Map && (r['returnValue'] as Map).isNotEmpty)
                  ? ToolIOSection(label: t.chat.tool.actReturnValue, value: r['returnValue'])
                  : null,
            ),
        ]);

// ── F09 get-record cards (B5.8): the thin dossiers (fn exec / hd call / mcp call / activation) ──
// fn/hd/mcp share the Execution/Call shape → RunDossier; activation is a distinct fire-record (no
// input/output/logs) → a bespoke thin body. get 卷宗卡。

/// The status·elapsed receipt for a fn/hd/mcp record (failed/timeout → danger auto-expand). get 回执。
ToolReceipt? execRecordReceipt(Translations t, String output) {
  final o = _obj(output);
  if (o == null) return null;
  return statusElapsedReceipt(t, o['status'] as String?, o['elapsedMs'] is int ? o['elapsedMs'] as int : null);
}

bool execRecordFailed(String output) {
  final s = _obj(output)?['status'];
  return s == 'failed' || s == 'timeout';
}

Widget _dossier(BuildContext context, ToolCardState s, {List<Widget> Function(Translations, Map<String, dynamic>)? headChips}) {
  final t = Translations.of(context);
  final o = _obj(s.resultText);
  if (o == null) {
    return Text(s.resultText, style: AnText.code.copyWith(color: context.colors.inkMuted), maxLines: 40, overflow: TextOverflow.ellipsis);
  }
  return RunDossier(
    status: '${o['status']}',
    triggeredBy: o['triggeredBy'] as String?,
    elapsedMs: o['elapsedMs'] is int ? o['elapsedMs'] as int : null,
    startedAt: o['startedAt'] as String?,
    endedAt: o['endedAt'] as String?,
    headChips: headChips?.call(t, o) ?? const [],
    input: o['input'],
    output: o['output'],
    errorMessage: o['errorMessage'] as String?,
    logs: o['logs'] as String?,
    provenance: ProvenanceLine(
      conversationId: o['conversationId'] as String?,
      messageId: o['messageId'] as String?,
      flowrunId: o['flowrunId'] as String?,
      nodeId: o['flowrunNodeId'] as String?,
      iteration: o['flowrunIteration'] is int ? o['flowrunIteration'] as int : null,
    ),
  );
}

Widget getFnExecBody(BuildContext context, ToolCardState s) => _dossier(context, s);

Widget getHdCallBody(BuildContext context, ToolCardState s) => _dossier(context, s, headChips: (t, o) => [
      if ((o['method'] as String?)?.isNotEmpty ?? false) AnBadge('${o['method']}()', tone: AnTone.accent),
      if ((o['instanceId'] as String?)?.isNotEmpty ?? false) AnBadge('${o['instanceId']}', tone: AnTone.none),
    ]);

Widget getMcpCallBody(BuildContext context, ToolCardState s) => _dossier(context, s, headChips: (t, o) => [
      if ((o['tool'] as String?)?.isNotEmpty ?? false) AnBadge('${o['tool']}', tone: AnTone.accent),
    ]);

/// The activation fire receipt — fired → `已 fire · 扇出 N`; not fired → grey `未 fire`; an error present
/// (a probe failure) → danger. 活化回执:fire 结论。
ToolReceipt? activationFireReceipt(Translations t, String output) {
  final o = _obj(output);
  if (o == null || o['fired'] is! bool) return null;
  final err = (o['error'] as String?)?.isNotEmpty ?? false;
  if (o['fired'] == true) {
    final fanout = o['firingCount'] is int ? o['firingCount'] as int : 0;
    final txt = fanout > 0 ? '${t.chat.tool.fireYes} · ${t.chat.tool.actFanout(n: '$fanout')}' : t.chat.tool.fireYes;
    return (text: txt, tone: err ? ToolReceiptTone.danger : ToolReceiptTone.none);
  }
  return (text: t.chat.tool.fireNo, tone: err ? ToolReceiptTone.danger : ToolReceiptTone.none);
}

bool activationRecordFailed(String output) => (_obj(output)?['error'] as String?)?.isNotEmpty ?? false;

/// get_activation body — a thin fire record (NO causal chain: the source is just a kind badge). Fire
/// conclusion + kind + returnValue tree + payload window + error window + a trigger provenance pill.
/// get_activation 薄卷宗:fire 结论 + returnValue + payload + error + 触发器出处。
Widget getActivationBody(BuildContext context, ToolCardState s) {
  final c = context.colors;
  final t = Translations.of(context);
  final o = _obj(s.resultText);
  if (o == null) return Text(s.resultText, style: AnText.code.copyWith(color: c.inkMuted));
  final fired = o['fired'] == true;
  final err = o['error'] as String?;
  final detail = o['detail'] as String?;
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    Wrap(spacing: AnGap.inline, runSpacing: AnSpace.s4, crossAxisAlignment: WrapCrossAlignment.center, children: [
      AnBadge(fired ? t.chat.tool.fireYes : t.chat.tool.fireNo, tone: fired ? AnTone.ok : AnTone.none),
      if ((o['kind'] as String?)?.isNotEmpty ?? false) AnBadge('${o['kind']}', tone: AnTone.none),
      if ((o['firingCount'] is int ? o['firingCount'] as int : 0) > 0) Text(t.chat.tool.actFanout(n: '${o['firingCount']}'), style: AnText.meta.copyWith(color: c.inkFaint)),
    ]),
    if (detail != null && detail.isNotEmpty) Padding(padding: const EdgeInsets.only(top: AnSpace.s4), child: Text(detail, style: AnText.meta.copyWith(color: c.inkMuted))),
    if (o['returnValue'] is Map && (o['returnValue'] as Map).isNotEmpty) ...[
      const SizedBox(height: AnSpace.s6),
      ToolIOSection(label: t.chat.tool.actReturnValue, value: o['returnValue']),
    ],
    if (o['payload'] is Map && (o['payload'] as Map).isNotEmpty) ...[
      const SizedBox(height: AnSpace.s6),
      ToolIOSection(label: t.chat.tool.ioInput, value: o['payload']),
    ],
    if (err != null && err.isNotEmpty) ...[
      const SizedBox(height: AnSpace.s6),
      ToolWindow(child: Text(err, style: AnText.code.copyWith(color: c.danger), maxLines: 20, overflow: TextOverflow.ellipsis)),
    ],
    const SizedBox(height: AnSpace.s6),
    ProvenanceLine(triggerId: o['triggerId'] as String?),
  ]);
}

// ── get_agent_execution (B5.10): the heavy dossier with a TranscriptPeek ──
// AgentExecution {status, triggeredBy, input, output?, transcript, errorMessage?, elapsedMs, modelId?,
// provider?, ...provenance} — NO logs field (the transcript IS the record). The body is a RunDossier
// (head + modelId/provider micro + input/output) with the hydrated trajectory as its extra section.
// get_agent_execution 重卡:卷宗 + 轨迹目录。

Widget getAgentExecBody(BuildContext context, ToolCardState s) {
  final o = _obj(s.resultText);
  if (o == null) {
    return Text(s.resultText, style: AnText.code.copyWith(color: context.colors.inkMuted), maxLines: 40, overflow: TextOverflow.ellipsis);
  }
  final transcript = o['transcript'];
  final roots = transcript is List ? hydrateTranscriptTree(transcript, scopeId: '${o['conversationId'] ?? ''}') : const <BlockNode>[];
  final failed = o['status'] == 'failed' || o['status'] == 'timeout';
  return RunDossier(
    status: '${o['status']}',
    triggeredBy: o['triggeredBy'] as String?,
    elapsedMs: o['elapsedMs'] is int ? o['elapsedMs'] as int : null,
    startedAt: o['startedAt'] as String?,
    endedAt: o['endedAt'] as String?,
    headChips: [
      if ((o['modelId'] as String?)?.isNotEmpty ?? false) AnBadge('${o['modelId']}', tone: AnTone.none),
      if ((o['provider'] as String?)?.isNotEmpty ?? false) AnBadge('${o['provider']}', tone: AnTone.none),
    ],
    input: o['input'],
    output: o['output'],
    errorMessage: o['errorMessage'] as String?,
    // The trajectory — hydrated from Execution.transcript through the SHARED adapter (live-path parity).
    // 轨迹:经共享适配器从 Execution.transcript 水合(与 live 路径同构)。
    extra: transcript is List
        ? TranscriptPeek(roots: roots, totalBlocks: transcript.length, failed: failed)
        : null,
    provenance: ProvenanceLine(
      conversationId: o['conversationId'] as String?,
      messageId: o['messageId'] as String?,
      flowrunId: o['flowrunId'] as String?,
      nodeId: o['flowrunNodeId'] as String?,
      iteration: o['flowrunIteration'] is int ? o['flowrunIteration'] as int : null,
    ),
  );
}
