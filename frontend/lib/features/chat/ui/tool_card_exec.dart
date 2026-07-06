import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import 'tool_card_io_section.dart';
import 'tool_card_nav.dart';
import 'tool_card_skins.dart';
import 'transcript_peek.dart';

// F08 exec bodies (B5) — «input → black box → output» made auditable. run_function / call_handler share
// the ExecutionResult shape ({ok, output, errorMsg, elapsedMs, logs?}); the body is intent → input
// section → (logs drawer) → output section → exec result bar. F08 执行体:输入→黑箱→输出的可核账凭据。

Map<String, dynamic>? _obj(String s) {
  try {
    final d = jsonDecode(s);
    if (d is Map<String, dynamic>) return d;
  } catch (_) {}
  return null;
}

/// The ExecutionResult receipt — ok → the elapsed time; ok:false → a red «运行失败 · elapsed» (auto-
/// expand); unparseable → no receipt. ExecutionResult 回执:成功耗时 / 失败红。
ToolReceipt? execReceipt(Translations t, String output) {
  final o = _obj(output);
  if (o == null || o['ok'] is! bool) return null;
  final ok = o['ok'] == true;
  final elapsed = o['elapsedMs'] is int ? fmtElapsed(o['elapsedMs'] as int) : null;
  if (ok) return elapsed == null ? null : (text: elapsed, tone: ToolReceiptTone.none);
  final label = elapsed == null ? t.chat.tool.execFailed : '${t.chat.tool.execFailed} · $elapsed';
  return (text: label, tone: ToolReceiptTone.danger);
}

/// Whether an ExecutionResult reports a payload failure (ok:false — «green but broken»). ok:false→失败。
bool execResultFailed(String output) => _obj(output)?['ok'] == false;

/// run_function body — intent → input (`args.args`) → logs drawer → output → exec result bar. The
/// output uses ToolIOSection's hard render rules (NEVER markdown-sniffed). run_function 执行体。
Widget runFunctionBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final out = _obj(state.resultText);
  final input = _obj(state.argsText)?['args'];
  final logs = out?['logs'] as String?;
  final errorMsg = out?['errorMsg'] as String?;
  final ok = out?['ok'] == true;

  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    if (state.summary.isNotEmpty)
      Padding(padding: const EdgeInsets.only(bottom: AnSpace.s6), child: Text(state.summary, style: AnText.meta.copyWith(color: c.inkMuted))),
    if (input != null) ToolIOSection(label: t.chat.tool.ioInput, value: input),
    if (logs != null && logs.isNotEmpty) ...[
      const SizedBox(height: AnSpace.s6),
      _LogsDrawer(logs: logs),
    ],
    const SizedBox(height: AnSpace.s6),
    if (!ok && errorMsg != null && errorMsg.isNotEmpty)
      Padding(padding: const EdgeInsets.only(bottom: AnSpace.s2), child: Text(errorMsg, style: AnText.code.copyWith(color: c.danger), maxLines: 20, overflow: TextOverflow.ellipsis))
    else
      ToolIOSection(label: t.chat.tool.ioOutput, value: out?['output']),
    if (out != null) ExecResultBar(ok: ok, elapsedMs: out['elapsedMs'] is int ? out['elapsedMs'] as int : null),
  ]);
}

/// call_handler body — intent → input (`method` label + `args`) → streamed-output drawer (progress) →
/// output (`result`) → exec result bar (no elapsed — the wire has none, never fabricate one). call_handler
/// 执行体(无耗时字段,绝不编造)。
Widget callHandlerBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final out = _obj(state.resultText);
  final method = argString(state.argsText, 'method');
  final input = _obj(state.argsText)?['args'];

  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    if (state.summary.isNotEmpty)
      Padding(padding: const EdgeInsets.only(bottom: AnSpace.s6), child: Text(state.summary, style: AnText.meta.copyWith(color: c.inkMuted))),
    if (method != null) Padding(padding: const EdgeInsets.only(bottom: AnSpace.s2), child: Text('$method()', style: AnText.mono.copyWith(color: c.inkMuted))),
    if (input != null) ToolIOSection(label: t.chat.tool.ioInput, value: input),
    // The streamed yields (if any) are the progress log. yield 流(如有)。
    if (state.progressText.isNotEmpty) ...[
      const SizedBox(height: AnSpace.s6),
      _LogsDrawer(logs: state.progressText),
    ],
    const SizedBox(height: AnSpace.s6),
    ToolIOSection(label: t.chat.tool.ioOutput, value: out?['result']),
  ]);
}

