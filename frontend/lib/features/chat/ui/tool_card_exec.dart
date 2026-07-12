import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import 'log_drawer.dart';
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
/// output uses ToolIOSection's hard render rules (NEVER markdown-sniffed). While IN FLIGHT the
/// output section is withheld — «无返回值» before the tool returned would be a lie (WRK-065).
/// run_function 执行体;在飞不渲输出段(工具还没返回,渲「无返回值」=撒谎)。
Widget runFunctionBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final live = toolLive(state);
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
      LogDrawer(logs: logs),
    ],
    if (!live) ...[
      const SizedBox(height: AnSpace.s6),
      if (!ok && errorMsg != null && errorMsg.isNotEmpty)
        Padding(padding: const EdgeInsets.only(bottom: AnSpace.s2), child: Text(errorMsg, style: AnText.code.copyWith(color: c.danger), maxLines: 20, overflow: TextOverflow.ellipsis))
      else
        ToolIOSection(label: t.chat.tool.ioOutput, value: out?['output']),
      if (out != null)
        // 批3 条族:the family head with the exec domain words (状态→色单源 AnStatus). 域词覆盖。
        AnStatBar(
          status: ok ? AnStatus.done : AnStatus.err,
          statusLabel: ok ? t.chat.tool.execOk : t.chat.tool.execFailed,
          stats: [if (out['elapsedMs'] is int) AnStat(fmtElapsed(out['elapsedMs'] as int), tabular: true)],
        ),
    ],
  ]);
}

/// call_handler body — intent → input (`method` label + `args`) → the yields (LIVE: a directly-visible
/// terminal tail — the streaming show must not hide behind a second click; SETTLED: the logs drawer) →
/// output (`result`, settled only — «无返回值» before the tool returned would be a lie, WRK-065) →
/// exec result bar (no elapsed — the wire has none, never fabricate one).
/// call_handler 执行体:活期 yields 直显终端尾(流式主秀不藏第二次点击后)、落定收进日志抽屉;输出段仅落定
/// 渲(在飞渲「无返回值」=撒谎);无耗时字段,绝不编造。
Widget callHandlerBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final live = toolLive(state);
  final out = _obj(state.resultText);
  final method = argStringPartial(state.argsText, 'method');
  final input = _obj(state.argsText)?['args'];

  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    if (state.summary.isNotEmpty)
      Padding(padding: const EdgeInsets.only(bottom: AnSpace.s6), child: Text(state.summary, style: AnText.meta.copyWith(color: c.inkMuted))),
    if (method != null) Padding(padding: const EdgeInsets.only(bottom: AnSpace.s2), child: Text('$method()', style: AnText.mono.copyWith(color: c.inkMuted))),
    if (input != null) ToolIOSection(label: t.chat.tool.ioInput, value: input),
    // The streamed yields: LIVE = the rolling terminal tail (the show), SETTLED = the drawer (record).
    // yield 流:活=滚动终端尾(主秀),落定=抽屉(档案)。
    if (state.progressText.isNotEmpty) ...[
      const SizedBox(height: AnSpace.s6),
      live ? AnLiveTail(state.progressText, tailLines: 12) : LogDrawer(logs: state.progressText),
    ],
    if (!live) ...[
      const SizedBox(height: AnSpace.s6),
      ToolIOSection(label: t.chat.tool.ioOutput, value: out?['result']),
    ],
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

