import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/an_disclosure.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import 'tool_card_io_section.dart';
import 'tool_card_skins.dart';

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