// ── invoke_agent — run an agent, SETTLED body (the live NestedRunPane is B6) ──
// Wire: InvokeResult {executionId, ok, output, status(ok|failed|cancelled|timeout), stopReason?, steps,
// tokensIn, tokensOut, errorMsg?, elapsedMs}. The E3 nested trajectory is EPHEMERAL (streamed only, not
// in message_blocks) — on reload the card shows the collapsed summary + output + stat bar; the full
// trajectory is replayed from the Execution record (get_agent_execution). invoke_agent 落定体。

/// The invoke receipt — ok→`{steps} 步·{elapsed}`; failed/timeout→red status word (auto-expand);
/// cancelled→grey `已取消` (NOT auto-expand — the user stopped it, red would be noise). invoke 回执。
ToolReceipt? invokeReceipt(Translations t, String output) {
  final o = _obj(output);
  final status = o?['status'];
  if (status is! String) return null;
  final elapsed = o!['elapsedMs'] is int ? fmtElapsed(o['elapsedMs'] as int) : null;
  final steps = o['steps'] is int ? o['steps'] as int : null;
  switch (status) {
    case 'ok':
      final head = steps == null ? null : t.chat.tool.agentSteps(n: '$steps');
      final txt = [head, elapsed].where((s) => s != null).join(' · ');
      return txt.isEmpty ? null : (text: txt, tone: ToolReceiptTone.none);
    case 'failed':
      return (text: t.chat.tool.failed, tone: ToolReceiptTone.danger);
    case 'timeout':
      return (text: t.chat.tool.agentTimeout, tone: ToolReceiptTone.danger);
    case 'cancelled':
      return (text: t.chat.tool.runCancelled, tone: ToolReceiptTone.none);
    default:
      return null;
  }
}

/// Whether the invoke failed/timed out (auto-expand for diagnosis; cancelled does NOT). 失败/超时→展开。
bool invokeResultFailed(String output) {
  final s = _obj(output)?['status'];
  return s == 'failed' || s == 'timeout';
}

/// invoke_agent SETTLED body — input → (a trajectory-streamed note) → output (prose if a free-text
/// string, per-key if a declared-output object) → errorMsg (red) → stat bar (status·steps·↑in ↓out·
/// elapsed·agent pill·executionId copy). invoke_agent 落定体(活期 NestedRunPane 属 B6)。
Widget invokeAgentBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final out = _obj(state.resultText);
  final input = _obj(state.argsText)?['input'];
  final agentId = argString(state.argsText, 'agentId');
  final status = out?['status'] as String?;
  final ok = status == 'ok';
  final outputVal = out?['output'];
  final errorMsg = out?['errorMsg'] as String?;

  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    if (state.summary.isNotEmpty)
      Padding(padding: const EdgeInsets.only(bottom: AnSpace.s6), child: Text(state.summary, style: AnText.meta.copyWith(color: c.inkMuted))),
    if (input != null) ToolIOSection(label: t.chat.tool.ioInput, value: input),
    const SizedBox(height: AnSpace.s6),
    // The nested trajectory: while the E3 subtree is still in the tree (live session) show it; once it's
    // gone (a history reload — E3 blocks aren't persisted) state that honestly (the durable record is
    // get_agent_execution). 轨迹:在树上就显嵌套,重载后诚实注明去执行档案回放。
    if (state.nested.isNotEmpty)
      NestedRunPane(nested: state.nested)
    else
      Text(t.chat.tool.agentTrajectoryNote, style: AnText.meta.copyWith(color: c.inkFaint)),
    const SizedBox(height: AnSpace.s6),
    if (!ok && errorMsg != null && errorMsg.isNotEmpty)
      Padding(padding: const EdgeInsets.only(bottom: AnSpace.s2), child: Text(errorMsg, style: AnText.code.copyWith(color: c.danger), maxLines: 20, overflow: TextOverflow.ellipsis))
    else
      // A free-text final answer → prose; a declared-output object → per-key (ToolIOSection rules).
      // 自由文本终答→散文;声明输出对象→逐键。
      ToolIOSection(label: t.chat.tool.ioOutput, value: outputVal, renderAsProse: outputVal is String),
    if (out != null) _InvokeStatBar(result: out, agentId: agentId),
  ]);
}

/// invoke_agent LIVE body — the E3 nested trajectory streaming under the card (empty until the first
/// nested block arrives). invoke_agent 活期:嵌套轨迹活窗。
Widget invokeAgentLiveBody(BuildContext context, ToolCardState state) =>
    state.nested.isEmpty ? const SizedBox.shrink() : NestedRunPane(nested: state.nested, live: true);