/// invoke_agent body — input → the nested trajectory (LIVE: streaming with the shimmer tail; SETTLED
/// in-tree: the full pane; reloaded: the get_agent_execution replay note) → output (prose if a free-text
/// string, per-key if a declared-output object; settled only — «无返回值» mid-run would lie, WRK-065) →
/// errorMsg (red) → stat bar (status·steps·↑in ↓out·elapsed·agent pill·executionId copy).
/// invoke_agent 体:活=嵌套轨迹流式(shimmer 尾);落定在树=全轨迹、重载=档案回放注;输出段仅落定渲。
Widget invokeAgentBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final live = toolLive(state);
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
    // The nested trajectory: streaming (live) or still in the tree (settled this session). Once gone
    // (a history reload — E3 blocks aren't persisted) state that honestly — but only when SETTLED: the
    // replay note mid-run would misread as «already archived». 轨迹:活=流式嵌套;重载注仅落定渲(在飞渲
    // 「档案回放」误读)。
    if (state.nested.isNotEmpty) ...[
      const SizedBox(height: AnSpace.s6),
      NestedRunPane(nested: state.nested, live: live),
    ] else if (!live) ...[
      const SizedBox(height: AnSpace.s6),
      Text(t.chat.tool.agentTrajectoryNote, style: AnText.meta.copyWith(color: c.inkFaint)),
    ],
    if (!live) ...[
      const SizedBox(height: AnSpace.s6),
      if (!ok && errorMsg != null && errorMsg.isNotEmpty)
        Padding(padding: const EdgeInsets.only(bottom: AnSpace.s2), child: Text(errorMsg, style: AnText.code.copyWith(color: c.danger), maxLines: 20, overflow: TextOverflow.ellipsis))
      else
        // A free-text final answer → prose; a declared-output object → per-key (ToolIOSection rules).
        // 自由文本终答→散文;声明输出对象→逐键。
        ToolIOSection(label: t.chat.tool.ioOutput, value: outputVal, renderAsProse: outputVal is String),
      if (out != null) _invokeStatBar(context, out, agentId),
    ],
  ]);
}

/// The invoke stat bar (批3 条族: a mapping onto the family head) — status word · steps ·
/// ↑tokensIn ↓tokensOut · elapsed · a navigable agent pill · the executionId (copy).
/// invoke 结果条:映射进当家件。
Widget _invokeStatBar(BuildContext context, Map<String, dynamic> result, String? agentId) {
  final t = Translations.of(context);
  final status = result['status'] as String? ?? '';
  final execId = result['executionId'] as String?;
  return AnStatBar(
    // 'timeout' has NO AnStatus.fromRaw alias (it would fold to idle and LOSE the danger tone) —
    // the explicit switch is load-bearing. timeout 无 fromRaw 别名(会折 idle 丢危险色),显式映射承重。
    status: switch (status) {
      'ok' => AnStatus.done,
      'failed' || 'timeout' => AnStatus.err,
      _ => AnStatus.idle,
    },
    statusLabel: switch (status) {
      'ok' => t.chat.tool.runCompleted,
      'failed' => t.chat.tool.failed,
      'timeout' => t.chat.tool.agentTimeout,
      'cancelled' => t.chat.tool.runCancelled,
      _ => status,
    },
    stats: [
      if (result['steps'] is int) AnStat(t.chat.tool.agentSteps(n: '${result['steps']}'), tabular: true),
      if (result['tokensIn'] is int && result['tokensOut'] is int)
        AnStat('↑${result['tokensIn']} ↓${result['tokensOut']}', tabular: true),
      if (result['elapsedMs'] is int) AnStat(fmtElapsed(result['elapsedMs'] as int), tabular: true),
    ],
    chips: [
      if (agentId != null && agentId.isNotEmpty) toolNavPill(context, kind: 'agent', label: agentId, id: agentId),
      if (execId != null && execId.isNotEmpty) AnChip(execId, look: AnChipLook.outlined, mono: true, copyValue: execId, tooltip: execId),
    ],
  );
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
  return (text: truncate(act, AnTrunc.id), tone: ToolReceiptTone.none);
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
      // The label prefix rides beside the chip (the head has no prefix slot). 前缀作芯片旁灰字。
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text(t.chat.tool.fireActivation, style: AnText.meta.copyWith(color: c.inkFaint)),
        const SizedBox(width: AnGap.inline),
        Flexible(child: AnChip(act, look: AnChipLook.outlined, mono: true, copyValue: act, tooltip: act)),
      ]),
    ],
    const SizedBox(height: AnSpace.s6),
    Text(t.chat.tool.firePayloadNote, style: AnText.meta.copyWith(color: c.inkFaint)),
  ]);
}