/// The invoke stat bar — status word (colored) · steps · ↑tokensIn ↓tokensOut · elapsed · a navigable
/// agent pill (agentId) · the executionId (copy). invoke 结果条。
class _InvokeStatBar extends StatelessWidget {
  const _InvokeStatBar({required this.result, this.agentId});
  final Map<String, dynamic> result;
  final String? agentId;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final status = result['status'] as String? ?? '';
    final word = switch (status) {
      'ok' => t.chat.tool.runCompleted,
      'failed' => t.chat.tool.failed,
      'timeout' => t.chat.tool.agentTimeout,
      'cancelled' => t.chat.tool.runCancelled,
      _ => status,
    };
    final tone = switch (status) {
      'ok' => AnTone.ok,
      'failed' || 'timeout' => AnTone.danger,
      _ => AnTone.none,
    };
    final steps = result['steps'] is int ? result['steps'] as int : null;
    final tin = result['tokensIn'] is int ? result['tokensIn'] as int : null;
    final tout = result['tokensOut'] is int ? result['tokensOut'] as int : null;
    final elapsed = result['elapsedMs'] is int ? fmtElapsed(result['elapsedMs'] as int) : null;
    final execId = result['executionId'] as String?;
    return Padding(
      padding: const EdgeInsets.only(top: AnSpace.s6),
      child: Wrap(spacing: AnGap.inline, runSpacing: AnSpace.s4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        AnBadge(word, tone: tone),
        if (steps != null) Text(t.chat.tool.agentSteps(n: '$steps'), style: AnText.metaTabular().copyWith(color: c.inkMuted)),
        if (tin != null && tout != null)
          Text('↑$tin ↓$tout', style: AnText.metaTabular().copyWith(color: c.inkFaint)),
        if (elapsed != null) Text(elapsed, style: AnText.metaTabular().copyWith(color: c.inkMuted)),
        if (agentId != null && agentId!.isNotEmpty) toolNavPill(context, kind: 'agent', label: agentId!, id: agentId),
        if (execId != null && execId.isNotEmpty) AnCopyChip(value: execId),
      ]),
    );
  }
}

// ── fire_trigger — the thin activation card ──
// Wire: {fired:true, triggerId, activationId}. NO custom payload (the synthetic fire payload is always
// {manual:true}); the fan-out count is NOT in the return (a zero-fan-out fire still records an
// activation) — so the card never fabricates a fan-out number, it points at the trigger log instead.
// fire_trigger 薄卡:三键;无 payload、扇出不在返回里(绝不编造扇出数)。

/// The activationId receipt (act_… truncated); null if unparseable. Never danger — the tool only
/// lights the fuse, so a return IS success. fire 回执:活化 id 截断;永不危险色(点火即成功)。
ToolReceipt? fireReceipt(Translations t, String output) {
  final act = _obj(output)?['activationId'];
  if (act is! String || act.isEmpty) return null;
  return (text: act.length > 12 ? '${act.substring(0, 12)}…' : act, tone: ToolReceiptTone.none);
}

/// fire_trigger body — the fired conclusion + a navigable trigger pill + the full activationId (copy) +
/// a fixed grey note (payload is always {manual:true}; fan-out lives in the trigger log). fire 落定体。
Widget fireTriggerBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final triggerId = argString(state.argsText, 'triggerId');
  final act = _obj(state.resultText)?['activationId'] as String?;
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    // The navigable trigger (its icon reads «trigger X»; opens the trigger panel to see activations).
    // 可导航触发器药丸(图标即「触发器 X」,点开去看活化)。
    if (triggerId != null) toolNavPill(context, kind: 'trigger', label: triggerId, id: triggerId),
    if (act != null && act.isNotEmpty) ...[
      const SizedBox(height: AnSpace.s6),
      AnCopyChip(value: act, label: t.chat.tool.fireActivation),
    ],
    const SizedBox(height: AnSpace.s6),
    Text(t.chat.tool.firePayloadNote, style: AnText.meta.copyWith(color: c.inkFaint)),
  ]);
}

/// A «日志 · N 行» disclosure over a capped mono window. 日志抽屉。
class _LogsDrawer extends StatefulWidget {
  const _LogsDrawer({required this.logs});
  final String logs;
  @override
  State<_LogsDrawer> createState() => _LogsDrawerState();
}

class _LogsDrawerState extends State<_LogsDrawer> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    final n = '\n'.allMatches(widget.logs.trimRight()).length + 1;
    final over = widget.logs.length > 6000;
    final shown = over ? widget.logs.substring(widget.logs.length - 6000) : widget.logs;
    return AnDisclosure(
      label: t.chat.tool.execLogs(n: '$n'),
      open: _open,
      onToggle: () => setState(() => _open = !_open),
      child: _open
          ? ToolWindow(child: Text(shown, style: AnText.code.copyWith(color: c.inkFaint), maxLines: 200, overflow: TextOverflow.ellipsis))
          : null,
    );
  }
}
